# Journal - sakura (Part 1)

> AI development session journal
> Started: 2026-08-19

---



## Session 1: 置顶切换提示气泡功能

**Date**: 2026-08-19
**Task**: 置顶切换提示气泡功能
**Branch**: `master`

### Summary

为 CClose 实现置顶切换提示：长按标题栏置顶/取消置顶时在鼠标旁显示中英文气泡（main.zig 新增 tooltip 窗口类+GDI 绘制+定位计时并挂钩 handleHoldTick，lang.zig 新增两条文案）。

### Git Commits

| Hash | Message |
|------|---------|
| `ce28465` | (see git log) |

### Status

[OK] **Completed**


## Session 2: CClose 单例功能

**Date**: 2026-08-19
**Task**: CClose 单例功能
**Branch**: `master`

### Summary

为 CClose 添加命名互斥体单例：wWinMain 入口用 CreateMutexW 检测已有实例，重复实例在创建窗口/钩子/托盘前静默退出；旧实例退出后无残留锁可正常重启。双实例冒烟测试通过。

### Git Commits

| Hash | Message |
|------|---------|
| `d214d4d` | (see git log) |

### Status

[OK] **Completed**


## Session 3: 重构 main.zig：按功能拆分模块

**Date**: 2026-08-19
**Task**: 重构 main.zig：按功能拆分模块
**Branch**: `master`

### Summary

将 1282 行 main.zig 拆分为 win32(纯绑定)/tooltip/tray/hooks 四个模块，main 精简至 268 行；行为不变，Debug+ReleaseSafe 构建与单例冒烟测试通过。

### Git Commits

| Hash | Message |
|------|---------|
| `dd7b452` | (see git log) |

### Status

[OK] **Completed**


## Session 4: pro-features：无标题栏窗口/工作区、Esc 黑名单、Ctrl+滚轮透明度 + 设置对话框

**Date**: 2026-08-19
**Task**: pro-features：无标题栏窗口/工作区、Esc 黑名单、Ctrl+滚轮透明度 + 设置对话框
**Branch**: `master`

### Summary

完成 CClose Pro 三项功能：例外列表改为工作区语义（列入窗口整面可当标题栏，GA_ROOT 匹配）、双击 Esc 关闭可设黑名单（esc_blacklist 保留类名匹配）、新增 Ctrl+滚轮调整窗口透明度（WS_EX_LAYERED+LWA_ALPHA，50-255，GetAncestor 取顶层）。新建 settings.zig 自包含模型态设置对话框（5 项功能开关、工作区/黑名单列表增删、跟随鼠标窗口信息拾取），main 消息循环接入 IsDialogMessageW。ini 新增 General/EnableTransparency。分组提交 3 个（3ac9554/4d086e4/bf7e68b），ReleaseSafe 构建通过，冒烟测试通过。本轮另将 .trellis 工作区纳入版本控制（5994cd0）。

### Git Commits

| Hash | Message |
|------|---------|
| `bf7e68b` | (see git log) |
| `4d086e4` | (see git log) |
| `3ac9554` | (see git log) |

### Status

[OK] **Completed**


## Session 5: 修复设置窗口无法编辑（owned-window 激活）

**Date**: 2026-08-19
**Task**: 修复设置窗口无法编辑（owned-window 激活）
**Branch**: `master`

### Summary

设置窗口原为隐藏托盘窗口的 owned 子窗口，点击无法激活、编辑框无键盘焦点。改为独立顶层窗口（owner=null）+ 退出时显式销毁。GetGUIThreadInfo 验证焦点进入编辑框、WM_CHAR 字符进入、复选框可切换。

### Git Commits

| Hash | Message |
|------|---------|
| `8d623d9` | (see git log) |

### Status

[OK] **Completed**
