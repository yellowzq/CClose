// Global input hooks: low-level mouse/keyboard hooks plus the derived behaviors
// (hold-left-click on a title bar toggles always-on-top, double-press Esc closes
// the foreground window). Owns all hook state; main.zig only drives suspend/
// resume/timer/shutdown through the public API.

const std = @import("std");
const config_mod = @import("config.zig");
const win32 = @import("win32.zig");
const tooltip = @import("tooltip.zig");

// =============================================================================
// Hold-to-topmost timings
// =============================================================================

const HOLD_TIMER_ID: usize = 10;
const HOLD_THRESHOLD_MS: i64 = 1000;
const DOUBLE_ESC_TIMEOUT_MS: i64 = 500;
const MOVE_THRESHOLD: i32 = 5;

// =============================================================================
// Hook state
// =============================================================================

var g_hWnd: win32.HWND = undefined;
var g_config: *const config_mod.Config = undefined;
var g_hMouseHook: ?win32.HHOOK = null;
var g_hKbdHook: ?win32.HHOOK = null;
var g_suspended: bool = false;

// Hold-to-topmost state
var g_hold_active: bool = false;
var g_hold_start_time: i64 = 0;
var g_hold_start_pos: win32.POINT = undefined;
var g_hold_target: win32.HWND = undefined;
var g_hold_timer_running: bool = false;

// Double-escape state
var g_last_esc_time: i64 = 0;
var g_last_esc_valid: bool = false;
var g_frequency: i64 = 0;

// =============================================================================
// Public API
// =============================================================================

/// Record the main window handle and the loaded config. Call once in WM_CREATE
/// after config is loaded and before install.
pub fn init(hWnd: win32.HWND, cfg: *const config_mod.Config) void {
    g_hWnd = hWnd;
    g_config = cfg;
    _ = win32.QueryPerformanceFrequency(&g_frequency);
}

pub fn isSuspended() bool {
    return g_suspended;
}

/// Mark suspended and remove the global hooks.
pub fn disable() void {
    g_suspended = true;
    uninstallHooks();
}

/// Mark resumed and reinstall the global hooks.
pub fn enable() bool {
    g_suspended = false;
    return installHooks();
}

/// Route the main window's WM_TIMER: drive the hold-to-topmost check.
pub fn onTimer(wParam: win32.WPARAM) void {
    if (wParam == HOLD_TIMER_ID) {
        handleHoldTick(g_hWnd);
    }
}

/// Stop the hold timer, clear hold state, and remove the global hooks.
pub fn shutdown() void {
    stopHoldTimer(g_hWnd);
    g_hold_active = false;
    uninstallHooks();
}

// =============================================================================
// Hook installation
// =============================================================================

fn installHooks() bool {
    const hmod = win32.GetModuleHandleW(null) orelse return false;
    g_hMouseHook = win32.SetWindowsHookExW(win32.WH_MOUSE_LL, @ptrCast(&mouseHookProc), hmod, 0);
    g_hKbdHook = win32.SetWindowsHookExW(win32.WH_KEYBOARD_LL, @ptrCast(&kbdHookProc), hmod, 0);
    return g_hMouseHook != null and g_hKbdHook != null;
}

fn uninstallHooks() void {
    if (g_hMouseHook) |h| {
        _ = win32.UnhookWindowsHookEx(h);
    }
    if (g_hKbdHook) |h| {
        _ = win32.UnhookWindowsHookEx(h);
    }
    g_hMouseHook = null;
    g_hKbdHook = null;
}

// =============================================================================
// Hold-to-topmost
// =============================================================================

fn startHoldTimer(hWnd: win32.HWND) void {
    if (!g_hold_timer_running) {
        _ = win32.SetTimer(hWnd, HOLD_TIMER_ID, 100, null);
        g_hold_timer_running = true;
    }
}

fn stopHoldTimer(hWnd: win32.HWND) void {
    if (g_hold_timer_running) {
        _ = win32.KillTimer(hWnd, HOLD_TIMER_ID);
        g_hold_timer_running = false;
    }
}

fn handleHoldTick(hWnd: win32.HWND) void {
    if (!g_hold_active) return;
    var now: i64 = 0;
    _ = win32.QueryPerformanceCounter(&now);
    const elapsed_ms = @divTrunc((now - g_hold_start_time) * 1000, g_frequency);
    if (elapsed_ms >= HOLD_THRESHOLD_MS) {
        // Toggle WS_EX_TOPMOST on the held window.
        // Extended styles are 32-bit even on 64-bit Windows.
        const ex_style = win32.GetWindowLongW(g_hold_target, win32.GWL_EXSTYLE);
        const is_topmost = (ex_style & @as(win32.LONG, @intCast(win32.WS_EX_TOPMOST))) != 0;
        const new_ex_style = if (is_topmost)
            ex_style & ~@as(win32.LONG, @intCast(win32.WS_EX_TOPMOST))
        else
            ex_style | @as(win32.LONG, @intCast(win32.WS_EX_TOPMOST));
        _ = win32.SetWindowLongW(g_hold_target, win32.GWL_EXSTYLE, new_ex_style);

        const hwnd_insert_after: win32.HWND = if (is_topmost) win32.HWND_NOTOPMOST else win32.HWND_TOPMOST;
        _ = win32.SetWindowPos(
            g_hold_target,
            hwnd_insert_after,
            0,
            0,
            0,
            0,
            win32.SWP_NOMOVE | win32.SWP_NOSIZE | win32.SWP_NOACTIVATE | win32.SWP_FRAMECHANGED,
        );
        // Notify the user of the new always-on-top state near the cursor.
        tooltip.showTopmost(!is_topmost);
        g_hold_active = false;
        stopHoldTimer(hWnd);
    }
}

fn nowInMs() i64 {
    var count: i64 = 0;
    _ = win32.QueryPerformanceCounter(&count);
    if (g_frequency == 0) return 0;
    return @divTrunc(count * 1000, g_frequency);
}

// =============================================================================
// Window classification helpers
// =============================================================================

fn packCoords(x: win32.LONG, y: win32.LONG) win32.LPARAM {
    const ux: u32 = @bitCast(x);
    const uy: u32 = @bitCast(y);
    const lo = @as(win32.LPARAM, @as(u16, @truncate(ux)));
    const hi = @as(win32.LPARAM, @as(u16, @truncate(uy))) << 16;
    return lo | hi;
}

fn isExceptionWindow(hWnd: win32.HWND, list: []const []const u8) bool {
    if (list.len == 0) return false;
    var buf: [256]u16 = undefined;
    const len = win32.GetClassNameW(hWnd, @as([*]u16, @ptrCast(&buf)), @intCast(buf.len));
    if (len <= 0) return false;
    const class_name = std.unicode.utf16LeToUtf8Alloc(std.heap.page_allocator, buf[0..@intCast(len)]) catch return false;
    defer std.heap.page_allocator.free(class_name);
    for (list) |item| {
        if (std.mem.eql(u8, class_name, item)) return true;
    }
    return false;
}

fn isTaskbarWindow(hWnd: win32.HWND) bool {
    var buf: [64]u16 = undefined;
    const len = win32.GetClassNameW(hWnd, @as([*]u16, @ptrCast(&buf)), buf.len);
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

fn isCaptionAt(hWnd: win32.HWND, x: win32.LONG, y: win32.LONG) bool {
    const lparam = packCoords(x, y);
    const result = win32.SendMessageW(hWnd, win32.WM_NCHITTEST, 0, lparam);
    return result == win32.HTCAPTION;
}

// =============================================================================
// Ctrl + mouse wheel transparency
// =============================================================================

const MIN_ALPHA: i32 = 50;
const MAX_ALPHA: i32 = 255;
const ALPHA_STEP: i32 = 15;

fn adjustOpacity(hwnd: win32.HWND, wheel_delta: i32) void {
    var alpha: u8 = 255;
    var flags: u32 = 0;
    if (win32.GetLayeredWindowAttributes(hwnd, null, &alpha, &flags) == 0) {
        alpha = 255; // Not layered yet: treat as fully opaque.
    }
    const current: i32 = alpha;
    var next = current + @divTrunc(wheel_delta, 120) * ALPHA_STEP;
    next = std.math.clamp(next, MIN_ALPHA, MAX_ALPHA);
    const ex = win32.GetWindowLongW(hwnd, win32.GWL_EXSTYLE);
    const layered_ex = ex | @as(win32.LONG, @intCast(win32.WS_EX_LAYERED));
    _ = win32.SetWindowLongW(hwnd, win32.GWL_EXSTYLE, layered_ex);
    _ = win32.SetLayeredWindowAttributes(hwnd, 0, @intCast(next), win32.LWA_ALPHA);
}

// =============================================================================
// Hook Procedures
// =============================================================================

fn mouseHookProc(nCode: i32, wParam: win32.WPARAM, lParam: win32.LPARAM) callconv(.winapi) win32.LRESULT {
    if (g_suspended) return win32.CallNextHookEx(g_hMouseHook orelse null, nCode, wParam, lParam);
    if (nCode == win32.HC_ACTION) {
        const ms: *const win32.MSLLHOOKSTRUCT = @ptrCast(@alignCast(@as(*const anyopaque, @ptrFromInt(@as(usize, @bitCast(lParam))))));
        switch (wParam) {
            win32.WM_LBUTTONDOWN, win32.WM_MBUTTONDOWN, win32.WM_RBUTTONDOWN => {
                const hwndUnder = win32.WindowFromPoint(ms.pt);
                if (hwndUnder) |hwnd| {
                    if (isTaskbarWindow(hwnd)) {
                        g_hold_active = false;
                        stopHoldTimer(g_hWnd);
                        return win32.CallNextHookEx(g_hMouseHook orelse null, nCode, wParam, lParam);
                    }
                    // Work-area semantics: a window listed in the exception list
                    // treats its whole surface as a title bar, so title-bar
                    // features work on windows without a proper one. Match the
                    // class name against the top-level window so clicks over
                    // child controls of an excepted window also count.
                    const in_workarea = isCaptionAt(hwnd, ms.pt.x, ms.pt.y) or
                        isExceptionWindow(win32.GetAncestor(hwnd, win32.GA_ROOT), g_config.titlebar_exceptions.items);
                    if (in_workarea) {
                        switch (wParam) {
                            win32.WM_MBUTTONDOWN => {
                                if (g_config.enable_titlebar_middle_click) {
                                    _ = win32.PostMessageW(hwnd, win32.WM_SYSCOMMAND, win32.SC_CLOSE, 0);
                                }
                            },
                            win32.WM_RBUTTONDOWN => {
                                if (g_config.enable_titlebar_right_click) {
                                    _ = win32.PostMessageW(hwnd, win32.WM_SYSCOMMAND, win32.SC_MINIMIZE, 0);
                                }
                            },
                            win32.WM_LBUTTONDOWN => {
                                if (g_config.enable_titlebar_hold_left_click) {
                                    g_hold_active = true;
                                    g_hold_start_pos = ms.pt;
                                    g_hold_target = hwnd;
                                    _ = win32.QueryPerformanceCounter(&g_hold_start_time);
                                    startHoldTimer(g_hWnd);
                                }
                            },
                            else => {},
                        }
                    }
                }
            },
            win32.WM_LBUTTONUP => {
                if (g_hold_active) {
                    g_hold_active = false;
                    stopHoldTimer(g_hWnd);
                }
            },
            win32.WM_MOUSEMOVE => {
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
            win32.WM_MOUSEWHEEL => {
                if (g_config.enable_transparency) {
                    // Low-level hooks don't carry modifier info; poll Ctrl directly.
                    const ctrl_down = (@as(u16, @bitCast(win32.GetAsyncKeyState(win32.VK_CONTROL))) & 0x8000) != 0;
                    if (ctrl_down) {
                        if (win32.WindowFromPoint(ms.pt)) |target| {
                            // Adjust the whole top-level window, not the deepest
                            // child under the cursor.
                            const root = win32.GetAncestor(target, win32.GA_ROOT);
                            // High word of mouseData is the signed wheel delta (±120/notch).
                            const delta: i32 = @as(i16, @bitCast(@as(u16, @truncate(ms.mouseData >> 16))));
                            adjustOpacity(root, delta);
                            return 1; // Consume: don't forward the wheel to the target window.
                        }
                    }
                }
            },
            else => {},
        }
    }
    return win32.CallNextHookEx(g_hMouseHook orelse null, nCode, wParam, lParam);
}

fn kbdHookProc(nCode: i32, wParam: win32.WPARAM, lParam: win32.LPARAM) callconv(.winapi) win32.LRESULT {
    if (g_suspended) return win32.CallNextHookEx(g_hKbdHook orelse null, nCode, wParam, lParam);
    if (nCode == win32.HC_ACTION) {
        const kbd: *const win32.KBDLLHOOKSTRUCT = @ptrCast(@alignCast(@as(*const anyopaque, @ptrFromInt(@as(usize, @bitCast(lParam))))));
        const is_key_up = (kbd.flags & win32.LLKHF_UP) != 0;
        if (kbd.vkCode == win32.VK_ESCAPE and !is_key_up and g_config.enable_esc_double_press) {
            const now = nowInMs();
            if (g_last_esc_valid and (now - g_last_esc_time) <= DOUBLE_ESC_TIMEOUT_MS) {
                // Double press: close the foreground window.
                g_last_esc_valid = false;
                if (win32.GetForegroundWindow()) |fg| {
                    if (!isExceptionWindow(fg, g_config.esc_blacklist.items)) {
                        _ = win32.PostMessageW(fg, win32.WM_SYSCOMMAND, win32.SC_CLOSE, 0);
                    }
                }
            } else {
                g_last_esc_valid = true;
                g_last_esc_time = now;
            }
        }
    }
    return win32.CallNextHookEx(g_hKbdHook orelse null, nCode, wParam, lParam);
}
