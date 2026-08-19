const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    // Embed the app icon into the exe (assets/app.rc -> assets/app.ico).
    mod.addWin32ResourceFile(.{ .file = b.path("assets/app.rc") });

    const exe = b.addExecutable(.{
        .name = "CClose",
        .root_module = mod,
    });
    exe.win32_manifest = null;
    exe.subsystem = .windows;

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run CClose");
    run_step.dependOn(&run_cmd.step);
}