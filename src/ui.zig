//! DPI and font helpers shared by the GDI-drawn UI (settings dialog and the
//! always-on-top toast). Layout stays in 96-DPI design units and is converted
//! to physical pixels with the scale of the monitor a window is shown on.

const win32 = @import("win32.zig");

pub const DESIGN_DPI: i32 = 96;

const FONT_FACE_DATA = [_]u16{ 'S', 'e', 'g', 'o', 'e', ' ', 'U', 'I', 0 };
const FONT_FACE: [*:0]const u16 = @ptrCast(&FONT_FACE_DATA);

/// System DPI (96 = 100%). Used only as a fallback when the per-monitor
/// queries are unavailable.
pub fn systemDpi() i32 {
    const hdc = win32.GetDC(null) orelse return DESIGN_DPI;
    defer _ = win32.ReleaseDC(null, hdc);
    const dpi = win32.GetDeviceCaps(hdc, win32.LOGPIXELSX);
    return if (dpi > 0) dpi else DESIGN_DPI;
}

pub fn dpiForWindow(hwnd: win32.HWND) i32 {
    const dpi = win32.GetDpiForWindow(hwnd);
    return if (dpi > 0) @intCast(dpi) else systemDpi();
}

pub fn dpiForMonitor(monitor: win32.HMONITOR) i32 {
    var x: u32 = 0;
    var y: u32 = 0;
    if (win32.GetDpiForMonitor(monitor, win32.MDT_EFFECTIVE_DPI, &x, &y) == 0 and x > 0) {
        return @intCast(x);
    }
    return systemDpi();
}

pub fn dpiAtPoint(pt: win32.POINT) i32 {
    const monitor = win32.MonitorFromPoint(pt, win32.MONITOR_DEFAULTTONEAREST) orelse return systemDpi();
    return dpiForMonitor(monitor);
}

pub fn workAreaAt(pt: win32.POINT) win32.RECT {
    return workAreaForMonitor(win32.MonitorFromPoint(pt, win32.MONITOR_DEFAULTTONEAREST));
}

pub fn workAreaForWindow(hwnd: win32.HWND) win32.RECT {
    return workAreaForMonitor(win32.MonitorFromWindow(hwnd, win32.MONITOR_DEFAULTTONEAREST));
}

pub fn scaleFor(dpi: i32) f32 {
    return @as(f32, @floatFromInt(@max(dpi, DESIGN_DPI))) / @as(f32, @floatFromInt(DESIGN_DPI));
}

/// Convert a 96-DPI design coordinate to physical pixels.
pub fn px(v: i32, scale: f32) i32 {
    return @intFromFloat(@round(@as(f32, @floatFromInt(v)) * scale));
}

/// Convert a physical pixel width to design units, rounding up so scaled
/// controls never end up narrower than the text laid out at the native size.
pub fn design(physical: i32, scale: f32) i32 {
    return @intFromFloat(@ceil(@as(f32, @floatFromInt(physical)) / scale));
}

/// 9 pt UI font at the given scale (12 px tall at 96 DPI), matching the stock
/// dialog font at 100%. Callers keep one per DPI.
pub fn font(scale: f32) ?win32.HGDIOBJ {
    const height: i32 = -@as(i32, @intFromFloat(@round(12.0 * scale)));
    return win32.CreateFontW(
        height,
        0, // width: match the aspect ratio
        0, // escapement
        0, // orientation
        400, // FW_NORMAL
        0, // italic
        0, // underline
        0, // strikeout
        1, // DEFAULT_CHARSET
        0, // OUT_DEFAULT_PRECIS
        0, // CLIP_DEFAULT_PRECIS
        5, // CLEARTYPE_QUALITY
        0, // DEFAULT_PITCH | FF_DONTCARE
        FONT_FACE,
    );
}

fn workAreaForMonitor(monitor: ?win32.HMONITOR) win32.RECT {
    if (monitor) |m| {
        var mi: win32.MONITORINFO = .{
            .cbSize = @sizeOf(win32.MONITORINFO),
            .rcMonitor = undefined,
            .rcWork = undefined,
            .dwFlags = 0,
        };
        if (win32.GetMonitorInfoW(m, &mi) != 0) return mi.rcWork;
    }
    // Whole virtual desktop: never clamp to the primary monitor only.
    const left = win32.GetSystemMetrics(win32.SM_XVIRTUALSCREEN);
    const top = win32.GetSystemMetrics(win32.SM_YVIRTUALSCREEN);
    return .{
        .left = left,
        .top = top,
        .right = left + win32.GetSystemMetrics(win32.SM_CXVIRTUALSCREEN),
        .bottom = top + win32.GetSystemMetrics(win32.SM_CYVIRTUALSCREEN),
    };
}
