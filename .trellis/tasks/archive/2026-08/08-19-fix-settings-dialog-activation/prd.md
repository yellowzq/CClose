# 修复设置窗口无法编辑/勾选（owned-window 激活问题）

## 背景 / 问题

用户报告高级设置对话框无法通过 GUI 编辑：输入框打不了字（「无法编辑」），勾选框无法操作（「无法勾选」）。

诊断确认根因：设置窗口（`settings.zig` 的 `show()`）以隐藏托盘主窗口（`hParent`）为 owner 创建。
被隐藏且从未激活的 owner 拥有的窗口无法通过点击激活——点击对话框不会把它带到前台，
其子控件永远拿不到键盘焦点，键盘输入全部进入前台窗口（如 Chrome）。表现为：
- 打开后前景经常仍是 Chrome（`SetForegroundWindow` 时好时坏，受前景锁影响）
- 点击输入框：对话框不激活、`GetGUIThreadInfo` 焦点仍为空
- 键入字符：编辑框始终为空（字符进了 Chrome）

复选框理论上可纯鼠标切换，但因对话框整体未激活，用户感知为「整个设置窗口死掉」。

## 需求

1. 设置窗口打开后成为前台活动窗口；用户点击窗口任意位置（含子控件）能可靠激活它。
2. 点击输入框后获得键盘焦点，键入的字符进入对应编辑框。
3. 复选框可正常勾选/取消。
4. 不改变对话框的视觉布局、控件、文案与既有功能。

## 技术方案（摘要）

- `settings.zig` `show()`：`CreateWindowExW` 的 owner 参数从 `hParent` 改为 `null`
  （独立顶层窗口，普通顶层窗口点击即激活）。删除废弃的 `hParent` 参数。
- `main.zig`：更新 `settings.show(...)` 调用；`WM_DESTROY` 时显式
  `DestroyWindow(settings.hwnd())`（独立窗口不再随 owner 自动销毁），再 `g_arena.deinit()`。

## 验收标准（AC）

- [ ] `zig build` 通过，无编译错误。
- [ ] 从托盘打开设置：对话框成为前景窗口（`GetForegroundWindow` == 对话框）。
- [ ] 点击编辑框：`GetGUIThreadInfo` 的 `hwndFocus` 变为该编辑框；向编辑框发送 `WM_CHAR` 后文本更新。
- [ ] 点击复选框：`BM_GETCHECK` 状态翻转。
- [ ] 原 `src/settings.zig` 布局/控件/文案无改动（仅 owner 相关 + 签名清理）。
