const std = @import("std");
const app = @import("app.zig");
const backend = @import("backends/backend.zig");
pub const ID = @import("id.zig").ID;
pub usingnamespace @import("structures.zig");
const build_opts = @import("build_options");

pub const StartBackend = backend.StartBackend;

pub fn range(max: usize) []const void {
    return @as([]const void, &[_]void{}).ptr[0..max];
}

pub const RenderNode = struct { value: union(enum) {
    rectangle: struct {
        wh: WH,
        radius: f64,
        bg_color: Color,
    },
    text: struct {
        layout: backend.TextLayout,
        color: Color,
    },
    text_line: struct {
        line: backend.TextLayoutLine,
        color: Color,
    },
    place: struct {
        node: RenderResult,
        offset: Point,
    },
    clipping_rect: struct {
        node: RenderResult,
        wh: WH,
    },
    clickable: struct {
        id: ID.Ident, // owned by the arena
        wh: WH,
    },
    scrollable: struct {
        id: ID.Ident, // owned by the arena
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
    black,
    gray100,
    gray200,
    gray300,
    gray500,
    gray700,
    white,
    red,
    blue500,
    pub fn getColor(col: ThemeColor) Color {
        return switch (col) {
            .black => Color.hex(0x000000),
            .gray100 => Color.hex(0x131516),
            .gray200 => Color.hex(0x181a1b),
            .gray300 => Color.hex(0x242729),
            .gray500 => Color.hex(0x9ca3af),
            .gray700 => Color.rgb(55, 65, 81),
            .white => Color.hex(0xFFFFFF),
            .red => Color.hex(0xFF3333),
            .blue500 => Color.rgb(59, 130, 246),
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
            .sans_serif => "system-ui",
            // TODO ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono",
            // "Courier New", monospace
            .monospace => "monospace",
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
    underline: bool,
    left_offset: c_int,
    pub fn format(value: AllFontOpts, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{s} {s} {s}", .{ value.family.getString(), value.weight.getString(), value.size.getString() });
    }
};

const TextHashKey = struct {
    font_opts: AllFontOpts,
    width: ?c_int,
    text: []const u8, // a duplicate is made using the persistent allocator before storing in the hm across frames
    pub fn eql(a: TextHashKey, b: TextHashKey) bool {
        return std.meta.eql(a.font_opts, b.font_opts) and std.meta.eql(a.width, b.width) and std.mem.eql(u8, a.text, b.text);
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
    pub fn init(imev: *ImEvent) RenderCtx {
        return RenderCtx{
            .imev = imev,
            .nodes = Queue(RenderNode){},
        };
    }
    // maybe .result() can do this instead?
    // then make sure that result is called on all renderctxs, only once.
    // uh oh renderctx is only for rendering fixed positioned things
    // if you return inset(…)
    // this needs a bit of a redo
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
    /// draw a rect of size WH
    ///
    /// sample:
    /// ```zig
    /// ctx.place(primitives.rect(imev, .{.w = 50, .h = 25}, .{.rounded = .md, .bg = .gray100}), .{.x = 25, .y = 50});
    /// ```
    pub fn rect(imev: *ImEvent, size: WH, opts: RectOpts) RenderResult {
        var ctx = imev.render();

        ctx.putRenderNode(RenderNode{ .value = .{ .rectangle = .{
            .wh = size,
            .radius = opts.rounded.getPx(),
            .bg_color = opts.bg.getColor(),
        } } });
        return ctx.result();
    }
    /// draw a clipping rect around some content of size WH
    ///
    /// sample:
    /// ```zig
    /// const content = primitives.rect(…);
    /// ctx.place(primitives.clippingRect(imev, .{.w = 50, .h = 25}, content), .{.x = 25, .y = 50});
    /// ```
    pub fn clippingRect(imev: *ImEvent, size: WH, content: RenderResult) RenderResult {
        var ctx = imev.render();

        ctx.putRenderNode(RenderNode{ .value = .{ .clipping_rect = .{
            .wh = size,
            .node = content,
        } } });

        return ctx.result();
    }
    const FontOpts = struct {
        family: FontFamily = .sans_serif,
        weight: FontWeight = .normal,
        underline: bool = false,
        size: FontSize,
        color: ThemeColor,
        left_offset: f64 = 0,
        pub fn all(opts: FontOpts) AllFontOpts {
            return AllFontOpts{
                .size = opts.size,
                .family = opts.family,
                .weight = opts.weight,
                .underline = opts.underline,
                .left_offset = backend.pangoScale(opts.left_offset),
            };
        }
    };
    pub fn textV(imev: *ImEvent, width: f64, opts: FontOpts, text_val: []const u8) VLayoutManager.Child {
        var ctx = imev.render();

        const all_font_opts = opts.all();
        const w_int = backend.pangoScale(width);
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
    pub fn text(imev: *ImEvent, opts: FontOpts, text_val: []const u8) Widget {
        var ctx = imev.render();

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
    pub fn textLayout(imev: *ImEvent, width: f64, opts: FontOpts, text_val: []const u8) backend.TextLayout {
        const all_font_opts = opts.all();
        const w_int = backend.pangoScale(width);
        const layout = imev.layoutText(.{ .font_opts = all_font_opts, .width = w_int, .text = text_val });

        return layout;
    }
    pub fn textLine(imev: *ImEvent, text_line: backend.TextLayoutLine, color: ThemeColor) RenderResult {
        var ctx = imev.render();

        ctx.putRenderNode(RenderNode{ .value = .{ .text_line = .{
            .line = text_line,
            .color = color.getColor(),
        } } });

        return ctx.result();
    }
    // advanced text:
    // https://docs.gtk.org/Pango/struct.AttrList.html
};

pub fn Queue(comptime T: type) type {
    return struct {
        pub const Node = struct {
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
        pub fn shift(list: *This, alloc: *std.mem.Allocator) ?T {
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
const TextCacheValue = struct {
    layout: backend.TextLayout,
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
        deinitFn: fn (entry: Entry, alloc: *std.mem.Allocator) void,
        // I think the point was for this{fyl,lyn,col} to be a value representing
        // the source location where useState was called so that if useState ends
        // up somehow with the same ID asking for different data, an error can be
        // made.

        used_this_frame: bool,

        pub fn readAs(value: Entry, comptime Type: type) *Type {
            return @intToPtr(*Type, value.ptr);
        }
    };
    const IscHM = std.HashMapUnmanaged(ID.Ident, Entry, ID.Ident.hash, ID.Ident.eql, std.hash_map.default_max_load_percentage);
    hm: IscHM,
    alloc: *std.mem.Allocator,

    pub fn init(alloc: *std.mem.Allocator) IdStateCache {
        return .{
            .hm = IscHM{},
            .alloc = alloc,
        };
    }

    pub fn useISC(isc: *IdStateCache, id_arg: ID.Arg) *IdStateCache {
        var res = isc.useStateCustomInit(id_arg, IdStateCache);
        if (!res.initialized) res.ptr.* = IdStateCache.init(isc.alloc);
        return res.ptr;
    }
    // this is where |these| {things} would be useful:
    // ` cache.state(@src(), imev, struct{x: f64}, |_| .{.x = 25});
    // unfortunately, not yet
    pub fn useState(isc: *IdStateCache, id_arg: ID.Arg, comptime Type: type, comptime initFn: fn () Type) *Type {
        var res = isc.useStateCustomInit(id_arg, Type);
        if (!res.initialized) res.ptr.* = initFn();
        return res.ptr;
    }
    pub fn useStateDefault(isc: *IdStateCache, id_arg: ID.Arg, comptime initial: anytype) *@TypeOf(initial) {
        var res = isc.useStateCustomInit(id_arg, @TypeOf(initial));
        if (!res.initialized) res.ptr.* = initial;
        return res.ptr;
    }
    fn StateRes(comptime Type: type) type {
        return struct {
            ptr: *Type,
            initialized: bool,
        };
    }
    // what if switch(useStateCustomInit()) {.initialized => {}, .unin => |unin| {unin.value.init(); break :blk unin}}
    // that could work
    pub fn useStateCustomInit(isc: *IdStateCache, id_val: ID.Arg, comptime Type: type) StateRes(Type) {
        const id = id_val.id.forSrc(@src());

        if (isc.hm.getEntry(id)) |hm_entry| {
            hm_entry.value.used_this_frame = true;
            return .{ .ptr = hm_entry.value.readAs(Type), .initialized = true };
        }
        const hm_entry = isc.hm.getOrPut(isc.alloc, id.dupe(isc.alloc)) catch @panic("oom");
        if (hm_entry.found_existing) unreachable;
        var item_ptr: *Type = isc.alloc.create(Type) catch @panic("oom");
        hm_entry.entry.value = .{
            .ptr = @ptrToInt(item_ptr),
            .deinitFn = struct {
                fn a(entry: Entry, alloc: *std.mem.Allocator) void {
                    const ptr_v = entry.readAs(Type);
                    if (switch (@typeInfo(Type)) {
                        .Struct, .Enum, .Union => true,
                        else => false,
                    } and @hasDecl(Type, "deinit")) {
                        ptr_v.deinit();
                    }
                    alloc.destroy(ptr_v);
                }
            }.a,
            .used_this_frame = true,
        };
        return .{ .ptr = item_ptr, .initialized = false };
    }
    pub fn cleanupUnused(isc: *IdStateCache, imev: *ImEvent) void {
        if (!imev.isRenderFrame()) return;

        var iter = isc.hm.iterator();
        var unused = std.ArrayList(ID.Ident).init(isc.alloc);
        defer unused.deinit();
        while (iter.next()) |ntry| {
            if (ntry.value.used_this_frame) {
                ntry.value.used_this_frame = false;
            } else {
                ntry.value.deinitFn(ntry.value, isc.alloc);
                unused.append(ntry.key) catch @panic("oom");
            }
        }
        for (unused.items) |key| {
            isc.hm.removeAssertDiscard(key);
            key.deinit(isc.alloc);
        }
    }
    pub fn deinit(isc: *IdStateCache) void {
        const alloc = isc.alloc;
        var iter = isc.hm.iterator();
        while (iter.next()) |ntry| {
            ntry.key.deinit(alloc);
            ntry.value.deinitFn(ntry.value, alloc);
        }
        isc.hm.deinit(alloc);
    }
};
pub const ImEvent = struct { // pinned?
    // structures that are created at init.
    persistent: struct {
        unprocessed_events: Queue(RawEvent),
        real_allocator: *std.mem.Allocator,
        text_cache: TextCacheHM,
        screen_size: WH,
        internal_screen_offset: Point,
        current_cursor: CursorEnum,
        allow_event_introspection: bool, // to set this a helper fn needs to be made. this must be set and then used next frame, not this frame.
        is_first_frame: bool,

        mouse_position: Point,
        mouse_held: bool,
        mouse_focused: ?MouseFocused,

        scroll_emulation_btn_held: bool,

        scroll_focused: ?ScrollFocused,
        // last_scroll_time: u64, // to prevent switching scroll focuses until «»ms of time without scrolling or similar

        prev_frame_keydown: ?Key = null, // todo + modifiers // todo determine who to dispatch to based on focus
    },

    /// structures that are only defined during a frame
    frame: struct {
        should_render: bool,
        arena_allocator: std.heap.ArenaAllocator,
        cr: backend.Context,
        cursor: CursorEnum = .default,
        render_result: RenderResult = undefined,

        mouse_down: bool = false,
        mouse_up: bool = false,

        scroll_delta: Point = Point.origin,

        key_down: ?Key = null,
    },

    const ScrollFocused = struct {
        id: ID.Ident, // saved across frames, must be duplicated and freed
        delta: Point,
        fn deinit(sf: ScrollFocused, alloc: *std.mem.Allocator) void {
            sf.id.deinit(alloc);
        }
    };
    const MouseFocused = struct {
        id: ID.Ident, // saved across frames, must be duplicated and freed
        hover: bool,
        mouse_up: bool,
        fn deinit(mf: MouseFocused, alloc: *std.mem.Allocator) void {
            mf.id.deinit(alloc);
        }
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
                .unprocessed_events = Queue(RawEvent){},
                .real_allocator = alloc,
                .text_cache = TextCacheHM.init(alloc),
                .screen_size = .{ .w = 0, .h = 0 },
                .internal_screen_offset = .{ .x = 0, .y = 0 },
                .current_cursor = .default,
                .allow_event_introspection = false,
                .is_first_frame = true,

                .mouse_position = .{ .x = -1, .y = -1 },
                .mouse_held = false,
                .mouse_focused = null,

                .scroll_emulation_btn_held = false,

                .scroll_focused = null,
            },
            .frame = undefined,
        };
    }
    pub fn deinit(imev: *ImEvent) void {
        if (!imev.persistent.is_first_frame) imev.destroyFrame();

        while (imev.persistent.unprocessed_events.shift(imev.persistent.real_allocator)) |_| {}

        var iter = imev.persistent.text_cache.iterator();
        while (iter.next()) |entry| {
            entry.value.layout.deinit();
            imev.persistent.real_allocator.free(entry.key.text);
        }
        imev.persistent.text_cache.deinit();

        if (imev.persistent.mouse_focused) |mf| mf.deinit(imev.persistentAlloc());
        if (imev.persistent.scroll_focused) |sf| sf.deinit(imev.persistentAlloc());
    }
    pub fn addEvent(imev: *ImEvent, event: RawEvent) !void {
        // could use an arena allocator, unfortunately arena allocators are created at frame start
        // rather than on init 🙲 frame end.
        // TODO consolidate similar events

        switch (event) {
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
            else => try imev.persistent.unprocessed_events.push(imev.persistent.real_allocator, event),
        }
    }
    pub fn prerender(imev: *ImEvent) bool {
        if (imev.persistent.is_first_frame) return true;
        const unpr_evs = imev.persistent.unprocessed_events;
        return !std.meta.eql(unpr_evs.start, unpr_evs.end); // AKA: unpr_evs.len >= 2
    }
    pub fn startFrame(imev: *ImEvent, cr: backend.Context, should_render: bool) void {
        if (!imev.persistent.is_first_frame) if (imev.persistent.unprocessed_events.shift(imev.persistent.real_allocator)) |ev| {
            switch (ev) {
                .resize => unreachable,
                .mouse_click => |mclick| {
                    imev.persistent.mouse_position = .{ .x = mclick.x, .y = mclick.y };
                    // TODO make this an enum for cross platform support
                    if (mclick.button == 1) {
                        if (mclick.down) {
                            imev.frame.mouse_down = true;
                            imev.persistent.mouse_held = true;
                        } else {
                            imev.frame.mouse_up = true;
                            imev.persistent.mouse_held = false;
                        }
                    } else if (mclick.button == 2) {
                        imev.persistent.scroll_emulation_btn_held = mclick.down;
                    }
                },
                .mouse_move => |mmove| {
                    if (imev.persistent.scroll_emulation_btn_held) {
                        const mdiff_x = mmove.x - imev.persistent.mouse_position.x;
                        const mdiff_y = mmove.y - imev.persistent.mouse_position.y;
                        imev.frame.scroll_delta = .{ .x = -mdiff_x, .y = -mdiff_y };
                    }
                    imev.persistent.mouse_position = .{ .x = mmove.x, .y = mmove.y };
                },
                .scroll => |sev| {
                    // imev.persistent.mouse_position = .{ .x = sev.mouse_x, .y = sev.mouse_y };
                    imev.frame.scroll_delta = .{ .x = sev.scroll_x, .y = sev.scroll_y };
                },
                .key => |key| {
                    // std.log.info("key: {s}{s}{s}{s}{s}{s}{s}", .{
                    //     (&[_][]const u8{ "↑", "↓" })[@boolToInt(key.down)],
                    //     @tagName(key.key),
                    //     (&[_][]const u8{ "", " ⌃" })[@boolToInt(key.modifiers.ctrl)],
                    //     (&[_][]const u8{ "", " ⎇ " })[@boolToInt(key.modifiers.alt)],
                    //     (&[_][]const u8{ "", " ⇧" })[@boolToInt(key.modifiers.shift)],
                    //     (&[_][]const u8{ "", " ⌘" })[@boolToInt(key.modifiers.win)],
                    //     "",
                    // });
                    if (key.down) imev.frame.key_down = key.key;
                },
                else => {},
            }

            if (!imev.persistent.mouse_held and !imev.frame.mouse_up) {
                if (imev.persistent.mouse_focused) |mf| mf.deinit(imev.persistentAlloc());
                imev.persistent.mouse_focused = null;
            }
            if (imev.persistent.scroll_focused) |sf| sf.deinit(imev.persistentAlloc());
            imev.persistent.scroll_focused = null;

            const soffset = imev.persistent.internal_screen_offset;
            imev.handleEvent(imev.frame.render_result, soffset, imev.persistent.screen_size.setUL(soffset));
        };

        if (imev.persistent.is_first_frame) imev.persistent.is_first_frame = false //
        else {
            imev.persistent.prev_frame_keydown = imev.frame.key_down;
            imev.destroyFrame();
        }

        if (should_render) {
            var iter = imev.persistent.text_cache.iterator();
            while (iter.next()) |entry| {
                entry.value.used_in_this_render_frame = false;
            }
        }

        imev.frame = .{
            .should_render = should_render,
            .arena_allocator = std.heap.ArenaAllocator.init(imev.persistent.real_allocator),
            .cr = cr,
        };
    }
    pub fn handleEvent(imev: *ImEvent, nodes: RenderResult, offset: Point, clip: Rect) void {
        var nodeiter = nodes;
        const cr = imev.frame.cr;
        while (nodeiter) |node| {
            const rnode: RenderNode = node.value;
            switch (rnode.value) {
                .rectangle => {},
                .text => {},
                .text_line => {},
                .place => |place| {
                    imev.handleEvent(place.node, .{ .x = offset.x + place.offset.x, .y = offset.y + place.offset.y }, clip);
                },
                .clipping_rect => |clip_rect| {
                    imev.handleEvent(clip_rect.node, offset, clip_rect.wh.setUL(offset).overlap(clip));
                },
                .clickable => |cable| {
                    const contains_point = offset.toRectBR(cable.wh).overlap(clip).containsPoint(imev.persistent.mouse_position);
                    const active_is_this = if (imev.persistent.mouse_focused) |mfx| ( //
                        mfx.id.eql(cable.id) //
                    ) else ( //
                        contains_point //
                    );
                    if (active_is_this) {
                        if (imev.persistent.mouse_focused) |mf| mf.deinit(imev.persistentAlloc());
                        imev.persistent.mouse_focused = MouseFocused{
                            .id = cable.id.dupe(imev.persistentAlloc()),
                            .hover = contains_point,
                            .mouse_up = imev.frame.mouse_up,
                        };
                    }
                },
                .scrollable => |sable| {
                    const contains_point = offset.toRectBR(sable.wh).overlap(clip).containsPoint(imev.persistent.mouse_position);
                    if (contains_point and !(imev.frame.scroll_delta.x == 0 and imev.frame.scroll_delta.y == 0)) {
                        if (imev.persistent.scroll_focused) |sf| sf.deinit(imev.persistentAlloc());
                        imev.persistent.scroll_focused = ScrollFocused{
                            .id = sable.id.dupe(imev.persistentAlloc()),
                            .delta = imev.frame.scroll_delta,
                        };
                    }
                },
            }
            nodeiter = node.next;
        }
    }
    pub fn internalRender(imev: *ImEvent, nodes: RenderResult, offset: Point, clip: Rect) void {
        var nodeiter = nodes;
        const cr = imev.frame.cr;
        while (nodeiter) |node| {
            const rnode: RenderNode = node.value;
            switch (rnode.value) {
                .rectangle => |rect| {
                    cr.renderRectangle(rect.bg_color, .{ .x = offset.x, .y = offset.y, .w = rect.wh.w, .h = rect.wh.h }, rect.radius);
                },
                .text => |text| {
                    cr.renderText(offset, text.layout, text.color);
                },
                .text_line => |tl| {
                    cr.renderTextLine(offset, tl.line, tl.color);
                },
                .place => |place| {
                    imev.internalRender(place.node, .{ .x = offset.x + place.offset.x, .y = offset.y + place.offset.y }, clip);
                },
                .clipping_rect => |clip_rect| {
                    const content_clip = clip_rect.wh.setUL(offset).overlap(clip);
                    cr.pushClippingRect(content_clip);
                    imev.internalRender(clip_rect.node, offset, content_clip);
                    cr.popState();
                },
                .clickable => {},
                .scrollable => {},
            }
            nodeiter = node.next;
        }
    }
    pub fn endFrameRender(imev: *ImEvent, render_v: RenderResult) void {
        if (!imev.frame.should_render) unreachable;

        const soffset = imev.persistent.internal_screen_offset;
        const ir_clip = imev.persistent.screen_size.setUL(soffset);
        imev.internalRender(render_v, soffset, ir_clip);

        imev.frame.render_result = render_v;
    }
    pub fn endFrame(imev: *ImEvent, render_v: RenderResult) void {
        if (imev.frame.should_render) unreachable;

        imev.frame.render_result = render_v;
    }
    pub fn destroyFrame(imev: *ImEvent) void {
        if (imev.frame.should_render) {
            var keys_to_remove = Queue(TextHashKey){};
            var iter = imev.persistent.text_cache.iterator();
            while (iter.next()) |entry| {
                if (!entry.value.used_in_this_render_frame) {
                    keys_to_remove.push(imev.arena(), entry.key) catch @panic("oom");
                }
            }
            while (keys_to_remove.shift(imev.arena())) |key| {
                if (imev.persistent.text_cache.remove(key)) |v| {
                    v.value.layout.deinit();
                    imev.persistent.real_allocator.free(v.key.text);
                } else unreachable;
            }

            if (imev.frame.cursor != imev.persistent.current_cursor) {
                imev.persistent.current_cursor = imev.frame.cursor;
                imev.frame.cr.setCursor(imev.frame.cursor);
            }
        }

        imev.frame.arena_allocator.deinit();
    }

    pub fn render(imev: *ImEvent) RenderCtx {
        // TODO the render fn should accept a source location so that the render node
        // knows what function called it. so the devtools can say "renderNode()" eg and
        // tell you what function rendered it. like "this is a scroll view", "this is
        // an action" eg.
        return RenderCtx.init(imev);
    }

    pub fn isRenderFrame(imev: *ImEvent) bool {
        return if (imev.persistent.allow_event_introspection) true else imev.frame.should_render;
    }

    pub fn layoutText(imev: *ImEvent, key: TextHashKey) backend.TextLayout {
        if (imev.persistent.text_cache.getEntry(key)) |cached_value| {
            cached_value.value.used_in_this_render_frame = true;
            return cached_value.value.layout;
        } else {
            const text_dupe = imev.persistent.real_allocator.dupe(u8, key.text) catch @panic("oom");
            const font_str = std.fmt.allocPrint0(imev.arena(), "{}", .{key.font_opts}) catch @panic("oom");

            // create an attr list
            // const attr_list = imev.frame.cr.newAttrList();
            // attr_list.addRange(0, font_str.len, .underline);
            // (in c, this is created using pango_attr_underline_new(.PANGO_UNDERLINE_SINGLE) and then set the attr)
            // start index and end index

            const attrs = backend.TextAttrList.new();
            if (key.font_opts.underline) attrs.addRange(0, 0 + text_dupe.len, .underline);
            const layout = imev.frame.cr.layoutText(font_str.ptr, text_dupe, .{ .width = key.width, .left_offset = key.font_opts.left_offset }, attrs);

            const cache_value: TextCacheValue = .{
                .layout = layout,
                .used_in_this_render_frame = true,
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

    pub fn clickable(imev: *ImEvent, id_h: ID.Arg) ClickableState {
        const id = id_h.id.forSrc(@src());
        return ClickableState{
            .key = .{ .id = id },
            .focused = if (imev.persistent.mouse_focused) |mfx| if (mfx.id.eql(id)) ( //
                ClickableState.Focused{
                .hover = mfx.hover,
                .click = mfx.mouse_up and mfx.hover,
            } //
            ) else null else null,
        };
    }

    pub fn scrollable(imev: *ImEvent, id_h: ID.Arg) ScrollableState {
        const id = id_h.id.forSrc(@src());
        return ScrollableState{
            .key = .{ .id = id },
            .scrolling = if (imev.persistent.scroll_focused) |scr| if (scr.id.eql(id)) ( //
                ScrollableState.Scrolling{ .delta = scr.delta } //
            ) else null else null,
        };
    }
};
pub const Src = ID.Src;

pub const ClickableKey = struct {
    id: ID.Ident,
    pub fn node(key: ClickableKey, imev: *ImEvent, wh: WH) RenderResult {
        var ctx = imev.render();
        ctx.putRenderNode(.{ .value = .{ .clickable = .{ .id = key.id, .wh = wh } } });
        return ctx.result();
    }
};
pub const ClickableState = struct {
    const Focused = struct {
        hover: bool,
        click: bool,
        // other stuff
        // clicking: bool
        // click: bool
        // mpos: ?Point, // while clicking, this can go negative. coords are relative to where the node was placed.
        pub fn setCursor(fcsd: Focused, imev: *ImEvent, cursor: CursorEnum) void {
            // alternatively: make this struct pinned and use fieldparentptr
            imev.frame.cursor = cursor;
        }
    };
    key: ClickableKey,

    focused: ?Focused,
};

pub const ScrollableKey = struct {
    id: ID.Ident,
    pub fn node(key: ScrollableKey, imev: *ImEvent, wh: WH) RenderResult {
        var ctx = imev.render();
        ctx.putRenderNode(.{ .value = .{ .scrollable = .{ .id = key.id, .wh = wh } } });
        return ctx.result();
    }
};
pub const ScrollableState = struct {
    const Scrolling = struct {
        delta: Point,
    };
    key: ScrollableKey,

    scrolling: ?Scrolling,
};

pub const VirtualScrollHelper = struct {
    scroll_offset: f64,
    top_node: u64, // unique id referring to the specific node
    node_data_cache: std.AutoHashMap(u64, *IdStateCache),

    pub fn init(alloc: *std.mem.Allocator, top_node: u64) VirtualScrollHelper {
        return .{
            .scroll_offset = 0,
            .top_node = top_node,
            .node_data_cache = std.AutoHashMap(u64, *IdStateCache).init(alloc),
        };
    }
    pub fn deinit(vsh: *VirtualScrollHelper) void {
        var iter = vsh.node_data_cache.iterator();
        while (iter.next()) |entry| {
            entry.value.deinit();
            vsh.node_data_cache.allocator.destroy(entry.value);
        }
        vsh.node_data_cache.deinit();
    }

    pub fn scroll(vsh: *VirtualScrollHelper, offset: f64) void {
        vsh.scroll_offset -= offset;
    }

    // a use case for |_| macros

    fn cacheForNode(vsh: *VirtualScrollHelper, node_id: u64) *IdStateCache {
        var gop_res = vsh.node_data_cache.getOrPut(node_id) catch @panic("oom");
        if (!gop_res.found_existing) {
            const ptr = vsh.node_data_cache.allocator.create(IdStateCache) catch @panic("oom");
            ptr.* = IdStateCache.init(vsh.node_data_cache.allocator);
            gop_res.entry.value = ptr;
        }
        return gop_res.entry.value;
    }

    fn renderOneNode(vsh: *VirtualScrollHelper, renderInfo: anytype, id_root: ID, imev: *ImEvent, node_id: u64) VLayoutManager.Child {
        const id = id_root.pushIndex(@src(), node_id); // if this errors, it means the same node is being rendered twice. id_root should *not* be .push(@src())'d

        const cache = vsh.cacheForNode(node_id);
        const rres = renderInfo.renderNode(id.push(@src()), imev, cache, node_id);
        cache.cleanupUnused(imev);
        return rres;
    }

    /// renderInfo:
    /// struct {
    ///     … any fields you need
    ///     pub fn renderNode(self: @This(), src: Src, imev: *ImEvent, isc: *IdStateCache, node_id: u64) VLayoutManager.Child {}
    ///     pub fn existsNode(self: @This(), node_id: u64) bool {}
    ///     pub fn getNextNode(self: @This(), node_id: u64) ?u64 {}
    ///     pub fn getPreviousNode(self: @This(), node_id: u64) ?u64 {}
    /// }
    pub fn render(vsh: *VirtualScrollHelper, id_arg: ID.Arg, imev: *ImEvent, render_info: anytype, height: f64, placement_y_offset: f64) RenderResult {
        const id = id_arg.id;
        var ctx_outer = imev.render();

        if (!render_info.existsNode(vsh.top_node)) {
            return ctx_outer.result(); // TODO something
        }

        if (placement_y_offset < 0) unreachable; // TODO what does this mean? + support it

        // here's the new plan:

        var ctx = imev.render();

        // part 1: render the top node
        var top_node_id = vsh.top_node;
        var top_node_rendered = vsh.renderOneNode(render_info, id, imev, top_node_id);
        ctx.place(top_node_rendered.node, .{ .x = 0, .y = @floor(vsh.scroll_offset) });

        var current_y: f64 = @floor(vsh.scroll_offset) + top_node_rendered.h;
        var lowest_rendered_id = vsh.top_node;
        var lowest_rendered_node = top_node_rendered;

        // part 2: if there are nodes above it, render those and update the top node
        while (vsh.scroll_offset > 0 - placement_y_offset) {
            top_node_id = render_info.getPreviousNode(top_node_id) orelse break;
            top_node_rendered = vsh.renderOneNode(render_info, id, imev, top_node_id);
            vsh.top_node = top_node_id;
            vsh.scroll_offset -= top_node_rendered.h;
            ctx.place(top_node_rendered.node, .{ .x = 0, .y = @floor(vsh.scroll_offset) });
        }

        // part 3: if the highest node has whitespace above it (scroll_offset > 0), assert it is the first node
        //         and transform all the previously rendered things and current_y, then place them on the screen
        //         (ctx = (nctx = new ctx, nctx.place(ctx), nctx))
        if (vsh.scroll_offset > 0) {
            if (render_info.getPreviousNode(vsh.top_node) != null) unreachable;

            var transform_dist = -@floor(vsh.scroll_offset);
            vsh.scroll_offset = 0;

            ctx = blk: {
                var new_ctx = imev.render();
                new_ctx.place(ctx.result(), .{ .x = 0, .y = transform_dist });
                current_y += transform_dist;
                break :blk new_ctx;
            };
        }

        // part 4a: while the top node is above the screen, advance it
        const undo_4a_top_node = vsh.top_node;
        const undo_4a_scroll_offset = vsh.scroll_offset;
        while (current_y < 0 - placement_y_offset) {
            lowest_rendered_id = render_info.getNextNode(lowest_rendered_id) orelse break;

            vsh.top_node = lowest_rendered_id;
            vsh.scroll_offset += lowest_rendered_node.h;

            lowest_rendered_node = vsh.renderOneNode(render_info, id, imev, lowest_rendered_id);
            ctx.place(lowest_rendered_node.node, .{ .x = 0, .y = current_y });
            current_y += lowest_rendered_node.h;
        }

        // part 4b: fill in nodes on the bottom. if the top node is above the screen, update the vsh.top_node and scroll to match
        while (current_y < height - placement_y_offset) {
            lowest_rendered_id = render_info.getNextNode(lowest_rendered_id) orelse break;
            const rendered_node = vsh.renderOneNode(render_info, id, imev, lowest_rendered_id);
            ctx.place(rendered_node.node, .{ .x = 0, .y = current_y });
            current_y += rendered_node.h;
        }

        // part 5: determine if the bottom of the rendered stuff is <60% of the height. if so, more repositioning
        //         is needed:

        const bottom_60p = @floor(height * 0.60);
        // part 5 is the hardest part probably
        if (current_y < bottom_60p - placement_y_offset) {
            const push_down_dist = current_y - (bottom_60p - placement_y_offset);
            // 5a. reposition down to the bottom

            ctx = blk: {
                var new_ctx = imev.render();
                new_ctx.place(ctx.result(), .{ .x = 0, .y = -push_down_dist });
                current_y += -push_down_dist;
                break :blk new_ctx;
            };
            // adjust the vertical

            vsh.top_node = undo_4a_top_node;
            vsh.scroll_offset = undo_4a_scroll_offset;

            vsh.scroll_offset += -push_down_dist;

            // 5b. fill nodes up until reaching the top of the filled area. (do? adjust top node)
            // TODO this. some things might¿ not render properly? maybe they will? not sure

            // 5c. if the highest rendered node is still not at the top of the filled area: reposition everything
            //     up to the top of the screen.

            if (vsh.scroll_offset > 0) {
                const push_up_dist = -@floor(vsh.scroll_offset);
                ctx = blk: {
                    var new_ctx = imev.render();
                    new_ctx.place(ctx.result(), .{ .x = 0, .y = push_up_dist });
                    current_y += push_up_dist;
                    break :blk new_ctx;
                };
            }
        }

        ctx_outer.place(ctx.result(), Point.origin);

        return ctx.result();
    }

    // issues: if the top node to be rendered was deleted, there will be an issue.
    // TODO fix
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

pub const BaseRootState = struct {
    devtools_open: bool = false,

    pub fn init() BaseRootState {
        return .{};
    }
};

const devtools = @import("devtools.zig");

pub fn renderBaseRoot(id: ID, imev: *ImEvent, isc: *IdStateCache, wh: WH, data: ExecData) RenderResult {
    var ctx = imev.render();

    const state = isc.useState(id.push(@src()), BaseRootState, BaseRootState.init);

    const rootfn_id = id.push(@src());

    // TODO imev.hotkey with dispatch based on focus and stuff
    if (imev.persistent.prev_frame_keydown) |kd| if (kd == .f12) {
        state.devtools_open = !state.devtools_open;
    };

    if (build_opts.devtools_enabled and state.devtools_open) {
        const content_rect: Rect = (WH{ .w = wh.w, .h = @divFloor(wh.h, 2) }).setUL(Point.origin);
        const devtools_rect: Rect = .{
            .x = 0,
            .y = content_rect.y + content_rect.h,
            .w = wh.w,
            .h = wh.h - content_rect.h,
        };

        // devtools.useDevtools()
        // if(mobile_emulation) useMobileEmulation // if(memu.clip) clip (should clip content or just memu frame)
        // actually the mobile emulation screen should have the options for clipping rather than devtools having them
        // devtools can just have a toggle
        const memu = devtools.useMobileEmulation(id.push(@src()), imev, isc, content_rect.wh());

        const root_result = data.rootFnGeneric(rootfn_id, imev, isc, memu.content_wh, data.root_fn_content);

        ctx.place(memu.render(id.push(@src()), imev, root_result), content_rect.ul());
        ctx.place(devtools.renderDevtools(id.push(@src()), imev, isc, devtools_rect.wh(), root_result), devtools_rect.ul());
    } else {
        ctx.place(data.rootFnGeneric(rootfn_id, imev, isc, wh, data.root_fn_content), Point.origin);
    }

    return ctx.result();
}

pub fn renderFrame(cr: backend.Context, rr: backend.RerenderRequest, data: ExecData) void {
    const timer = std.time.Timer.start() catch @panic("bad timer");
    const imev = data.imev;
    const root_state_cache = data.root_state_cache;

    var id: ID = undefined;

    var render_count: usize = 0;
    while (imev.prerender()) {
        render_count += 1;
        imev.startFrame(cr, false);
        id = ID.init(imev.persistentAlloc(), imev.arena());
        imev.endFrame(renderBaseRoot(id, imev, root_state_cache, imev.persistent.screen_size, data));
        id.deinit();
        root_state_cache.cleanupUnused(imev);
    }
    render_count += 1;
    imev.startFrame(cr, true);
    id = ID.init(imev.persistentAlloc(), imev.arena());
    imev.endFrameRender(renderBaseRoot(id, imev, root_state_cache, imev.persistent.screen_size, data));
    id.deinit();
    root_state_cache.cleanupUnused(imev);

    // std.log.info("rerender×{} in {}ns", .{ render_count, timer.read() }); // max allowed time is 4ms
}
pub fn pushEvent(ev: RawEvent, rr: backend.RerenderRequest, data: ExecData) void {
    const imev = data.imev;

    imev.addEvent(ev) catch @panic("oom");
    rr.queueDraw();
}

const ExecData = struct {
    root_fn_content: usize,
    rootFnGeneric: RenderRootFn(usize),
    imev: *ImEvent,
    root_state_cache: *IdStateCache,
};

fn RenderRootFn(comptime Content: type) type {
    return fn (id_arg: ID.Arg, imev: *ImEvent, isc: *IdStateCache, wh: WH, content: Content) RenderResult;
}
pub fn runUntilExit(alloc: *std.mem.Allocator, content: anytype, comptime renderRoot: RenderRootFn(@TypeOf(content))) !void {
    var imevent = ImEvent.init(alloc);
    defer imevent.deinit();

    var root_state_cache = IdStateCache.init(alloc);
    defer root_state_cache.deinit();

    const root_fn_content = @ptrToInt(&content);
    comptime const RootFnContent = @TypeOf(&content);
    var exec_data = ExecData{
        .root_fn_content = root_fn_content,
        .rootFnGeneric = (struct {
            fn a(id_arg: ID.Arg, imev: *ImEvent, isc: *IdStateCache, wh: WH, content_ptr: usize) RenderResult {
                return renderRoot(id_arg, imev, isc, wh, @intToPtr(RootFnContent, content_ptr).*);
            }
        }).a,
        .imev = &imevent,
        .root_state_cache = &root_state_cache,
    };
    try backend.runUntilExit(exec_data, renderFrame, pushEvent);
}
