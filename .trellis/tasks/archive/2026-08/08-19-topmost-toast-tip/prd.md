# 置顶状态切换时在鼠标旁显示提示

## Goal

在用户通过"长按标题栏左键"将窗口切换为"总在最前"（置顶）或取消置顶时，在鼠标指针附近弹出一个短暂的提示气泡，告知当前置顶状态。

- 置顶成功 → 显示"窗口已置顶"
- 取消置顶 → 显示"窗口已取消置顶"

## Background

CClose 是 Zig + Win32 自包含实现（无第三方依赖）。置顶逻辑位于 `src/main.zig` 的 `handleHoldTick()`：长按标题栏 1 秒后，切换目标窗口的 `WS_EX_TOPMOST` 扩展样式并调用 `SetWindowPos(HWND_TOPMOST/HWND_NOTOPMOST)`。当前切换动作没有视觉反馈。

## Requirements

1. 当 `handleHoldTick` 完成置顶切换后，在鼠标指针附近显示提示气泡，内容为置顶/取消置顶对应文案。
2. 气泡需跟随鼠标出现（显示于当前鼠标位置附近），不抢占焦点、不激活、不进入任务栏。
3. 气泡短暂停留后自动消失（约 1.5 秒）。
4. 文案需支持中英文双语，接入现有 `lang.zig` i18n 机制：
   - 中文：`窗口已置顶` / `窗口已取消置顶`
   - 英文：`Window set to always on top` / `Window no longer on top`
5. 保持项目自包含风格：仅使用 Win32/GDI 原生 API，不引入第三方库；不修改 `build.zig` / `build.zig.zon` 的依赖。
6. 保持现有行为不变：置顶切换逻辑、钩子、托盘图标等不回归。

## Non-Goals

- 不新增设置项（不把"是否显示提示"做成可配置项）。
- 不改变置顶的触发方式（仍为长按标题栏 1 秒）。
- 不为其它动作（中键关闭、右键最小化、双击 Esc）添加提示。
- 不重写既有 Win32 封装结构。

## Acceptance Criteria

- [ ] 长按标题栏 1 秒将窗口置顶后，鼠标旁弹出提示"窗口已置顶"（英文环境为 "Window set to always on top"）。
- [ ] 再次长按标题栏 1 秒取消置顶后，鼠标旁弹出提示"窗口已取消置顶"（英文环境为 "Window no longer on top"）。
- [ ] 提示气泡自动消失（约 1.5 秒），不常驻。
- [ ] 气泡显示期间不抢占输入焦点，不导致目标窗口失活。
- [ ] 提示气泡不进入任务栏 / Alt+Tab 列表。
- [ ] 气泡始终在最上层（即使目标窗口也是置顶窗口）。
- [ ] 文案随系统语言（`GetUserDefaultUILanguage`）自动切换中英文。
- [ ] `zig build` 编译通过，无错误。
- [ ] 现有功能（中键关闭、右键最小化、双击 Esc、托盘菜单）不回归。

## Notes

- 实现集中在 `src/main.zig`（tooltip 窗口类、绘制、定位、计时）与 `src/lang.zig`（新增两条文案字段）。
- 完整技术方案见 `design.md`，执行清单见 `implement.md`。
