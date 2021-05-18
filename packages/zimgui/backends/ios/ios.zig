const std = @import("std");
const backend = @import("../backend.zig");
const structures = @import("../../structures.zig");

// const CGFloat = ; // switch(os) {.watchos => double, else => float}
const CGFloat = f64;

pub const Context = struct {
    ref: *CData,

    pub fn renderRectangle(ctx: Context, color: structures.Color, rect: structures.Rect, radius: f64) void {
        // std.log.info("rounded rect called!", .{});
        ctx.ref.objc_draw_rect(rect.x, rect.y, rect.w, rect.h, color.r, color.g, color.b, color.a);
    }
};

pub const RerenderRequest = struct {
    pub fn queueDraw(rr: @This()) void {
        // TODO
    }
};

extern fn c_main(argc: c_int, argv: [*]const [*]const u8, data: *const backend.OpaquePtrData) c_int;

var global_data_ptr: *const backend.OpaquePtrData = undefined;

pub fn startBackend(data: *const backend.OpaquePtrData) error{Failure}!void {
    global_data_ptr = data;
    _ = c_main(@intCast(c_int, std.os.argv.len), std.os.argv.ptr, data);
    unreachable; // never returns unfortunately. that means eg leak detection will never occur. TODO.
    // fake event
    // data.pushEvent(.{ .resize = .{ .x = 0, .y = 0, .w = 200, .h = 200 } }, .{}, data.data);
}

const CData = opaque{
    extern fn objc_draw_rect(ref: *CData, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) void;
};

export fn zig_render(ref: *CData, w: CGFloat, h: CGFloat) void {
    const data = global_data_ptr; // todo make this an arg

    // todo actual screen size
    data.pushEvent(.{ .resize = .{ .x = 0, .y = 0, .w = @floatToInt(c_int, w), .h = @floatToInt(c_int, h) } }, .{}, data.data); // this shouldn't have to be sent each frame
    data.renderFrame(Context{ .ref = ref }, .{}, data.data);

    // ref.objc_draw_rect(25, 25, 100, 100, 1.0, 0.5, 0.0, 1.0);
}