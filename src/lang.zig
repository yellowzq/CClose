const std = @import("std");
const build_options = @import("build_options");

extern "kernel32" fn GetUserDefaultUILanguage() u16;

/// Release CI passes -Dversion; local builds read src/VERSION. @embedFile
/// makes the file a compile dependency, so editing it rebuilds the About
/// string (a value read in build.zig at configure time would be cached).
const version = if (build_options.version.len != 0)
    build_options.version
else
    std.mem.trim(u8, @embedFile("VERSION"), " \t\r\n");

const about_msg = std.fmt.comptimePrint(
    "CClose zig v{s}\n\nCopyright(c)2026 yellowzq",
    .{version},
);

pub const Language = enum {
    English,
    Chinese,

    pub fn detect() Language {
        const id = GetUserDefaultUILanguage();
        return switch (id) {
            0x0804, 0x0404, 0x0C04 => .Chinese,
            else => .English,
        };
    }
};

pub const Strings = struct {
    @"suspend": []const u8,
    @"resume": []const u8,
    settings: []const u8,
    help: []const u8,
    about: []const u8,
    exit: []const u8,
    always_on_top: []const u8,
    not_always_on_top: []const u8,
    topmost_on_tip: []const u8,
    topmost_off_tip: []const u8,
    menu_autostart: []const u8,
    menu_titlebar_middle_click: []const u8,
    menu_titlebar_right_click: []const u8,
    menu_titlebar_hold_left_click: []const u8,
    menu_esc_double_press: []const u8,
    menu_taskbar_right_click: []const u8,
    ok: []const u8,
    cancel: []const u8,
    settings_features: []const u8,
    settings_enable_transparency: []const u8,
    add_to_exception: []const u8,
    add_to_blacklist: []const u8,
    help_msg: []const u8,
    about_msg: []const u8,
    get_pro: []const u8,
    get_pro_msg: []const u8,
    advanced_settings_title: []const u8,
    trial_notice: []const u8,
    trial_msg: []const u8,
    tab_exception_list: []const u8,
    tab_blacklist: []const u8,
    window_info: []const u8,
    field_title: []const u8,
    field_class: []const u8,
    field_exe: []const u8,
    field_pid: []const u8,
    follow_mouse: []const u8,
    not_frozen: []const u8,
    frozen: []const u8,
    group_blacklist: []const u8,
    group_exception_list: []const u8,
    add: []const u8,
    delete: []const u8,
};

fn join(a: std.mem.Allocator, lines: []const []const u8) []u8 {
    return std.mem.join(a, "\n", lines) catch unreachable;
}

fn fmt(a: std.mem.Allocator, comptime format: []const u8, args: anytype) []u8 {
    return std.fmt.allocPrint(a, format, args) catch unreachable;
}

pub fn getStrings(lang: Language, a: std.mem.Allocator) Strings {
    return switch (lang) {
        .English => Strings{
            .@"suspend" = "Suspend",
            .@"resume" = "Resume",
            .settings = "Settings",
            .help = "Help",
            .about = "About",
            .exit = "Exit",
            .always_on_top = "Always on top",
            .not_always_on_top = "Not always on top",
            .topmost_on_tip = "Window set to always on top",
            .topmost_off_tip = "Window no longer on top",
            .menu_autostart = "Run CClose on system startup",
            .menu_titlebar_middle_click = "Middle click on title bar to close window",
            .menu_titlebar_right_click = "Right click on title bar to minimize window",
            .menu_titlebar_hold_left_click = "Hold left click on title bar to toggle window always on top",
            .menu_esc_double_press = "Double press Esc key to close active window",
            .menu_taskbar_right_click = "Right click on taskbar button to move pointer to \"Close window\"",
            .ok = "OK",
            .cancel = "Cancel",
            .settings_features = "Features",
            .settings_enable_transparency = "Hold Ctrl + mouse wheel to adjust window transparency",
            .add_to_exception = "Add to Exception List",
            .add_to_blacklist = "Add to Blacklist",
            .help_msg = join(a, &.{
                "Middle click   \t+ title bar[1][2]\t= close window",
                "Right click    \t+ title bar[1][2]\t= minimize window[3]",
                "Hold left click\t+ title bar[1][2]\t= toggle window always on top",
                "Double press   \t+ Esc key        \t= close active window",
                "Right click    \t+ taskbar button \t= move pointer to \"Close window\"",
                "",
                "[1] If CClose is installed outside the default directory Program Files, you need to run it as administrator to manipulate high-privileged windows, e.g. the Task Manager.",
                "",
                "[2] Few programs don't have proper GUIs. Either there isn't a title bar, or the whole interface is technically a giant title bar. In such cases, title bar related functions will not work as expected. You can solve this issue by adding those programs to the exception list in advanced settings.",
                "",
                "[3] Hold right click for a normal right click.",
            }),
            .about_msg = about_msg,
            .get_pro = "Upgrade to Pro",
            .get_pro_msg = join(a, &.{
                "Upgrade to CClose Pro to unlock extra features, including:",
                "",
                "- Support windows without a proper title bar",
                "- Blacklist for Esc key feature",
                "- Change window transparency",
                "- Support the developer and future updates",
                "",
                "Proceed to upgrade?",
            }),
            .advanced_settings_title = "Advanced Settings",
            .trial_notice = "Trial Notice",
            .trial_msg = "The trial version allows you to test out some selected Pro features. However, the settings you made will not be saved beyond the current session. If you enjoy using CClose, please consider upgrading to Pro for a small fee to support the developer and future updates, thank you!",
            .tab_exception_list = "Title Bar Exception List",
            .tab_blacklist = "Esc Hotkey Blacklist",
            .window_info = "Window Info",
            .field_title = "Title",
            .field_class = "Class",
            .field_exe = "EXE",
            .field_pid = "PID",
            .follow_mouse = "Follow Mouse",
            .not_frozen = "(Hold Ctrl or Shift to suspend updates)",
            .frozen = "(Updates suspended)",
            .group_blacklist = "Blacklist",
            .group_exception_list = "Exception List",
            .add = "Add",
            .delete = "Delete",
        },
        .Chinese => Strings{
            .@"suspend" = "暂时停用",
            .@"resume" = "恢复",
            .settings = "设置",
            .help = "帮助",
            .about = "关于",
            .exit = "退出",
            .always_on_top = "总在最前",
            .not_always_on_top = "非总在最前",
            .topmost_on_tip = "窗口已置顶",
            .topmost_off_tip = "窗口已取消置顶",
            .menu_autostart = "开机时运行 CClose",
            .menu_titlebar_middle_click = "鼠标中键点击标题栏关闭窗口",
            .menu_titlebar_right_click = "鼠标右键点击标题栏最小化窗口",
            .menu_titlebar_hold_left_click = "长按鼠标左键切换窗口总在最前",
            .menu_esc_double_press = "连续按两次 Esc 键关闭当前窗口",
            .menu_taskbar_right_click = "鼠标右键点击任务栏按钮将指针移动到\"关闭窗口\"",
            .ok = "确定",
            .cancel = "取消",
            .settings_features = "功能开关",
            .settings_enable_transparency = "按住 Ctrl + 滚轮调整窗口透明度",
            .add_to_exception = "添加到例外列表",
            .add_to_blacklist = "添加到黑名单",
            .help_msg = join(a, &.{
                "鼠标中键    \t+ 标题栏[1][2]\t= 关闭窗口",
                "鼠标右键    \t+ 标题栏[1][2]\t= 最小化窗口[3]",
                "长按左键    \t+ 标题栏[1][2]\t= 切换窗口总在最前",
                "连续按两次  \t+ Esc 键      \t= 关闭当前窗口",
                "鼠标右键    \t+ 任务栏按钮 \t= 将指针移动到\"关闭窗口\"",
                "",
                "[1] 如果将 CClose 安装在默认 Program Files 目录之外，则需要以管理员身份运行才能操作高权限窗口，例如任务管理器。",
                "",
                "[2] 少数程序没有正常的 GUI。要么没有标题栏，或者整个界面实际上就是一个巨大的标题栏。在这种情况下，标题栏相关的功能将无法按预期工作。您可以通过在高级设置中将这些程序添加到例外列表来解决此问题。",
                "",
                "[3] 长按右键可进行正常的右键单击。",
            }),
            .about_msg = about_msg,
            .get_pro = "升级到 Pro",
            .get_pro_msg = join(a, &.{
                "升级到 CClose Pro 以解锁额外功能，包括：",
                "",
                "- 支持没有正常标题栏的窗口",
                "- Esc 键功能的黑名单",
                "- 更改窗口透明度",
                "- 支持开发者和未来更新",
                "",
                "是否继续升级？",
            }),
            .advanced_settings_title = "高级设置",
            .trial_notice = "试用通知",
            .trial_msg = "试用版允许您测试一些选定的 Pro 功能。但是，您所做的设置将不会在当前会话之后保存。如果您喜欢使用 CClose，请考虑升级到 Pro 以支持开发者和未来的更新，谢谢！",
            .tab_exception_list = "标题栏例外列表",
            .tab_blacklist = "Esc 热键黑名单",
            .window_info = "窗口信息",
            .field_title = "标题",
            .field_class = "类别",
            .field_exe = "程序",
            .field_pid = "PID",
            .follow_mouse = "跟随鼠标",
            .not_frozen = "(按住 Ctrl 或 Shift 暂停更新)",
            .frozen = "(更新已暂停)",
            .group_blacklist = "黑名单",
            .group_exception_list = "例外列表",
            .add = "添加",
            .delete = "删除",
        },
    };
}