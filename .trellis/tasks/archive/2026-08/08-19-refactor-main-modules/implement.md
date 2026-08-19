# 执行计划：按功能拆分 main.zig

## 前置条件

- 任务已激活（`task.py start` 后）。
- 当前 git 工作区干净。

## 实施清单（每步后执行对应验证）

### 1. 新建 src/win32.zig
把 main.zig 的「类型别名 + 常量（纯 Win32 部分）+ 结构体 + 全部 extern」原样搬入，全部声明加 `pub`，保留原分节注释（type aliases / constants / structs / externs by dll）。不含业务逻辑、不含全局状态。

### 2. 精简 main.zig（win32 部分）
- 顶部加 `const win32 = @import("win32.zig");`
- 删除已搬移的声明段
- 剩余代码中所有 `HWND/WPARAM/LPCWSTR/…`、常量、extern 改为 `win32.` 限定名
- 验证：`zig build` 通过

### 3. 新建 src/tooltip.zig
- 搬移 `initTooltip/hideTooltip/showTooltip/tipWndProc` + `TIP_*` 常量 + `g_hTip/g_tip_text/g_tip_visible`
- 新增 `g_on_text/g_off_text`；公开 `init/showTopmost/hide/destroy`
- main.zig：删除 tooltip 段；`WM_DESTROY` 改 `tooltip.destroy()`；`wWinMain` 的 `_ = initTooltip()` 改 `_ = tooltip.init(g_hInstance, g_ws_topmost_on, g_ws_topmost_off)`
- 验证：`zig build` 通过

### 4. 新建 src/tray.zig
- 搬移 `addTrayIcon/removeTrayIcon` + 托盘提示串
- main.zig：`WM_CREATE` 用 `_ = tray.add(hWnd, g_hInstance)`；`WM_CLOSE`/`WM_DESTROY` 用 `tray.remove(hWnd)`
- 验证：`zig build` 通过

### 5. 新建 src/hooks.zig
- 搬移 `mouseHookProc/kbdHookProc/handleHoldTick/installHooks/uninstallHooks/startHoldTimer/stopHoldTimer/nowInMs/isExceptionWindow/isTaskbarWindow/isCaptionAt/packCoords` + `HOLD_*` 常量 + 全部相关全局
- 新增公开 API：`init/isSuspended/disable/enable/onTimer/shutdown`（`suspend`/`resume` 为 Zig 保留关键字，不能用作字段名）
- `handleHoldTick` 内 `showTooltip(g_ws_topmost_on/off)` 改为 `tooltip.showTopmost(!is_topmost)`（新置顶状态）
- main.zig：删除 hooks 段；`WM_CREATE` 加 `hooks.init(hWnd, &g_config)` + `_ = hooks.enable()`；`IDM_SUSPEND` 用 `isSuspended/disable/enable`；`WM_TIMER` 转发 `hooks.onTimer(wParam)`；`WM_DESTROY` 加 `hooks.shutdown()`；菜单文案用 `hooks.isSuspended()`
- 验证：`zig build` 通过

### 6. ReleaseSafe 构建
- 验证：`zig build -Doptimize=ReleaseSafe` 通过

### 7. 行为冒烟测试
- 启动 `zig-out/bin/CClose.exe`，`tasklist //FI "IMAGENAME eq CClose.exe"` 确认恰 1 个进程，托盘图标存在
- 单例：再启动一次，进程数仍为 1（第二个静默退出）；全部退出后能再次正常启动
- 长按任意窗口标题栏 1 秒：窗口置顶 + 光标旁出现提示；再次长按取消并提示；提示自动隐藏
- 托盘右键：挂起/恢复、退出正常
- 中键标题栏关闭、右键标题栏最小化、双击 Esc 关闭前台窗口抽查

### 8. trellis-check 质量门禁
- 按 trellis-check 流程核对变更、运行项目检查、报告违规并修复

### 9. 提交
- 向用户展示提交计划，获得确认后 `git add` + `git commit`（`refactor: 拆分 main.zig 为 win32/tooltip/tray/hooks 模块`）

### 10. 归档与日志
- `python ./.trellis/scripts/task.py archive <task-name>`
- `python ./.trellis/scripts/add_session.py --title ... --commit <hash> --summary ...`

## 验证命令汇总

```bash
zig build
zig build -Doptimize=ReleaseSafe
./zig-out/bin/CClose.exe &
tasklist //FI "IMAGENAME eq CClose.exe"
```

## 回滚

- 未提交前：`git checkout -- src/` 恢复既有文件；删除新增模块文件。
- 已提交后：`git revert <commit>` 或 `git reset --hard HEAD~1`。
- 整个重构为纯搬移 + 接线，单文件可逆，风险低。

## 不做什么（范围外）

- 不重构 `config.zig` / `lang.zig` / `build.zig` / `build.zig.zon`
- 不做 App 上下文结构体改造（用户已选定模块拆分方案）
- 不运行 `zig fmt`，不改现有格式化风格
- 不清理既有死常量（`AUTOSTART_KEY/VALUE` 等原样保留）
