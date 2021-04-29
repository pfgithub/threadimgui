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
