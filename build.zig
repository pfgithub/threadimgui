const std = @import("std");

const RenderBackend = enum {
    cairo_gtk3,
    windows,
    ios,
    raylib,
    pub fn defaultFor(target: std.zig.CrossTarget) ?RenderBackend {
        if (target.isWindows()) return .windows;
        if (target.isLinux()) return .cairo_gtk3;
        if (target.getOsTag() == .ios) return .ios;
        return null;
    }
};

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const tracy_enabled = b.option([]const u8, "tracy", "Enable tracy (path to folder containing TracyClient.cpp)");
    // more build options:
    // - enable devtools (defaults to true on Debug, false on Release builds)
    // - set backend (defaults to cairo, only option is cairo)
    //   (in the future this would pick based on what platform you're building for)

    const render_backend = b.option(RenderBackend, "renderer", "Set the render backend") orelse //
        RenderBackend.defaultFor(target) orelse //
        @panic("there is no default backend for this target; select one with -Drenderer=[backend]") //
    ;

    const raylib_version = b.option([]const u8, "raylib-version", "Set the verison if using the raylib backend");

    const devtools_enabled = b.option(bool, "devtools", "Enable or disable devtools") orelse (mode == .Debug);

    const main_file = "apps/app_selector.zig";
    const app_name = "app_selector";

    const exe = switch (render_backend) {
        .cairo_gtk3, .windows, .raylib => b.addExecutable(app_name, main_file),
        .ios => b.addStaticLibrary(app_name, main_file),
    };
    if (render_backend == .ios) {
        exe.bundle_compiler_rt = true;
    }
    exe.setTarget(target);
    exe.setBuildMode(mode);

    exe.addBuildOption(RenderBackend, "render_backend", render_backend);
    exe.addBuildOption(bool, "devtools_enabled", devtools_enabled);
    exe.addPackagePath("callbacks", "packages/callbacks/callbacks.zig");

    var imgui_deps = std.ArrayList(std.build.Pkg).init(b.allocator);
    imgui_deps.appendSlice(&.{
        .{ .name = "build_options", .path = "zig-cache/" ++ app_name ++ "_build_options.zig" },
        .{ .name = "callbacks", .path = "packages/callbacks/callbacks.zig" },
    }) catch @panic("oom");
    switch (render_backend) {
        .cairo_gtk3 => {
            exe.linkLibC();

            exe.linkSystemLibrary("cairo");
            exe.linkSystemLibrary("gtk+-3.0");
            exe.addIncludeDir("packages/zimgui/backends/cairo");
            exe.addCSourceFile("packages/zimgui/backends/cairo/cairo_cbind.c", &[_][]const u8{});
        },
        .windows => {
            exe.linkLibC();
            exe.linkSystemLibrary("gdi32");
            exe.addIncludeDir("packages/zimgui/backends/windows");
            exe.addCSourceFile("packages/zimgui/backends/windows/windows_cbind.c", &[_][]const u8{});
        },
        .ios => {
            // idk
        },
        .raylib => {
            exe.linkLibC();
            exe.addIncludeDir("packages/zimgui/backends/raylib/workaround");
            exe.addCSourceFile("packages/zimgui/backends/raylib/workaround/workaround.c", &.{});
            imgui_deps.append(
                .{.name = "raylib", .path = "packages/zimgui/backends/raylib/workaround/raylib.zig"},
            ) catch @panic("oom");

            const raylib_name = "packages/zimgui/backends/raylib/deps/raylib-{s}_{s}/{s}";
            const target_name: []const u8 = switch(target.getOsTag()) {
                .macos => blk: {
                    exe.linkFramework("CoreVideo");
                    exe.linkFramework("IOKit");
                    exe.linkFramework("Cocoa");
                    exe.linkFramework("GLUT");
                    exe.linkFramework("OpenGL");
                    break :blk "macos";
                },
                else => @panic("raylib is not supported for this target"),
            };

            const version = raylib_version orelse {
                @panic("a raylib version must be set with -Draylib-version=[version] eg 3.7.0");
            };
            exe.addIncludeDir(b.fmt(raylib_name, .{version, target_name, "include"}));
            exe.addObjectFile(b.fmt(raylib_name, .{version, target_name, "lib/libraylib.a"}));
        },
    }
    exe.addPackage(.{
        .name = "imgui",
        .path = "packages/zimgui/main.zig",
        .dependencies = imgui_deps.toOwnedSlice(),
    });

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

    if (exe.kind == .Exe) {
        const run_cmd = exe.run();
        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);
    }
}
