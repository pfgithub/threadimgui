const backend = switch (@import("build_options").render_backend) {
    .cairo_gtk3 => @import("cairo/cairo.zig"),
    .windows => @import("windows/windows.zig"),
};
const structures = @import("../structures.zig");

pub const TextAttrList = struct {
    const BackendValue = if (@hasDecl(backend, "TextAttrList")) backend.TextAttrList else void;
    value: BackendValue,
    pub fn new() TextAttrList {
        // TODO warn once if void
        // var warned_things = std.EnumArray(enum{things to warn about})
        // also option to comptime error instead of runtime warn
        if (BackendValue != void) return .{ .value = BackendValue.new() };
        return .{ .value = {} };
    }
    pub fn addRange(a: TextAttrList, start: usize, end: usize, format: structures.TextAttr) void {
        if (BackendValue != void) a.value.addRange(start, end, format);
    }
};

pub const TextLayout = struct {
    value: backend.TextLayout,
    pub fn deinit(layout: TextLayout) void {
        layout.value.deinit();
    }
    pub fn getSize(layout: TextLayout) structures.WH {
        return layout.value.getSize();
    }
};
pub fn pangoScale(float: f64) c_int {
    return backend.pangoScale(float);
}
pub const Context = struct {
    value: backend.Context,
    pub fn setCursor(ctx: Context, cursor: structures.CursorEnum) void {
        ctx.value.setCursor(cursor);
    }
    pub fn renderRectangle(ctx: Context, color: structures.Color, rect: structures.Rect, radius: f64) void {
        ctx.value.renderRectangle(color, rect, radius);
    }
    pub fn renderText(ctx: Context, point: structures.Point, text: TextLayout, color: structures.Color) void {
        ctx.value.renderText(point, text.value, color);
    }
    pub const TextLayoutOpts = struct {
        /// pango scaled
        width: ?c_int,
        left_offset: ?c_int = null,
    };
    pub fn layoutText(ctx: Context, font: [*:0]const u8, text: []const u8, opts: TextLayoutOpts, attrs: TextAttrList) TextLayout {
        return .{ .value = ctx.value.layoutText(font, text, opts.width, opts.left_offset orelse 0, attrs.value) };
    }
};
pub const RerenderRequest = struct {
    value: backend.RerenderRequest,
    pub fn queueDraw(rr: RerenderRequest) void {
        rr.value.queueDraw();
    }
};

pub const OpaquePtrData = struct {
    data: usize,
    renderFrame: fn (cr: backend.Context, rr: backend.RerenderRequest, data: usize) void,
    pushEvent: fn (ev: structures.RawEvent, rr: backend.RerenderRequest, data: usize) void,
};

pub fn runUntilExit(
    data_in: anytype,
    comptime renderFrame: fn (cr: Context, rr: RerenderRequest, data: @TypeOf(data_in)) void,
    comptime pushEvent: fn (ev: structures.RawEvent, rr: RerenderRequest, data: @TypeOf(data_in)) void,
) error{Failure}!void {
    const data_ptr = @ptrToInt(&data_in);
    comptime const DataPtr = @TypeOf(&data_in);
    const opaque_ptr_data = OpaquePtrData{
        .data = data_ptr,
        .renderFrame = struct {
            fn a(cr: backend.Context, rr: backend.RerenderRequest, data: usize) void {
                return renderFrame(.{ .value = cr }, .{ .value = rr }, @intToPtr(DataPtr, data).*);
            }
        }.a,
        .pushEvent = struct {
            fn a(ev: structures.RawEvent, rr: backend.RerenderRequest, data: usize) void {
                return pushEvent(ev, .{ .value = rr }, @intToPtr(DataPtr, data).*);
            }
        }.a,
    };

    try backend.startBackend(&opaque_ptr_data);
    // fn(data_ptr: *const OpaquePtrData) error{Failure}!void
}
