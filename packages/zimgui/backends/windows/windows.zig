const std = @import("std");
const backend = @import("../backend.zig");
usingnamespace @import("../../structures.zig");

const WindowData = opaque {};

extern fn c_repaint_window(wd: *WindowData) void;
extern fn c_rounded_rect(wd: *WindowData, color_rgb: c_ulong, left: c_int, top: c_int, right: c_int, bottom: c_int, rx: c_int, ry: c_int) void;

export fn zig_on_paint(wd: *WindowData, state_ptr: *const backend.OpaquePtrData) void {
    state_ptr.renderFrame(Context{ .wd = wd }, .{ .wd = wd }, state_ptr.data);
}
export fn zig_on_resize(wd: *WindowData, data: *const backend.OpaquePtrData, width: c_int, height: c_int) void {
    data.pushEvent(.{ .resize = .{ .x = 0, .y = 0, .w = width, .h = height } }, .{ .wd = wd }, data.data);
}

export fn zig_on_mouse_click(wd: *WindowData, data: *const backend.OpaquePtrData, btn: u8, clicked: c_int, pt_x: c_short, pt_y: c_short) void {
    data.pushEvent(.{ .mouse_click = .{ .down = clicked == 1, .x = @intToFloat(f64, pt_x), .y = @intToFloat(f64, pt_y), .button = btn } }, .{ .wd = wd }, data.data);
}
export fn zig_on_mouse_move(wd: *WindowData, data: *const backend.OpaquePtrData, pt_x: c_short, pt_y: c_short) void {
    data.pushEvent(.{ .mouse_move = .{ .x = @intToFloat(f64, pt_x), .y = @intToFloat(f64, pt_y) } }, .{ .wd = wd }, data.data);
}

fn winColor(color: Color) c_ulong {
    if (color.a < 0.99) {
        backend.warn.once(@src(), "Windows GDI does not support partially transparent colors");
    }
    return (@floatToInt(c_ulong, color.r * 255)) + (@floatToInt(c_ulong, color.g * 255) << 0x8) + (@floatToInt(c_ulong, color.b * 255) << 0x10);
}

pub const RerenderRequest = struct {
    wd: *WindowData,
    pub fn queueDraw(rr: RerenderRequest) void {
        // TODO
        c_repaint_window(rr.wd);
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
    wd: *WindowData,
    pub fn renderRectangle(ctx: Context, color: Color, rect: Rect, radius: f64) void {
        // std.log.info("rounded rect called!", .{});
        c_rounded_rect(
            ctx.wd,
            winColor(color),
            @floatToInt(c_int, rect.x),
            @floatToInt(c_int, rect.y),
            @floatToInt(c_int, rect.x + rect.w + 1),
            @floatToInt(c_int, rect.y + rect.h + 1),
            @floatToInt(c_int, radius * 2),
            @floatToInt(c_int, radius * 2),
        );
    }
    pub fn renderText(ctx: Context, point: Point, text: TextLayout, color: Color) void {
        // TODO
    }
    pub fn layoutText(ctx: Context, font: [*:0]const u8, text: []const u8, width: ?c_int, left_offset: c_int, attrs: void) TextLayout {
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

pub fn startBackend(data_ptr: *const backend.OpaquePtrData) error{Failure}!void {
    if (startCv2("Demo", 500, 500, data_ptr) != 0) return error.Failure;
}
