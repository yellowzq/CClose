// Advanced settings dialog. A modeless, self-contained Win32 dialog built from
// hand-created child controls (no resource files). It owns its module-level
// state; main.zig only calls show()/isActive()/hwnd() and routes messages.

const std = @import("std");
const config_mod = @import("config.zig");
const lang_mod = @import("lang.zig");
const win32 = @import("win32.zig");
const icon = @import("icon.zig");
const ui = @import("ui.zig");

// =============================================================================
// Class and control identifiers
// =============================================================================

const SETTINGS_CLASS_DATA = [_]u16{ 'C', 'C', 'l', 'o', 's', 'e', 'S', 'e', 't', 't', 'i', 'n', 'g', 's', 'C', 'l', 'a', 's', 's', 0 };
const SETTINGS_CLASS: [*:0]const u16 = @ptrCast(&SETTINGS_CLASS_DATA);

// Standard dialog command IDs sent by IsDialogMessageW for Enter / Esc.
const IDOK: usize = 1;
const IDCANCEL: usize = 2;

// Feature switches
const ID_EN_MIDDLE: usize = 2001;
const ID_EN_RIGHT: usize = 2002;
const ID_EN_HOLD: usize = 2003;
const ID_EN_ESC: usize = 2004;
const ID_EN_TRANSPARENCY: usize = 2005;

// Title-bar exception list (work area)
const ID_LB_EXCEPT: usize = 2101;
const ID_EDIT_EXCEPT: usize = 2102;
const ID_ADD_EXCEPT: usize = 2103;
const ID_DEL_EXCEPT: usize = 2104;

// Esc hotkey blacklist
const ID_LB_BLACK: usize = 2111;
const ID_EDIT_BLACK: usize = 2112;
const ID_ADD_BLACK: usize = 2113;
const ID_DEL_BLACK: usize = 2114;

// Window info picker
const ID_CHK_FOLLOW: usize = 2201;
const ID_TXT_TITLE: usize = 2202;
const ID_TXT_CLASS: usize = 2203;
const ID_TXT_EXE: usize = 2204;
const ID_TXT_PID: usize = 2205;
const ID_PICK_EXCEPT: usize = 2206;
const ID_PICK_BLACK: usize = 2207;

// Bottom buttons
const ID_OK: usize = 2301;
const ID_CANCEL: usize = 2302;

// Follow-mouse refresh timer
const FOLLOW_TIMER_ID: usize = 1;
const FOLLOW_TIMER_MS: u32 = 80;

// Dialog client size (layout coordinates are DPI-aware pixels).
const DLG_WIDTH: i32 = 400;
const DLG_HEIGHT: i32 = 688;

// =============================================================================
// Module state
// =============================================================================

var g_hDlg: ?win32.HWND = null;
var g_cfg: *config_mod.Config = undefined;
var g_strs: *const lang_mod.Strings = undefined;
var g_a: std.mem.Allocator = undefined;
var g_hInstance: win32.HINSTANCE = undefined;
var g_class_registered: bool = false;
var g_font: ?win32.HGDIOBJ = null;
var g_scale: f32 = 1.0;

var g_hchk_middle: win32.HWND = undefined;
var g_hchk_right: win32.HWND = undefined;
var g_hchk_hold: win32.HWND = undefined;
var g_hchk_esc: win32.HWND = undefined;
var g_hchk_trans: win32.HWND = undefined;
var g_hlb_except: win32.HWND = undefined;
var g_hedit_except: win32.HWND = undefined;
var g_hlb_black: win32.HWND = undefined;
var g_hedit_black: win32.HWND = undefined;
var g_hchk_follow: win32.HWND = undefined;
var g_htxt_title: win32.HWND = undefined;
var g_htxt_class: win32.HWND = undefined;
var g_htxt_exe: win32.HWND = undefined;
var g_htxt_pid: win32.HWND = undefined;
var g_hbtn_ok: win32.HWND = undefined;

var g_follow_active: bool = false;
var g_picked: ?win32.HWND = null;

// Edited in the dialog, committed to g_cfg only on OK.
var g_except_edit: std.ArrayList([]const u8) = .empty;
var g_black_edit: std.ArrayList([]const u8) = .empty;

// Control class names (ASCII, sentinel-terminated for wide-string coercion).
const CLASS_BUTTON = [_:0]u16{ 'B', 'U', 'T', 'T', 'O', 'N' };
const CLASS_STATIC = [_:0]u16{ 'S', 'T', 'A', 'T', 'I', 'C' };
const CLASS_EDIT = [_:0]u16{ 'E', 'D', 'I', 'T' };
const CLASS_LISTBOX = [_:0]u16{ 'L', 'I', 'S', 'T', 'B', 'O', 'X' };

// Wide empty string for controls without a caption.
const EMPTY_WIDE: [1:0]u16 = .{0};

// =============================================================================
// Public API
// =============================================================================

pub fn isActive() bool {
    return g_hDlg != null;
}

pub fn hwnd() win32.HWND {
    return g_hDlg orelse undefined;
}

/// Open (or raise) the settings dialog. `cfg` and `strs` are owned by main.zig;
/// `a` is the arena used for list-item strings, so edits share one lifetime.
pub fn show(hInstance: win32.HINSTANCE, cfg: *config_mod.Config, strs: *const lang_mod.Strings, a: std.mem.Allocator) void {
    if (g_hDlg) |h| {
        _ = win32.SetForegroundWindow(h);
        return;
    }
    g_cfg = cfg;
    g_strs = strs;
    g_a = a;
    g_hInstance = hInstance;
    registerClass(hInstance);
    if (g_font == null) {
        // One process-lifetime UI font/scale pair: the process is system-DPI
        // aware, so the system DPI cannot change while it runs.
        g_scale = chooseScale(ui.systemDpi());
        g_font = ui.font(g_scale) orelse win32.GetStockObject(win32.DEFAULT_GUI_FONT);
    }

    var title_buf: [256]u16 = undefined;
    const title = wbuf(g_strs.advanced_settings_title, &title_buf);

    var rc: win32.RECT = .{ .left = 0, .top = 0, .right = ui.px(DLG_WIDTH, g_scale), .bottom = ui.px(DLG_HEIGHT, g_scale) };
    _ = win32.AdjustWindowRectEx(&rc, win32.WS_CAPTION | win32.WS_SYSMENU, 0, 0);
    const win_w = rc.right - rc.left;
    const win_h = rc.bottom - rc.top;
    const work = ui.workArea();
    const avail_w = work.right - work.left;
    const avail_h = work.bottom - work.top;
    const x = work.left + @max(0, @divTrunc(avail_w - win_w, 2));
    const y = work.top + @max(0, @divTrunc(avail_h - win_h, 3));

    const dlg = win32.CreateWindowExW(
        0,
        SETTINGS_CLASS,
        title.ptr,
        win32.WS_CAPTION | win32.WS_SYSMENU | win32.WS_VISIBLE,
        x,
        y,
        win_w,
        win_h,
        // Standalone top-level window. Owning it to the hidden tray window
        // broke click-activation: the dialog never became the active window,
        // so its edit boxes could not receive keyboard focus and typing was
        // impossible. As an unowned window it activates on any click.
        null,
        null,
        hInstance,
        null,
    ) orelse return;
    g_hDlg = dlg;
    _ = win32.SetForegroundWindow(dlg);
    _ = win32.SetFocus(g_hbtn_ok);
}

// =============================================================================
// Class registration
// =============================================================================

fn registerClass(hInstance: win32.HINSTANCE) void {
    if (g_class_registered) return;
    var wc: win32.WNDCLASSEXW = undefined;
    wc.cbSize = @sizeOf(win32.WNDCLASSEXW);
    wc.style = 0;
    wc.lpfnWndProc = settingsWndProc;
    wc.cbClsExtra = 0;
    wc.cbWndExtra = 0;
    wc.hInstance = hInstance;
    wc.hIcon = icon.app();
    wc.hIconSm = wc.hIcon;
    wc.hCursor = null;
    wc.hbrBackground = @as(win32.HBRUSH, @ptrFromInt(@as(usize, @intCast(win32.COLOR_BTNFACE + 1))));
    wc.lpszMenuName = null;
    wc.lpszClassName = SETTINGS_CLASS;
    if (win32.RegisterClassExW(&wc) != 0) g_class_registered = true;
}

// =============================================================================
// Window procedure
// =============================================================================

fn settingsWndProc(hWnd: win32.HWND, message: u32, wParam: win32.WPARAM, lParam: win32.LPARAM) callconv(.winapi) win32.LRESULT {
    switch (message) {
        win32.WM_CREATE => {
            createControls(hWnd);
            initControls();
        },
        win32.WM_COMMAND => {
            const id = wParam & 0xFFFF;
            switch (id) {
                ID_OK, IDOK => doOk(hWnd),
                ID_CANCEL, IDCANCEL => doCancel(hWnd),
                ID_ADD_EXCEPT => addFromEdit(&g_except_edit, g_hedit_except, g_hlb_except),
                ID_DEL_EXCEPT => delSelected(&g_except_edit, g_hlb_except),
                ID_ADD_BLACK => addFromEdit(&g_black_edit, g_hedit_black, g_hlb_black),
                ID_DEL_BLACK => delSelected(&g_black_edit, g_hlb_black),
                ID_CHK_FOLLOW => toggleFollow(hWnd),
                ID_PICK_EXCEPT => addPicked(&g_except_edit, g_hlb_except),
                ID_PICK_BLACK => addPicked(&g_black_edit, g_hlb_black),
                else => {},
            }
        },
        win32.WM_TIMER => {
            if (wParam == FOLLOW_TIMER_ID) updateWindowInfo();
        },
        win32.WM_CTLCOLORSTATIC => {
            // Match the dialog's button-face background for statics, group
            // boxes, and checkboxes instead of DefWindowProc's white brush.
            const hbr = win32.GetSysColorBrush(win32.COLOR_BTNFACE);
            return @as(win32.LRESULT, @intCast(@intFromPtr(hbr)));
        },
        win32.WM_DESTROY => {
            if (g_follow_active) _ = win32.KillTimer(hWnd, FOLLOW_TIMER_ID);
            g_hDlg = null;
            g_follow_active = false;
            g_picked = null;
            g_except_edit = .empty;
            g_black_edit = .empty;
        },
        else => {
            return win32.DefWindowProcW(hWnd, message, wParam, lParam);
        },
    }
    return 0;
}

// =============================================================================
// Control creation and initialization
// =============================================================================

fn createControls(hWnd: win32.HWND) void {
    var buf: [512]u16 = undefined;
    const base = win32.WS_CHILD | win32.WS_VISIBLE | win32.WS_CLIPSIBLINGS;

    // Group 1: feature switches.
    g_hchk_middle = ctrl(hWnd, &CLASS_BUTTON, wbuf(g_strs.menu_titlebar_middle_click, &buf).ptr, base | win32.WS_TABSTOP | win32.BS_AUTOCHECKBOX, 24, 30, 360, 20, ID_EN_MIDDLE);
    g_hchk_right = ctrl(hWnd, &CLASS_BUTTON, wbuf(g_strs.menu_titlebar_right_click, &buf).ptr, base | win32.WS_TABSTOP | win32.BS_AUTOCHECKBOX, 24, 55, 360, 20, ID_EN_RIGHT);
    g_hchk_hold = ctrl(hWnd, &CLASS_BUTTON, wbuf(g_strs.menu_titlebar_hold_left_click, &buf).ptr, base | win32.WS_TABSTOP | win32.BS_AUTOCHECKBOX, 24, 80, 360, 20, ID_EN_HOLD);
    g_hchk_esc = ctrl(hWnd, &CLASS_BUTTON, wbuf(g_strs.menu_esc_double_press, &buf).ptr, base | win32.WS_TABSTOP | win32.BS_AUTOCHECKBOX, 24, 105, 360, 20, ID_EN_ESC);
    g_hchk_trans = ctrl(hWnd, &CLASS_BUTTON, wbuf(g_strs.settings_enable_transparency, &buf).ptr, base | win32.WS_TABSTOP | win32.BS_AUTOCHECKBOX, 24, 130, 360, 20, ID_EN_TRANSPARENCY);
    // Group boxes are created after their contents: child windows are placed at
    // the bottom of the sibling z-order when created, so a group box created
    // first would sit ON TOP of its contents and swallow every click aimed at
    // them (edit boxes could never gain focus, checkboxes never toggle).
    // Creating it last keeps it a paint-only frame that hit-testing passes
    // through to the controls it visually frames.
    _ = ctrl(hWnd, &CLASS_BUTTON, wbuf(g_strs.settings_features, &buf).ptr, base | win32.BS_GROUPBOX, 12, 10, 376, 150, 0);

    // Group 2: title-bar exception list (work area).
    g_hlb_except = ctrl(hWnd, &CLASS_LISTBOX, null, base | win32.WS_TABSTOP | win32.WS_BORDER | win32.WS_VSCROLL | win32.LBS_NOTIFY, 24, 186, 270, 86, ID_LB_EXCEPT);
    g_hedit_except = ctrl(hWnd, &CLASS_EDIT, null, base | win32.WS_TABSTOP | win32.WS_BORDER | win32.ES_AUTOHSCROLL, 24, 278, 270, 24, ID_EDIT_EXCEPT);
    _ = ctrl(hWnd, &CLASS_BUTTON, wbuf(g_strs.add, &buf).ptr, base | win32.WS_TABSTOP | win32.BS_PUSHBUTTON, 302, 186, 74, 24, ID_ADD_EXCEPT);
    _ = ctrl(hWnd, &CLASS_BUTTON, wbuf(g_strs.delete, &buf).ptr, base | win32.WS_TABSTOP | win32.BS_PUSHBUTTON, 302, 216, 74, 24, ID_DEL_EXCEPT);
    _ = ctrl(hWnd, &CLASS_BUTTON, wbuf(g_strs.tab_exception_list, &buf).ptr, base | win32.BS_GROUPBOX, 12, 168, 376, 164, 0);

    // Group 3: Esc hotkey blacklist.
    g_hlb_black = ctrl(hWnd, &CLASS_LISTBOX, null, base | win32.WS_TABSTOP | win32.WS_BORDER | win32.WS_VSCROLL | win32.LBS_NOTIFY, 24, 358, 270, 86, ID_LB_BLACK);
    g_hedit_black = ctrl(hWnd, &CLASS_EDIT, null, base | win32.WS_TABSTOP | win32.WS_BORDER | win32.ES_AUTOHSCROLL, 24, 450, 270, 24, ID_EDIT_BLACK);
    _ = ctrl(hWnd, &CLASS_BUTTON, wbuf(g_strs.add, &buf).ptr, base | win32.WS_TABSTOP | win32.BS_PUSHBUTTON, 302, 358, 74, 24, ID_ADD_BLACK);
    _ = ctrl(hWnd, &CLASS_BUTTON, wbuf(g_strs.delete, &buf).ptr, base | win32.WS_TABSTOP | win32.BS_PUSHBUTTON, 302, 388, 74, 24, ID_DEL_BLACK);
    _ = ctrl(hWnd, &CLASS_BUTTON, wbuf(g_strs.tab_blacklist, &buf).ptr, base | win32.BS_GROUPBOX, 12, 340, 376, 164, 0);

    // Group 4: window info picker. Size the two buttons to their translated
    // labels (measured in the dialog font) and right-align them inside the
    // group so longer captions such as "Add to Exception List" are not clipped;
    // the Follow Mouse checkbox takes the remaining width.
    const btn_pad: i32 = 20;
    const btn_gap: i32 = 6;
    const row_right: i32 = 380;
    const w_except = @max(74, ui.design(textWidth(g_strs.add_to_exception), g_scale) + btn_pad);
    const w_black = @max(74, ui.design(textWidth(g_strs.add_to_blacklist), g_scale) + btn_pad);
    const x_black = row_right - w_black;
    const x_except = x_black - btn_gap - w_except;
    const follow_w = @max(90, x_except - btn_gap - 24);
    g_hchk_follow = ctrl(hWnd, &CLASS_BUTTON, wbuf(g_strs.follow_mouse, &buf).ptr, base | win32.WS_TABSTOP | win32.BS_AUTOCHECKBOX, 24, 528, follow_w, 20, ID_CHK_FOLLOW);
    _ = ctrl(hWnd, &CLASS_BUTTON, wbuf(g_strs.add_to_exception, &buf).ptr, base | win32.WS_TABSTOP | win32.BS_PUSHBUTTON, x_except, 528, w_except, 22, ID_PICK_EXCEPT);
    _ = ctrl(hWnd, &CLASS_BUTTON, wbuf(g_strs.add_to_blacklist, &buf).ptr, base | win32.WS_TABSTOP | win32.BS_PUSHBUTTON, x_black, 528, w_black, 22, ID_PICK_BLACK);

    _ = ctrl(hWnd, &CLASS_STATIC, wbuf(g_strs.field_title, &buf).ptr, base | win32.SS_LEFT, 24, 556, 44, 18, 0);
    g_htxt_title = ctrl(hWnd, &CLASS_EDIT, null, base | win32.WS_TABSTOP | win32.WS_BORDER | win32.ES_AUTOHSCROLL | win32.ES_READONLY, 72, 554, 304, 22, ID_TXT_TITLE);
    _ = ctrl(hWnd, &CLASS_STATIC, wbuf(g_strs.field_class, &buf).ptr, base | win32.SS_LEFT, 24, 580, 44, 18, 0);
    g_htxt_class = ctrl(hWnd, &CLASS_EDIT, null, base | win32.WS_TABSTOP | win32.WS_BORDER | win32.ES_AUTOHSCROLL | win32.ES_READONLY, 72, 578, 304, 22, ID_TXT_CLASS);
    _ = ctrl(hWnd, &CLASS_STATIC, wbuf(g_strs.field_exe, &buf).ptr, base | win32.SS_LEFT, 24, 604, 44, 18, 0);
    g_htxt_exe = ctrl(hWnd, &CLASS_EDIT, null, base | win32.WS_TABSTOP | win32.WS_BORDER | win32.ES_AUTOHSCROLL | win32.ES_READONLY, 72, 602, 304, 22, ID_TXT_EXE);
    _ = ctrl(hWnd, &CLASS_STATIC, wbuf(g_strs.field_pid, &buf).ptr, base | win32.SS_LEFT, 24, 628, 44, 18, 0);
    g_htxt_pid = ctrl(hWnd, &CLASS_EDIT, null, base | win32.WS_TABSTOP | win32.WS_BORDER | win32.ES_AUTOHSCROLL | win32.ES_READONLY, 72, 626, 304, 22, ID_TXT_PID);
    _ = ctrl(hWnd, &CLASS_BUTTON, wbuf(g_strs.window_info, &buf).ptr, base | win32.BS_GROUPBOX, 12, 512, 376, 138, 0);

    // Bottom buttons.
    g_hbtn_ok = ctrl(hWnd, &CLASS_BUTTON, wbuf(g_strs.ok, &buf).ptr, base | win32.WS_TABSTOP | win32.BS_DEFPUSHBUTTON, 236, 656, 76, 24, ID_OK);
    _ = ctrl(hWnd, &CLASS_BUTTON, wbuf(g_strs.cancel, &buf).ptr, base | win32.WS_TABSTOP | win32.BS_PUSHBUTTON, 320, 656, 68, 24, ID_CANCEL);
}

/// Scale the 96-DPI layout for the current system DPI, but cap it so the whole
/// dialog still fits the work area on small or heavily scaled screens.
fn chooseScale(dpi: i32) f32 {
    var scale = ui.scaleFor(dpi);
    const work = ui.workArea();
    const avail_w = work.right - work.left;
    const avail_h = work.bottom - work.top;
    while (scale > 1.0) {
        var rc: win32.RECT = .{
            .left = 0,
            .top = 0,
            .right = ui.px(DLG_WIDTH, scale),
            .bottom = ui.px(DLG_HEIGHT, scale),
        };
        _ = win32.AdjustWindowRectEx(&rc, win32.WS_CAPTION | win32.WS_SYSMENU, 0, 0);
        if (rc.right - rc.left <= avail_w and rc.bottom - rc.top <= avail_h) break;
        scale -= 0.05;
    }
    return scale;
}

/// Create a child control (coordinates in 96-DPI design units, converted to
/// physical pixels with the current scale), apply the dialog font, and return
/// its handle.
fn ctrl(parent: win32.HWND, class: win32.LPCWSTR, text: ?win32.LPCWSTR, style: u32, x: i32, y: i32, w: i32, h: i32, id: usize) win32.HWND {
    const menu: ?win32.HMENU = if (id == 0) null else @as(?win32.HMENU, @ptrFromInt(id));
    const wtext: win32.LPCWSTR = text orelse &EMPTY_WIDE;
    const hw = win32.CreateWindowExW(
        0,
        class,
        wtext,
        style,
        ui.px(x, g_scale),
        ui.px(y, g_scale),
        ui.px(w, g_scale),
        ui.px(h, g_scale),
        parent,
        menu,
        g_hInstance,
        null,
    ) orelse return undefined;
    if (g_font) |f| {
        _ = win32.SendMessageW(hw, win32.WM_SETFONT, @intFromPtr(f), 1);
    }
    return hw;
}

fn initControls() void {
    initEditLists();
    setCheck(g_hchk_middle, g_cfg.enable_titlebar_middle_click);
    setCheck(g_hchk_right, g_cfg.enable_titlebar_right_click);
    setCheck(g_hchk_hold, g_cfg.enable_titlebar_hold_left_click);
    setCheck(g_hchk_esc, g_cfg.enable_esc_double_press);
    setCheck(g_hchk_trans, g_cfg.enable_transparency);
    setCheck(g_hchk_follow, false);
    fillListbox(g_hlb_except, g_except_edit.items);
    fillListbox(g_hlb_black, g_black_edit.items);
}

/// Copy the committed lists into the dialog's working copies. Only OK writes
/// them back; Cancel or closing the window discards the edits.
fn initEditLists() void {
    g_except_edit = .empty;
    g_black_edit = .empty;
    for (g_cfg.titlebar_exceptions.items) |item| {
        g_except_edit.append(g_a, item) catch {};
    }
    for (g_cfg.esc_blacklist.items) |item| {
        g_black_edit.append(g_a, item) catch {};
    }
}

fn setCheck(h: win32.HWND, on: bool) void {
    _ = win32.SendMessageW(h, win32.BM_SETCHECK, if (on) 1 else 0, 0);
}

fn getCheck(h: win32.HWND) bool {
    return win32.SendMessageW(h, win32.BM_GETCHECK, 0, 0) != 0;
}

fn fillListbox(h: win32.HWND, items: []const []const u8) void {
    _ = win32.SendMessageW(h, win32.LB_RESETCONTENT, 0, 0);
    var buf: [512]u16 = undefined;
    for (items) |item| {
        const witem = wbuf(item, &buf);
        _ = win32.SendMessageW(h, win32.LB_ADDSTRING, 0, @as(win32.LPARAM, @intCast(@intFromPtr(witem.ptr))));
    }
}

// =============================================================================
// List editing (shared by both lists; items are arena-allocated)
// =============================================================================

fn addFromEdit(list: *std.ArrayList([]const u8), hedit: win32.HWND, hlb: win32.HWND) void {
    var buf: [512]u16 = undefined;
    const n = win32.SendMessageW(hedit, win32.WM_GETTEXT, 512, @as(win32.LPARAM, @intCast(@intFromPtr(&buf))));
    if (n <= 0) return;
    const text = std.unicode.utf16LeToUtf8Alloc(g_a, buf[0..@intCast(n)]) catch return;
    list.append(g_a, text) catch return;
    _ = win32.SendMessageW(hlb, win32.LB_ADDSTRING, 0, @as(win32.LPARAM, @intCast(@intFromPtr(buf[0..@intCast(n) :0].ptr))));
    const empty = [_]u16{0};
    _ = win32.SendMessageW(hedit, win32.WM_SETTEXT, 0, @as(win32.LPARAM, @intCast(@intFromPtr(&empty))));
}

fn delSelected(list: *std.ArrayList([]const u8), hlb: win32.HWND) void {
    const idx = win32.SendMessageW(hlb, win32.LB_GETCURSEL, 0, 0);
    if (idx == -1 or idx >= @as(win32.LRESULT, @intCast(list.items.len))) return;
    _ = win32.SendMessageW(hlb, win32.LB_DELETESTRING, @as(win32.WPARAM, @intCast(idx)), 0);
    _ = list.orderedRemove(@as(usize, @intCast(idx)));
}

fn addPicked(list: *std.ArrayList([]const u8), hlb: win32.HWND) void {
    const h = g_picked orelse return;
    var buf: [256]u16 = undefined;
    const n = win32.GetClassNameW(h, &buf, @intCast(buf.len));
    if (n <= 0) return;
    const cls = std.unicode.utf16LeToUtf8Alloc(g_a, buf[0..@intCast(n)]) catch return;
    list.append(g_a, cls) catch return;
    _ = win32.SendMessageW(hlb, win32.LB_ADDSTRING, 0, @as(win32.LPARAM, @intCast(@intFromPtr(buf[0..@intCast(n) :0].ptr))));
}

// =============================================================================
// Follow-mouse window info
// =============================================================================

fn toggleFollow(hWnd: win32.HWND) void {
    if (getCheck(g_hchk_follow)) {
        g_follow_active = true;
        _ = win32.SetTimer(hWnd, FOLLOW_TIMER_ID, FOLLOW_TIMER_MS, null);
        updateWindowInfo();
    } else {
        g_follow_active = false;
        _ = win32.KillTimer(hWnd, FOLLOW_TIMER_ID);
    }
}

fn updateWindowInfo() void {
    var pt: win32.POINT = undefined;
    _ = win32.GetCursorPos(&pt);
    const under = win32.WindowFromPoint(pt) orelse return;
    const root = win32.GetAncestor(under, win32.GA_ROOT);
    // Keep the previously picked window while the cursor is over this dialog,
    // so moving back to click 确认/添加到… doesn't overwrite the inspected
    // window's info with the dialog's own. The pick updates only while the
    // cursor is over an external window.
    const dlg = g_hDlg orelse return;
    if (root == dlg) return;
    g_picked = root;

    var buf: [1024]u16 = undefined;
    var n = win32.GetWindowTextW(root, &buf, @intCast(buf.len));
    if (n > 0) setText(g_htxt_title, buf[0..@intCast(n)]) else setText(g_htxt_title, &.{});
    n = win32.GetClassNameW(root, &buf, @intCast(buf.len));
    if (n > 0) setText(g_htxt_class, buf[0..@intCast(n)]) else setText(g_htxt_class, &.{});

    var pid: u32 = 0;
    _ = win32.GetWindowThreadProcessId(root, &pid);
    var pidbuf: [32]u8 = undefined;
    const pidtext = std.fmt.bufPrint(&pidbuf, "{d}", .{pid}) catch unreachable;
    var wpid: [32]u16 = undefined;
    const wn = std.unicode.utf8ToUtf16Le(wpid[0 .. wpid.len - 1], pidtext) catch 0;
    setText(g_htxt_pid, wpid[0..wn]);

    updateExePath(pid);
}

fn updateExePath(pid: u32) void {
    var buf: [1024]u16 = undefined;
    const hproc = win32.OpenProcess(win32.PROCESS_QUERY_LIMITED_INFORMATION, 0, pid);
    if (hproc) |hp| {
        defer _ = win32.CloseHandle(hp);
        var size: u32 = @intCast(buf.len);
        if (win32.QueryFullProcessImageNameW(hp, 0, &buf, &size) != 0 and size > 0) {
            const full = buf[0..@intCast(size)];
            var start = full.len;
            while (start > 0 and full[start - 1] != '\\') : (start -= 1) {}
            setText(g_htxt_exe, full[start..]);
            return;
        }
    }
    setText(g_htxt_exe, &.{});
}

// =============================================================================
// OK / Cancel
// =============================================================================

fn doOk(hWnd: win32.HWND) void {
    g_cfg.enable_titlebar_middle_click = getCheck(g_hchk_middle);
    g_cfg.enable_titlebar_right_click = getCheck(g_hchk_right);
    g_cfg.enable_titlebar_hold_left_click = getCheck(g_hchk_hold);
    g_cfg.enable_esc_double_press = getCheck(g_hchk_esc);
    g_cfg.enable_transparency = getCheck(g_hchk_trans);
    g_cfg.titlebar_exceptions = g_except_edit;
    g_cfg.esc_blacklist = g_black_edit;
    g_except_edit = .empty;
    g_black_edit = .empty;
    g_cfg.save(g_a);
    _ = win32.DestroyWindow(hWnd);
}

fn doCancel(hWnd: win32.HWND) void {
    g_except_edit = .empty;
    g_black_edit = .empty;
    _ = win32.DestroyWindow(hWnd);
}

// =============================================================================
// Small helpers
// =============================================================================

fn setText(h: win32.HWND, text: []const u16) void {
    var buf: [2048]u16 = undefined;
    const n = @min(text.len, buf.len - 1);
    @memcpy(buf[0..n], text[0..n]);
    buf[n] = 0;
    _ = win32.SendMessageW(h, win32.WM_SETTEXT, 0, @as(win32.LPARAM, @intCast(@intFromPtr(&buf))));
}

/// UTF-8 to null-terminated UTF-16 in `buf` (must have room for a terminator).
fn wbuf(s: []const u8, buf: []u16) [:0]u16 {
    const n = std.unicode.utf8ToUtf16Le(buf[0 .. buf.len - 1], s) catch {
        buf[0] = 0;
        return buf[0..1 :0];
    };
    buf[n] = 0;
    return buf[0..n :0];
}

/// Physical pixel width of `s` in the dialog font, used to size buttons to
/// their translated labels (fixed widths clip longer captions like the English
/// "Add to Exception List"). Converted to design units by the caller.
fn textWidth(s: []const u8) i32 {
    const font = g_font orelse return 0;
    const hdc = win32.GetDC(null) orelse return 0;
    defer _ = win32.ReleaseDC(null, hdc);
    const prev = win32.SelectObject(hdc, font);
    defer _ = win32.SelectObject(hdc, prev);
    var buf: [512]u16 = undefined;
    const w = wbuf(s, &buf);
    var sz: win32.SIZE = .{ .cx = 0, .cy = 0 };
    if (win32.GetTextExtentPoint32W(hdc, w.ptr, @intCast(w.len), &sz) == 0) return 0;
    return sz.cx;
}
