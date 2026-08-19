# 设计：置顶切换提示气泡（Tooltip Toast）

## 概述

复用 Win32 自带样式（系统提示配色 + 系统默认字体），实现一个**程序生命周期内只创建一次、平时隐藏**的顶层小气泡窗口。置顶切换发生后，把文案写入全局指针，测量文本、按鼠标位置定位、显示气泡，并用定时器在约 1.5 秒后自动隐藏。

不引入任何第三方库，与现有自包含风格一致。

## 边界与职责

- `src/main.zig`：新增 tooltip 窗口类、`tipWndProc`（绘制）、`showTooltip` / `hideTooltip` / `initTooltip`、切换点挂钩、全局状态与 Win32 extern/常量/结构体。
- `src/lang.zig`：`Strings` 新增 `topmost_on_tip` / `topmost_off_tip` 两字段及中英文文案。
- `build.zig` / `build.zig.zon`：**不修改**。

## 数据流

```
长按标题栏 1s
  → handleHoldTick 读取 ex_style，判定 is_topmost
  → SetWindowLongW + SetWindowPos 完成置顶/取消置顶
  → new_is_topmost = !is_topmost
  → showTooltip(g_ws_topmost_on | g_ws_topmost_off)   ← 挂钩点
      ├ 记录 g_tip_text（arena 常驻宽字符串指针，无所有权问题）
      ├ 用屏幕 DC + DEFAULT_GUI_FONT 测量文本尺寸 → 加 padding 得窗口宽高
      ├ GetCursorPos 取鼠标位置，偏移 (12, 16) 并 clamp 到屏幕内
      ├ SetWindowPos(HWND_TOPMOST, …, SWP_NOACTIVATE|SWP_SHOWWINDOW)
      ├ InvalidateRect 触发重绘（文本/尺寸可能变化）
      └ SetTimer(TOOLTIP_TIMER_ID, 1500ms)
  → 1500ms 后 tipWndProc 收到 WM_TIMER
      → hideTooltip()：KillTimer + ShowWindow(SW_HIDE)
```

## 窗口与绘制设计

| 项 | 值 | 说明 |
|---|---|---|
| 窗口类 | `CCloseTipClass`，独立 wndProc `tipWndProc` | 不复用主窗口类，避免消息耦合 |
| 样式 | `WS_POPUP` | 顶层弹出窗口 |
| 扩展样式 | `WS_EX_TOPMOST \| WS_EX_TOOLWINDOW \| WS_EX_NOACTIVATE` | 置顶显示、不进任务栏/Alt+Tab、不激活不抢焦点 |
| 背景 | `FillRect(COLOR_INFOBK)` | 系统"提示/信息"浅黄背景 |
| 边框 | `FrameRect(COLOR_WINDOWFRAME)` | 细黑框，视觉上更清晰 |
| 字体/前景 | `DEFAULT_GUI_FONT`，`SetTextColor(COLOR_INFOTEXT)` | 系统默认 UI 字体 |
| 文本绘制 | `DrawTextW(DT_CENTER\|DT_VCENTER\|DT_SINGLELINE)` | 单行居中 |

创建时机：`wWinMain` 中主窗口创建成功后调用 `initTooltip()`（需要 `g_hInstance`）。销毁时机：主窗口 `WM_DESTROY` 中 `hideTooltip()` + `DestroyWindow(g_hTip)`。

## 定位与尺寸

- 文本测量：`GetTextExtentPoint32W` 在 `GetDC(null)`（屏幕 DC）上、先 `SelectObject` 选择 `DEFAULT_GUI_FONT`。
- 窗口宽高 = 文本尺寸 + padding（水平 16px ×2，垂直 6px ×2）。
- 位置 = `GetCursorPos` + 偏移 (12, 16)（右下方向）。
- 屏幕边界 clamp：`GetSystemMetrics(SM_CXSCREEN/SM_CYSCREEN)`，保证气泡完整可见。
- 应用已 `SetProcessDPIAware()`，上述坐标与尺寸均为物理像素，口径一致，无需额外 DPI 换算。

## 文案（lang.zig）

| 字段 | 英文 | 中文 |
|---|---|---|
| `topmost_on_tip` | Window set to always on top | 窗口已置顶 |
| `topmost_off_tip` | Window no longer on top | 窗口已取消置顶 |

宽字符串 `g_ws_topmost_on` / `g_ws_topmost_off` 在 `WM_CREATE` 中随现有 `g_ws_*` 一并转换（arena 分配，常驻）。

## 状态与生命周期

- `g_hTip: HWND`、`g_tip_text: LPCWSTR`（默认 null）、`g_tip_visible: bool`。
- `showTooltip` 重复调用安全：`SetTimer` 同 ID 会重置计时；`InvalidateRect` 保证新文案/尺寸正确重绘。
- `initTooltip` 失败（窗口创建返回 null）时功能优雅降级：`showTooltip` 内 `g_hTip` 为空则直接返回，不影响其它功能。
- `hideTooltip` 幂等：`KillTimer` + 仅当可见时 `SW_HIDE`。

## 兼容性与回归

- 置顶核心逻辑（`handleHoldTick` 中样式切换 + `SetWindowPos`）不动，仅在末尾追加提示调用。
- 新增的 Win32 extern 均来自 `user32.dll` / `gdi32.dll`，为稳定 API。
- 不触碰钩子、托盘、注册表、配置保存逻辑。

## 风险与对策

| 风险 | 对策 |
|---|---|
| 气泡抢焦点导致目标窗口失活 | `WS_EX_NOACTIVATE` + `SWP_NOACTIVATE`，且从不调用 `SetForegroundWindow` |
| 气泡被其它置顶窗口盖住 | 显示时显式 `HWND_TOPMOST` |
| 中文/窄字文本测量偏差 | 直接用系统字体测量实际渲染文本，宽高即为渲染尺寸 |
| 屏幕边缘气泡溢出 | 位置 clamp 到 `[0, cx-w]` / `[0, cy-h]` |
