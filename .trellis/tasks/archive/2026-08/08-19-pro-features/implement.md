# 执行计划：高级设置对话框 + 无标题栏支持 + Esc 黑名单 + 透明度

## 前置
- 任务已激活（`task.py start` 后）。
- git 工作区干净。

## 实施清单（每步后 `zig build` 验证）

### 1. config.zig + lang.zig
- config.zig：`Config` 增 `enable_transparency: bool = true`；`load`/`save` 增 `General/EnableTransparency`。
- lang.zig：`Strings` 增 `ok`、`cancel`、`settings_enable_transparency`（声明顺序，EN/ZH 双分支）。
- 验证：`zig build`。

### 2. win32.zig 新增绑定
- extern：`SetLayeredWindowAttributes`、`GetLayeredWindowAttributes`、`GetWindowTextW`、`GetAsyncKeyState`、`GetAncestor`、`OpenProcess`、`QueryFullProcessImageNameW`、`CloseHandle`。
- 常量：`WS_EX_LAYERED`、`LWA_ALPHA`、`VK_CONTROL`、`PROCESS_QUERY_LIMITED_INFORMATION`、控件/窗口样式与控件消息（`WS_CHILD/VISIBLE/CAPTION/SYSMENU/VSCROLL/TABSTOP/CLIPSIBLINGS`、`BS_AUTOCHECKBOX/GROUPBOX/PUSHBUTTON`、`SS_LEFT`、`ES_AUTOHSCROLL/READONLY`、`LBS_NOTIFY`、`BM_GETCHECK/SETCHECK`、`LB_ADDSTRING/GETCURSEL/DELETESTRING/RESETCONTENT/GETTEXTLEN/GETTEXT`、`WM_GETTEXT/SETTEXT/GETTEXTLENGTH`、`WM_MOUSEWHEEL`、`GA_ROOT`）。
- 验证：`zig build`。

### 3. hooks.zig：工作区语义 + Ctrl+滚轮透明度
- mouseHookProc：`isCaptionAt(...) or isExceptionWindow(hwnd, g_config.titlebar_exceptions.items)` 作为命中条件（原为命中后跳过例外）。
- mouseHookProc：新增 `WM_MOUSEWHEEL` 分支 → `adjustOpacity`，消费消息返回 1。
- 新增 `adjustOpacity`、常量 `MIN_ALPHA=50 / MAX_ALPHA=255 / ALPHA_STEP=15`。
- 验证：`zig build`。

### 4. settings.zig 新模块
- 注册 `CCloseSettingsClass`，`settingsWndProc`。
- `pub fn show(hWnd, hInstance)`：去重前置；创建对话框窗口。
- WM_CREATE：创建全部子控件、按 g_config 初始化。
- 跟随鼠标定时器 + 窗口信息读取（GetWindowTextW/GetClassNameW/GetWindowThreadProcessId/OpenProcess/QueryFullProcessImageNameW）。
- 添加/删除列表项（EDIT 输入 + 拾取）。
- 确定（写回 + save + 销毁）/取消（不保存 + 销毁）。
- 验证：`zig build`。

### 5. main.zig：托盘菜单「设置」
- `IDM_SETTINGS = 1005`；`AppendMenuW` 加项；`WM_COMMAND` 接 `settings.show(hWnd, g_hInstance)`。
- 验证：`zig build`。

### 6. ReleaseSafe + 冒烟
- `zig build -Doptimize=ReleaseSafe`。
- 冒烟：启动存活、单例、托盘菜单出现「设置」、对话框可打开关闭；`grep` 校验新 extern 对齐。

### 7. trellis-check
- 按 trellis-check 流程核对变更、检查重复常量/依赖环、报告并修复。

### 8. 提交（分组，逐个征求确认）
- 候选分组：A) config+lang+win32 绑定；B) hooks（工作区+透明度）；C) settings 对话框 + main 接线。每组合并为一个提交，提交前分别给用户确认。

### 9. 归档 + journal
- `task.py archive 08-19-pro-features`；`add_session.py` 记录。

## 验证命令
```bash
zig build
zig build -Doptimize=ReleaseSafe
./zig-out/bin/CClose.exe &
tasklist //FI "IMAGENAME eq CClose.exe"
```

## 回滚
- 未提交：`git checkout -- src/`；新文件 `rm src/settings.zig`。
- 已提交：`git revert <hash>`。
- 行为反转点（工作区语义）单点可控。

## 不做什么
- 不改 `build.zig`/`build.zig.zon`；不引入资源文件；不做任务栏右键功能（`enable_taskbar_right_click` 为遗留字段，保持不动）；不清理既有死常量。
