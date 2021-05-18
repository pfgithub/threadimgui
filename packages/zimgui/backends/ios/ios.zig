const std = @import("std");
const backend = @import("../backend.zig");
const structures = @import("../../structures.zig");

// const CGFloat = ; // switch(os) {.watchos => double, else => float}
const CGFloat = f64;

pub const Context = struct {};

pub const RerenderRequest = struct {
    pub fn queueDraw(rr: @This()) void {
        // TODO
    }
};

extern fn c_main(argc: c_int, argv: [*]const [*]const u8, data: *const backend.OpaquePtrData) c_int;

pub fn startBackend(data: *const backend.OpaquePtrData) error{Failure}!void {
    _ = c_main(@intCast(c_int, std.os.argv.len), std.os.argv.ptr, data);
    unreachable; // never returns unfortunately. that means eg leak detection will never occur. TODO.
    // fake event
    // data.pushEvent(.{ .resize = .{ .x = 0, .y = 0, .w = 200, .h = 200 } }, .{}, data.data);
}

const CData = opaque{
    extern fn objc_draw_rect(ref: *CData, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) void;
};

export fn zig_render(ref: *CData) void {
    ref.objc_draw_rect(25, 25, 100, 100, 1.0, 0.5, 0.0, 1.0);
}