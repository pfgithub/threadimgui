const std = @import("std");
const ray = @import("raylib");
const backend = @import("../backend.zig");
const structures = @import("../../structures.zig");

pub const Context = struct {};
pub const RerenderRequest = struct {};

pub fn startBackend(data: *const backend.OpaquePtrData) error{Failure}!void {
    ray.SetConfigFlags(ray.FLAG_WINDOW_RESIZABLE);
    // ray.SetConfigFlags(ray.FLAG_VSYNC_HINT);
    ray.SetExitKey(0);

    ray.InitWindow(800, 450, "Sample");
    defer ray.CloseWindow();

    while(!ray.WindowShouldClose()) {
        std.log.info("raying", .{});
    }
}