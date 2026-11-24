# CClose

CClose 是一款 Windows 窗口管理小工具：通过标题栏鼠标手势、双击 Esc 等快捷操作，快速关闭、最小化、置顶窗口，还可以调整窗口透明度、维护例外列表与黑名单。

本项目使用 **Zig 0.17.1 + Win32** 重新实现，单个 exe、绿色免安装、普通权限即可运行，自动识别简体中文 / English 界面。

> 本项目参考并修改自 [Chaohe Shi 的 CClose](https://github.com/chaohershi/cclose)（原版 CClose 1.4.1.0，Copyright (c) 2018-2020 Chaohe Shi）。保留原版的核心交互思路，代码用 Zig 重写，并在此基础上做了调整与补充。

---

## 功能特性

### 标题栏手势

| 操作 | 效果 |
|------|------|
| 鼠标中键点击标题栏 | 关闭窗口 |
| 鼠标右键点击标题栏 | 最小化窗口（长按右键仍是正常右键） |
| 长按标题栏左键约 1 秒 | 切换窗口“总在最前”，屏幕上有提示气泡 |

### 快捷键

| 操作 | 效果 |
|------|------|
| 连续按两次 `Esc` | 关闭当前前台窗口 |

### 其他

- **Ctrl + 鼠标滚轮** 调整窗口透明度（范围 50%–100%）。
- **例外列表**：把列表中的程序整个窗口当作标题栏处理，适用于没有正常标题栏的程序。
- **Esc 热键黑名单**：排除不希望被双击 Esc 关闭的程序。
- **托盘菜单**：暂时停用全部功能 / 开机自动运行 / 高级设置 / 帮助 / 关于。
- **开机自动运行**：写入当前用户 `HKCU\...\CurrentVersion\Run`，普通权限即可生效，勾选状态以真实注册表为准。
- **自定义应用图标**：多尺寸嵌入 exe 资源，主窗口、托盘、设置窗口统一使用。

### 高级设置（托盘菜单 → 高级设置）

- 功能开关（中键关闭 / 右键最小化 / 长按置顶 / 双击 Esc / Ctrl+滚轮透明度）。
- 标题栏例外列表与 Esc 热键黑名单的管理（添加、删除）。
- 窗口信息拾取：跟随鼠标实时显示目标窗口的标题、类名、程序与 PID，可一键加入例外/黑名单。

---

## 系统要求

- Windows 10 / 11（64 位）
- 无需管理员权限

## 构建

需要 [Zig 0.17.1](https://ziglang.org/download/)。

在 Windows 上直接构建：

```bash
zig build
```

在 Linux / macOS 上交叉编译：

```bash
zig build -Dtarget=x86_64-windows-gnu
```

产物位于 `zig-out/bin/CClose.exe`。

## 许可与致谢

本项目以 [MIT 许可证](LICENSE) 发布，Copyright (c) 2026 yellowzq。

本项目参考 [https://github.com/chaohershi/cclose](https://github.com/chaohershi/cclose)（Chaohe Shi）进行修改。原版版权信息：Copyright (c) 2018-2020 Chaohe Shi。
