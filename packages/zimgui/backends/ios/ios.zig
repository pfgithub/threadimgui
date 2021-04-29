const std = @import("std");
const backend = @import("../backend.zig");
const structures = @import("../../structures.zig");

pub const Context = struct {};

pub const RerenderRequest = struct {
    pub fn queueDraw(rr: @This()) void {
        // TODO
    }
};

pub fn startBackend(data: *const backend.OpaquePtrData) error{Failure}!void {
    // fake event
    data.pushEvent(.{ .resize = .{ .x = 0, .y = 0, .w = 200, .h = 200 } }, .{}, data.data);
}

pub const StartBackend = struct {
    export fn zimgui_start() void {
        //const return_code = std.start.callMain();
        std.log.info("Hello, World!", .{});
    }
    extern fn zimgui_bind_panic() noreturn;
    pub fn panic(message: []const u8, trace: ?*std.builtin.StackTrace) noreturn {
        zimgui_bind_panic();
        // the default panic fn has a linking error missing __zig_probe_stack
    }
};
