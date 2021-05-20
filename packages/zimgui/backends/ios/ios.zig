const std = @import("std");
const backend = @import("../backend.zig");
const structures = @import("../../structures.zig");

// const CGFloat = ; // switch(os) {.watchos => double, else => float}
const CGFloat = f64;

// pub const TextLayout = struct {
//     layout: *CFrame,
//     // https://developer.apple.com/documentation/coretext/ctframe?language=objc
//     pub fn deinit() void {}
//     pub fn getSize(layout: TextLayout) structures.WH {
//         //
//     }
// };
const SCALE = 100;
pub fn pangoScale(float: f64) c_int {
    return @floatToInt(c_int, float * SCALE);
}
pub fn cairoScale(int: c_int) f64 {
    return @intToFloat(f64, int) / SCALE;
}

extern fn objc_layout(in_string_ptr: [*]const u8, in_string_len: c_long, width_constraint: CGFloat, height_constraint: CGFloat) *CTextLayout;
const CTextLayout = opaque {
    extern fn objc_drop_layout(layout: *CTextLayout) void;
    extern fn objc_measure_layout(layout: *CTextLayout, w: *CGFloat, h: *CGFloat) void;
    extern fn objc_display_text(layout: *CTextLayout, context: *CData, x: CGFloat, y: CGFloat) void;
};

pub const TextLayout = struct {
    layout: *CTextLayout,
    pub fn deinit(layout: TextLayout) void {
        layout.layout.objc_drop_layout();
    }
    pub fn getSize(layout: TextLayout) structures.WH {
        var w: CGFloat = 0;
        var h: CGFloat = 0;
        layout.layout.objc_measure_layout(&w, &h);
        return .{ .w = w, .h = h };
    }
    // pub fn lines(layout: TextLayout) TextLayoutLinesIter {
    //     return .{ .node = pango_layout_get_lines_readonly(layout.layout) };
    // }
};

pub const Context = struct {
    ref: *CData,

    pub fn renderText(ctx: Context, point: structures.Point, text: TextLayout) void {
        text.layout.objc_display_text(ctx.ref, point.x, point.y);
        // TODO color
    }
    pub fn renderRectangle(ctx: Context, color: structures.Color, rect: structures.Rect, radius: f64) void {
        // std.log.info("rounded rect called!", .{});
        ctx.ref.objc_draw_rect(rect.x, rect.y, rect.w, rect.h, color.r, color.g, color.b, color.a);
    }

    pub fn layoutText(ctx: Context, font: [*:0]const u8, text: []const u8, width: ?c_int, left_offset: c_int, attrs: void) TextLayout {
        const maxw: CGFloat = if (width) |w| cairoScale(w) else 10_000;
        const maxh: CGFloat = 10_000;

        const layout = objc_layout(text.ptr, @intCast(c_long, text.len), maxw, maxh);
        return TextLayout{ .layout = layout };
    }
};

pub const RerenderRequest = struct {
    rkey: *CRerenderKey,
    pub fn queueDraw(rr: @This()) void {
        rr.rkey.objc_request_rerender();
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

const CData = opaque {
    extern fn objc_draw_rect(ref: *CData, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) void;
};
const CRerenderKey = opaque {
    extern fn objc_request_rerender(rkey: *CRerenderKey) void;
};

export fn zig_render(ref: *CData, rkey: *CRerenderKey, w: CGFloat, h: CGFloat) void {
    const data = global_data_ptr; // todo make this an arg

    // todo actual screen size
    data.pushEvent(.{ .resize = .{ .x = 0, .y = 0, .w = @floatToInt(c_int, w), .h = @floatToInt(c_int, h) } }, .{ .rkey = rkey }, data.data); // this shouldn't have to be sent each frame
    data.renderFrame(Context{ .ref = ref }, .{ .rkey = rkey }, data.data);

    // ref.objc_draw_rect(25, 25, 100, 100, 1.0, 0.5, 0.0, 1.0);
}

export fn zig_tap(rkey: *CRerenderKey, x: CGFloat, y: CGFloat) void {
    const data = global_data_ptr;

    data.pushEvent(.{ .mouse_click = .{ .down = true, .x = x, .y = y, .button = 1 } }, .{ .rkey = rkey }, data.data);
    data.pushEvent(.{ .mouse_click = .{ .down = false, .x = x, .y = y, .button = 1 } }, .{ .rkey = rkey }, data.data);
}
