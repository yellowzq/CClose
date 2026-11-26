const std = @import("std");
const w = std.os.windows;

extern "kernel32" fn GetEnvironmentVariableW(lpName: [*:0]const u16, lpBuffer: [*]u16, nSize: u32) u32;
extern "kernel32" fn CreateDirectoryW(lpPathName: [*:0]const u16, lpSecurityAttributes: ?*anyopaque) i32;
extern "advapi32" fn RegOpenKeyExW(hKey: w.HKEY, lpSubKey: [*:0]const u16, ulOptions: u32, samDesired: u32, phkResult: *w.HKEY) i32;
extern "advapi32" fn RegSetValueExW(hKey: w.HKEY, lpValueName: [*:0]const u16, Reserved: u32, dwType: u32, lpData: [*]const u8, cbData: u32) i32;
extern "advapi32" fn RegDeleteValueW(hKey: w.HKEY, lpValueName: [*:0]const u16) i32;
extern "advapi32" fn RegCloseKey(hKey: w.HKEY) i32;
extern "advapi32" fn RegQueryValueExW(hKey: w.HKEY, lpValueName: [*:0]const u16, lpReserved: ?*u32, lpType: ?*u32, lpData: ?[*]u8, lpcbData: *u32) i32;
extern "kernel32" fn WritePrivateProfileStringW(lpAppName: [*:0]const u16, lpKeyName: [*:0]const u16, lpString: [*:0]const u16, lpFileName: [*:0]const u16) i32;
extern "kernel32" fn GetPrivateProfileStringW(lpAppName: [*:0]const u16, lpKeyName: [*:0]const u16, lpDefault: ?[*:0]const u16, lpReturnedString: [*]u16, nSize: u32, lpFileName: [*:0]const u16) u32;
extern "kernel32" fn GetModuleFileNameW(hModule: ?*anyopaque, lpFilename: [*]u16, nSize: u32) u32;

const app_name = "CClose";
const APP_NAME_W: [*:0]const u16 = @ptrCast(&[_]u16{ 'C', 'C', 'l', 'o', 's', 'e', 0 });
const ini_dir = "CClose";
const ini_file = "CClose.ini";

fn u8ToW(input: []const u8) ![:0]u16 {
    return try std.unicode.utf8ToUtf16LeAllocZ(std.heap.page_allocator, input);
}

fn getAppData(a: std.mem.Allocator) ?[]const u8 {
    var buf: [4096]u16 = undefined;
    const len = GetEnvironmentVariableW(@ptrCast(&[_]u16{ 'A', 'P', 'P', 'D', 'A', 'T', 'A', 0 }), &buf, @intCast(buf.len));
    if (len == 0) return null;
    return std.unicode.utf16LeToUtf8Alloc(a, buf[0..len]) catch return null;
}

fn parsePipeList(input: []const u8, a: std.mem.Allocator) std.ArrayList([]const u8) {
    var list: std.ArrayList([]const u8) = .empty;
    if (input.len == 0) return list;
    var it = std.mem.splitScalar(u8, input, '|');
    while (it.next()) |item| {
        if (item.len > 0) {
            list.append(a, a.dupe(u8, item) catch unreachable) catch unreachable;
        }
    }
    return list;
}

pub const Config = struct {
    enable_titlebar_middle_click: bool = true,
    enable_titlebar_right_click: bool = true,
    enable_titlebar_hold_left_click: bool = true,
    enable_esc_double_press: bool = true,
    enable_transparency: bool = true,
    titlebar_exceptions: std.ArrayList([]const u8),
    esc_blacklist: std.ArrayList([]const u8),

    pub fn load(a: std.mem.Allocator) !@This() {
        var self = @This(){
            .titlebar_exceptions = .empty,
            .esc_blacklist = .empty,
        };
        const appdata = getAppData(a) orelse "C:\\Users\\Default\\AppData\\Roaming";
        const ini_path = try std.fs.path.join(a, &.{ appdata, ini_dir, ini_file });
        defer a.free(ini_path);

        if (std.fs.path.dirname(ini_path)) |dir| {
            if (u8ToW(dir)) |d| {
                _ = CreateDirectoryW(d.ptr, null);
                std.heap.page_allocator.free(d);
            } else |_| {}
        }

        self.enable_titlebar_middle_click = readBool(ini_path, "General", "EnableTitleBarMiddleClick", true);
        self.enable_titlebar_right_click = readBool(ini_path, "General", "EnableTitleBarRightClick", true);
        self.enable_titlebar_hold_left_click = readBool(ini_path, "General", "EnableTitleBarHoldLeftClick", true);
        self.enable_esc_double_press = readBool(ini_path, "General", "EnableEscKeyDoublePress", true);
        self.enable_transparency = readBool(ini_path, "General", "EnableTransparency", true);

        const ex_list = readStr(ini_path, "Advanced", "TitleBarExceptionList", "", a);
        defer a.free(ex_list);
        self.titlebar_exceptions = parsePipeList(ex_list, a);

        const bl_list = readStr(ini_path, "Advanced", "EscHotkeyBlackList", "", a);
        defer a.free(bl_list);
        self.esc_blacklist = parsePipeList(bl_list, a);

        return self;
    }

    pub fn save(self: *const @This(), a: std.mem.Allocator) void {
        const appdata = getAppData(a) orelse "C:\\Users\\Default\\AppData\\Roaming";
        const ini_path = std.fs.path.join(a, &.{ appdata, ini_dir, ini_file }) catch return;
        defer a.free(ini_path);
        writeBool(ini_path, "General", "EnableTitleBarMiddleClick", self.enable_titlebar_middle_click);
        writeBool(ini_path, "General", "EnableTitleBarRightClick", self.enable_titlebar_right_click);
        writeBool(ini_path, "General", "EnableTitleBarHoldLeftClick", self.enable_titlebar_hold_left_click);
        writeBool(ini_path, "General", "EnableEscKeyDoublePress", self.enable_esc_double_press);
        writeBool(ini_path, "General", "EnableTransparency", self.enable_transparency);
        writeList(ini_path, "Advanced", "TitleBarExceptionList", self.titlebar_exceptions.items, a);
        writeList(ini_path, "Advanced", "EscHotkeyBlackList", self.esc_blacklist.items, a);
    }
};

fn getIniPath(a: std.mem.Allocator) ![]u8 {
    const appdata = getAppData(a) orelse "C:\\Users\\Default\\AppData\\Roaming";
    return try std.fs.path.join(a, &.{ appdata, ini_dir, ini_file });
}

fn readBool(ini: []const u8, section: []const u8, key: []const u8, default: bool) bool {
    const iniW = u8ToW(ini) catch return default;
    defer std.heap.page_allocator.free(iniW);
    const secW = u8ToW(section) catch return default;
    defer std.heap.page_allocator.free(secW);
    const keyW = u8ToW(key) catch return default;
    defer std.heap.page_allocator.free(keyW);
    var buf: [8]u16 = undefined;
    _ = GetPrivateProfileStringW(
        secW.ptr, keyW.ptr,
        if (default) @as([*:0]const u16, @ptrCast(&[_:0]u16{'1'})) else @as([*:0]const u16, @ptrCast(&[_:0]u16{'0'})),
        &buf, @intCast(buf.len), iniW.ptr,
    );
    return buf[0] == '1';
}

fn writeBool(ini: []const u8, section: []const u8, key: []const u8, value: bool) void {
    const iniW = u8ToW(ini) catch return;
    defer std.heap.page_allocator.free(iniW);
    const secW = u8ToW(section) catch return;
    defer std.heap.page_allocator.free(secW);
    const keyW = u8ToW(key) catch return;
    defer std.heap.page_allocator.free(keyW);
    _ = WritePrivateProfileStringW(
        secW.ptr, keyW.ptr,
        if (value) @as([*:0]const u16, @ptrCast(&[_:0]u16{'1'})) else @as([*:0]const u16, @ptrCast(&[_:0]u16{'0'})),
        iniW.ptr,
    );
}

fn readStr(ini: []const u8, section: []const u8, key: []const u8, default: []const u8, a: std.mem.Allocator) []u8 {
    const iniW = u8ToW(ini) catch return a.dupe(u8, default) catch unreachable;
    defer std.heap.page_allocator.free(iniW);
    const secW = u8ToW(section) catch return a.dupe(u8, default) catch unreachable;
    defer std.heap.page_allocator.free(secW);
    const keyW = u8ToW(key) catch return a.dupe(u8, default) catch unreachable;
    defer std.heap.page_allocator.free(keyW);
    var buf: [4096]u16 = undefined;
    const result = GetPrivateProfileStringW(secW.ptr, keyW.ptr, &[_:0]u16{0}, &buf, @intCast(buf.len), iniW.ptr);
    if (result == 0) return a.dupe(u8, default) catch unreachable;
    return std.unicode.utf16LeToUtf8Alloc(a, buf[0..result]) catch return a.dupe(u8, default) catch unreachable;
}

fn writeList(ini: []const u8, section: []const u8, key: []const u8, items: []const []const u8, a: std.mem.Allocator) void {
    if (items.len == 0) {
        writeStr(ini, section, key, "", a);
        return;
    }
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(a);
    for (items, 0..) |item, i| {
        if (i > 0) list.append(a, '|') catch return;
        list.appendSlice(a, item) catch return;
    }
    writeStr(ini, section, key, list.items, a);
}

fn writeStr(ini: []const u8, section: []const u8, key: []const u8, value: []const u8, a: std.mem.Allocator) void {
    _ = a;
    const iniW = u8ToW(ini) catch return;
    defer std.heap.page_allocator.free(iniW);
    const secW = u8ToW(section) catch return;
    defer std.heap.page_allocator.free(secW);
    const keyW = u8ToW(key) catch return;
    defer std.heap.page_allocator.free(keyW);
    const valW = u8ToW(value) catch return;
    defer std.heap.page_allocator.free(valW);
    _ = WritePrivateProfileStringW(secW.ptr, keyW.ptr, valW.ptr, iniW.ptr);
}

const KEY_SET_VALUE: u32 = 0x0002;
const KEY_READ: u32 = 0x00020019;
const REG_SZ: u32 = 1;

pub fn setAutostart(enabled: bool) bool {
    // Per-user Run key (HKCU): no admin rights needed. HKLM\...\Run requires
    // elevation, so writing there silently failed for non-elevated processes.
    const run_path = u8ToW("SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run") catch return false;
    defer std.heap.page_allocator.free(run_path);
    const name = APP_NAME_W;
    var hkey: w.HKEY = undefined;
    if (RegOpenKeyExW(w.HKEY_CURRENT_USER, run_path.ptr, 0, KEY_SET_VALUE, &hkey) != 0) return false;
    defer _ = RegCloseKey(hkey);
    if (enabled) {
        var buf: [1024]u16 = undefined;
        const len = GetModuleFileNameW(null, &buf, @intCast(buf.len));
        if (len == 0) return false;
        _ = RegSetValueExW(hkey, name, 0, REG_SZ, @ptrCast(&buf), len * 2 + 2);
    } else {
        _ = RegDeleteValueW(hkey, name);
    }
    return true;
}

pub fn isAutostartEnabled() bool {
    const run_path = u8ToW("SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run") catch return false;
    defer std.heap.page_allocator.free(run_path);
    const name = APP_NAME_W;
    var hkey: w.HKEY = undefined;
    if (RegOpenKeyExW(w.HKEY_CURRENT_USER, run_path.ptr, 0, KEY_READ, &hkey) != 0) return false;
    defer _ = RegCloseKey(hkey);
    var buf: [128]u16 = undefined;
    var size: u32 = @intCast(buf.len * 2);
    return RegQueryValueExW(hkey, name, null, null, @ptrCast(&buf), &size) == 0;
}