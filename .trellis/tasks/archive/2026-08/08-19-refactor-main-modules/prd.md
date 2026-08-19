# 重构 main.zig：按功能拆分模块

## Goal

当前所有功能代码都集中在 `src/main.zig`（1282 行，74 个 extern）。本任务按功能将单文件拆分为若干模块，降低单一文件臃肿度，使职责清晰、便于维护，同时保持全部现有行为不变。

## Requirements

1. 新建 `src/win32.zig`：承载 main.zig 中所有纯 Win32 绑定（类型别名、结构体、常量、extern），全部 `pub`，无业务逻辑。
2. 新建 `src/tooltip.zig`：置顶提示 Toast 窗口（类注册、绘制、自动隐藏计时器、光标旁定位）。
3. 新建 `src/tray.zig`：托盘图标的添加 / 移除。
4. 新建 `src/hooks.zig`：鼠标/键盘全局钩子、长按置顶、双击 Esc、挂起/恢复、异常窗口判断。
5. 精简 `src/main.zig`：只保留窗口过程、托盘右键菜单、开机自启、单例守卫、配置与 l10n 装配、入口点。
6. 保持模块级全局变量风格（不引入 App 上下文结构体）。
7. 行为完全不变：中键标题栏关闭、右键标题栏最小化、长按标题栏切换置顶并弹提示、双击 Esc 关闭前台窗口、托盘右键菜单（挂起/恢复、自启、帮助、关于、退出）、单例（第二个实例静默退出）、Autostart。

## Constraints

- Zig 0.16.0、Windows 子系统、自包含 Win32 绑定（`callconv(.winapi)`，不依赖 `std.os.windows`）。
- 不引入第三方依赖；不改 `build.zig` / `build.zig.zon` / `src/config.zig` / `src/lang.zig`。
- 保持仓库手写格式化风格（4 空格缩进、extern 对齐），不运行 `zig fmt`。
- 遗留死常量（如 `AUTOSTART_KEY/VALUE`）原样保留，不在本任务清理。

## Acceptance Criteria

- [ ] `src/main.zig` 从 1282 行降至约 350 行以内。
- [ ] 新增 `src/win32.zig`、`src/tooltip.zig`、`src/tray.zig`、`src/hooks.zig` 四个模块，职责清晰、无循环依赖。
- [ ] `zig build`（Debug）通过。
- [ ] `zig build -Doptimize=ReleaseSafe` 通过。
- [ ] 行为冒烟测试通过：
  - 启动 CClose 后进程存活（`tasklist` 检查），托盘图标存在。
  - 单例：启动第二个实例静默退出，第一个实例不受影响；全部退出后可再次启动。
  - 长按标题栏切换置顶 + 光标旁提示正常显示 / 自动隐藏。
  - 托盘右键菜单（挂起/恢复、退出）正常。
- [ ] 不改变 `build.zig` / `build.zig.zon` / `src/config.zig` / `src/lang.zig`。

## Notes

- 复杂任务：`design.md`（模块边界与公开 API）与 `implement.md`（执行清单与验证）已随本文件编写。
