const std = @import("std");
const build_opts = @import("build_options");
const backend = switch (build_opts.render_backend) {
    .cairo_gtk3 => @import("cairo/cairo.zig"),
    .windows => @import("windows/windows.zig"),
    .ios => @import("ios/ios.zig"),
    // huh a "runtime backend" could be made that calls functions from a vtable
};
const structures = @import("../structures.zig");

pub const StartBackend = if (@hasDecl(backend, "StartBackend")) backend.StartBackend else struct {};

pub const warn = struct {
    fn sourceLocationEql(a: std.builtin.SourceLocation, b: std.builtin.SourceLocation) bool {
        return std.meta.eql(a.line, b.line) and std.meta.eql(a.column, b.column) and std.mem.eql(u8, a.file, b.file);
    }
    fn sourceLocationHash(key: std.builtin.SourceLocation) u64 {
        var hasher = std.hash.Wyhash.init(0);
        std.hash.autoHash(&hasher, key.line);
        std.hash.autoHash(&hasher, key.column);
        hasher.update(key.file);
        return hasher.final();
    }
    const WarnedMap = std.HashMap(
        std.builtin.SourceLocation,
        void,
        sourceLocationHash,
        sourceLocationEql,
        std.hash_map.default_max_load_percentage,
    );
    const logger = std.log.scoped(.backend);
    var warned_map: ?WarnedMap = null;
    pub fn once(src: std.builtin.SourceLocation, label: []const u8) void {
        // if(!build_opts.allow_missing_backend_functionality) @panic("error")
        if (warned_map == null) warned_map = WarnedMap.init(std.heap.page_allocator);
        const wm = &(warned_map orelse unreachable);
        if ((wm.getOrPut(src) catch WarnedMap.GetOrPutResult{ .entry = undefined, .found_existing = true }).found_existing) return;
        logger.warn("Missing {s} implementation for {s}", .{ @tagName(build_opts.render_backend), label });
    }
};

pub const TextAttrList = struct {
    const FakeTextAttrList = struct {
        pub fn new() FakeTextAttrList {
            warn.once(@src(), "TextAttrList.new");
            return .{};
        }
        pub fn addRange(a: FakeTextAttrList, start: usize, end: usize, format: structures.TextAttr) void {
            warn.once(@src(), "TextAttrList.addRange");
        }
    };
    const BackendValue = if (@hasDecl(backend, "TextAttrList")) backend.TextAttrList else FakeTextAttrList;
    value: BackendValue,
    pub fn new() TextAttrList {
        return .{ .value = BackendValue.new() };
    }
    pub fn addRange(a: TextAttrList, start: usize, end: usize, format: structures.TextAttr) void {
        a.value.addRange(start, end, format);
    }
};

pub const TextLayout = struct {
    const FakeTextLayout = struct {
        size: structures.WH,
        pub fn deinit(this: @This()) void {
            warn.once(@src(), "TextLayout.deinit");
        }
        pub fn getSize(ftl: FakeTextLayout) structures.WH {
            warn.once(@src(), "TextLayout.getSize");
            return ftl.size;
        }
    };
    const BackendValue = if (@hasDecl(backend, "TextLayout")) backend.TextLayout else FakeTextLayout;
    value: BackendValue,
    pub fn deinit(layout: TextLayout) void {
        layout.value.deinit();
    }
    pub fn getSize(layout: TextLayout) structures.WH {
        return layout.value.getSize();
    }
    pub fn lines(layout: TextLayout) TextLayoutLinesIter {
        if (!@hasDecl(BackendValue, "lines")) return .{ .value = .{} };
        return .{ .value = layout.value.lines() };
    }
};
pub const TextLayoutLinesIter = struct {
    const FakeTextLayoutLinesIter = struct {
        pub fn next(this: *@This()) ?TextLayoutLine.FakeTextLayoutLine {
            warn.once(@src(), "TextLayoutLinesIter.next");
            return null;
        }
        pub fn hasNext(this: @This()) bool {
            warn.once(@src(), "TextLayoutLinesIter.hasNext");
            return false;
        }
    };
    const BackendValue = if (@hasDecl(backend, "TextLayoutLinesIter")) backend.TextLayoutLinesIter else FakeTextLayoutLinesIter;
    value: BackendValue,
    pub fn next(tlli: *TextLayoutLinesIter) ?TextLayoutLine {
        return TextLayoutLine{ .value = tlli.value.next() orelse return null };
    }
    pub fn hasNext(tlli: TextLayoutLinesIter) bool {
        return tlli.value.hasNext();
    }
};
pub const TextLayoutLine = struct {
    const FakeTextLayoutLine = struct {
        pub fn getSize(this: @This()) structures.BlWH {
            @panic("no");
        }
    };
    const BackendValue = if (@hasDecl(backend, "TextLayoutLine")) backend.TextLayoutLine else FakeTextLayoutLine;
    value: BackendValue,
    pub fn getSize(this: TextLayoutLine) structures.BlWH {
        return this.value.getSize();
    }
};
pub fn pangoScale(float: f64) c_int {
    if (!@hasDecl(backend, "pangoScale")) return @floatToInt(c_int, float * 1000);
    return backend.pangoScale(float);
}
pub const Context = struct {
    value: backend.Context,
    pub fn setCursor(ctx: Context, cursor: structures.CursorEnum) void {
        if (!@hasDecl(backend.Context, "setCursor")) {
            warn.once(@src(), "Context.setCursor");
            return;
        }
        ctx.value.setCursor(cursor);
    }
    pub fn renderRectangle(ctx: Context, color: structures.Color, rect: structures.Rect, radius: f64) void {
        if (!@hasDecl(backend.Context, "renderRectangle")) {
            warn.once(@src(), "Context.renderRectangle");
            return;
        }
        ctx.value.renderRectangle(color, rect, radius);
    }
    pub fn renderText(ctx: Context, point: structures.Point, text: TextLayout) void {
        if (!@hasDecl(backend.Context, "renderText")) {
            warn.once(@src(), "Context.renderText");
            return;
        }
        ctx.value.renderText(point, text.value);
    }
    pub fn renderTextLine(ctx: Context, point: structures.Point, text: TextLayoutLine, color: structures.Color) void {
        if (@hasDecl(backend.Context, "renderTextLine")) {
            ctx.value.renderTextLine(point, text.value, color);
        } else warn.once(@src(), "Context.renderTextLine");
    }
    pub fn pushClippingRect(ctx: Context, rect: structures.Rect) void {
        if (@hasDecl(backend.Context, "pushClippingRect")) {
            ctx.value.pushClippingRect(rect);
        } else warn.once(@src(), "Context.pushClippingRect");
    }
    // in the future maybe this will be → popClippingRect(resulting rect) eg
    // and then Context will have to store a debug mode stack of the types of
    // states pushed in order to error if you pop a clipping rect when the last
    // state that was pushed was something else
    pub fn popState(ctx: Context) void {
        if (@hasDecl(backend.Context, "popState")) {
            ctx.value.popState();
        } else warn.once(@src(), "Context.popState");
    }
    pub const TextLayoutOpts = struct {
        /// pango scaled
        width: ?c_int,
        left_offset: ?c_int = null,
    };
    pub fn layoutText(ctx: Context, font: [*:0]const u8, text: []const u8, opts: TextLayoutOpts, attrs: TextAttrList) TextLayout {
        if (!@hasDecl(backend.Context, "layoutText") and TextLayout.BackendValue == TextLayout.FakeTextLayout) {
            warn.once(@src(), "Context.layoutText");
            return TextLayout{ .value = .{ .size = .{ .w = 25, .h = 25 } } };
        }
        return .{ .value = ctx.value.layoutText(
            font,
            text,
            opts.width,
            opts.left_offset orelse 0,
            if (TextAttrList.BackendValue == TextAttrList.FakeTextAttrList) {} else attrs.value,
        ) };
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
