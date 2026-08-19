# 设计：按功能拆分 main.zig

## 目标结构

```
src/
├── win32.zig    # 纯 Win32 绑定层（类型/结构体/常量/extern），全部 pub，无逻辑
├── tooltip.zig  # 置顶 Toast 窗口
├── tray.zig     # 托盘图标
├── hooks.zig    # 输入钩子 + 长按置顶 + 双击 Esc + 挂起/恢复
├── config.zig   # 配置（不改）
├── lang.zig     # i18n（不改）
└── main.zig     # 窗口过程/托盘菜单/自启/单例/入口（精简后约 330 行）
```

## 模块边界与公开 API

### win32.zig（~630 行）
纯绑定，无逻辑，全部 `pub`，保留原分节注释：
- 类型别名：`HWND/HINSTANCE/HICON/HMENU/HMODULE/HHOOK/HBRUSH/HCURSOR/HANDLE/HKEY/HDC/HGDIOBJ`、`BOOL/BYTE/WORD/DWORD/LONG/LRESULT/WPARAM/LPARAM/LPCWSTR/LPWSTR`
- 结构体：`POINT/RECT/SIZE/PAINTSTRUCT/MSG/GUID/MSLLHOOKSTRUCT/KBDLLHOOKSTRUCT/NOTIFYICONDATAW/WNDCLASSEXW`
- 常量（纯 Win32 部分）：`WH_*`、`WM_*`（含 `WM_USER`/`WM_TRAY`）、`SC_CLOSE/SC_MINIMIZE`、`HTCAPTION`、`WS_EX_*`、`WS_POPUP`、`SWP_*`、`GWL_EXSTYLE`、`MAX_PATH`、`NIM_*`、`NIF_*`、`MF_*`、`VK_ESCAPE`、`HC_ACTION`、`LLKHF_UP`、`TPM_*`、`HKEY_CURRENT_USER`、`KEY_*`、`REG_SZ`、`ERROR_SUCCESS`、`HWND_TOPMOST/HWND_NOTOPMOST`、`IDI_APPLICATION`、`SW_HIDE`、`SM_*`、`COLOR_*`、`DEFAULT_GUI_FONT`、`TRANSPARENT`、`DT_*`、`ERROR_ALREADY_EXISTS`
- extern：kernel32 / user32 / gdi32 / shell32 / advapi32 全部声明 + `SetProcessDPIAware`

### tooltip.zig（~120 行）
持有全局：`g_hTip: ?HWND`、`g_tip_text: ?LPCWSTR`、`g_on_text: ?LPCWSTR`、`g_off_text: ?LPCWSTR`、`g_tip_visible: bool`。
常量：`TOOLTIP_TIMER_ID/SHOW_MS`、`TIP_PAD_X/PAD_Y`、`TIP_OFFSET_X/Y`、`TIP_CLASS_NAME`、`TIP_WINDOW_NAME`。
公开 API：
- `pub fn init(hInstance: win32.HINSTANCE, on_text: [:0]const u16, off_text: [:0]const u16) bool` — 注册 `CCloseTipClass` 并创建提示窗口，保存两份文案指针；失败返回 false
- `pub fn showTopmost(is_on: bool) void` — 按新状态选中文案，在光标旁显示
- `pub fn hide() void` — 隐藏（供内部计时器与 destroy 使用）
- `pub fn destroy() void` — 隐藏并销毁窗口

内部：`initTipWindow`、`doShow`、`tipWndProc`（`WM_PAINT` 用 GDI 绘制、`WM_TIMER` 自动隐藏）。

### tray.zig（~50 行）
无状态。
- `pub fn add(hWnd: win32.HWND, hInstance: win32.HINSTANCE) bool` — `Shell_NotifyIconW(NIM_ADD)`
- `pub fn remove(hWnd: win32.HWND) void` — `Shell_NotifyIconW(NIM_DELETE)`

### hooks.zig（~230 行）
持有全局：`g_hWnd`、`g_config: *const Config`、`g_hMouseHook`、`g_hKbdHook`、`g_suspended`、`g_hold_active/start_time/start_pos/target/timer_running`、`g_last_esc_time/valid`、`g_frequency`。
常量：`HOLD_TIMER_ID`、`HOLD_THRESHOLD_MS`、`DOUBLE_ESC_TIMEOUT_MS`、`MOVE_THRESHOLD`。
公开 API：
- `pub fn init(hWnd: win32.HWND, cfg: *const Config) void` — 记录主窗口与配置指针，初始化性能计数频率
- `pub fn isSuspended() bool`
- `pub fn disable() void` — `g_suspended = true` + 卸载钩子（`suspend`/`resume` 为 Zig 保留关键字，故命名 disable/enable）
- `pub fn enable() bool` — `g_suspended = false` + 安装钩子
- `pub fn onTimer(wParam: win32.WPARAM) void` — `HOLD_TIMER_ID` → 长按置顶检测
- `pub fn shutdown() void` — 停止长按计时器、重置挂起态、卸载钩子

内部：`mouseHookProc`、`kbdHookProc`、`handleHoldTick`、`installHooks`、`uninstallHooks`、`startHoldTimer`、`stopHoldTimer`、`nowInMs`、`isExceptionWindow`、`isTaskbarWindow`、`isCaptionAt`、`packCoords`。

依赖：hooks → tooltip（置顶切换后调 `tooltip.showTopmost`）、config、win32。

### main.zig（~330 行）
持有全局：`g_hWnd`、`g_hInstance`、`g_singleton_mutex`、`g_arena`、`g_config`、`g_strs`、9 个 `g_ws_*` 菜单文案（`g_ws_topmost_on/off` 不再驻留，直接作为 `tooltip.init` 参数）。
常量：`CLASS_NAME`/`APP_NAME`、`IDM_*`（1000–1004）、`SINGLETON_MUTEX_NAME`（`AUTOSTART_KEY/VALUE` 死常量原样保留）。
- helpers：`toWide`、`toggleAutostart`、`showContextMenu`
- `wndProc`：`WM_CREATE`（配置/l10n/`tray.add`/`hooks.init`+`hooks.enable`）、`WM_TRAY`、`WM_COMMAND`、`WM_TIMER`（转发 `hooks.onTimer`）、`WM_CLOSE`、`WM_DESTROY`（`hooks.shutdown` + `tray.remove` + `tooltip.destroy` + 保存配置 + `g_arena.deinit` + `PostQuitMessage`）
- `wWinMain`/`main`：单例互斥守卫 + `SetProcessDPIAware` + 注册主类 + 创建窗口 + `tooltip.init` + 消息循环

## 依赖图（无环）

```
main → tooltip, tray, hooks, config, lang, win32
hooks → tooltip, config, win32
tooltip → win32
tray → win32
```

## 生命周期接线（保持原行为顺序）

1. `wWinMain`：`CreateMutexW` 单例守卫（`ERROR_ALREADY_EXISTS` 则静默退出）→ `SetProcessDPIAware` → `RegisterClassExW` → `CreateWindowExW`（触发 `WM_CREATE`）。
2. `WM_CREATE`：`g_config` 加载 → `g_strs`/`toWide` 生成文案 → `tray.add(hWnd, g_hInstance)` → `hooks.init(hWnd, &g_config)` + `_ = hooks.enable()`。
3. `wWinMain`（窗口创建后）：`_ = tooltip.init(g_hInstance, g_ws_topmost_on, g_ws_topmost_off)`。
4. 钩子事件：长按标题栏 1000 ms → `handleHoldTick` 切换 `WS_EX_TOPMOST` → `tooltip.showTopmost(新置顶状态)`。
5. `WM_DESTROY`：`hooks.shutdown()` → `tray.remove(hWnd)` → `tooltip.destroy()` → `g_config.save` → `g_arena.deinit` → `PostQuitMessage(0)`。

## Zig 0.16 适配要点

- 无 `usingnamespace`：跨模块引用一律使用限定名（`win32.X`）。
- 模块内的 `fn`/`const` 不再对引用方隐式可见；每个模块显式 `@import` 自己依赖的模块。
- 保持既有类型风格：可选句柄 `?HWND` 等；`@ptrFromInt(0)` 禁用等约束不变。
- `tooltip.init` 的文案是 `main` 在 `WM_CREATE` 用 `toWide` 生成的 arena 字符串，生命周期覆盖整个进程，tooltip 只存指针。

## 迁移顺序（每步保持可编译）

1. 新建 `win32.zig`（整体搬移 + `pub`）→ main.zig 改 import 并限定名，删除搬移段 → build。
2. 新建 `tooltip.zig` → 从 main.zig 删除 tooltip 段，接 `tooltip.init/destroy` → build。
3. 新建 `tray.zig` → 从 main.zig 删除 tray 段，接 `tray.add/remove` → build。
4. 新建 `hooks.zig` → 从 main.zig 删除 hooks 段，接 `hooks.init/isSuspended/suspend/resume/onTimer/shutdown` → build。
5. 收尾校验（ReleaseSafe + 行为冒烟 + trellis-check）。
