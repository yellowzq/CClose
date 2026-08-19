// System tray icon: add/remove the tray icon and its tooltip string.

const win32 = @import("win32.zig");

const TRAY_ICON_ID: u32 = 1;
const TRAY_TOOLTIP = "CClose - window management";

/// Add the tray icon so the main window can receive WM_TRAY callbacks.
pub fn add(hWnd: win32.HWND, _: win32.HINSTANCE) bool {
    var nid: win32.NOTIFYICONDATAW = undefined;
    nid.cbSize = @sizeOf(win32.NOTIFYICONDATAW);
    nid.hWnd = hWnd;
    nid.uID = TRAY_ICON_ID;
    nid.uFlags = win32.NIF_MESSAGE | win32.NIF_ICON | win32.NIF_TIP;
    nid.uCallbackMessage = win32.WM_TRAY;
    const idi_app: win32.LPCWSTR = @ptrFromInt(@as(usize, win32.IDI_APPLICATION));
    nid.hIcon = win32.LoadIconW(null, idi_app);
    @memset(nid.szTip[0..], 0);
    const tip = TRAY_TOOLTIP;
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
    return win32.Shell_NotifyIconW(win32.NIM_ADD, &nid) != 0;
}

/// Remove the tray icon (called before the main window is destroyed).
pub fn remove(hWnd: win32.HWND) void {
    var nid: win32.NOTIFYICONDATAW = undefined;
    nid.cbSize = @sizeOf(win32.NOTIFYICONDATAW);
    nid.hWnd = hWnd;
    nid.uID = TRAY_ICON_ID;
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
    _ = win32.Shell_NotifyIconW(win32.NIM_DELETE, &nid);
}
