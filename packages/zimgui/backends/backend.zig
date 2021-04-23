const std = @import("std");
const build_opts = @import("build_options");
const backend = switch (build_opts.render_backend) {
    .cairo_gtk3 => @import("cairo/cairo.zig"),
    .windows => @import("windows/windows.zig"),
    // huh a "runtime backend" could be made that calls functions from a vtable
};
const structures = @import("../structures.zig");

const warn = struct {
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
    fn once(src: std.builtin.SourceLocation, label: []const u8) void {
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
        pub fn deinit() void {
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
        if (BackendValue != void) layout.value.deinit();
    }
    pub fn getSize(layout: TextLayout) structures.WH {
        // TODO a fake backend rather than void
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
    pub fn renderTextLine(ctx: Context, point: structures.Point, text: TextLayoutLine, color: structures.Color) void {
        if (@hasDecl(backend.Context, "renderTextLine")) {
            ctx.value.renderTextLine(point, text.value, color);
        } else warn.once(@src(), "Context.renderTextLine");
    }
    pub fn setClippingRect(ctx: Context, rect: structures.Rect) void {
        if (@hasDecl(backend.Context, "setClippingRect")) {
            ctx.value.setClippingRect(rect);
        } else warn.once(@src(), "Context.setClippingRect");
    }
    pub const TextLayoutOpts = struct {
        /// pango scaled
        width: ?c_int,
        left_offset: ?c_int = null,
    };
    pub fn layoutText(ctx: Context, font: [*:0]const u8, text: []const u8, opts: TextLayoutOpts, attrs: TextAttrList) TextLayout {
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
