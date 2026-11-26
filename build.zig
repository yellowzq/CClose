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
