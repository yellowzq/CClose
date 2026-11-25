//! DPI and font helpers shared by the GDI-drawn UI (settings dialog and the
//! always-on-top toast). Layout stays in 96-DPI design units and is converted
//! to physical pixels with the system scale factor.

const win32 = @import("win32.zig");

pub const DESIGN_DPI: i32 = 96;

const FONT_FACE_DATA = [_]u16{ 'S', 'e', 'g', 'o', 'e', ' ', 'U', 'I', 0 };
const FONT_FACE: [*:0]const u16 = @ptrCast(&FONT_FACE_DATA);

/// System DPI (96 = 100%). The process calls SetProcessDPIAware, so this is
/// stable for its lifetime.
pub fn systemDpi() i32 {
    const hdc = win32.GetDC(null) orelse return DESIGN_DPI;
    defer _ = win32.ReleaseDC(null, hdc);
    const dpi = win32.GetDeviceCaps(hdc, win32.LOGPIXELSX);
    return if (dpi > 0) dpi else DESIGN_DPI;
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
/// dialog font at 100%. Callers keep one per process.
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

/// Work area of the primary monitor (excludes the taskbar), in physical pixels.
pub fn workArea() win32.RECT {
    var rect: win32.RECT = .{
        .left = 0,
        .top = 0,
        .right = win32.GetSystemMetrics(win32.SM_CXSCREEN),
        .bottom = win32.GetSystemMetrics(win32.SM_CYSCREEN),
    };
    _ = win32.SystemParametersInfoW(win32.SPI_GETWORKAREA, 0, @ptrCast(&rect), 0);
    return rect;
}
