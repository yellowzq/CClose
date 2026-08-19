// Pure Win32 bindings for CClose: type aliases, structs, constants, and extern
// function declarations. No business logic. All declarations are `pub` so that
// feature modules (tooltip.zig, tray.zig, hooks.zig, main.zig) share one set.

// =============================================================================
// Windows Type Aliases (self-contained for portability)
// =============================================================================

pub const HWND = *anyopaque;
pub const HINSTANCE = *anyopaque;
pub const HICON = *anyopaque;
pub const HMENU = *anyopaque;
pub const HMODULE = *anyopaque;
pub const HHOOK = *anyopaque;
pub const HBRUSH = *anyopaque;
pub const HCURSOR = *anyopaque;
pub const HANDLE = *anyopaque;
pub const HKEY = *opaque {};
pub const HDC = *anyopaque;
pub const HGDIOBJ = *anyopaque;

pub const BOOL = i32;
pub const BYTE = u8;
pub const WORD = u16;
pub const DWORD = u32;
pub const LONG = i32;
pub const LRESULT = isize;
pub const WPARAM = usize;
pub const LPARAM = isize;
pub const LPCWSTR = [*:0]const u16;
pub const LPWSTR = [*:0]u16;

pub const POINT = extern struct {
    x: LONG,
    y: LONG,
};

pub const RECT = extern struct {
    left: LONG,
    top: LONG,
    right: LONG,
    bottom: LONG,
};

pub const SIZE = extern struct {
    cx: LONG,
    cy: LONG,
};

pub const PAINTSTRUCT = extern struct {
    hdc: HDC,
    fErase: BOOL,
    rcPaint: RECT,
    fRestore: BOOL,
    fIncUpdate: BOOL,
    rgbReserved: [32]u8,
};

pub const MSG = extern struct {
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
pub const WH_MOUSE_LL: i32 = 14;
pub const WH_KEYBOARD_LL: i32 = 13;

// Window messages
pub const WM_CREATE: u32 = 0x0001;
pub const WM_DESTROY: u32 = 2;
pub const WM_CLOSE: u32 = 0x0010;
pub const WM_COMMAND: u32 = 0x0111;
pub const WM_SYSCOMMAND: u32 = 0x0112;
pub const WM_TIMER: u32 = 0x0113;
pub const WM_LBUTTONDOWN: u32 = 0x0201;
pub const WM_LBUTTONUP: u32 = 0x0202;
pub const WM_MBUTTONDOWN: u32 = 0x0207;
pub const WM_MBUTTONUP: u32 = 0x0208;
pub const WM_RBUTTONDOWN: u32 = 0x0204;
pub const WM_RBUTTONUP: u32 = 0x0205;
pub const WM_MOUSEMOVE: u32 = 0x0200;
pub const WM_NCHITTEST: u32 = 0x0084;
pub const WM_PAINT: u32 = 0x000F;

pub const WM_USER: u32 = 0x0400;
// Tray icon callback message (app-defined: WM_USER + 1), shared by tray.zig and
// main.zig's window procedure.
pub const WM_TRAY: u32 = 0x8001;

// System command parameters
pub const SC_CLOSE: WPARAM = 0xF060;
pub const SC_MINIMIZE: WPARAM = 0xF020;

// Hit test results
pub const HTCAPTION: LONG = 2;

// Extended window styles
pub const WS_EX_TOOLWINDOW: u32 = 0x00000080;
pub const WS_EX_TOPMOST: u32 = 0x00000008;
pub const WS_EX_NOACTIVATE: u32 = 0x08000000;

// Window styles
pub const WS_POPUP: u32 = 0x80000000;

// SetWindowPos flags
pub const SWP_NOSIZE: u32 = 0x0001;
pub const SWP_NOMOVE: u32 = 0x0002;
pub const SWP_NOACTIVATE: u32 = 0x0010;
pub const SWP_NOZORDER: u32 = 0x0004;
pub const SWP_FRAMECHANGED: u32 = 0x0020;
pub const SWP_SHOWWINDOW: u32 = 0x0040;

// Window long indices
pub const GWL_EXSTYLE: i32 = -20;

// File system
pub const MAX_PATH: u32 = 260;
pub const NIM_ADD: u32 = 0;
pub const NIM_MODIFY: u32 = 1;
pub const NIM_DELETE: u32 = 2;

// NotifyIcon flags
pub const NIF_MESSAGE: u32 = 0x0001;
pub const NIF_ICON: u32 = 0x0002;
pub const NIF_TIP: u32 = 0x0004;

// Menu flags
pub const MF_STRING: u32 = 0;
pub const MF_SEPARATOR: u32 = 0x00000800;
pub const MF_CHECKED: u32 = 0x00000008;
pub const MF_UNCHECKED: u32 = 0;

// Keyboard virtual key codes
pub const VK_ESCAPE: DWORD = 0x1B;

// Hook action codes
pub const HC_ACTION: i32 = 0;

// Keyboard hook flags
pub const LLKHF_UP: DWORD = 0x80;

// TrackPopupMenu flags
pub const TPM_RIGHTALIGN: u32 = 0x0008;
pub const TPM_RETURNCMD: u32 = 0x0100;

// Registry constants
pub const HKEY_CURRENT_USER: HKEY = @ptrFromInt(@as(usize, 0x80000001));
pub const KEY_SET_VALUE: u32 = 0x0002;
pub const KEY_QUERY_VALUE: u32 = 0x0001;
pub const REG_SZ: u32 = 1;
pub const ERROR_SUCCESS: u32 = 0;

// Special window handles for SetWindowPos
pub const HWND_TOPMOST: HWND = @ptrFromInt(@as(usize, @bitCast(@as(isize, -1))));
pub const HWND_NOTOPMOST: HWND = @ptrFromInt(@as(usize, @bitCast(@as(isize, -2))));

// Icon resource IDs
pub const IDI_APPLICATION: DWORD = 32512;

// ShowWindow / system metrics / system colors / stock objects / DrawText
pub const SW_HIDE: i32 = 0;
pub const SM_CXSCREEN: i32 = 0;
pub const SM_CYSCREEN: i32 = 1;
pub const COLOR_INFOBK: i32 = 24;
pub const COLOR_INFOTEXT: i32 = 23;
pub const COLOR_WINDOWFRAME: i32 = 6;
pub const DEFAULT_GUI_FONT: i32 = 17;
pub const TRANSPARENT: i32 = 1;
pub const DT_CENTER: u32 = 0x0001;
pub const DT_VCENTER: u32 = 0x0004;
pub const DT_SINGLELINE: u32 = 0x0020;

// Error codes
pub const ERROR_ALREADY_EXISTS: u32 = 183;

// =============================================================================
// Structures
// =============================================================================

pub const GUID = extern struct {
    Data1: u32,
    Data2: u16,
    Data3: u16,
    Data4: [8]u8,
};

pub const MSLLHOOKSTRUCT = extern struct {
    pt: POINT,
    mouseData: DWORD,
    flags: DWORD,
    time: DWORD,
    dwExtraInfo: usize,
};

pub const KBDLLHOOKSTRUCT = extern struct {
    vkCode: DWORD,
    scanCode: DWORD,
    flags: DWORD,
    time: DWORD,
    dwExtraInfo: usize,
};

pub const NOTIFYICONDATAW = extern struct {
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

pub const WNDCLASSEXW = extern struct {
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

pub extern "kernel32" fn GetModuleHandleW(
    lpModuleName: ?[*:0]const u16,
) callconv(.winapi) ?HMODULE;

pub extern "kernel32" fn QueryPerformanceCounter(
    lpPerformanceCount: *i64,
) callconv(.winapi) BOOL;

pub extern "kernel32" fn QueryPerformanceFrequency(
    lpFrequency: *i64,
) callconv(.winapi) BOOL;

pub extern "kernel32" fn GetModuleFileNameW(
    hModule: ?HMODULE,
    lpFilename: [*]u16,
    nSize: DWORD,
) callconv(.winapi) DWORD;

pub extern "kernel32" fn GetCommandLineW() callconv(.winapi) LPWSTR;

pub extern "kernel32" fn CreateMutexW(
    lpMutexAttributes: ?*anyopaque,
    bInitialOwner: BOOL,
    lpName: ?LPCWSTR,
) callconv(.winapi) ?HANDLE;

pub extern "kernel32" fn GetLastError() callconv(.winapi) u32;

// =============================================================================
// External Functions - user32.dll
// =============================================================================

pub extern "user32" fn SetWindowsHookExW(
    idHook: i32,
    lpfn: ?*const anyopaque,
    hmod: HINSTANCE,
    dwThreadId: DWORD,
) callconv(.winapi) ?HHOOK;

pub extern "user32" fn UnhookWindowsHookEx(
    hhk: HHOOK,
) callconv(.winapi) BOOL;

pub extern "user32" fn CallNextHookEx(
    hhk: ?HHOOK,
    nCode: i32,
    wParam: WPARAM,
    lParam: LPARAM,
) callconv(.winapi) LRESULT;

pub extern "user32" fn RegisterClassExW(
    lpWndClass: *const WNDCLASSEXW,
) callconv(.winapi) u16;

pub extern "user32" fn CreateWindowExW(
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

pub extern "user32" fn DefWindowProcW(
    hWnd: HWND,
    Msg: u32,
    wParam: WPARAM,
    lParam: LPARAM,
) callconv(.winapi) LRESULT;

pub extern "user32" fn DestroyWindow(
    hWnd: HWND,
) callconv(.winapi) BOOL;

pub extern "user32" fn PostQuitMessage(
    nExitCode: i32,
) callconv(.winapi) void;

pub extern "user32" fn GetMessageW(
    lpMsg: *MSG,
    hWnd: ?HWND,
    wMsgFilterMin: u32,
    wMsgFilterMax: u32,
) callconv(.winapi) BOOL;

pub extern "user32" fn TranslateMessage(
    lpMsg: *const MSG,
) callconv(.winapi) BOOL;

pub extern "user32" fn DispatchMessageW(
    lpMsg: *const MSG,
) callconv(.winapi) LRESULT;

pub extern "user32" fn LoadIconW(
    hInstance: ?HINSTANCE,
    lpIconName: ?LPCWSTR,
) callconv(.winapi) ?HICON;

pub extern "user32" fn LoadCursorW(
    hInstance: ?HINSTANCE,
    lpCursorName: ?LPCWSTR,
) callconv(.winapi) ?HCURSOR;

pub extern "user32" fn SendMessageW(
    hWnd: HWND,
    Msg: u32,
    wParam: WPARAM,
    lParam: LPARAM,
) callconv(.winapi) LRESULT;

pub extern "user32" fn PostMessageW(
    hWnd: HWND,
    Msg: u32,
    wParam: WPARAM,
    lParam: LPARAM,
) callconv(.winapi) BOOL;

pub extern "user32" fn WindowFromPoint(
    Point: POINT,
) callconv(.winapi) ?HWND;

pub extern "user32" fn GetClassNameW(
    hWnd: HWND,
    lpClassName: [*]u16,
    nMaxCount: i32,
) callconv(.winapi) i32;

pub extern "user32" fn CreatePopupMenu(
) callconv(.winapi) ?HMENU;

pub extern "user32" fn AppendMenuW(
    hMenu: HMENU,
    uFlags: u32,
    uIDNewItem: usize,
    lpNewItem: ?LPCWSTR,
) callconv(.winapi) BOOL;

pub extern "user32" fn TrackPopupMenu(
    hMenu: HMENU,
    uFlags: u32,
    x: i32,
    y: i32,
    nReserved: i32,
    hWnd: HWND,
    prcRect: ?*const anyopaque,
) callconv(.winapi) BOOL;

pub extern "user32" fn DestroyMenu(
    hMenu: HMENU,
) callconv(.winapi) BOOL;

pub extern "user32" fn SetTimer(
    hWnd: HWND,
    nIDEvent: usize,
    uElapse: u32,
    lpTimerFunc: ?*const anyopaque,
) callconv(.winapi) usize;

pub extern "user32" fn KillTimer(
    hWnd: HWND,
    nIDEvent: usize,
) callconv(.winapi) BOOL;

pub extern "user32" fn SetWindowPos(
    hWnd: HWND,
    hWndInsertAfter: HWND,
    X: i32,
    Y: i32,
    cx: i32,
    cy: i32,
    uFlags: u32,
) callconv(.winapi) BOOL;

pub extern "user32" fn GetForegroundWindow(
) callconv(.winapi) ?HWND;

pub extern "user32" fn GetCursorPos(
    lpPoint: *POINT,
) callconv(.winapi) BOOL;

pub extern "user32" fn MessageBoxW(
    hWnd: ?HWND,
    lpText: LPCWSTR,
    lpCaption: LPCWSTR,
    uType: u32,
) callconv(.winapi) i32;

pub extern "user32" fn IsWindowVisible(
    hWnd: HWND,
) callconv(.winapi) BOOL;

pub extern "user32" fn GetWindowThreadProcessId(
    hWnd: HWND,
    lpdwProcessId: ?*DWORD,
) callconv(.winapi) u32;

pub extern "user32" fn ShowWindow(
    hWnd: HWND,
    nCmdShow: i32,
) callconv(.winapi) BOOL;

pub extern "user32" fn SetForegroundWindow(
    hWnd: HWND,
) callconv(.winapi) BOOL;

pub extern "user32" fn GetWindowLongW(
    hWnd: HWND,
    nIndex: i32,
) callconv(.winapi) LONG;

pub extern "user32" fn SetWindowLongW(
    hWnd: HWND,
    nIndex: i32,
    dwNewLong: LONG,
) callconv(.winapi) LONG;

pub extern "user32" fn GetDC(
    hWnd: ?HWND,
) callconv(.winapi) ?HDC;

pub extern "user32" fn ReleaseDC(
    hWnd: ?HWND,
    hDC: HDC,
) callconv(.winapi) i32;

pub extern "user32" fn BeginPaint(
    hWnd: HWND,
    lpPaint: *PAINTSTRUCT,
) callconv(.winapi) HDC;

pub extern "user32" fn EndPaint(
    hWnd: HWND,
    lpPaint: *const PAINTSTRUCT,
) callconv(.winapi) BOOL;

pub extern "user32" fn GetClientRect(
    hWnd: HWND,
    lpRect: *RECT,
) callconv(.winapi) BOOL;

pub extern "user32" fn InvalidateRect(
    hWnd: HWND,
    lpRect: ?*const RECT,
    bErase: BOOL,
) callconv(.winapi) BOOL;

pub extern "user32" fn FillRect(
    hDC: HDC,
    lprc: *const RECT,
    hbr: HBRUSH,
) callconv(.winapi) i32;

pub extern "user32" fn FrameRect(
    hDC: HDC,
    lprc: *const RECT,
    hbr: HBRUSH,
) callconv(.winapi) i32;

pub extern "user32" fn GetSysColorBrush(
    nIndex: i32,
) callconv(.winapi) HBRUSH;

pub extern "user32" fn GetSysColor(
    nIndex: i32,
) callconv(.winapi) u32;

pub extern "user32" fn SetBkMode(
    hdc: HDC,
    iBkMode: i32,
) callconv(.winapi) i32;

pub extern "user32" fn SetTextColor(
    hdc: HDC,
    crColor: u32,
) callconv(.winapi) u32;

pub extern "user32" fn DrawTextW(
    hdc: HDC,
    lpchText: LPCWSTR,
    cchText: i32,
    lprc: *RECT,
    format: u32,
) callconv(.winapi) i32;

pub extern "user32" fn GetSystemMetrics(
    nIndex: i32,
) callconv(.winapi) i32;

pub extern "user32" fn SetProcessDPIAware() callconv(.winapi) BOOL;

// =============================================================================
// External Functions - gdi32.dll
// =============================================================================

pub extern "gdi32" fn GetStockObject(
    fnObject: i32,
) callconv(.winapi) ?HGDIOBJ;

pub extern "gdi32" fn SelectObject(
    hdc: HDC,
    h: HGDIOBJ,
) callconv(.winapi) HGDIOBJ;

pub extern "gdi32" fn GetTextExtentPoint32W(
    hdc: HDC,
    lpString: LPCWSTR,
    c: i32,
    lpSize: *SIZE,
) callconv(.winapi) BOOL;

// =============================================================================
// External Functions - shell32.dll
// =============================================================================

pub extern "shell32" fn Shell_NotifyIconW(
    dwMessage: DWORD,
    lpData: *const NOTIFYICONDATAW,
) callconv(.winapi) BOOL;

// =============================================================================
// External Functions - advapi32.dll
// =============================================================================

pub extern "advapi32" fn RegOpenKeyExW(
    hKey: HKEY,
    lpSubKey: LPCWSTR,
    ulOptions: u32,
    samDesired: u32,
    phkResult: *HKEY,
) callconv(.winapi) i32;

pub extern "advapi32" fn RegSetValueExW(
    hKey: HKEY,
    lpValueName: LPCWSTR,
    Reserved: u32,
    dwType: u32,
    lpData: [*]const u8,
    cbData: u32,
) callconv(.winapi) i32;

pub extern "advapi32" fn RegDeleteValueW(
    hKey: HKEY,
    lpValueName: LPCWSTR,
) callconv(.winapi) i32;

pub extern "advapi32" fn RegCloseKey(
    hKey: HKEY,
) callconv(.winapi) i32;

pub extern "advapi32" fn RegQueryValueExW(
    hKey: HKEY,
    lpValueName: LPCWSTR,
    lpReserved: ?*DWORD,
    lpType: ?*DWORD,
    lpData: ?[*]u8,
    lpcbData: *DWORD,
) callconv(.winapi) i32;
