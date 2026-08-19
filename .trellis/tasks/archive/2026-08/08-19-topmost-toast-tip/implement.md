# 执行计划：置顶切换提示气泡

## 目标

在 `src/main.zig` 中实现 tooltip 气泡（窗口类 + GDI 绘制 + 定位 + 计时），并在 `handleHoldTick` 挂钩；在 `src/lang.zig` 增加两条中英文文案。不改 `build.zig` / `build.zig.zon`。

## 前置检查（Review Gate 1）

- [ ] `zig version` 可运行，确认本机 Zig 版本。
- [ ] 基线 `zig build` 成功（改动前干净可编译）。

## 执行清单（有序）

### Step 1 — lang.zig：新增文案字段

- `Strings` 结构体新增：`topmost_on_tip`、`topmost_off_tip`。
- `.English` 新增：`"Window set to always on top"`、`"Window no longer on top"`。
- `.Chinese` 新增：`"窗口已置顶"`、`"窗口已取消置顶"`。

### Step 2 — main.zig：常量与结构体

- 常量：`WS_POPUP`、`WS_EX_NOACTIVATE`、`SW_HIDE`、`SWP_SHOWWINDOW`、`WM_PAINT`、`COLOR_INFOBK`、`COLOR_INFOTEXT`、`COLOR_WINDOWFRAME`、`DEFAULT_GUI_FONT`、`TRANSPARENT`、`DT_CENTER`、`DT_VCENTER`、`DT_SINGLELINE`、`SM_CXSCREEN`、`SM_CYSCREEN`、`TOOLTIP_TIMER_ID`、`TOOLTIP_SHOW_MS`、tip 窗口类名、tip padding。
- 结构体：`HDC`、`HGDIOBJ`、`RECT`、`SIZE`、`PAINTSTRUCT`（均为 `extern struct` / 指针别名）。

### Step 3 — main.zig：extern 声明

- `user32`：`GetDC`、`ReleaseDC`、`BeginPaint`、`EndPaint`、`FillRect`、`FrameRect`、`GetSysColorBrush`、`GetSysColor`、`SetBkMode`、`SetTextColor`、`DrawTextW`、`GetClientRect`、`GetSystemMetrics`、`InvalidateRect`。
- `gdi32`：`GetStockObject`、`SelectObject`、`GetTextExtentPoint32W`。

### Step 4 — main.zig：全局状态

- `g_hTip: HWND`、`g_tip_text: LPCWSTR`、`g_tip_visible: bool`。
- `g_ws_topmost_on` / `g_ws_topmost_off`（`[:0]u16`）。

### Step 5 — main.zig：Tooltip 函数

- `tipWndProc`：处理 `WM_PAINT`（画背景、边框、居中文本）与 `WM_TIMER`（调 `hideTooltip`），其余 `DefWindowProcW`。
- `initTooltip()`：注册 `CCloseTipClass`，`CreateWindowExW` 创建隐藏气泡窗口，失败返回 false（优雅降级）。
- `showTooltip(text: [:0]const u16)`：设置文本指针 → 测量尺寸 → 定位（含 clamp）→ `SetWindowPos` 显示 → `InvalidateRect` → `SetTimer`。
- `hideTooltip()`：`KillTimer` + 可见才 `SW_HIDE`（幂等）。

### Step 6 — main.zig：挂钩

- `handleHoldTick`：在样式切换完成后，按新置顶状态调用 `showTooltip`（`g_ws_topmost_on` / `g_ws_topmost_off`）。
- `WM_CREATE`：转换 `g_ws_topmost_on` / `g_ws_topmost_off`。
- `wWinMain`：主窗口创建成功后调用 `initTooltip()`。
- `WM_DESTROY`：`hideTooltip()` + `DestroyWindow(g_hTip)`。

### Step 7 — 构建验证

- [ ] `zig build` 编译通过，无错误无警告新增。

### Review Gate 2（质量检查）

- [ ] 逐行核对：不修改置顶切换逻辑本身，仅在末尾追加提示调用。
- [ ] 核对新增 extern 签名与 Win32 一致（调用约定 `.winapi`）。
- [ ] 核对中英文文案字段在两处（struct 声明 + 两个语言分支）都齐全。
- [ ] 全文件无未使用声明（Zig 会报错，编译器即门禁）。

## 验证命令

```bash
zig version          # 确认编译器版本
zig build            # 编译验证
zig build run        # 冒烟测试（需 Windows 交互环境）
```

冒烟测试路径：运行 `zig build run` → 拖一个窗口到长按其标题栏 1 秒 → 应出现"窗口已置顶"气泡并自动消失 → 再长按 → 出现"窗口已取消置顶"气泡。系统语言为中文时文案为中文，否则为英文。

## 回滚点

- 改动集中在 `src/main.zig` 与 `src/lang.zig` 两个文件；如出问题，`git checkout -- src/main.zig src/lang.zig` 即可整体回滚。
- 置顶核心逻辑未动，回滚后功能与原版一致。

## 完成后

- 更新本任务 spec（如适用）。
- 提交（`task.py finish` 后提交 commit，遵循项目 Git 规范）。
