const std = @import("std");
const backend = @import("../backend.zig");
usingnamespace @import("../../structures.zig");

export fn zig_on_resize(data: *const backend.OpaquePtrData, width: c_int, height: c_int) void {
    data.pushEvent(.{ .resize = .{ .x = 0, .y = 0, .w = width, .h = height } }, RerenderRequest{}, data.data);
}

pub const RerenderRequest = struct {
    pub fn queueDraw(rr: RerenderRequest) void {
        // TODO
    }
};
pub const TextLayout = struct {
    pub fn deinit(layout: TextLayout) void {
        // TODO
    }
    pub fn getSize(layout: TextLayout) WH {
        return .{ .w = 25, .h = 25 };
    }
};
pub const Context = struct {
    pub fn setCursor(ctx: Context, cursor_tag: CursorEnum) void {
        std.log.warn("setCursor not implemented", .{});
    }
    pub fn renderRectangle(ctx: Context, color: Color, rect: Rect, radius: f64) void {
        // TODO
    }
    pub fn renderText(ctx: Context, point: Point, text: TextLayout, color: Color) void {
        // TODO
    }
    pub fn layoutText(ctx: Context, font: [*:0]const u8, text: []const u8, width: ?c_int) TextLayout {
        // TODO
        return TextLayout{};
    }
};

extern fn startCv2(
    win_name: [*:0]const u8,
    width: c_int,
    height: c_int,
    data_ptr: *const backend.OpaquePtrData,
) c_int;

pub fn pangoScale(float: f64) c_int {
    return @floatToInt(c_int, float * 1000);
}

pub fn start(data_ptr: *const backend.OpaquePtrData) error{Failure}!void {
    if (startCv2("Demo", 500, 500, data_ptr) != 0) return error.Failure;
}
