//! Load the application icon embedded in the exe resources (assets/app.rc).

const win32 = @import("win32.zig");

/// Icon resource ID declared in assets/app.rc. Even value so the pointer cast
/// to LPCWSTR keeps 2-byte alignment (MAKEINTRESOURCE).
const RESOURCE_ID: usize = 2;

/// The app icon. LoadIconW resolves the best-fitting size from the multi-size
/// .ico for each context (taskbar large, title bar / tray small).
pub fn app() ?win32.HICON {
    return win32.LoadIconW(
        win32.GetModuleHandleW(null),
        @as(win32.LPCWSTR, @ptrFromInt(RESOURCE_ID)),
    );
}

/// Fallback used when the embedded icon resource cannot be loaded, so the
/// tray icon is still visible instead of silently disappearing.
pub fn fallback() ?win32.HICON {
    return win32.LoadIconW(
        null,
        @as(win32.LPCWSTR, @ptrFromInt(@as(usize, win32.IDI_APPLICATION))),
    );
}
