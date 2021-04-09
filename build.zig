const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const tracy_enabled = b.option([]const u8, "tracy", "Enable tracy");

    const exe = b.addExecutable("threadimgui", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);

    exe.linkLibC();

    exe.linkSystemLibrary("cairo");
    exe.linkSystemLibrary("gtk+-3.0");
    exe.addIncludeDir("src/c");
    exe.addCSourceFile("src/c/cairo_cbind.c", &[_][]const u8{});

    exe.addBuildOption(bool, "enable_tracy", tracy_enabled != null);
    if (tracy_enabled) |tracy_path| {
        exe.addIncludeDir(tracy_path);
        exe.addCSourceFile(
            std.fs.path.join(b.allocator, &[_][]const u8{ tracy_path, "TracyClient.cpp" }) catch @panic("oom"),
            &[_][]const u8{ "-DTRACY_ENABLE=1", "-fno-sanitize=undefined" },
        );
        exe.linkSystemLibrary("c++");
        exe.linkLibC();
        if (exe.target.isWindows()) {
            exe.linkSystemLibrary("Advapi32");
            exe.linkSystemLibrary("User32");
        }
    }

    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
