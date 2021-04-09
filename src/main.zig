const std = @import("std");
const app = @import("app.zig");
const cairo = @import("cairo.zig");
const generic = @import("generic.zig"); // temporary
const ID = @import("id.zig").ID;

pub fn range(max: usize) []const void {
    return @as([]const void, &[_]void{}).ptr[0..max];
}

pub const Color = struct {
    r: f64,
    g: f64,
    b: f64,
    a: f64 = 1,
    pub fn rgb(r: u8, g: u8, b: u8) Color {
        return Color{
            .r = @intToFloat(f64, r) / 0xFF,
            .g = @intToFloat(f64, g) / 0xFF,
            .b = @intToFloat(f64, b) / 0xFF,
        };
    }
    pub fn hex(v: u24) Color {
        const r = @intCast(u8, (v & 0xFF0000) >> 16);
        const g = @intCast(u8, (v & 0x00FF00) >> 8);
        const b = @intCast(u8, (v & 0x0000FF) >> 0);
        return Color.rgb(r, g, b);
    }
};
pub const RenderNode = struct { value: union(enum) {
    rectangle: struct {
        wh: WH,
        radius: f64,
        bg_color: Color,
    },
    text: struct {
        layout: cairo.TextLayout,
        color: Color,
    },
    place: struct {
        node: ?*Queue(RenderNode).Node,
        offset: Point,
    },
    clickable: struct {
        id: u64,
        wh: WH,
    },
    scrollable: struct {
        id: u64,
        wh: WH,
    },
} };

pub const RoundedStyle = enum {
    none,
    sm, // 5px
    md, // 10px
    xl, // 15px
    pub fn getPx(rs: RoundedStyle) f64 {
        return switch (rs) {
            .none => 0,
            .sm => 5,
            .md => 10,
            .xl => 15,
        };
    }
};
pub const ThemeColor = enum {
    black, // #000
    gray100, // #131516
    gray200, // #181a1b
    gray500, // #9ca3af
    gray700, // 55, 65, 81
    white, // #fff
    pub fn getColor(col: ThemeColor) Color {
        return switch (col) {
            .black => Color.hex(0x000000),
            .gray100 => Color.hex(0x131516),
            .gray200 => Color.hex(0x181a1b),
            .gray500 => Color.hex(0x9ca3af),
            .gray700 => Color.rgb(55, 65, 81),
            .white => Color.hex(0xFFFFFF),
        };
    }
};
pub const FontWeight = enum {
    normal, // 400 ("normal")
    bold, // 700 ("bold")
    black, // 900 ("heavy")
    pub fn getString(weight: FontWeight) []const u8 {
        return switch (weight) {
            .normal => "normal", // 400
            .bold => "bold", // 700
            .black => "heavy", // 900
        };
    }
};
pub const FontFamily = enum {
    sans_serif,
    monospace,
    pub fn getString(ffamily: FontFamily) []const u8 {
        return switch (ffamily) {
            // TODO ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
            // "Helvetica Neue", Arial, "Noto Sans", sans-serif, "Apple Color Emoji", "Segoe UI Emoji",
            // "Segoe UI Symbol", "Noto Color Emoji"
            .sans_serif => "ui-sans-serif,system-ui",
            // TODO ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono",
            // "Courier New", monospace
            .monospace => "ui-monospace",
        };
    }
};
pub const FontSize = enum {
    sm, // 0.875rem ≈ 10.541pt
    base, // 1rem ≈ 12.0468pt
    pub fn getString(fsize: FontSize) []const u8 {
        return switch (fsize) {
            .sm => "10.541",
            .base => "12.0468",
        };
    }
};
const AllFontOpts = struct {
    size: FontSize,
    family: FontFamily,
    weight: FontWeight,
    pub fn format(value: AllFontOpts, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{s} {s} {s}", .{ value.family.getString(), value.weight.getString(), value.size.getString() });
    }
};

const TextHashKey = struct {
    font_opts: AllFontOpts,
    width: ?c_int,
    text: []const u8, // a duplicate is made using the persistent allocator before storing in the hm across frames
    pub fn eql(a: TextHashKey, b: TextHashKey) bool {
        return std.meta.eql(a.font_opts, b.font_opts) or std.meta.eql(a.width, b.width) or std.mem.eql(u8, a.text, b.text);
    }
    pub fn hash(key: TextHashKey) u64 {
        var hasher = std.hash.Wyhash.init(0);
        std.hash.autoHash(&hasher, key.font_opts);
        std.hash.autoHash(&hasher, key.width);
        hasher.update(key.text);
        return hasher.final();
    }
};

pub const RenderCtx = struct {
    imev: *ImEvent,
    nodes: Queue(RenderNode),
    pop_id: ?ID.PopID,
    pub fn init(imev: *ImEvent, pop_id: ?ID.PopID) RenderCtx {
        return RenderCtx{
            .imev = imev,
            .nodes = Queue(RenderNode){},
            .pop_id = pop_id,
        };
    }
    // maybe .result() can do this instead?
    // then make sure that result is called on all renderctxs, only once.
    // uh oh renderctx is only for rendering fixed positioned things
    // if you return inset(…)
    // this needs a bit of a redo
    pub fn pop(ctx: *RenderCtx) void {
        if (ctx.pop_id) |pid| pid.pop();
    }
    pub fn putRenderNode(ctx: *RenderCtx, node: RenderNode) void {
        ctx.nodes.push(ctx.imev.arena(), node) catch @panic("oom");
    }
    pub fn result(ctx: *RenderCtx) RenderResult {
        return ctx.nodes.start;
    }
    pub fn place(ctx: *RenderCtx, node: RenderResult, point: Point) void {
        ctx.putRenderNode(.{ .value = .{ .place = .{
            .node = node,
            .offset = point,
        } } });
    }
};
pub const RenderResult = ?*Queue(RenderNode).Node;

pub const Widget = struct {
    wh: WH,
    node: RenderResult,
};

pub const primitives = struct {
    const RectOpts = struct {
        rounded: RoundedStyle = .none,
        bg: ThemeColor,
    };
    pub fn rect(src: Src, imev: *ImEvent, size: WH, opts: RectOpts) RenderResult {
        var ctx = imev.render(src);
        defer ctx.pop();

        ctx.putRenderNode(RenderNode{ .value = .{ .rectangle = .{
            .wh = size,
            .radius = opts.rounded.getPx(),
            .bg_color = opts.bg.getColor(),
        } } });
        return ctx.result();
    }
    const FontOpts = struct {
        family: FontFamily = .sans_serif,
        weight: FontWeight = .normal,
        size: FontSize,
        color: ThemeColor,
        pub fn all(opts: FontOpts) AllFontOpts {
            return AllFontOpts{ .size = opts.size, .family = opts.family, .weight = opts.weight };
        }
    };
    pub fn textV(src: Src, imev: *ImEvent, width: f64, opts: FontOpts, text_val: []const u8) VLayoutManager.Child {
        var ctx = imev.render(src);
        defer ctx.pop();

        const all_font_opts = opts.all();
        const w_int = cairo.pangoScale(width);
        const layout = imev.layoutText(.{ .font_opts = all_font_opts, .width = w_int, .text = text_val });

        const size = layout.getSize();

        ctx.putRenderNode(RenderNode{ .value = .{ .text = .{
            .layout = layout,
            .color = opts.color.getColor(),
        } } });

        return VLayoutManager.Child{
            .h = size.h,
            .node = ctx.result(),
        };
    }
    pub fn text(src: Src, imev: *ImEvent, opts: FontOpts, text_val: []const u8) Widget {
        var ctx = imev.render(src);
        defer ctx.pop();

        const all_font_opts = opts.all();
        const layout = imev.layoutText(.{ .font_opts = all_font_opts, .width = null, .text = text_val });

        const size = layout.getSize();

        ctx.putRenderNode(RenderNode{ .value = .{ .text = .{
            .layout = layout,
            .color = opts.color.getColor(),
        } } });

        return Widget{
            .wh = .{ .w = size.w, .h = size.h },
            .node = ctx.result(),
        };
    }
};

fn Queue(comptime T: type) type {
    return struct {
        const Node = struct {
            next: ?*Node,
            value: T,
        };

        start: ?*Node = null,
        end: ?*Node = null,

        const This = @This();
        pub fn push(list: *This, alloc: *std.mem.Allocator, value: T) !void {
            const node = try alloc.create(Node);
            node.* = .{ .next = null, .value = value };

            if (list.end) |endn| {
                endn.next = node;
                list.end = node;
            } else {
                list.start = node;
                list.end = node;
            }
        }
        pub fn pop(list: *This, alloc: *std.mem.Allocator) ?T {
            if (list.start) |startn| {
                const res = startn.value;
                list.start = startn.next;
                if (startn.next == null) list.end = null;
                alloc.destroy(startn);
                return res;
            } else return null;
        }
    };
}
pub const Point = struct {
    x: f64,
    y: f64,
    pub const origin = Point{ .x = 0, .y = 0 };
    pub fn toRectBR(pt: Point, wh: WH) Rect {
        return .{ .x = pt.x, .y = pt.y, .w = wh.w, .h = wh.h };
    }
};
pub const Rect = struct {
    x: f64,
    y: f64,
    w: f64,
    h: f64,
    pub fn inset(rect: Rect, distance: f64) Rect {
        return .{
            .x = rect.x + distance,
            .y = rect.y + distance,
            .w = rect.w - distance * 2,
            .h = rect.h - distance * 2,
        };
    }
    pub fn wh(rect: Rect) WH {
        return .{ .w = rect.w, .h = rect.h };
    }
    pub fn ul(rect: Rect) Point {
        return .{ .x = rect.x, .y = rect.y };
    }
    pub fn ur(rect: Rect) Point {
        return .{ .x = rect.x + rect.w, .y = rect.y };
    }
    pub fn bl(rect: Rect) Point {
        return .{ .x = rect.x, .y = rect.y + rect.h };
    }
    pub fn br(rect: Rect) Point {
        return .{ .x = rect.x + rect.w, .y = rect.y + rect.h };
    }
    pub fn containsPoint(rect: Rect, point: Point) bool {
        return point.x >= rect.x and point.x < rect.x + rect.w and
            point.y >= rect.y and point.y < rect.y + rect.h //
        ;
    }
};
pub const WH = struct {
    w: f64,
    h: f64,
    // should this be float or int?
};
const TextCacheValue = struct {
    layout: cairo.TextLayout,
    used_in_this_render_frame: bool,
};
const TextCacheHM = std.HashMap(
    TextHashKey,
    TextCacheValue,
    TextHashKey.hash,
    TextHashKey.eql,
    std.hash_map.default_max_load_percentage,
);
pub const IdStateCache = struct {
    pub const Entry = struct {
        ptr: usize,
        deinitFn: fn (entry: Entry, imev: *ImEvent) void,
        created_src_file: [*:0]const u8,
        created_src_line: u32,
        created_src_col: u32,

        used_this_frame: bool,

        pub fn readAs(value: Entry, comptime src: Src, comptime Type: type) *Type {
            if (value.created_src_line != src.line or value.created_src_col != src.column or value.created_src_file != src.file.ptr) {
                @panic("random crash. TODO fix.");
            }
            return @intToPtr(*Type, value.ptr);
        }
    };
    hm: std.AutoHashMapUnmanaged(u64, Entry),

    pub fn init() IdStateCache {
        return .{
            .hm = std.AutoHashMapUnmanaged(u64, Entry){},
        };
    }

    // this is where |these| {things} would be useful:
    // ` cache.state(@src(), imev, struct{x: f64}, |_| .{.x = 25});
    // unfortunately, not yet
    pub fn state(isc: *IdStateCache, comptime src: Src, imev: *ImEvent, comptime Type: type, comptime initFn: fn () Type) *Type {
        const id = imev.frame.id.forSrc(src);
        if (isc.hm.getEntry(id)) |entry| {
            entry.value.used_this_frame = true;
            return entry.value.readAs(src, Type);
        }
        var item_ptr: *Type = imev.persistentAlloc().create(Type) catch @panic("oom");
        item_ptr.* = initFn();
        isc.hm.putNoClobber(imev.persistentAlloc(), id, .{
            .ptr = @ptrToInt(item_ptr),
            .deinitFn = struct {
                fn a(entry: Entry, imev_shadow: *ImEvent) void {
                    const ptr_v = entry.readAs(src, Type);
                    if (@hasDecl(Type, "deinit")) {
                        ptr_v.deinit(imev_shadow);
                    }
                    imev_shadow.persistentAlloc().destroy(ptr_v);
                }
            }.a,
            .created_src_file = src.file.ptr,
            .created_src_line = src.line,
            .created_src_col = src.column,
            .used_this_frame = true,
        }) catch @panic("oom");
        return item_ptr;
    }
    pub fn cleanupUnused(isc: *IdStateCache, imev: *ImEvent) void {
        if (!imev.isRenderFrame()) return;

        var iter = isc.hm.iterator();
        var unused = std.ArrayList(u64).init(imev.persistentAlloc());
        defer unused.deinit();
        while (iter.next()) |ntry| {
            if (ntry.value.used_this_frame) {
                ntry.value.used_this_frame = false;
            } else {
                ntry.value.deinitFn(ntry.value, imev);
                unused.append(ntry.key) catch @panic("oom");
            }
        }
        for (unused.items) |key| {
            isc.hm.removeAssertDiscard(key);
        }
    }
    pub fn deinit(isc: *IdStateCache, imev: *ImEvent) void {
        var iter = isc.hm.iterator();
        while (iter.next()) |ntry| {
            ntry.value.deinitFn(ntry.value, imev);
        }
        isc.hm.deinit(imev.persistentAlloc());
    }
};
pub const ImEvent = struct { // pinned?
    // structures that are created at init.
    persistent: struct {
        unprocessed_events: Queue(cairo.RawEvent),
        real_allocator: *std.mem.Allocator,
        text_cache: TextCacheHM,
        screen_size: WH,
        internal_screen_offset: Point,
        current_cursor: cairo.CursorEnum,
        allow_event_introspection: bool, // to set this a helper fn needs to be made. this must be set and then used next frame, not this frame.

        mouse_position: Point,
        mouse_held: bool,
        mouse_focused: ?MouseFocused,

        scroll_focused: ?ScrollFocused,
        // last_scroll_time: u64, // to prevent switching scroll focuses until «»ms of time without scrolling or similar

    },

    /// structures that are only defined during a frame
    frame: struct {
        should_render: bool,
        should_continue: bool,
        arena_allocator: std.heap.ArenaAllocator,
        id: ID,
        cr: cairo.Context,
        cursor: cairo.CursorEnum,

        mouse_down: bool,
        mouse_up: bool,

        scroll_delta: Point,
    },

    const ScrollFocused = struct {
        id: u64,
        delta: Point,
    };
    const MouseFocused = struct {
        id: u64,
        hover: bool,
    };

    pub fn arena(imev: *ImEvent) *std.mem.Allocator {
        return &imev.frame.arena_allocator.allocator;
    }
    pub fn persistentAlloc(imev: *ImEvent) *std.mem.Allocator {
        return imev.persistent.real_allocator;
    }

    pub fn init(alloc: *std.mem.Allocator) ImEvent {
        return .{
            .persistent = .{
                .unprocessed_events = Queue(cairo.RawEvent){},
                .real_allocator = alloc,
                .text_cache = TextCacheHM.init(alloc),
                .screen_size = .{ .w = 0, .h = 0 },
                .internal_screen_offset = .{ .x = 0, .y = 0 },
                .current_cursor = .default,
                .allow_event_introspection = false,

                .mouse_position = .{ .x = -1, .y = -1 },
                .mouse_held = false,
                .mouse_focused = null,

                .scroll_focused = null,
            },
            .frame = undefined,
        };
    }
    pub fn deinit(imev: *ImEvent) void {
        while (imev.persistent.unprocessed_events.pop(imev.persistent.real_allocator)) |_| {}

        var iter = imev.persistent.text_cache.iterator();
        while (iter.next()) |entry| {
            entry.value.layout.deinit();
            imev.persistent.real_allocator.free(entry.key.text);
        }
        imev.persistent.text_cache.deinit();
    }
    pub fn addEvent(imev: *ImEvent, event: cairo.RawEvent) !void {
        // could use an arena allocator, unfortunately arena allocators are created at frame start
        // rather than on init 🙲 frame end.
        // TODO consolidate similar events
        try imev.persistent.unprocessed_events.push(imev.persistent.real_allocator, event);
    }
    pub fn startFrame(imev: *ImEvent, cr: cairo.Context, should_render: bool) !void {
        const event: ?cairo.RawEvent = imev.persistent.unprocessed_events.pop(imev.persistent.real_allocator);

        imev.frame = .{
            .should_render = should_render,
            .should_continue = event != null,
            .arena_allocator = std.heap.ArenaAllocator.init(imev.persistent.real_allocator),
            .id = ID.init(imev.persistent.real_allocator),
            .cr = cr,
            .cursor = .default,

            .mouse_down = false,
            .mouse_up = false,

            .scroll_delta = Point.origin,
        };
        if (event == null) {
            var iter = imev.persistent.text_cache.iterator();
            while (iter.next()) |entry| {
                entry.value.used_in_this_render_frame = false;
            }
        }
        if (event) |ev| switch (ev) {
            .resize => |rsz| {
                imev.persistent.internal_screen_offset = .{
                    .x = @intToFloat(f64, rsz.x),
                    .y = @intToFloat(f64, rsz.y),
                };
                imev.persistent.screen_size = .{
                    .w = @intToFloat(f64, rsz.w),
                    .h = @intToFloat(f64, rsz.h),
                };
            },
            .mouse_click => |mclick| {
                imev.persistent.mouse_position = .{ .x = mclick.x, .y = mclick.y };
                if (mclick.button == 1) {
                    if (mclick.down) {
                        imev.frame.mouse_down = true;
                        imev.persistent.mouse_held = true;
                    } else {
                        imev.frame.mouse_up = true;
                        imev.persistent.mouse_held = false;
                    }
                }
            },
            .mouse_move => |mmove| {
                imev.persistent.mouse_position = .{ .x = mmove.x, .y = mmove.y };
            },
            .scroll => |sev| {
                // imev.persistent.mouse_position = .{ .x = sev.mouse_x, .y = sev.mouse_y };
                imev.frame.scroll_delta = .{ .x = sev.scroll_x, .y = sev.scroll_y };
            },
            else => {},
        };
    }
    pub fn internalRender(imev: *ImEvent, nodes: RenderResult, offset: Point, should_render: bool) void {
        var nodeiter = nodes;
        const cr = imev.frame.cr;
        while (nodeiter) |node| {
            const rnode: RenderNode = node.value;
            switch (rnode.value) {
                .rectangle => |rect| if (should_render) {
                    cr.renderRectangle(rect.bg_color, .{ .x = offset.x, .y = offset.y, .w = rect.wh.w, .h = rect.wh.h }, rect.radius);
                },
                .text => |text| if (should_render) {
                    cr.renderText(offset, text.layout, text.color);
                },
                .place => |place| {
                    imev.internalRender(place.node, .{ .x = offset.x + place.offset.x, .y = offset.y + place.offset.y }, should_render);
                },
                .clickable => |cable| {
                    const contains_point = offset.toRectBR(cable.wh).containsPoint(imev.persistent.mouse_position);
                    const active_is_this = if (imev.persistent.mouse_focused) |mfx| mfx.id == cable.id else contains_point;
                    if (active_is_this) {
                        imev.persistent.mouse_focused = MouseFocused{
                            .id = cable.id,
                            .hover = contains_point,
                        };
                    }
                },
                .scrollable => |sable| {
                    const contains_point = offset.toRectBR(sable.wh).containsPoint(imev.persistent.mouse_position);
                    if (contains_point and !(imev.frame.scroll_delta.x == 0 and imev.frame.scroll_delta.y == 0)) {
                        imev.persistent.scroll_focused = ScrollFocused{
                            .id = sable.id,
                            .delta = imev.frame.scroll_delta,
                        };
                    }
                },
            }
            nodeiter = node.next;
        }
    }
    pub fn endFrameRender(imev: *ImEvent, render_v: RenderResult) void {
        if (!imev.frame.should_render) unreachable;

        var keys_to_remove = Queue(TextHashKey){};
        var iter = imev.persistent.text_cache.iterator();
        while (iter.next()) |entry| {
            if (!entry.value.used_in_this_render_frame) {
                keys_to_remove.push(imev.arena(), entry.key) catch @panic("oom");
            }
        }
        while (keys_to_remove.pop(imev.arena())) |key| {
            if (imev.persistent.text_cache.remove(key)) |v| {
                v.value.layout.deinit();
                imev.persistent.real_allocator.free(v.key.text);
            } else unreachable;
        }

        if (imev.frame.cursor != imev.persistent.current_cursor) {
            imev.persistent.current_cursor = imev.frame.cursor;
            imev.frame.cr.setCursor(imev.frame.cursor);
        }

        if (!imev.internalEndFrame(render_v)) unreachable; // a render frame indicated that there was more to do this tick; this is invalid
    }
    pub fn endFrame(imev: *ImEvent, render_v: RenderResult) bool {
        if (imev.frame.should_render) unreachable;

        return imev.internalEndFrame(render_v);
    }
    pub fn internalEndFrame(imev: *ImEvent, render_v: RenderResult) bool {
        if (!imev.persistent.mouse_held) {
            imev.persistent.mouse_focused = null;
        }
        imev.persistent.scroll_focused = null;
        imev.internalRender(render_v, imev.persistent.internal_screen_offset, imev.frame.should_render);

        imev.frame.arena_allocator.deinit();
        imev.frame.id.deinit();
        imev.frame.id = undefined;

        return !imev.frame.should_continue; // rendering is over, do not execute more frames this frame
    }

    // TODO const ctx = imev.render(@src())
    // defer ctx.pop();
    // then it adds the source location to the hash thing automatically
    pub fn render(imev: *ImEvent, src: Src) RenderCtx {
        return RenderCtx.init(imev, imev.frame.id.pushFunction(src));
    }
    pub fn renderNoSrc(imev: *ImEvent) RenderCtx {
        return RenderCtx.init(imev, null);
    }

    pub fn isRenderFrame(imev: *ImEvent) bool {
        return if (imev.persistent.allow_event_introspection) true else imev.frame.should_render;
    }

    pub fn layoutText(imev: *ImEvent, key: TextHashKey) cairo.TextLayout {
        if (imev.persistent.text_cache.getEntry(key)) |cached_value| {
            cached_value.value.used_in_this_render_frame = true;
            return cached_value.value.layout;
        } else {
            const text_dupe = imev.persistent.real_allocator.dupe(u8, key.text) catch @panic("oom");
            const font_str = std.fmt.allocPrint0(imev.arena(), "{}", .{key.font_opts}) catch @panic("oom");
            const layout = imev.frame.cr.layoutText(font_str.ptr, text_dupe, .{ .width = key.width });

            const cache_value: TextCacheValue = .{
                .layout = layout,
                .used_in_this_render_frame = false,
            };
            const entry_key: TextHashKey = .{
                .font_opts = key.font_opts,
                .width = key.width,
                .text = text_dupe,
            };
            imev.persistent.text_cache.putNoClobber(entry_key, cache_value) catch @panic("oom");
            return layout;
        }
    }

    pub fn clickable(imev: *ImEvent, src: Src) ClickableState {
        const id = imev.frame.id.forSrc(src);
        return ClickableState{ .id = id, .imev = imev, .focused = if (imev.persistent.mouse_focused) |mfx| if (mfx.id == id) ClickableState.Focused{
            .hover = mfx.hover,
        } else null else null };
    }

    pub fn scrollable(imev: *ImEvent, src: Src) ScrollableState {
        const id = imev.frame.id.forSrc(src);
        return ScrollableState{ .id = id, .imev = imev, .scrolling = if (imev.persistent.scroll_focused) |scr| if (scr.id == id) ScrollableState.Scrolling{
            .delta = scr.delta,
        } else null else null };
    }
};
pub const Src = ID.Src;

const ClickableState = struct {
    const Focused = struct {
        hover: bool,
        // other stuff
        // clicking: bool
        // click: bool
        // mpos: ?Point, // while clicking, this can go negative. coords are relative to where the node was placed.
        pub fn setCursor(fcsd: Focused, imev: *ImEvent, cursor: cairo.CursorEnum) void {
            // alternatively: make this struct pinned and use fieldparentptr
            imev.frame.cursor = cursor;
        }
    };
    id: u64,
    imev: *ImEvent,

    focused: ?Focused,

    pub fn node(fc: ClickableState, wh: WH) RenderResult {
        var ctx = fc.imev.renderNoSrc();
        ctx.putRenderNode(.{ .value = .{ .clickable = .{ .id = fc.id, .wh = wh } } });
        return ctx.result();
    }
};

const ScrollableState = struct {
    const Scrolling = struct {
        delta: Point,
    };
    id: u64,
    imev: *ImEvent,

    scrolling: ?Scrolling,

    pub fn node(fc: ScrollableState, wh: WH) RenderResult {
        var ctx = fc.imev.renderNoSrc();
        ctx.putRenderNode(.{ .value = .{ .scrollable = .{ .id = fc.id, .wh = wh } } });
        return ctx.result();
    }
};

pub const TopRect = struct {
    x: f64,
    y: f64,
    w: f64,
};
pub const VLayoutManager = struct {
    top_rect: TopRect,
    uncommitted_gap: f64, // maybe don't do this it's weird ; do the opposite maybe idk
    bottom_offset: f64, // added with inset
    start_y: f64,
    pub const Child = struct {
        node: RenderResult,
        h: f64,
    };
    pub fn result(lm: *VLayoutManager, ctx: *RenderCtx) Child {
        return Child{
            .h = lm.height(),
            .node = ctx.result(),
        };
    }
    pub fn fromWidth(w: f64) VLayoutManager {
        return fromTopRect(.{ .x = 0, .y = 0, .w = w });
    }
    pub fn fromTopRect(rect: TopRect) VLayoutManager {
        return VLayoutManager{
            .top_rect = .{
                .x = rect.x,
                .y = rect.y,
                .w = rect.w,
            },
            .uncommitted_gap = 0,
            .bottom_offset = 0,
            .start_y = rect.y,
        };
    }
    pub fn cutRight(lm: *VLayoutManager, opts: struct { w: f64, gap: f64 }) VLayoutManager {
        lm.top_rect.w -= opts.w + opts.gap;
        return VLayoutManager{
            .top_rect = .{
                .x = lm.top_rect.x + lm.top_rect.w + opts.gap,
                .w = opts.w,
                .y = lm.top_rect.y,
            },
            .uncommitted_gap = lm.uncommitted_gap,
            .bottom_offset = 0,
            .start_y = lm.top_rect.y,
        };
    }
    const TakeOpts = struct { h: f64, gap: f64 };
    pub fn take(lm: *VLayoutManager, opts: TakeOpts) Rect {
        lm.top_rect.y += lm.uncommitted_gap;
        lm.uncommitted_gap = opts.gap;
        const res = Rect{
            .x = lm.top_rect.x,
            .y = lm.top_rect.y,
            .w = lm.top_rect.w,
            .h = opts.h,
        };
        lm.top_rect.y += opts.h;
        return res;
    }
    pub fn use(lm: *VLayoutManager, opts: TakeOpts) void {
        _ = lm.take(opts);
    }
    pub fn topRect(lm: *VLayoutManager) TopRect {
        return TopRect{
            .x = lm.top_rect.x,
            .y = lm.top_rect.y + lm.uncommitted_gap,
            .w = lm.top_rect.w,
        };
    }
    /// supports negatives I guess
    pub fn inset(lm: *VLayoutManager, dist: f64) void {
        lm.top_rect.x += dist;
        lm.top_rect.w -= 2 * dist;
        lm.insetY(dist);
    }
    pub fn insetY(lm: *VLayoutManager, dist: f64) void {
        lm.top_rect.y += dist;
        lm.bottom_offset += dist;
    }
    pub fn height(lm: VLayoutManager) f64 {
        return lm.top_rect.y - lm.start_y + lm.bottom_offset;
    }
    pub fn maxWidth(lm: *VLayoutManager, max_w: f64, mode: enum { center }) void {
        const res_w = std.math.min(max_w, lm.top_rect.w);
        lm.top_rect.x = lm.top_rect.x + @divFloor(lm.top_rect.w, 2) - @divFloor(res_w, 2);
        lm.top_rect.w = res_w;
    }
    pub fn place(lm: *VLayoutManager, ctx: *RenderCtx, opts: struct { gap: f64 }, node: Child) void {
        const rect = lm.take(.{ .gap = opts.gap, .h = node.h });
        ctx.place(node.node, .{ .x = rect.x, .y = rect.y });
    }
};

var content: generic.Page = undefined;
var global_imevent: ImEvent = undefined;
var root_state_cache: IdStateCache = undefined;
pub fn renderFrame(cr: cairo.Context, rr: cairo.RerenderRequest) void {
    const timer = std.time.Timer.start() catch @panic("bad timer");
    const imev = &global_imevent;

    const root_src = @src();

    var render_count: usize = 0;
    while (true) {
        render_count += 1;
        imev.startFrame(cr, false) catch @panic("Start frame error");
        if (imev.endFrame(app.renderApp(root_src, imev, imev.persistent.screen_size, content, &root_state_cache))) break;
    }

    render_count += 1;
    imev.startFrame(cr, true) catch @panic("Start frame error");
    imev.endFrameRender(app.renderApp(root_src, imev, imev.persistent.screen_size, content, &root_state_cache));
    root_state_cache.cleanupUnused(imev);

    // std.log.info("rerender×{} in {}ns", .{ render_count, timer.read() }); // max allowed time is 4ms
}
pub fn pushEvent(ev: cairo.RawEvent, rr: cairo.RerenderRequest) void {
    const imev = &global_imevent;

    imev.addEvent(ev) catch @panic("oom");
    rr.queueDraw();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const alloc = &gpa.allocator;

    var sample_arena = std.heap.ArenaAllocator.init(alloc);
    defer sample_arena.deinit();

    content = generic.initSample(&sample_arena.allocator);

    global_imevent = ImEvent.init(alloc);
    defer global_imevent.deinit();

    root_state_cache = IdStateCache.init();
    defer root_state_cache.deinit(&global_imevent);

    try cairo.start();
}
