const std = @import("std");
const config_mod = @import("config.zig");
const lang_mod = @import("lang.zig");
const win32 = @import("win32.zig");
const tooltip = @import("tooltip.zig");
const tray = @import("tray.zig");
const icon = @import("icon.zig");
const hooks = @import("hooks.zig");
const settings = @import("settings.zig");

// =============================================================================
// App-specific constants
// =============================================================================

// Window class name
const CLASS_NAME_DATA = [_]u16{ 'C', 'C', 'l', 'o', 's', 'e', 'W', 'c', 'l', 'a', 's', 's', 0 };
const CLASS_NAME: [*:0]const u16 = @ptrCast(&CLASS_NAME_DATA);
const APP_NAME_DATA = [_]u16{ 'C', 'C', 'l', 'o', 's', 'e', 0 };
const APP_NAME: [*:0]const u16 = @ptrCast(&APP_NAME_DATA);

// Autostart registry path (legacy constants, kept as-is)
const AUTOSTART_KEY_DATA = [_]u16{ 'S', 'O', 'F', 'T', 'W', 'A', 'R', 'E', '\\', 'M', 'i', 'c', 'r', 'o', 's', 'o', 'f', 't', '\\', 'W', 'i', 'n', 'd', 'o', 'w', 's', '\\', 'C', 'u', 'r', 'r', 'e', 'n', 't', 'V', 'e', 'r', 's', 'i', 'o', 'n', '\\', 'R', 'u', 'n', 0 };
const AUTOSTART_KEY: [*:0]const u16 = @ptrCast(&AUTOSTART_KEY_DATA);
const AUTOSTART_VALUE_DATA = [_]u16{ 'C', 'C', 'l', 'o', 's', 'e', 0 };
const AUTOSTART_VALUE: [*:0]const u16 = @ptrCast(&AUTOSTART_VALUE_DATA);

// Menu item IDs
const IDM_SUSPEND: usize = 1000;
const IDM_AUTOSTART: usize = 1001;
const IDM_EXIT: usize = 1002;
const IDM_HELP: usize = 1003;
const IDM_ABOUT: usize = 1004;
const IDM_SETTINGS: usize = 1005;

// Singleton constants
const SINGLETON_MUTEX_NAME_DATA = [_]u16{ 'C', 'C', 'l', 'o', 's', 'e', '_', 'S', 'i', 'n', 'g', 'l', 'e', 't', 'o', 'n', '_', 'M', 'u', 't', 'e', 'x', '_', 'v', '1', 0 };
const SINGLETON_MUTEX_NAME: [*:0]const u16 = @ptrCast(&SINGLETON_MUTEX_NAME_DATA);

// Broadcast by Explorer when it (re)creates the taskbar. Re-add the tray icon
// so it survives an Explorer restart.
const TASKBAR_CREATED_DATA = [_]u16{ 'T', 'a', 's', 'k', 'b', 'a', 'r', 'C', 'r', 'e', 'a', 't', 'e', 'd', 0 };
const TASKBAR_CREATED: [*:0]const u16 = @ptrCast(&TASKBAR_CREATED_DATA);

// =============================================================================
// Global State
// =============================================================================

var g_hWnd: win32.HWND = undefined;
var g_hInstance: win32.HINSTANCE = undefined;
var g_autostart: bool = false;
var g_taskbar_created_msg: u32 = 0;

// Singleton guard: holds the named mutex for the process lifetime.
// The kernel closes the handle (and releases the mutex) when the process exits.
var g_singleton_mutex: ?win32.HANDLE = null;

// Config and l10n (initialized in WM_CREATE)
var g_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
var g_config: config_mod.Config = undefined;
var g_strs: lang_mod.Strings = undefined;

// Pre-converted wide menu strings (arena-allocated)
var g_ws_suspend: [:0]u16 = undefined;
var g_ws_settings: [:0]u16 = undefined;
var g_ws_help: [:0]u16 = undefined;
var g_ws_about: [:0]u16 = undefined;
var g_ws_exit: [:0]u16 = undefined;
var g_ws_autostart: [:0]u16 = undefined;
var g_ws_help_msg: [:0]u16 = undefined;
var g_ws_about_msg: [:0]u16 = undefined;
// Always-on-top toast strings, converted in WM_CREATE and handed to tooltip.init
// after the main window is created.
var g_ws_topmost_on: [:0]u16 = undefined;
var g_ws_topmost_off: [:0]u16 = undefined;

// =============================================================================
// Helpers
// =============================================================================

fn toWide(a: std.mem.Allocator, s: []const u8) ![:0]u16 {
    return try std.unicode.utf8ToUtf16LeAllocZ(a, s);
}

fn toggleAutostart() void {
    // Autostart lives in the HKCU Run registry key, not the ini config. Only
    // flip the menu state when the registry write succeeds, so the checkmark
    // never claims enabled after a failed write.
    const next = !g_autostart;
    if (config_mod.setAutostart(next)) {
        g_autostart = next;
    }
}

fn showContextMenu(hWnd: win32.HWND) void {
    const hMenu = win32.CreatePopupMenu() orelse return;
    defer _ = win32.DestroyMenu(hMenu);

    // The suspend menu item keeps a single label and a checkmark shows the
    // current state (checked = temporarily disabled, click again to resume).
    _ = win32.AppendMenuW(hMenu, win32.MF_STRING | (if (hooks.isSuspended()) win32.MF_CHECKED else 0), IDM_SUSPEND, @as(?win32.LPCWSTR, g_ws_suspend.ptr));
    _ = win32.AppendMenuW(hMenu, win32.MF_STRING | (if (g_autostart) win32.MF_CHECKED else 0), IDM_AUTOSTART, @as(?win32.LPCWSTR, g_ws_autostart.ptr));
    _ = win32.AppendMenuW(hMenu, win32.MF_STRING, IDM_SETTINGS, @as(?win32.LPCWSTR, g_ws_settings.ptr));
    _ = win32.AppendMenuW(hMenu, win32.MF_SEPARATOR, 0, null);
    _ = win32.AppendMenuW(hMenu, win32.MF_STRING, IDM_HELP, @as(?win32.LPCWSTR, g_ws_help.ptr));
    _ = win32.AppendMenuW(hMenu, win32.MF_STRING, IDM_ABOUT, @as(?win32.LPCWSTR, g_ws_about.ptr));
    _ = win32.AppendMenuW(hMenu, win32.MF_SEPARATOR, 0, null);
    _ = win32.AppendMenuW(hMenu, win32.MF_STRING, IDM_EXIT, @as(?win32.LPCWSTR, g_ws_exit.ptr));

    var pt: win32.POINT = undefined;
    _ = win32.GetCursorPos(&pt);
    _ = win32.SetForegroundWindow(hWnd);
    _ = win32.TrackPopupMenu(hMenu, win32.TPM_RIGHTALIGN, pt.x, pt.y, 0, hWnd, null);
}

// =============================================================================
// Window Procedure
// =============================================================================

fn wndProc(hWnd: win32.HWND, message: u32, wParam: win32.WPARAM, lParam: win32.LPARAM) callconv(.winapi) win32.LRESULT {
    if (g_taskbar_created_msg != 0 and message == g_taskbar_created_msg) {
        // Explorer restarted: the old notification icon is gone.
        _ = tray.add(hWnd, g_hInstance);
        return 0;
    }
    switch (message) {
        win32.WM_CREATE => {
            g_hWnd = hWnd;
            // Init config and l10n
            const a = g_arena.allocator();
            g_config = config_mod.Config.load(a) catch config_mod.Config{
                .titlebar_exceptions = .empty,
                .esc_blacklist = .empty,
            };
            // Autostart state comes from the HKCU Run registry key (the actual
            // mechanism), so the menu checkmark reflects reality.
            g_autostart = config_mod.isAutostartEnabled();
            g_strs = lang_mod.getStrings(lang_mod.Language.detect(), a);
            g_ws_suspend = toWide(a, g_strs.@"suspend") catch unreachable;
            g_ws_settings = toWide(a, g_strs.settings) catch unreachable;
            g_ws_help = toWide(a, g_strs.help) catch unreachable;
            g_ws_about = toWide(a, g_strs.about) catch unreachable;
            g_ws_exit = toWide(a, g_strs.exit) catch unreachable;
            g_ws_autostart = toWide(a, g_strs.menu_autostart) catch unreachable;
            g_ws_help_msg = toWide(a, g_strs.help_msg) catch unreachable;
            g_ws_about_msg = toWide(a, g_strs.about_msg) catch unreachable;
            g_ws_topmost_on = toWide(a, g_strs.topmost_on_tip) catch unreachable;
            g_ws_topmost_off = toWide(a, g_strs.topmost_off_tip) catch unreachable;
            _ = tray.add(hWnd, g_hInstance);
            hooks.init(hWnd, &g_config);
            _ = hooks.enable();
        },
        win32.WM_TRAY => {
            const tray_lparam: u32 = @intCast(lParam);
            switch (tray_lparam) {
                win32.WM_RBUTTONUP => showContextMenu(hWnd),
                win32.WM_LBUTTONUP => showContextMenu(hWnd),
                else => {},
            }
        },
        win32.WM_COMMAND => {
            const id = wParam & 0xFFFF;
            switch (id) {
                IDM_SUSPEND => {
                    if (hooks.isSuspended()) {
                        _ = hooks.enable();
                    } else {
                        hooks.disable();
                    }
                },
                IDM_AUTOSTART => toggleAutostart(),
                IDM_SETTINGS => settings.show(g_hInstance, &g_config, &g_strs, g_arena.allocator()),
                IDM_HELP => {
                    _ = win32.MessageBoxW(null, @as(win32.LPCWSTR, g_ws_help_msg.ptr), APP_NAME, 0);
                },
                IDM_ABOUT => {
                    _ = win32.MessageBoxW(null, @as(win32.LPCWSTR, g_ws_about_msg.ptr), APP_NAME, 0);
                },
                IDM_EXIT => {
                    _ = win32.DestroyWindow(hWnd);
                },
                else => {},
            }
        },
        win32.WM_TIMER => {
            hooks.onTimer(wParam);
        },
        win32.WM_CLOSE => {
            tray.remove(hWnd);
            _ = win32.DestroyWindow(hWnd);
        },
        win32.WM_DESTROY => {
            hooks.shutdown();
            tray.remove(hWnd);
            tooltip.destroy();
            // The settings dialog is now an unowned top-level window, so close
            // it explicitly before tearing down the arena it allocates from.
            if (settings.isActive()) _ = win32.DestroyWindow(settings.hwnd());
            // Save config and cleanup
            g_config.save(std.heap.page_allocator);
            g_arena.deinit();
            win32.PostQuitMessage(0);
        },
        else => {
            return win32.DefWindowProcW(hWnd, message, wParam, lParam);
        },
    }
    return 0;
}

// =============================================================================
// Entry Point
// =============================================================================

pub export fn wWinMain(
    hInstance: win32.HINSTANCE,
    hPrevInstance: ?win32.HINSTANCE,
    lpCmdLine: win32.LPWSTR,
    nCmdShow: i32,
) callconv(.winapi) i32 {
    _ = hPrevInstance;
    _ = lpCmdLine;
    _ = nCmdShow;

    // Single-instance guard: if another CClose is already running, exit silently
    // before creating any windows, hooks, or tray icon.
    const mutex = win32.CreateMutexW(null, 0, SINGLETON_MUTEX_NAME);
    if (win32.GetLastError() == win32.ERROR_ALREADY_EXISTS) return 0;
    g_singleton_mutex = mutex;

    // Per-monitor V2 so the toast and settings follow the DPI of the monitor
    // they are shown on. Fall back to system awareness on older Windows.
    if (win32.SetProcessDpiAwarenessContext(win32.DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2) == 0) {
        _ = win32.SetProcessDPIAware();
    }

    g_hInstance = hInstance;
    g_hWnd = undefined;
    g_taskbar_created_msg = win32.RegisterWindowMessageW(TASKBAR_CREATED);

    var wc: win32.WNDCLASSEXW = undefined;
    wc.cbSize = @sizeOf(win32.WNDCLASSEXW);
    wc.style = 0;
    wc.lpfnWndProc = wndProc;
    wc.cbClsExtra = 0;
    wc.cbWndExtra = 0;
    wc.hInstance = hInstance;
    wc.hIcon = icon.app();
    wc.hIconSm = wc.hIcon;
    wc.hCursor = win32.LoadCursorW(null, @as(win32.LPCWSTR, @ptrFromInt(@as(usize, 32512))));
    wc.hbrBackground = @as(win32.HBRUSH, @ptrFromInt(@as(usize, 1)));
    wc.lpszMenuName = null;
    wc.lpszClassName = CLASS_NAME;

    const class_atom = win32.RegisterClassExW(&wc);
    if (class_atom == 0) return 1;

    const hwnd = win32.CreateWindowExW(
        0,
        CLASS_NAME,
        APP_NAME,
        0,
        0,
        0,
        0,
        0,
        null,
        null,
        hInstance,
        null,
    );
    if (hwnd) |h| {
        g_hWnd = h;
    } else {
        return 1;
    }
    _ = tooltip.init(g_hInstance, g_ws_topmost_on, g_ws_topmost_off);

    var msg: win32.MSG = undefined;
    while (true) {
        const get_msg_result = win32.GetMessageW(&msg, null, 0, 0);
        if (get_msg_result == 0) break;
        if (get_msg_result == -1) break;
        // While the modeless settings dialog is open, let IsDialogMessageW
        // handle Tab navigation and Enter/Esc so it behaves like a dialog.
        if (settings.isActive() and win32.IsDialogMessageW(settings.hwnd(), &msg) != 0) {
            continue;
        }
        _ = win32.TranslateMessage(&msg);
        _ = win32.DispatchMessageW(&msg);
    }

    return 0;
}

// Provide a standard Zig main() entry point as a convenience.
pub fn main() void {
    const hInstance = win32.GetModuleHandleW(null) orelse return;
    const cmdLine = win32.GetCommandLineW();
    _ = wWinMain(hInstance, null, cmdLine, 1);
}
