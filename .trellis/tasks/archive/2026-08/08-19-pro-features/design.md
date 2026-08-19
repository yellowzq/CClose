# 设计：高级设置对话框 + 无标题栏支持 + Esc 黑名单 + 透明度

## 模块结构（复用现有拆分）

```
src/
├── win32.zig      # 新增：透明度/窗口信息/控件样式等绑定
├── hooks.zig      # 改：例外列表→工作区语义；新增 Ctrl+滚轮透明度
├── settings.zig   # 新模块：高级设置对话框（自包含 Win32 控件）
├── config.zig     # 改：新增 EnableTransparency；列表存取不变
├── lang.zig       # 改：新增对话框文案（中英双分支）
├── tray.zig       # 不变
├── tooltip.zig    # 不变
└── main.zig       # 改：托盘菜单加「设置」，调 settings.show()
```

依赖：`settings → win32, config, lang, hooks(?)`；`main → settings`；`hooks → win32, config, tooltip`。无环。

## 1. win32.zig 新增绑定（全 `pub`）

**extern（user32）**：`SetLayeredWindowAttributes(HWND, u32 crKey, u8 bAlpha, u32 dwFlags) BOOL`、`GetLayeredWindowAttributes(HWND, ?*u32, ?*u8, ?*u32) BOOL`、`GetWindowTextW(HWND, [*]u16, i32) i32`、`GetAsyncKeyState(i32) i16`、`GetAncestor(HWND, u32) HWND`、`SetFocus(HWND) ?HWND`、`EnableWindow(HWND, BOOL) BOOL`、`IsWindowEnabled(HWND) BOOL`、`GetDlgItem(HWND, i32) ?HWND`。
**extern（kernel32）**：`OpenProcess(u32, BOOL, u32) ?HANDLE`、`QueryFullProcessImageNameW(?HANDLE, u32, [*]u16, *u32) BOOL`、`CloseHandle(?HANDLE) BOOL`。
**extern（user32 已有无需加）**：`GetClassNameW`、`GetWindowThreadProcessId`、`WindowFromPoint`、`SetWindowLongW`、`GetWindowLongW`。

**常量**：
- `WS_EX_LAYERED = 0x00080000`、`LWA_ALPHA = 2`
- `VK_CONTROL = 0x11`（DWORD）
- `PROCESS_QUERY_INFORMATION = 0x0400`、`PROCESS_QUERY_LIMITED_INFORMATION = 0x1000`、`PROCESS_VM_READ = 0x0010`
- 控件/窗口样式：`WS_CHILD=0x40000000`、`WS_VISIBLE=0x10000000`、`WS_CAPTION=0x00C00000`、`WS_SYSMENU=0x00080000`、`WS_VSCROLL=0x00200000`、`WS_TABSTOP=0x00010000`、`WS_GROUP=0x00020000`、`WS_CLIPSIBLINGS=0x04000000`
- 控件样式：`BS_AUTOCHECKBOX=0x0003`、`BS_GROUPBOX=0x0007`、`BS_PUSHBUTTON=0x0000`、`SS_LEFT=0x0000`、`ES_AUTOHSCROLL=0x0080`、`ES_READONLY=0x0800`、`LBS_NOTIFY=0x0001`
- 控件消息：`BM_GETCHECK=0x00F0`、`BM_SETCHECK=0x00F1`、`LB_ADDSTRING=0x0180`、`LB_GETCURSEL=0x0188`、`LB_DELETESTRING=0x0182`、`LB_RESETCONTENT=0x0184`、`LB_GETCOUNT=0x018B`、`LB_GETTEXTLEN=0x018A`、`LB_GETTEXT=0x0189`、`WM_GETTEXT=0x000D`、`WM_SETTEXT=0x000C`、`WM_GETTEXTLENGTH=0x000E`、`WM_COMMAND`(已有)
- `GA_ROOT = 2`、`GWL_EXSTYLE`(已有)、`WM_MOUSEWHEEL = 0x020A`、`WM_GETDLGCODE` 不需要
- `IDC_*` 控件 ID：对话框内自定（见下）

## 2. config.zig 变更

```zig
pub const Config = struct {
    // ... 既有字段不变 ...
    enable_transparency: bool = true,
    // 新字段
};
```
- ini 键：`General/EnableTransparency`（readBool/writeBool），默认 true。
- `titlebar_exceptions`、`esc_blacklist` 读写逻辑不变；语义变更在 hooks.zig 落实。
- **工作区语义说明**：`titlebar_exceptions` 现为「对列入的窗口，标题栏功能作用于整个表面」。字段名与 ini 键保持 `TitleBarExceptionList` 以兼容旧配置。

## 3. hooks.zig 变更

### 3.1 例外列表 → 工作区语义（mouseHookProc）
原：`isCaptionAt(hwnd, x, y)` 命中后才检查例外并 **跳过**。
改：`isCaptionAt(hwnd, x, y) or isExceptionWindow(hwnd, g_config.titlebar_exceptions.items)` → 命中即应用标题栏功能（中键/右键/长按）。即列入列表的窗口整面视为标题栏。

```zig
const in_workarea = isCaptionAt(hwnd, ms.pt.x, ms.pt.y) or
    isExceptionWindow(hwnd, g_config.titlebar_exceptions.items);
if (in_workarea) {
    switch (wParam) { ... 原有 MBUTTONDOWN/RBUTTONDOWN/LBUTTONDOWN ... }
}
```
（isExceptionWindow 保留，供工作区与黑名单复用。）

### 3.2 Ctrl+滚轮透明度
mouseHookProc 增加 `WM_MOUSEWHEEL` 分支：

```zig
win32.WM_MOUSEWHEEL => {
    if (g_config.enable_transparency and (win32.GetAsyncKeyState(win32.VK_CONTROL) & 0x8000) != 0) {
        if (win32.WindowFromPoint(ms.pt)) |target| {
            adjustOpacity(target, @as(i32, @truncate(ms.mouseData >> 16)));  // ±120/格
            return 1;  // 消费消息，不传给目标程序
        }
    }
},
```

```zig
const MIN_ALPHA: u8 = 50;
const MAX_ALPHA: u8 = 255;
const ALPHA_STEP: i32 = 15;

fn adjustOpacity(hwnd: win32.HWND, wheel_delta: i32) void {
    var alpha: u8 = 255;
    var flags: u32 = 0;
    if (win32.GetLayeredWindowAttributes(hwnd, null, &alpha, &flags) == 0) {
        alpha = 255;  // 非分层窗口视为全不透明
    }
    const current: i32 = alpha;
    var next = current + @divTrunc(wheel_delta, 120) * ALPHA_STEP;
    next = std.math.clamp(next, MIN_ALPHA, MAX_ALPHA);
    const ex = win32.GetWindowLongW(hwnd, win32.GWL_EXSTYLE);
    const layered_ex = ex | @as(win32.LONG, @intCast(win32.WS_EX_LAYERED));
    _ = win32.SetWindowLongW(hwnd, win32.GWL_EXSTYLE, layered_ex);
    _ = win32.SetLayeredWindowAttributes(hwnd, 0, @intCast(next), win32.LWA_ALPHA);
}
```

> 注意：`WM_MOUSEWHEEL` 在低层钩子中 `ms.mouseData` 高字为带符号滚轮增量。返回 1 表示已处理，阻止目标程序再响应 Ctrl+滚轮。滚轮目标含 tooltip 提示窗等边缘情形，可忽略。

### 3.3 VK_CONTROL 说明
低层钩子不直接带修饰键信息，用 `GetAsyncKeyState(VK_CONTROL)` 判断 Ctrl 是否按下。

## 4. settings.zig（新模块，约 700–900 行）

### 4.1 窗口类与打开方式
- 类名 `CCloseSettingsClass`，`settingsWndProc`。
- `pub fn show(hWnd: win32.HWND, hInstance: win32.HINSTANCE) void`：若对话框已存在则 `SetForegroundWindow` 前置；否则注册类、`CreateWindowExW(0, 类名, 设置标题, WS_CAPTION|WS_SYSMENU|WS_VISIBLE, 初始尺寸居中…)`。**无模态循环**，走主消息循环（主窗口不可见，无需 EnableWindow 父窗口）。
- 对话框持有自身状态 `SettingsState`：跟随鼠标开关、当前拾取窗口、各控件句柄、指向 g_config 的指针（用于读写列表与布尔值）。
- 打开时从 `g_config` 初始化复选框与 ListBox 内容。

### 4.2 布局（Client 约 380×460）
- 组「功能开关」：
  - 复选框：中键关闭 / 右键最小化 / 长按置顶 / 双击 Esc / Ctrl+滚轮透明度（5 项，两个 BS_AUTOCHECKBOX 列或单列）
- 组「标题栏例外列表（工作区）」：ListBox（LBS_NOTIFY）+ EDIT + 添加按钮 + 删除按钮
- 组「Esc 黑名单」：ListBox + EDIT + 添加/删除按钮
- 组「窗口信息」：跟随鼠标复选框 + 4 行只读字段（标题/类名/程序/进程）+ 添加→例外 / 添加→黑名单 按钮
- 底部：确定 / 取消

控件 ID（WM_COMMAND 用）：`ID_SETTINGS_EN_MIDDLE=2001`、`EN_RIGHT=2002`、`EN_HOLD=2003`、`EN_ESC=2004`、`EN_TRANSPARENCY=2005`、`ID_LB_EXCEPT=2101`、`ID_EDIT_EXCEPT=2102`、`ID_ADD_EXCEPT=2103`、`ID_DEL_EXCEPT=2104`、`ID_LB_BLACK=2111`、`ID_EDIT_BLACK=2112`、`ID_ADD_BLACK=2113`、`ID_DEL_BLACK=2114`、`ID_CHK_FOLLOW=2201`、`ID_TXT_TITLE=2202`、`ID_TXT_CLASS=2203`、`ID_TXT_EXE=2204`、`ID_TXT_PID=2205`、`ID_PICK_EXCEPT=2206`、`ID_PICK_BLACK=2207`、`ID_OK=2301`、`ID_CANCEL=2302`。

### 4.3 关键逻辑
- **WM_INITDIALOG 等价（首次 WM_CREATE）**：创建全部子控件；按 `g_config` 设置复选框状态（`BM_SETCHECK`）；把 `titlebar_exceptions`/`esc_blacklist` 逐项 `LB_ADDSTRING`。
- **跟随鼠标**：复选框勾选时 `SetTimer(dlg, 1, 80, null)`；`WM_TIMER` 里 `GetCursorPos` + `WindowFromPoint` + `GetAncestor(GA_ROOT)`，更新 4 个只读字段（标题/类名/程序/进程），并记录当前窗口供「添加」使用。不勾选则 KillTimer。
  - 标题：`GetWindowTextW`；类名：`GetClassNameW`；进程：`GetWindowThreadProcessId` → PID；程序：`OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION)` + `QueryFullProcessImageNameW`（失败则留空）。
  - 字段用 `WM_SETTEXT` 设置，`ES_READONLY` 防编辑。
- **添加/删除列表项**：
  - 手动输入：读取 EDIT（`WM_GETTEXT`），非空则 `config.list.append(a, a.dupe(class名))` + `LB_ADDSTRING` + 清空输入框。
  - 拾取添加：从跟随鼠标记录的当前窗口类名添加。
  - 删除：`LB_GETCURSEL` → `LB_DELETESTRING` + 从内存列表按索引 `orderedRemove`。
  - 列表项即窗口类名（与 `isExceptionWindow` 的匹配单位一致）。
- **确定/取消**：
  - 确定：把复选框状态写回 `g_config` 的布尔字段；`g_config.save(page_allocator)`；`DestroyWindow`。
  - 取消：不保存；`DestroyWindow`。文档说明「取消不改动 ini，但本次会话内的列表编辑会保留在内存」（可接受，重启恢复）。
- **WM_COMMAND 分发**：按 ID 处理上述控件。

### 4.4 i18n
lang.zig `Strings` 新增字段（声明顺序 + EN/ZH 双分支）：
- `ok` / `cancel`
- `settings_title`（高级设置）→ 复用 `advanced_settings_title`
- `settings_enable_transparency`（Ctrl+滚轮透明度复选框）
- 其余（功能开关文案、组标题、窗口信息字段、添加/删除、跟随鼠标、例外列表/黑名单）复用已有 `menu_*` / `group_*` / `field_*` / `tab_*` / `add` / `delete` / `follow_mouse` 字符串。

## 5. main.zig 变更
- 托盘菜单新增 `IDM_SETTINGS = 1005`：`AppendMenuW(hMenu, MF_STRING, IDM_SETTINGS, g_ws_settings.ptr)`（`g_ws_settings` 已存在、此前未用）。
- `WM_COMMAND` 加 `IDM_SETTINGS => settings.show(hWnd, g_hInstance)`。

## 6. 兼容与回滚
- ini 新增键带默认值；旧配置不受影响。
- 工作区语义改变是唯一行为反转点，已在 R2 明确；若需回滚，仅改 hooks.zig 条件即可。
- 全部新增代码在 `settings.zig`/`win32.zig`/`hooks.zig`/`config.zig`/`lang.zig`/`main.zig`，`git checkout` 可整体回退。

## 7. 实现说明（与实际代码的偏差）
- `settings.show` 实际签名：`show(hWnd, hInstance, cfg: *Config, strs: *const Strings, a: Allocator)`——传入 `g_config`/`g_strs`/arena，列表项统一 arena 分配。
- lang.zig 实际新增字段：`ok`、`cancel`、`settings_features`、`settings_enable_transparency`、`add_to_exception`、`add_to_blacklist`（前三字段设计未列，为布局必需）。
- 工作区与透明度命中均用 `GetAncestor(hwnd, GA_ROOT)` 取顶层窗口（设计用 WindowFromPoint 的直接结果，会落到子控件）。
- main.zig 消息循环新增 `IsDialogMessageW` 路由，使对话框支持 Tab/Enter/Esc（设计未述）。
- 未实现设计列出的 `GetDlgItem`/`EnableWindow`/`IsWindowEnabled`/`PROCESS_QUERY_INFORMATION`/`PROCESS_VM_READ`/`LB_GETTEXT*`/`WM_GETTEXTLENGTH`/`WS_GROUP`（无调用点）；额外加 `AdjustWindowRectEx`、`WM_SETFONT`、`WM_CTLCOLORSTATIC`、`COLOR_BTNFACE`、`WS_BORDER`。
