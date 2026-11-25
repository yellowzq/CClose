// Always-on-top toast: a dedicated WS_POPUP + WS_EX_TOPMOST window drawn with GDI
// that appears near the cursor for a short while when a window is toggled to/from
// always-on-top. Owns all tooltip window state; nothing else touches it.

const std = @import("std");
const win32 = @import("win32.zig");
const ui = @import("ui.zig");

// =============================================================================
// Tooltip constants
// =============================================================================

const TOOLTIP_TIMER_ID: usize = 20;
const TOOLTIP_SHOW_MS: u32 = 1500;
const TIP_PAD_X: i32 = 16;
const TIP_PAD_Y: i32 = 6;
const TIP_OFFSET_X: i32 = 12;
const TIP_OFFSET_Y: i32 = 16;

const TIP_CLASS_NAME_DATA = [_]u16{ 'C', 'C', 'l', 'o', 's', 'e', 'T', 'i', 'p', 'C', 'l', 'a', 's', 's', 0 };
const TIP_CLASS_NAME: [*:0]const u16 = @ptrCast(&TIP_CLASS_NAME_DATA);
const TIP_WINDOW_NAME_DATA = [_]u16{ 0 };
const TIP_WINDOW_NAME: [*:0]const u16 = @ptrCast(&TIP_WINDOW_NAME_DATA);

// =============================================================================
// Tooltip state
// =============================================================================

var g_hTip: ?win32.HWND = null;
var g_tip_text: ?win32.LPCWSTR = null;
var g_on_text: ?[:0]const u16 = null;
var g_off_text: ?[:0]const u16 = null;
var g_tip_visible: bool = false;
var g_scale: f32 = 1.0;
var g_font: ?win32.HGDIOBJ = null;

// =============================================================================
// Public API
// =============================================================================

/// Register the tip class and create the toast window. `on_text`/`off_text` are
/// arena-allocated by the caller (main.zig) and live for the whole process; only
/// their pointers are kept. Returns false if window creation failed.
pub fn init(hInstance: win32.HINSTANCE, on_text: [:0]const u16, off_text: [:0]const u16) bool {
    g_on_text = on_text;
    g_off_text = off_text;
    g_scale = ui.scaleFor(ui.systemDpi());
    g_font = ui.font(g_scale);

    var wc: win32.WNDCLASSEXW = undefined;
    wc.cbSize = @sizeOf(win32.WNDCLASSEXW);
    wc.style = 0;
    wc.lpfnWndProc = tipWndProc;
    wc.cbClsExtra = 0;
    wc.cbWndExtra = 0;
    wc.hInstance = hInstance;
    wc.hIcon = null;
    wc.hCursor = null;
    wc.hbrBackground = @as(win32.HBRUSH, @ptrFromInt(@as(usize, 1)));
    wc.lpszMenuName = null;
    wc.lpszClassName = TIP_CLASS_NAME;
    wc.hIconSm = null;
    _ = win32.RegisterClassExW(&wc);

    const hwnd = win32.CreateWindowExW(
        win32.WS_EX_TOPMOST | win32.WS_EX_TOOLWINDOW | win32.WS_EX_NOACTIVATE,
        TIP_CLASS_NAME,
        TIP_WINDOW_NAME,
        win32.WS_POPUP,
        0,
        0,
        1,
        1,
        null,
        null,
        hInstance,
        null,
    ) orelse return false;
    g_hTip = hwnd;
    g_tip_visible = false;
    return true;
}

/// Show the toast for the new always-on-top state. `target` selects the monitor
/// (the window whose state changed) and anchors the toast if the cursor is not
/// on that monitor.
pub fn showTopmost(is_on: bool, target: ?win32.HWND) void {
    const text = if (is_on) g_on_text else g_off_text;
    const t = text orelse return;
    doShow(t, target);
}

/// Hide the toast (used by the auto-hide timer and on shutdown).
pub fn hide() void {
    const tip = g_hTip orelse return;
    _ = win32.KillTimer(tip, TOOLTIP_TIMER_ID);
    if (g_tip_visible) {
        _ = win32.ShowWindow(tip, win32.SW_HIDE);
        g_tip_visible = false;
    }
}

/// Hide and destroy the toast window (called from the main window's WM_DESTROY).
pub fn destroy() void {
    const tip = g_hTip orelse return;
    hide();
    _ = win32.DestroyWindow(tip);
    g_hTip = null;
}

// =============================================================================
// Internals
// =============================================================================

fn doShow(text: [:0]const u16, target: ?win32.HWND) void {
    const tip = g_hTip orelse return;
    g_tip_text = text.ptr;
    // Measure the text with the same font that paints it.
    var sz: win32.SIZE = .{ .cx = 120, .cy = 20 };
    if (win32.GetDC(null)) |hdc| {
        defer _ = win32.ReleaseDC(null, hdc);
        if (g_font orelse win32.GetStockObject(win32.DEFAULT_GUI_FONT)) |hFont| {
            const prev = win32.SelectObject(hdc, hFont);
            _ = win32.GetTextExtentPoint32W(hdc, text.ptr, @intCast(text.len), &sz);
            _ = win32.SelectObject(hdc, prev);
        }
    }
    const pad_x = ui.px(TIP_PAD_X, g_scale);
    const pad_y = ui.px(TIP_PAD_Y, g_scale);
    const w = sz.cx + pad_x * 2;
    const h = sz.cy + pad_y * 2;
    var pt: win32.POINT = undefined;
    _ = win32.GetCursorPos(&pt);
    const work = workAreaFor(target, pt);
    var target_rect: ?win32.RECT = null;
    if (target) |hWnd| {
        var wr: win32.RECT = undefined;
        if (win32.GetWindowRect(hWnd, &wr) != 0) target_rect = wr;
    }
    const pos = placeToast(
        pt,
        .{ .cx = w, .cy = h },
        work,
        target_rect,
        ui.px(TIP_OFFSET_X, g_scale),
        ui.px(TIP_OFFSET_Y, g_scale),
    );
    _ = win32.SetWindowPos(tip, win32.HWND_TOPMOST, pos.x, pos.y, w, h, win32.SWP_NOACTIVATE | win32.SWP_SHOWWINDOW);
    g_tip_visible = true;
    _ = win32.InvalidateRect(tip, null, @as(win32.BOOL, 1));
    _ = win32.SetTimer(tip, TOOLTIP_TIMER_ID, TOOLTIP_SHOW_MS, null);
}

/// Work area (monitor rect minus taskbars) of the monitor containing the target
/// window, or of the monitor under the cursor when there is no target window.
/// Falls back to the whole virtual desktop if monitor queries fail.
fn workAreaFor(target: ?win32.HWND, cursor: win32.POINT) win32.RECT {
    var monitor: ?win32.HMONITOR = null;
    if (target) |hWnd| monitor = win32.MonitorFromWindow(hWnd, win32.MONITOR_DEFAULTTONEAREST);
    if (monitor == null) monitor = win32.MonitorFromPoint(cursor, win32.MONITOR_DEFAULTTONEAREST);
    if (monitor) |m| {
        var mi: win32.MONITORINFO = .{
            .cbSize = @sizeOf(win32.MONITORINFO),
            .rcMonitor = undefined,
            .rcWork = undefined,
            .dwFlags = 0,
        };
        if (win32.GetMonitorInfoW(m, &mi) != 0) return mi.rcWork;
    }
    const left = win32.GetSystemMetrics(win32.SM_XVIRTUALSCREEN);
    const top = win32.GetSystemMetrics(win32.SM_YVIRTUALSCREEN);
    return .{
        .left = left,
        .top = top,
        .right = left + win32.GetSystemMetrics(win32.SM_CXVIRTUALSCREEN),
        .bottom = top + win32.GetSystemMetrics(win32.SM_CYVIRTUALSCREEN),
    };
}

/// Place the toast near the cursor, clamped to `work`. If the cursor is not on
/// the target window's monitor (window on a secondary screen, or a stray move),
/// anchor it above the target window and center it horizontally instead.
fn placeToast(
    cursor: win32.POINT,
    size: win32.SIZE,
    work: win32.RECT,
    target_rect: ?win32.RECT,
    offset_x: i32,
    offset_y: i32,
) win32.POINT {
    const max_x = @max(work.left, work.right - size.cx);
    const max_y = @max(work.top, work.bottom - size.cy);
    const cursor_on_work = cursor.x >= work.left and cursor.x < work.right and
        cursor.y >= work.top and cursor.y < work.bottom;
    var x: i32 = cursor.x + offset_x;
    var y: i32 = cursor.y + offset_y;
    if (!cursor_on_work) {
        if (target_rect) |r| {
            x = r.left + @divTrunc((r.right - r.left) - size.cx, 2);
            const above = r.top - size.cy - offset_y;
            y = if (above >= work.top) above else work.top + offset_y;
        }
    }
    return .{
        .x = std.math.clamp(x, work.left, max_x),
        .y = std.math.clamp(y, work.top, max_y),
    };
}

fn tipWndProc(hWnd: win32.HWND, message: u32, wParam: win32.WPARAM, lParam: win32.LPARAM) callconv(.winapi) win32.LRESULT {
    switch (message) {
        win32.WM_PAINT => {
            var ps: win32.PAINTSTRUCT = undefined;
            const hdc = win32.BeginPaint(hWnd, &ps);
            defer _ = win32.EndPaint(hWnd, &ps);
            var rc: win32.RECT = undefined;
            _ = win32.GetClientRect(hWnd, &rc);
            _ = win32.FillRect(hdc, &rc, win32.GetSysColorBrush(win32.COLOR_INFOBK));
            _ = win32.FrameRect(hdc, &rc, win32.GetSysColorBrush(win32.COLOR_WINDOWFRAME));
            if (g_tip_text) |text| {
                _ = win32.SetBkMode(hdc, win32.TRANSPARENT);
                _ = win32.SetTextColor(hdc, win32.GetSysColor(win32.COLOR_INFOTEXT));
                if (g_font orelse win32.GetStockObject(win32.DEFAULT_GUI_FONT)) |hFont| {
                    _ = win32.SelectObject(hdc, hFont);
                }
                _ = win32.DrawTextW(hdc, text, -1, &rc, win32.DT_CENTER | win32.DT_VCENTER | win32.DT_SINGLELINE);
            }
            return 0;
        },
        win32.WM_TIMER => {
            if (wParam == TOOLTIP_TIMER_ID) {
                hide();
            }
            return 0;
        },
        else => {
            return win32.DefWindowProcW(hWnd, message, wParam, lParam);
        },
    }
}
