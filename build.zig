const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    // Empty means "use the embedded VERSION file" (see src/lang.zig). Release
    // CI passes the tag here after checking it against VERSION.
    const version = b.option(
        []const u8,
        "version",
        "Version shown in About and VERSIONINFO; defaults to the VERSION file",
    ) orelse "";

    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const build_options = b.addOptions();
    build_options.addOption([]const u8, "version", version);
    mod.addOptions("build_options", build_options);
    // Embed the app icon into the exe (assets/app.rc -> assets/app.ico).
    mod.addWin32ResourceFile(.{ .file = b.path("assets/app.rc") });

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