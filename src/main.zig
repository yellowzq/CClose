const std = @import("std");
const config_mod = @import("config.zig");
const lang_mod = @import("lang.zig");

// =============================================================================
// Windows Type Aliases (self-contained for portability)
// =============================================================================

const HWND = *anyopaque;
const HINSTANCE = *anyopaque;
const HICON = *anyopaque;
const HMENU = *anyopaque;
const HMODULE = *anyopaque;
const HHOOK = *anyopaque;
const HBRUSH = *anyopaque;
const HCURSOR = *anyopaque;
const HANDLE = *anyopaque;
const HKEY = *opaque {};

const BOOL = i32;
const BYTE = u8;
const WORD = u16;
const DWORD = u32;
const LONG = i32;
const LRESULT = isize;
const WPARAM = usize;
const LPARAM = isize;
const LPCWSTR = [*:0]const u16;
const LPWSTR = [*:0]u16;

const POINT = extern struct {
    x: LONG,
    y: LONG,
};

const MSG = extern struct {
    hwnd: HWND,
    message: u32,
    wParam: WPARAM,
    lParam: LPARAM,
    time: DWORD,
    pt: POINT,
};


// =============================================================================
// Constants
// =============================================================================

// Hook types
const WH_MOUSE_LL: i32 = 14;
const WH_KEYBOARD_LL: i32 = 13;

// Window messages
const WM_CREATE: u32 = 0x0001;
const WM_DESTROY: u32 = 2;
const WM_CLOSE: u32 = 0x0010;
const WM_COMMAND: u32 = 0x0111;
const WM_SYSCOMMAND: u32 = 0x0112;
const WM_TIMER: u32 = 0x0113;
const WM_LBUTTONDOWN: u32 = 0x0201;
const WM_LBUTTONUP: u32 = 0x0202;
const WM_MBUTTONDOWN: u32 = 0x0207;
const WM_MBUTTONUP: u32 = 0x0208;
const WM_RBUTTONDOWN: u32 = 0x0204;
const WM_RBUTTONUP: u32 = 0x0205;
const WM_MOUSEMOVE: u32 = 0x0200;
const WM_NCHITTEST: u32 = 0x0084;

const WM_USER: u32 = 0x0400;
const WM_TRAY: u32 = 0x8001;

// System command parameters
const SC_CLOSE: WPARAM = 0xF060;
const SC_MINIMIZE: WPARAM = 0xF020;

// Hit test results
const HTCAPTION: LONG = 2;

// Extended window styles
const WS_EX_TOOLWINDOW: u32 = 0x00000080;
const WS_EX_TOPMOST: u32 = 0x00000008;

// SetWindowPos flags
const SWP_NOSIZE: u32 = 0x0001;
const SWP_NOMOVE: u32 = 0x0002;
const SWP_NOACTIVATE: u32 = 0x0010;
const SWP_NOZORDER: u32 = 0x0004;
const SWP_FRAMECHANGED: u32 = 0x0020;

// Window long indices
const GWL_EXSTYLE: i32 = -20;

// File system
const MAX_PATH: u32 = 260;
const NIM_ADD: u32 = 0;
const NIM_MODIFY: u32 = 1;
const NIM_DELETE: u32 = 2;

// NotifyIcon flags
const NIF_MESSAGE: u32 = 0x0001;
const NIF_ICON: u32 = 0x0002;
const NIF_TIP: u32 = 0x0004;

// Menu flags
const MF_STRING: u32 = 0;
const MF_SEPARATOR: u32 = 0x00000800;
const MF_CHECKED: u32 = 0x00000008;
const MF_UNCHECKED: u32 = 0;

// Menu item IDs
const IDM_SUSPEND: usize = 1000;
const IDM_AUTOSTART: usize = 1001;
const IDM_EXIT: usize = 1002;
const IDM_HELP: usize = 1003;
const IDM_ABOUT: usize = 1004;

// Keyboard virtual key codes
const VK_ESCAPE: DWORD = 0x1B;

// Hook action codes
const HC_ACTION: i32 = 0;

// Keyboard hook flags
const LLKHF_UP: DWORD = 0x80;

// TrackPopupMenu flags
const TPM_RIGHTALIGN: u32 = 0x0008;
const TPM_RETURNCMD: u32 = 0x0100;

// Registry constants
const HKEY_CURRENT_USER: HKEY = @ptrFromInt(@as(usize, 0x80000001));
const KEY_SET_VALUE: u32 = 0x0002;
const KEY_QUERY_VALUE: u32 = 0x0001;
const REG_SZ: u32 = 1;
const ERROR_SUCCESS: u32 = 0;

// Special window handles for SetWindowPos
const HWND_TOPMOST: HWND = @ptrFromInt(@as(usize, @bitCast(@as(isize, -1))));
const HWND_NOTOPMOST: HWND = @ptrFromInt(@as(usize, @bitCast(@as(isize, -2))));

// Icon resource IDs
const IDI_APPLICATION: DWORD = 32512;

// Window class name
const CLASS_NAME_DATA = [_]u16{ 'C', 'C', 'l', 'o', 's', 'e', 'W', 'c', 'l', 'a', 's', 's', 0 };
const CLASS_NAME: [*:0]const u16 = @ptrCast(&CLASS_NAME_DATA);
const APP_NAME_DATA = [_]u16{ 'C', 'C', 'l', 'o', 's', 'e', 0 };
const APP_NAME: [*:0]const u16 = @ptrCast(&APP_NAME_DATA);

// Autostart registry path
const AUTOSTART_KEY_DATA = [_]u16{ 'S', 'O', 'F', 'T', 'W', 'A', 'R', 'E', '\\', 'M', 'i', 'c', 'r', 'o', 's', 'o', 'f', 't', '\\', 'W', 'i', 'n', 'd', 'o', 'w', 's', '\\', 'C', 'u', 'r', 'r', 'e', 'n', 't', 'V', 'e', 'r', 's', 'i', 'o', 'n', '\\', 'R', 'u', 'n', 0 };
const AUTOSTART_KEY: [*:0]const u16 = @ptrCast(&AUTOSTART_KEY_DATA);
const AUTOSTART_VALUE_DATA = [_]u16{ 'C', 'C', 'l', 'o', 's', 'e', 0 };
const AUTOSTART_VALUE: [*:0]const u16 = @ptrCast(&AUTOSTART_VALUE_DATA);

// Timings
const HOLD_TIMER_ID: usize = 10;
const HOLD_THRESHOLD_MS: i64 = 1000;
const DOUBLE_ESC_TIMEOUT_MS: i64 = 500;
const MOVE_THRESHOLD: i32 = 5;

// =============================================================================
// Structures
// =============================================================================

const GUID = extern struct {
    Data1: u32,
    Data2: u16,
    Data3: u16,
    Data4: [8]u8,
};

const MSLLHOOKSTRUCT = extern struct {
    pt: POINT,
    mouseData: DWORD,
    flags: DWORD,
    time: DWORD,
    dwExtraInfo: usize,
};

const KBDLLHOOKSTRUCT = extern struct {
    vkCode: DWORD,
    scanCode: DWORD,
    flags: DWORD,
    time: DWORD,
    dwExtraInfo: usize,
};

const NOTIFYICONDATAW = extern struct {
    cbSize: DWORD,
    hWnd: HWND,
    uID: DWORD,
    uFlags: DWORD,
    uCallbackMessage: DWORD,
    hIcon: ?HICON,
    szTip: [128]u16,
    dwState: DWORD,
    dwStateMask: DWORD,
    szInfo: [256]u16,
    uVersion: DWORD,
    szInfoTitle: [64]u16,
    dwInfoFlags: DWORD,
    guidItem: GUID,
    hBalloonIcon: ?HICON,
};

const WNDCLASSEXW = extern struct {
    cbSize: u32,
    style: u32,
    lpfnWndProc: *const fn (HWND, u32, WPARAM, LPARAM) callconv(.winapi) LRESULT,
    cbClsExtra: i32,
    cbWndExtra: i32,
    hInstance: HINSTANCE,
    hIcon: ?HICON,
    hCursor: ?HCURSOR,
    hbrBackground: HBRUSH,
    lpszMenuName: ?LPCWSTR,
    lpszClassName: LPCWSTR,
    hIconSm: ?HICON,
};

// =============================================================================
// External Functions - kernel32.dll
// =============================================================================

extern "kernel32" fn GetModuleHandleW(
    lpModuleName: ?[*:0]const u16,
) callconv(.winapi) ?HMODULE;

extern "kernel32" fn QueryPerformanceCounter(
    lpPerformanceCount: *i64,
) callconv(.winapi) BOOL;

extern "kernel32" fn QueryPerformanceFrequency(
    lpFrequency: *i64,
) callconv(.winapi) BOOL;

extern "kernel32" fn GetModuleFileNameW(
    hModule: ?HMODULE,
    lpFilename: [*]u16,
    nSize: DWORD,
) callconv(.winapi) DWORD;

extern "kernel32" fn GetCommandLineW() callconv(.winapi) LPWSTR;

// =============================================================================
// External Functions - user32.dll
// =============================================================================

extern "user32" fn SetWindowsHookExW(
    idHook: i32,
    lpfn: ?*const anyopaque,
    hmod: HINSTANCE,
    dwThreadId: DWORD,
) callconv(.winapi) ?HHOOK;

extern "user32" fn UnhookWindowsHookEx(
    hhk: HHOOK,
) callconv(.winapi) BOOL;

extern "user32" fn CallNextHookEx(
    hhk: ?HHOOK,
    nCode: i32,
    wParam: WPARAM,
    lParam: LPARAM,
) callconv(.winapi) LRESULT;

extern "user32" fn RegisterClassExW(
    lpWndClass: *const WNDCLASSEXW,
) callconv(.winapi) u16;

extern "user32" fn CreateWindowExW(
    dwExStyle: u32,
    lpClassName: LPCWSTR,
    lpWindowName: LPCWSTR,
    dwStyle: u32,
    x: i32,
    y: i32,
    nWidth: i32,
    nHeight: i32,
    hWndParent: ?HWND,
    hMenu: ?HMENU,
    hInstance: HINSTANCE,
    lpParam: ?*anyopaque,
) callconv(.winapi) ?HWND;

extern "user32" fn DefWindowProcW(
    hWnd: HWND,
    Msg: u32,
    wParam: WPARAM,
    lParam: LPARAM,
) callconv(.winapi) LRESULT;

extern "user32" fn DestroyWindow(
    hWnd: HWND,
) callconv(.winapi) BOOL;

extern "user32" fn PostQuitMessage(
    nExitCode: i32,
) callconv(.winapi) void;

extern "user32" fn GetMessageW(
    lpMsg: *MSG,
    hWnd: ?HWND,
    wMsgFilterMin: u32,
    wMsgFilterMax: u32,
) callconv(.winapi) BOOL;

extern "user32" fn TranslateMessage(
    lpMsg: *const MSG,
) callconv(.winapi) BOOL;

extern "user32" fn DispatchMessageW(
    lpMsg: *const MSG,
) callconv(.winapi) LRESULT;

extern "user32" fn LoadIconW(
    hInstance: ?HINSTANCE,
    lpIconName: ?LPCWSTR,
) callconv(.winapi) ?HICON;

extern "user32" fn LoadCursorW(
    hInstance: ?HINSTANCE,
    lpCursorName: ?LPCWSTR,
) callconv(.winapi) ?HCURSOR;

extern "user32" fn SendMessageW(
    hWnd: HWND,
    Msg: u32,
    wParam: WPARAM,
    lParam: LPARAM,
) callconv(.winapi) LRESULT;

extern "user32" fn PostMessageW(
    hWnd: HWND,
    Msg: u32,
    wParam: WPARAM,
    lParam: LPARAM,
) callconv(.winapi) BOOL;

extern "user32" fn WindowFromPoint(
    Point: POINT,
) callconv(.winapi) ?HWND;

extern "user32" fn GetClassNameW(
    hWnd: HWND,
    lpClassName: [*]u16,
    nMaxCount: i32,
) callconv(.winapi) i32;

extern "user32" fn CreatePopupMenu(
) callconv(.winapi) ?HMENU;

extern "user32" fn AppendMenuW(
    hMenu: HMENU,
    uFlags: u32,
    uIDNewItem: usize,
    lpNewItem: ?LPCWSTR,
) callconv(.winapi) BOOL;

extern "user32" fn TrackPopupMenu(
    hMenu: HMENU,
    uFlags: u32,
    x: i32,
    y: i32,
    nReserved: i32,
    hWnd: HWND,
    prcRect: ?*const anyopaque,
) callconv(.winapi) BOOL;

extern "user32" fn DestroyMenu(
    hMenu: HMENU,
) callconv(.winapi) BOOL;

extern "user32" fn SetTimer(
    hWnd: HWND,
    nIDEvent: usize,
    uElapse: u32,
    lpTimerFunc: ?*const anyopaque,
) callconv(.winapi) usize;

extern "user32" fn KillTimer(
    hWnd: HWND,
    nIDEvent: usize,
) callconv(.winapi) BOOL;

extern "user32" fn SetWindowPos(
    hWnd: HWND,
    hWndInsertAfter: HWND,
    X: i32,
    Y: i32,
    cx: i32,
    cy: i32,
    uFlags: u32,
) callconv(.winapi) BOOL;

extern "user32" fn GetForegroundWindow(
) callconv(.winapi) ?HWND;

extern "user32" fn GetCursorPos(
    lpPoint: *POINT,
) callconv(.winapi) BOOL;

extern "user32" fn MessageBoxW(
    hWnd: ?HWND,
    lpText: LPCWSTR,
    lpCaption: LPCWSTR,
    uType: u32,
) callconv(.winapi) i32;

extern "user32" fn IsWindowVisible(
    hWnd: HWND,
) callconv(.winapi) BOOL;

extern "user32" fn GetWindowThreadProcessId(
    hWnd: HWND,
    lpdwProcessId: ?*DWORD,
) callconv(.winapi) u32;

extern "user32" fn ShowWindow(
    hWnd: HWND,
    nCmdShow: i32,
) callconv(.winapi) BOOL;

extern "user32" fn SetForegroundWindow(
    hWnd: HWND,
) callconv(.winapi) BOOL;

extern "user32" fn GetWindowLongW(
    hWnd: HWND,
    nIndex: i32,
) callconv(.winapi) LONG;

extern "user32" fn SetWindowLongW(
    hWnd: HWND,
    nIndex: i32,
    dwNewLong: LONG,
) callconv(.winapi) LONG;

// =============================================================================
// External Functions - shell32.dll
// =============================================================================

extern "shell32" fn Shell_NotifyIconW(
    dwMessage: DWORD,
    lpData: *const NOTIFYICONDATAW,
) callconv(.winapi) BOOL;

// =============================================================================
// External Functions - advapi32.dll
// =============================================================================

extern "advapi32" fn RegOpenKeyExW(
    hKey: HKEY,
    lpSubKey: LPCWSTR,
    ulOptions: u32,
    samDesired: u32,
    phkResult: *HKEY,
) callconv(.winapi) i32;

extern "advapi32" fn RegSetValueExW(
    hKey: HKEY,
    lpValueName: LPCWSTR,
    Reserved: u32,
    dwType: u32,
    lpData: [*]const u8,
    cbData: u32,
) callconv(.winapi) i32;

extern "advapi32" fn RegDeleteValueW(
    hKey: HKEY,
    lpValueName: LPCWSTR,
) callconv(.winapi) i32;

extern "advapi32" fn RegCloseKey(
    hKey: HKEY,
) callconv(.winapi) i32;

extern "advapi32" fn RegQueryValueExW(
    hKey: HKEY,
    lpValueName: LPCWSTR,
    lpReserved: ?*DWORD,
    lpType: ?*DWORD,
    lpData: ?[*]u8,
    lpcbData: *DWORD,
) callconv(.winapi) i32;

// =============================================================================
// Global State
// =============================================================================

var g_hWnd: HWND = undefined;
var g_hInstance: HINSTANCE = undefined;
var g_hMouseHook: ?HHOOK = null;
var g_hKbdHook: ?HHOOK = null;
var g_suspended: bool = false;
var g_autostart: bool = false;

// Hold-to-topmost state
var g_hold_active: bool = false;
var g_hold_start_time: i64 = 0;
var g_hold_start_pos: POINT = undefined;
var g_hold_target: HWND = undefined;
var g_hold_timer_running: bool = false;

// Double-escape state
var g_last_esc_time: i64 = 0;
var g_last_esc_valid: bool = false;
var g_frequency: i64 = 0;

// Config and l10n (initialized in WM_CREATE)
var g_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
var g_config: config_mod.Config = undefined;
var g_strs: lang_mod.Strings = undefined;

// Pre-converted wide menu strings (arena-allocated)
var g_ws_suspend: [:0]u16 = undefined;
var g_ws_resume: [:0]u16 = undefined;
var g_ws_settings: [:0]u16 = undefined;
var g_ws_help: [:0]u16 = undefined;
var g_ws_about: [:0]u16 = undefined;
var g_ws_exit: [:0]u16 = undefined;
var g_ws_autostart: [:0]u16 = undefined;
var g_ws_help_msg: [:0]u16 = undefined;
var g_ws_about_msg: [:0]u16 = undefined;

// =============================================================================
// Helpers
// =============================================================================

fn packCoords(x: LONG, y: LONG) LPARAM {
    const ux: u32 = @bitCast(x);
    const uy: u32 = @bitCast(y);
    const lo = @as(LPARAM, @as(u16, @truncate(ux)));
    const hi = @as(LPARAM, @as(u16, @truncate(uy))) << 16;
    return lo | hi;
}

fn toWide(a: std.mem.Allocator, s: []const u8) ![:0]u16 {
    return try std.unicode.utf8ToUtf16LeAllocZ(a, s);
}

fn isExceptionWindow(hWnd: HWND, list: []const []const u8) bool {
    if (list.len == 0) return false;
    var buf: [256]u16 = undefined;
    const len = GetClassNameW(hWnd, @as([*]u16, @ptrCast(&buf)), @intCast(buf.len));
    if (len <= 0) return false;
    const class_name = std.unicode.utf16LeToUtf8Alloc(std.heap.page_allocator, buf[0..@intCast(len)]) catch return false;
    defer std.heap.page_allocator.free(class_name);
    for (list) |item| {
        if (std.mem.eql(u8, class_name, item)) return true;
    }
    return false;
}

fn isTaskbarWindow(hWnd: HWND) bool {
    var buf: [64]u16 = undefined;
    const len = GetClassNameW(hWnd, @as([*]u16, @ptrCast(&buf)), buf.len);
    if (len <= 0) return false;
    const class_name = buf[0..@intCast(len)];
    const tray = "Shell_TrayWnd";
    const secondary = "Shell_SecondaryTrayWnd";
    if (class_name.len != tray.len and class_name.len != secondary.len) return false;
    var i: usize = 0;
    while (i < class_name.len) : (i += 1) {
        const expected: u8 = if (class_name.len == tray.len) tray[i] else secondary[i];
        const c: u16 = class_name[i];
        if (c < 128 and @as(u8, @intCast(c)) != expected) return false;
    }
    return true;
}

fn isCaptionAt(hWnd: HWND, x: LONG, y: LONG) bool {
    const lparam = packCoords(x, y);
    const result = SendMessageW(hWnd, WM_NCHITTEST, 0, lparam);
    return result == HTCAPTION;
}

fn addTrayIcon(hWnd: HWND, _: HINSTANCE) bool {
    var nid: NOTIFYICONDATAW = undefined;
    nid.cbSize = @sizeOf(NOTIFYICONDATAW);
    nid.hWnd = hWnd;
    nid.uID = 1;
    nid.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
    nid.uCallbackMessage = WM_TRAY;
    const idi_app: LPCWSTR = @ptrFromInt(@as(usize, IDI_APPLICATION));
    nid.hIcon = LoadIconW(null, idi_app);
    @memset(nid.szTip[0..], 0);
    const tip = "CClose - window management";
    for (tip, 0..) |c, i| {
        if (i >= nid.szTip.len) break;
        nid.szTip[i] = c;
    }
    nid.dwState = 0;
    nid.dwStateMask = 0;
    @memset(nid.szInfo[0..], 0);
    nid.uVersion = 0;
    @memset(nid.szInfoTitle[0..], 0);
    nid.dwInfoFlags = 0;
    nid.guidItem = .{ .Data1 = 0, .Data2 = 0, .Data3 = 0, .Data4 = @splat(0) };
    nid.hBalloonIcon = null;
    return Shell_NotifyIconW(NIM_ADD, &nid) != 0;
}

fn removeTrayIcon(hWnd: HWND) void {
    var nid: NOTIFYICONDATAW = undefined;
    nid.cbSize = @sizeOf(NOTIFYICONDATAW);
    nid.hWnd = hWnd;
    nid.uID = 1;
    nid.uFlags = 0;
    nid.uCallbackMessage = 0;
    nid.hIcon = null;
    nid.szTip = @splat(0);
    nid.dwState = 0;
    nid.dwStateMask = 0;
    nid.szInfo = @splat(0);
    nid.uVersion = 0;
    nid.szInfoTitle = @splat(0);
    nid.dwInfoFlags = 0;
    nid.guidItem = .{ .Data1 = 0, .Data2 = 0, .Data3 = 0, .Data4 = @splat(0) };
    nid.hBalloonIcon = null;
    _ = Shell_NotifyIconW(NIM_DELETE, &nid);
}

fn installHooks() bool {
    const hmod = GetModuleHandleW(null) orelse return false;
    g_hMouseHook = SetWindowsHookExW(WH_MOUSE_LL, @ptrCast(&mouseHookProc), hmod, 0);
    g_hKbdHook = SetWindowsHookExW(WH_KEYBOARD_LL, @ptrCast(&kbdHookProc), hmod, 0);
    return g_hMouseHook != null and g_hKbdHook != null;
}

fn uninstallHooks() void {
    if (g_hMouseHook) |h| {
        _ = UnhookWindowsHookEx(h);
    }
    if (g_hKbdHook) |h| {
        _ = UnhookWindowsHookEx(h);
    }
    g_hMouseHook = null;
    g_hKbdHook = null;
}

fn toggleAutostart() void {
    g_autostart = !g_autostart;
    _ = config_mod.setAutostart(g_autostart);
    // Update config
    g_config.autostart = g_autostart;
    _ = g_config.save(std.heap.page_allocator);
}

fn showContextMenu(hWnd: HWND) void {
    const hMenu = CreatePopupMenu() orelse return;
    defer _ = DestroyMenu(hMenu);

    _ = AppendMenuW(hMenu, MF_STRING, IDM_SUSPEND, if (g_suspended) @as(?LPCWSTR, g_ws_resume.ptr) else @as(?LPCWSTR, g_ws_suspend.ptr));
    _ = AppendMenuW(hMenu, MF_STRING, IDM_AUTOSTART, @as(?LPCWSTR, g_ws_autostart.ptr));
    _ = AppendMenuW(hMenu, MF_SEPARATOR, 0, null);
    _ = AppendMenuW(hMenu, MF_STRING, IDM_HELP, @as(?LPCWSTR, g_ws_help.ptr));
    _ = AppendMenuW(hMenu, MF_STRING, IDM_ABOUT, @as(?LPCWSTR, g_ws_about.ptr));
    _ = AppendMenuW(hMenu, MF_SEPARATOR, 0, null);
    _ = AppendMenuW(hMenu, MF_STRING, IDM_EXIT, @as(?LPCWSTR, g_ws_exit.ptr));

    var pt: POINT = undefined;
    _ = GetCursorPos(&pt);
    _ = SetForegroundWindow(hWnd);
    _ = TrackPopupMenu(hMenu, TPM_RIGHTALIGN, pt.x, pt.y, 0, hWnd, null);
}

fn startHoldTimer(hWnd: HWND) void {
    if (!g_hold_timer_running) {
        _ = SetTimer(hWnd, HOLD_TIMER_ID, 100, null);
        g_hold_timer_running = true;
    }
}

fn stopHoldTimer(hWnd: HWND) void {
    if (g_hold_timer_running) {
        _ = KillTimer(hWnd, HOLD_TIMER_ID);
        g_hold_timer_running = false;
    }
}

fn handleHoldTick(hWnd: HWND) void {
    if (!g_hold_active) return;
    var now: i64 = 0;
    _ = QueryPerformanceCounter(&now);
    const elapsed_ms = @divTrunc((now - g_hold_start_time) * 1000, g_frequency);
    if (elapsed_ms >= HOLD_THRESHOLD_MS) {
        // Toggle WS_EX_TOPMOST on the held window.
        // Extended styles are 32-bit even on 64-bit Windows.
        const ex_style = GetWindowLongW(g_hold_target, GWL_EXSTYLE);
        const is_topmost = (ex_style & @as(LONG, @intCast(WS_EX_TOPMOST))) != 0;
        const new_ex_style = if (is_topmost)
            ex_style & ~@as(LONG, @intCast(WS_EX_TOPMOST))
        else
            ex_style | @as(LONG, @intCast(WS_EX_TOPMOST));
        _ = SetWindowLongW(g_hold_target, GWL_EXSTYLE, new_ex_style);

        const hwnd_insert_after: HWND = if (is_topmost) HWND_NOTOPMOST else HWND_TOPMOST;
        _ = SetWindowPos(
            g_hold_target,
            hwnd_insert_after,
            0,
            0,
            0,
            0,
            SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_FRAMECHANGED,
        );
        g_hold_active = false;
        stopHoldTimer(hWnd);
    }
}

fn nowInMs() i64 {
    var count: i64 = 0;
    _ = QueryPerformanceCounter(&count);
    if (g_frequency == 0) return 0;
    return @divTrunc(count * 1000, g_frequency);
}

// =============================================================================
// Hook Procedures
// =============================================================================

fn mouseHookProc(nCode: i32, wParam: WPARAM, lParam: LPARAM) callconv(.winapi) LRESULT {
    if (g_suspended) return CallNextHookEx(g_hMouseHook orelse null, nCode, wParam, lParam);
    if (nCode == HC_ACTION) {
        const ms: *const MSLLHOOKSTRUCT = @ptrCast(@alignCast(@as(*const anyopaque, @ptrFromInt(@as(usize, @bitCast(lParam))))));
        switch (wParam) {
            WM_LBUTTONDOWN, WM_MBUTTONDOWN, WM_RBUTTONDOWN => {
                const hwndUnder = WindowFromPoint(ms.pt);
                if (hwndUnder) |hwnd| {
                    if (isTaskbarWindow(hwnd)) {
                        g_hold_active = false;
                        stopHoldTimer(g_hWnd);
                        return CallNextHookEx(g_hMouseHook orelse null, nCode, wParam, lParam);
                    }
                    if (isCaptionAt(hwnd, ms.pt.x, ms.pt.y)) {
                        // Check exception list
                        if (isExceptionWindow(hwnd, g_config.titlebar_exceptions.items)) {
                            return CallNextHookEx(g_hMouseHook orelse null, nCode, wParam, lParam);
                        }
                        switch (wParam) {
                            WM_MBUTTONDOWN => {
                                if (g_config.enable_titlebar_middle_click) {
                                    _ = PostMessageW(hwnd, WM_SYSCOMMAND, SC_CLOSE, 0);
                                }
                            },
                            WM_RBUTTONDOWN => {
                                if (g_config.enable_titlebar_right_click) {
                                    _ = PostMessageW(hwnd, WM_SYSCOMMAND, SC_MINIMIZE, 0);
                                }
                            },
                            WM_LBUTTONDOWN => {
                                if (g_config.enable_titlebar_hold_left_click) {
                                    g_hold_active = true;
                                    g_hold_start_pos = ms.pt;
                                    g_hold_target = hwnd;
                                    _ = QueryPerformanceCounter(&g_hold_start_time);
                                    startHoldTimer(g_hWnd);
                                }
                            },
                            else => {},
                        }
                    }
                }
            },
            WM_LBUTTONUP => {
                if (g_hold_active) {
                    g_hold_active = false;
                    stopHoldTimer(g_hWnd);
                }
            },
            WM_MOUSEMOVE => {
                if (g_hold_active) {
                    const dx = ms.pt.x - g_hold_start_pos.x;
                    const dy = ms.pt.y - g_hold_start_pos.y;
                    const dist2 = dx * dx + dy * dy;
                    if (dist2 > MOVE_THRESHOLD * MOVE_THRESHOLD) {
                        g_hold_active = false;
                        stopHoldTimer(g_hWnd);
                    }
                }
            },
            else => {},
        }
    }
    return CallNextHookEx(g_hMouseHook orelse null, nCode, wParam, lParam);
}

fn kbdHookProc(nCode: i32, wParam: WPARAM, lParam: LPARAM) callconv(.winapi) LRESULT {
    if (g_suspended) return CallNextHookEx(g_hKbdHook orelse null, nCode, wParam, lParam);
    if (nCode == HC_ACTION) {
        const kbd: *const KBDLLHOOKSTRUCT = @ptrCast(@alignCast(@as(*const anyopaque, @ptrFromInt(@as(usize, @bitCast(lParam))))));
        const is_key_up = (kbd.flags & LLKHF_UP) != 0;
        if (kbd.vkCode == VK_ESCAPE and !is_key_up and g_config.enable_esc_double_press) {
            const now = nowInMs();
            if (g_last_esc_valid and (now - g_last_esc_time) <= DOUBLE_ESC_TIMEOUT_MS) {
                // Double press: close the foreground window.
                g_last_esc_valid = false;
                if (GetForegroundWindow()) |fg| {
                    if (!isExceptionWindow(fg, g_config.esc_blacklist.items)) {
                        _ = PostMessageW(fg, WM_SYSCOMMAND, SC_CLOSE, 0);
                    }
                }
            } else {
                g_last_esc_valid = true;
                g_last_esc_time = now;
            }
        }
    }
    return CallNextHookEx(g_hKbdHook orelse null, nCode, wParam, lParam);
}

// =============================================================================
// Window Procedure
// =============================================================================

fn wndProc(hWnd: HWND, message: u32, wParam: WPARAM, lParam: LPARAM) callconv(.winapi) LRESULT {
    switch (message) {
        WM_CREATE => {
            g_hWnd = hWnd;
            // Init config and l10n
            const a = g_arena.allocator();
            g_config = config_mod.Config.load(a) catch config_mod.Config{
                .titlebar_exceptions = .empty,
                .esc_blacklist = .empty,
            };
            g_autostart = g_config.autostart;
            g_strs = lang_mod.getStrings(lang_mod.Language.detect(), a);
            g_ws_suspend = toWide(a, g_strs.@"suspend") catch unreachable;
            g_ws_resume = toWide(a, g_strs.@"resume") catch unreachable;
            g_ws_settings = toWide(a, g_strs.settings) catch unreachable;
            g_ws_help = toWide(a, g_strs.help) catch unreachable;
            g_ws_about = toWide(a, g_strs.about) catch unreachable;
            g_ws_exit = toWide(a, g_strs.exit) catch unreachable;
            g_ws_autostart = toWide(a, g_strs.menu_autostart) catch unreachable;
            g_ws_help_msg = toWide(a, g_strs.help_msg) catch unreachable;
            g_ws_about_msg = toWide(a, g_strs.about_msg) catch unreachable;
            _ = addTrayIcon(hWnd, g_hInstance);
            _ = installHooks();
            _ = QueryPerformanceFrequency(&g_frequency);
        },
        WM_TRAY => {
            const tray_lparam: u32 = @intCast(lParam);
            switch (tray_lparam) {
                WM_RBUTTONUP => showContextMenu(hWnd),
                WM_LBUTTONUP => showContextMenu(hWnd),
                else => {},
            }
        },
        WM_COMMAND => {
            const id = wParam & 0xFFFF;
            switch (id) {
                IDM_SUSPEND => {
                    g_suspended = !g_suspended;
                    if (g_suspended) {
                        uninstallHooks();
                    } else {
                        _ = installHooks();
                    }
                },
                IDM_AUTOSTART => toggleAutostart(),
                IDM_HELP => {
                    _ = MessageBoxW(null, @as(LPCWSTR, g_ws_help_msg.ptr), APP_NAME, 0);
                },
                IDM_ABOUT => {
                    _ = MessageBoxW(null, @as(LPCWSTR, g_ws_about_msg.ptr), APP_NAME, 0);
                },
                IDM_EXIT => {
                    _ = DestroyWindow(hWnd);
                },
                else => {},
            }
        },
        WM_TIMER => {
            if (wParam == HOLD_TIMER_ID) {
                handleHoldTick(hWnd);
            }
        },
        WM_CLOSE => {
            removeTrayIcon(hWnd);
            _ = DestroyWindow(hWnd);
        },
        WM_DESTROY => {
            stopHoldTimer(hWnd);
            g_hold_active = false;
            uninstallHooks();
            removeTrayIcon(hWnd);
            // Save config and cleanup
            g_config.save(std.heap.page_allocator);
            g_arena.deinit();
            PostQuitMessage(0);
        },
        else => {
            return DefWindowProcW(hWnd, message, wParam, lParam);
        },
    }
    return 0;
}

// =============================================================================
// Entry Point
// =============================================================================

extern "user32" fn SetProcessDPIAware() BOOL;

pub export fn wWinMain(
    hInstance: HINSTANCE,
    hPrevInstance: ?HINSTANCE,
    lpCmdLine: LPWSTR,
    nCmdShow: i32,
) callconv(.winapi) i32 {
    _ = hPrevInstance;
    _ = lpCmdLine;
    _ = nCmdShow;

    // Set DPI awareness programmatically (no manifest needed)
    _ = SetProcessDPIAware();

    g_hInstance = hInstance;
    g_hWnd = undefined;

    var wc: WNDCLASSEXW = undefined;
    wc.cbSize = @sizeOf(WNDCLASSEXW);
    wc.style = 0;
    wc.lpfnWndProc = wndProc;
    wc.cbClsExtra = 0;
    wc.cbWndExtra = 0;
    wc.hInstance = hInstance;
    wc.hIcon = LoadIconW(null, @as(LPCWSTR, @ptrFromInt(@as(usize, IDI_APPLICATION))));
    wc.hCursor = LoadCursorW(null, @as(LPCWSTR, @ptrFromInt(@as(usize, 32512))));
    wc.hbrBackground = @as(HBRUSH, @ptrFromInt(@as(usize, 1)));
    wc.lpszMenuName = null;
    wc.lpszClassName = CLASS_NAME;
    wc.hIconSm = null;

    const class_atom = RegisterClassExW(&wc);
    if (class_atom == 0) return 1;

    const hwnd = CreateWindowExW(
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

    var msg: MSG = undefined;
    while (true) {
        const get_msg_result = GetMessageW(&msg, null, 0, 0);
        if (get_msg_result == 0) break;
        if (get_msg_result == -1) break;
        _ = TranslateMessage(&msg);
        _ = DispatchMessageW(&msg);
    }

    return 0;
}

// Provide a standard Zig main() entry point as a convenience.
pub fn main() void {
    const hInstance = GetModuleHandleW(null) orelse return;
    const cmdLine = GetCommandLineW();
    _ = wWinMain(hInstance, null, cmdLine, 1);
}
