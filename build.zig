const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("threadimgui", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);

    exe.linkLibC();

    exe.linkSystemLibrary("cairo");
    exe.linkSystemLibrary("gtk+-3.0");
    exe.addIncludeDir("src/c");
    exe.addCSourceFile("src/c/cairo_cbind.c", &[_][]const u8{});

    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
