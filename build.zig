const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    // The release tag is the single version source. CI passes the validated
    // tag as -Dversion; local builds use git describe. No repository file
    // needs a version bump.
    const version = b.option(
        []const u8,
        "version",
        "Version shown in About and VERSIONINFO; defaults to git describe --tags",
    ) orelse gitVersion(b);

    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const build_options = b.addOptions();
    build_options.addOption([]const u8, "version", version);
    mod.addOptions("build_options", build_options);

    // Generate VERSIONINFO from the same version, so the exe metadata can
    // never drift from the About box. The icon stays a normal asset.
    const semver = std.SemanticVersion.parse(version) catch std.SemanticVersion{
        .major = 0,
        .minor = 0,
        .patch = 0,
    };
    const rc = b.fmt(
        \\2 ICON "app.ico"
        \\VS_VERSION_INFO VERSIONINFO
        \\FILEVERSION {d},{d},{d},0
        \\PRODUCTVERSION {d},{d},{d},0
        \\FILEFLAGSMASK 0x3f
        \\FILEFLAGS 0x0
        \\FILEOS 0x40004
        \\FILETYPE 0x1
        \\FILESUBTYPE 0x0
        \\BEGIN
        \\    BLOCK "StringFileInfo"
        \\    BEGIN
        \\        BLOCK "040904b0"
        \\        BEGIN
        \\            VALUE "CompanyName", "yellowzq"
        \\            VALUE "FileDescription", "CClose - Windows window management tool"
        \\            VALUE "FileVersion", "{s}"
        \\            VALUE "InternalName", "CClose"
        \\            VALUE "LegalCopyright", "Copyright (c) 2026 yellowzq"
        \\            VALUE "OriginalFilename", "CClose.exe"
        \\            VALUE "ProductName", "CClose"
        \\            VALUE "ProductVersion", "{s}"
        \\        END
        \\    END
        \\    BLOCK "VarFileInfo"
        \\    BEGIN
        \\        VALUE "Translation", 0x0409, 0x04b0
        \\    END
        \\END
        \\
    , .{
        semver.major, semver.minor, semver.patch,
        semver.major, semver.minor, semver.patch,
        version,      version,
    });
    const wf = b.addWriteFiles();
    mod.addWin32ResourceFile(.{
        .file = wf.add("CClose.rc", rc),
        .include_paths = &.{b.path("assets")},
    });

    const exe = b.addExecutable(.{
        .name = "CClose",
        .root_module = mod,
    });
    exe.subsystem = .windows;

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run CClose");
    run_step.dependOn(&run_cmd.step);
}

fn gitVersion(b: *std.Build) []const u8 {
    const result = b.runFallible(
        &.{ "git", "describe", "--tags", "--always", "--dirty" },
        .{ .stderr_behavior = .ignore },
    );
    const stdout = switch (result) {
        .success => |out| out,
        else => return "0.0.0-dev",
    };
    const raw = std.mem.trim(u8, stdout, " \t\r\n");
    if (raw.len == 0) return "0.0.0-dev";
    return if (raw[0] == 'v') raw[1..] else raw;
}
