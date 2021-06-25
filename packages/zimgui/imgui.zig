const std = @import("std");
const app = @import("app.zig");
const backend = @import("backends/backend.zig");
pub const ID = @import("id.zig").ID;
pub usingnamespace @import("structures.zig");
const build_opts = @import("build_options");
const callback = @import("callbacks").callback;
const Callback = @import("callbacks").Callback;

pub const StartBackend = backend.StartBackend;

pub fn range(max: usize) []const void {
    return @as([]const void, &[_]void{}).ptr[0..max];
}

pub const MouseState = enum { down, held, up, none };
pub const MouseEvent = struct {
    imev: *ImEvent,

    /// coords, relative to the clickable node origin
    x: f64,
    y: f64,

    // /// offsets from last frame
    // dx: f64,
    // dy: f64,

    state: MouseState,

    button: c_int, // TODO fix

    overlap: bool, // is this necessary? I think the event handler could decide on its own if it was clicked or not or smth
};
pub const EventUsed = enum {
    /// don't propagate the event. eg you hit the ⭾tab key and the focused editor wants to eat it
    /// so it doesn't perform the default action of advancing focus
    used,
    /// continue propagating the event
    ignored,
};

pub const RenderNode = struct { value: union(enum) {
    rectangle: struct {
        wh: WH,
        radius: f64,
        bg_color: Color,
    },
    text: struct {
        layout: backend.TextLayout,
    },
    text_line: struct {
        line: backend.TextLayoutLine,
        color: Color,
    },
    push_offset: struct {
        offset: Point,
    },
    pop_offset,
    push_clipping_rect: struct {
        wh: WH,
    },
    pop_clipping_rect,
    clickable: ClickableNode,
    scrollable: struct {
        id: ID.Ident, // owned by the arena
        wh: WH,
    },
    focusable: struct {
        id: ID.Ident, // owned by the arena
        focusable_by: FocusableReason,
    },
} };

const ClickableNode = struct {
    id: ID.Ident, // owned by the arena
    wh: WH,
    cb: Callback(MouseEvent, EventUsed),
};

pub const Width = enum {
    none,
    p4,
    p8,
    p12,
    p16,
    p20,
    xl,
    xl2,
    pub fn getPx(w: Width) f64 {
        return switch (w) {
            .none => 0,
            .p4 => 4,
            .p8 => 8,
            .p12 => 12,
            .p16 => 16,
            .p20 => 20,
            .xl => 600,
            .xl2 => 1000,
        };
    }
};
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

pub const Sample = struct {
    const black = ColorStyle.wrapping(SampleColors, .black);
};
pub const ColorStyle = struct {
    enum_key: u32, // since this is a u32, it can also store a full hex rgba color if needed.
    get_color_fn: fn (enum_key: u32, imev: *ImEvent) Color,
    pub fn getColor(col: ColorStyle, imev: *ImEvent) Color {
        return col.get_color_fn(col.enum_key, imev);
    }

    // alternatively, this could just be two colors, one dark mode and one light mode. that's 8 u64s rather than 2 though
    // and less extensible (eg high contrast mode) although high contrast mode might be something that's handled differently
    // like the point of high contrast is to add more borders and stuff. ah eg : text scaling, this doesn't handle that.
    // unless text scaling is just a global modifier.

    // also, this has the advantage that it can be used as a hashmap key (whereas floats can't)
};

// TODO union(enum) {custom: Color} and also this needs to be customizable
// and support dark/light mode and stuff
// ALTERNATIVELY
// .{.color = Style.black}
// and then Style.black is a constant of type ColorStyle which has a
// fn to get the color
// that's actually a much better idea. do that. have functions accept
// ColorStyle rather than accepting Color
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
    xl5, // 3rem ≈ 36.1404pt
    pub fn getString(fsize: FontSize) []const u8 {
        return switch (fsize) {
            .sm => "10.541",
            .base => "12.0468",
            .xl5 => "36.1404",
        };
    }
};
const AllFontOpts = struct {
    size: FontSize,
    color: ThemeColor,
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
    has_returned: bool = false, // TODO void in release modes

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
        if (ctx.has_returned) unreachable;
        ctx.nodes.push(ctx.imev.arena(), node) catch @panic("oom");
    }
    pub fn putRenderNodes(ctx: *RenderCtx, node: RenderResult) void {
        if (ctx.has_returned) unreachable;
        ctx.nodes.pushQueue(node.value);
    }
    pub fn result(ctx: *RenderCtx) RenderResult {
        if (ctx.has_returned) unreachable;
        ctx.has_returned = true; // alternatively: ctx.* = undefined, but zig doesn't catch that as a bug as easily.
        return .{ .value = ctx.nodes };
    }
    pub fn place(ctx: *RenderCtx, node: RenderResult, point: Point) void {
        if (ctx.has_returned) unreachable;
        ctx.putRenderNode(.{ .value = .{ .push_offset = .{ .offset = point } } });
        ctx.putRenderNodes(node);
        ctx.putRenderNode(.{ .value = .pop_offset });
    }
};
pub const RenderResult = struct {
    value: Queue(RenderNode),
    pub fn walk(rr: RenderResult, alloc: *std.mem.Allocator) RenderWalker {
        return RenderWalker.init(alloc, rr);
    }
};
pub const RenderWalker = struct {
    stack: std.ArrayList(*Queue(RenderNode).Node),
    pub fn init(alloc: *std.mem.Allocator, root_node: RenderResult) RenderWalker {
        var al = std.ArrayList(*Queue(RenderNode).Node).init(alloc);
        if (root_node.value) |v| al.append(v) catch @panic("oom");
        return RenderWalker{ .stack = al };
    }
    pub fn deinit(rw: RenderWalker) void {
        rw.stack.deinit();
    }
    pub fn next(rw: *RenderWalker) ?*RenderNode {
        var res = rw.stack.popOrNull() orelse return null;
        if (res.next) |nxt| {
            rw.stack.append(nxt) catch @panic("oom");
        }
        switch (res.value.value) {
            .place => |plc| {
                if (plc.node.value) |v| rw.stack.append(v) catch @panic("oom");
            },
            .clipping_rect => |clr| {
                if (clr.node.value) |v| rw.stack.append(v) catch @panic("oom");
            },
            else => {},
        }
        return &res.value;
    }
};

pub const Widget = struct {
    wh: WH,
    node: RenderResult,
};

pub const primitives = struct {
    pub const RectOpts = struct {
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

        ctx.putRenderNode(.{ .value = .{ .push_clipping_rect = .{ .wh = size } } });
        ctx.putRenderNodes(content);
        ctx.putRenderNode(.{ .value = .pop_clipping_rect });

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
                .color = opts.color,
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
        /// pushes a queue to the end of this one. *note*: adding additional
        /// items to the pushed queue after pushing it will be ignored.
        pub fn pushQueue(list: *This, value: This) void {
            if (value.start == null) return;
            if (value.end == null) unreachable;

            if (list.end) |endn| {
                endn.next = value.start;
                list.end = value.end;
            } else {
                list.start = value.start;
                list.end = value.end;
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

    pub fn useISC(isc: *IdStateCache, id_arg: ID.Arg, imev: *ImEvent) *IdStateCache {
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

pub const WFocused = struct {
    id: ID.Ident,
    reason: FocusableReason,

    pub fn dupe(focused: WFocused, alloc: *std.mem.Allocator) WFocused {
        return .{
            .id = focused.id.dupe(alloc),
            .reason = focused.reason,
        };
    }
    pub fn deinit(focused: WFocused, alloc: *std.mem.Allocator) void {
        focused.id.deinit(alloc);
    }
};

pub const ImEvent = struct { // pinned?
    const MouseFocused = struct {
        /// saved across frames, must be duplicated and freed
        id: ID.Ident,
        /// this must be updated every frame, otherwise it will have pointers to
        /// invalid data. call the callback and say it's a mouse out event on mouse out I guess.
        cb: Callback(MouseEvent, EventUsed),
        fn deinit(mf: MouseFocused, alloc: *std.mem.Allocator) void {
            mf.id.deinit(alloc);
        }
    };

    /// structures that are created at init.
    persistent: struct {
        unprocessed_events: Queue(RawEvent),
        real_allocator: *std.mem.Allocator,
        text_cache: TextCacheHM,
        screen_size: WH,
        internal_screen_offset: Point,
        current_cursor: CursorEnum,
        allow_event_introspection: bool, // to set this a helper fn needs to be made. this must be set and then used next frame, not this frame.
        is_first_frame: bool,
        interaction_isc: IdStateCache,

        mouse_focused: ?MouseFocused,

        focus: ?WFocused = null,
        // if, at the end of the frame, focus_used_this_frame is null:
        // - diff with the previous and current frame to find which ident to use
        // - or if there are no idents just keep it null
        // - also memory has to be kept for two frames instead of one now

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

        scroll_delta: Point = Point.origin,

        key_down: ?Key = null,

        focus_used_this_frame: bool = false,
        next_frame_focus: ?WFocused = null,

        request_rerender: bool = false,
    },

    const ScrollFocused = struct {
        id: ID.Ident, // saved across frames, must be duplicated and freed
        delta: Point,
        fn deinit(sf: ScrollFocused, alloc: *std.mem.Allocator) void {
            sf.id.deinit(alloc);
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
                .interaction_isc = IdStateCache.init(alloc),

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
        if (imev.persistent.focus) |f| f.deinit(imev.persistentAlloc());

        imev.persistent.interaction_isc.deinit();
    }
    /// returns true if a rerender is requested, false otherwise.
    pub fn addEvent(imev: *ImEvent, event: RawEvent) !bool {
        // could use an arena allocator, unfortunately arena allocators are created at frame start
        // rather than on init 🙲 frame end.
        // TODO consolidate similar events

        try imev.persistent.unprocessed_events.push(imev.persistent.real_allocator, event);
        return true;
    }
    pub fn prerender(imev: *ImEvent) bool {
        if (imev.persistent.is_first_frame) return true;
        const unpr_evs = imev.persistent.unprocessed_events;
        return !std.meta.eql(unpr_evs.start, unpr_evs.end); // AKA: unpr_evs.len >= 2
    }
    const FocusDirection = enum { manual, from_left, from_right };
    /// focusdirection is used for eg scroll views. they might have content above that they don't know about,
    /// so if you tab from the top you would expect the scrollview to scroll all the way to the top and set focus
    /// to the first item, but from the bottom you would expect the scrollview to just scroll up a little bit.
    /// manual focusdirection generally should never be triggered in situations like that.
    fn setFocus(imev: *ImEvent, id: ID.Ident, reason: FocusableReason, direction: FocusDirection) void {
        if (imev.persistent.focus) |f| f.deinit(imev.persistentAlloc());
        imev.persistent.focus = .{
            .id = id.dupe(imev.persistentAlloc()),
            .reason = reason,
        };
    }
    // const RenderResultIter = struct {
    //     index: ?RenderResult,
    //     // mode: enum{enter, next} = .enter, // this would be for if you could get enter and leave events
    //     // in the loop but you can't.
    //     // the entire renderresult thing could be switched to just a linked list instead of
    //     // having these objects which you have to descend into
    //     // like it could say set_offset(x, y) and then set_offset(-x, -y)
    //     // that might be a good idea idk
    //     pub fn next(iter: *RenderResultIter) ?RenderResult {
    //         if(iter.index == null) return null;
    //         const res = iter.index.?;
    //         var index = res;
    //         switch()
    //         return res;
    //     }
    // };
    // wait there's literally a walker already what am I doing
    const MouseFocusTarget = struct {
        node: *ClickableNode,
        offset: Point,
    };
    const MouseFocusTargetResult = struct { same: bool, previous: ?MouseFocusTarget, current: ?MouseFocusTarget };
    fn findMouseFocusTarget(imev: *ImEvent, pos: Point) MouseFocusTargetResult {
        var match: ?MouseFocusTarget = null;
        // var iter = RenderResultIter{.index = imev.render_result};
        // while(iter.next()) |itm| switch(itm.node) {
        //     .clickable => |cable| {

        //     },
        // };
        var walker = imev.frame.render_result.walk(imev.persistentAlloc());
        defer walker.deinit();
        while (walker.next()) |node| switch (node.value) {
            .clickable => |*cable| {
                var offset: Point = .{ .x = 0, .y = 0 };
                for (walker.stack.items) |it| switch (it.value.value) {
                    .place => |place| {
                        offset.x += place.offset.x;
                        offset.y += place.offset.y;
                    },
                    else => {},
                };
                if (cable.wh.setUL(offset).containsPoint(pos)) {
                    match = .{ .node = cable, .offset = offset };
                }
            },
            else => {},
        };
        return .{ .same = false, .previous = null, .current = match };
    }
    // the mouse focus target should be just for the current frame probably right?
    // yeah it should store an id and then findMouseFocusTarget can search for
    // that ID in the tree.
    fn setMouseFocusTarget(imev: *ImEvent, id: ID.Ident) void {}
    pub fn startFrame(imev: *ImEvent, cr: backend.Context, should_render: bool) void {
        if (!imev.persistent.is_first_frame) if (imev.frame.next_frame_focus) |nff| {
            imev.setFocus(nff.id, nff.reason, .manual);
            imev.frame.next_frame_focus = null;
        };

        if (!imev.persistent.is_first_frame) if (imev.persistent.unprocessed_events.shift(imev.persistent.real_allocator)) |ev| {
            switch (ev) {
                .resize => |rsz| {
                    imev.persistent.internal_screen_offset = .{
                        .x = @intToFloat(f64, rsz.x),
                        .y = @intToFloat(f64, rsz.y),
                    };
                    imev.persistent.screen_size = .{
                        .w = @intToFloat(f64, rsz.w),
                        .h = @intToFloat(f64, rsz.h),
                    };
                    // this event does not need to propagate anywhere
                },
                .mouse_down => |mclick| {
                    std.log.info("Mouse {} down at {d},{d}", .{ mclick.button, mclick.x, mclick.y });
                    // - if there is a focused mouse object, @panic("mouse down event without a mouse up event between")
                    //   - probably not a good idea to error there, should handle these situations and also
                    //     there are multiple mouse buttons
                    // -
                },
                .mouse_up => |mclick| {
                    std.log.info("Mouse {} up at {d},{d}", .{ mclick.button, mclick.x, mclick.y });
                    // - if there is a focused mouse object, @panic("mouse down event without a mouse up event between")
                    //   - probably not a good idea to error there, there are multiple mouse buttons
                    // -
                },
                .mouse_move => |mmove| {
                    // how to handle this:
                    // - if there is a current mouse focus and the mouse is clicked:
                    //   - send the event to that item and update its hover state and stuff
                    // - else (or if the saved focused item could not be found):
                    //   - get the previous and current focused items
                    //   - if they're different:
                    //     - send a MouseOut event to the previous item
                    //     - send a MouseIn event to the next item
                    //   -  send a MouseMotion event to the current focused item
                },
                .scroll => |sev| {},
                .key => |key| {
                    std.log.info("key: {s}{s}{s}{s}{s}{s}{s}", .{
                        (&[_][]const u8{ "↑", "↓" })[@boolToInt(key.down)],
                        @tagName(key.key),
                        (&[_][]const u8{ "", " ⌃" })[@boolToInt(key.modifiers.ctrl)],
                        (&[_][]const u8{ "", " ⎇ " })[@boolToInt(key.modifiers.alt)],
                        (&[_][]const u8{ "", " ⇧" })[@boolToInt(key.modifiers.shift)],
                        (&[_][]const u8{ "", " ⌘" })[@boolToInt(key.modifiers.win)],
                        "",
                    });
                },
                .textcommit => |text| {
                    std.log.info("text committed: `{s}`", .{text});
                },
                .empty => {},
            }
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
    // TODO make this not recursive, there's no point to it being recursive
    pub fn internalRender(imev: *ImEvent, nodes: ?*Queue(RenderNode).Node, offset: Point, clip: Rect) ?*Queue(RenderNode).Node {
        var nodeiter = nodes;
        const cr = imev.frame.cr;
        while (nodeiter) |node| {
            const rnode: RenderNode = node.value;
            switch (rnode.value) {
                .rectangle => |rect| {
                    cr.renderRectangle(rect.bg_color, .{ .x = offset.x, .y = offset.y, .w = rect.wh.w, .h = rect.wh.h }, rect.radius);
                },
                .text => |text| {
                    cr.renderText(offset, text.layout);
                },
                .text_line => |tl| {
                    cr.renderTextLine(offset, tl.line, tl.color);
                },
                .push_offset => |place| {
                    nodeiter = imev.internalRender(node.next, .{ .x = offset.x + place.offset.x, .y = offset.y + place.offset.y }, clip);
                    continue;
                },
                .pop_offset => return node.next,
                .push_clipping_rect => |clip_rect| {
                    const content_clip = clip_rect.wh.setUL(offset).overlap(clip);
                    cr.pushClippingRect(content_clip);
                    nodeiter = imev.internalRender(node.next, offset, content_clip);
                    cr.popState();
                    continue;
                },
                .pop_clipping_rect => return node.next,
                .clickable => {},
                .scrollable => {},
                .focusable => {},
            }
            nodeiter = node.next;
        }
        return undefined; // all push and pop nodes must be matched ; once this is moved to not be recursive this will no longer be needed
    }
    pub fn endFrameRender(imev: *ImEvent, render_v: RenderResult) void {
        if (!imev.frame.should_render) unreachable;

        const soffset = imev.persistent.internal_screen_offset;
        const ir_clip = imev.persistent.screen_size.setUL(soffset);
        _ = imev.internalRender(render_v.value.start, soffset, ir_clip);

        if (imev.frame.cursor != imev.persistent.current_cursor) {
            imev.persistent.current_cursor = imev.frame.cursor;
            imev.frame.cr.setCursor(imev.frame.cursor);
        }

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
        }
        imev.persistent.interaction_isc.cleanupUnused(imev);

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

            const attrs = backend.TextAttrList.new(text_dupe);
            if (key.font_opts.underline) attrs.addRange(0, 0 + text_dupe.len, .underline);
            attrs.addRange(0, 0 + text_dupe.len, .{ .color = key.font_opts.color.getColor() });
            const layout = imev.frame.cr.layoutText(font_str.ptr, .{ .width = key.width, .left_offset = key.font_opts.left_offset }, attrs);

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

    // TODO:
    // backend.clickable(.{w, h}, callback(arena_allocated_data, CbFn));
    // and then useClickable will just be a wrapper
    // while I replace the fns
    // so useClickable will just be
    // var cs: *ClickableState = useState(ClickableState);
    // return {…}
    // and then the clickablestate key has a
    // fn that just returns the backend clickable

    /// this should assert that the resulting clickablestate is placed
    /// ideally this could be done by the language in the typesystem,
    /// but zig doesn't have a way to do that.
    fn onClickableClicked(state: *ClickablePersistentState, ev: MouseEvent) EventUsed {
        state.clicking = ev.state != .none;
        state.focus = ev.overlap or ev.state != .none;
        state.on_mouse_down = ev.state == .down;
        state.on_mouse_up = ev.state == .up;
        state.hover = ev.overlap;
        ev.imev.invalidate();
        return .used;
    }
    const ClickablePersistentState = struct {
        // reset these every frame
        on_mouse_up: bool = false,
        on_mouse_down: bool = false,

        // store these across frames
        hover: bool = false,
        clicking: bool = false,
        focus: bool = false,
    };
    pub fn useClickable(imev: *ImEvent, id_h: ID.Arg) ClickableState {
        const id = id_h.id;
        var saved_clickable_state = imev.persistent.interaction_isc.useStateDefault(id.push(@src()), ClickablePersistentState{});

        const is_mouse_up_frame = saved_clickable_state.on_mouse_up;
        saved_clickable_state.on_mouse_up = false;
        const is_mouse_down_frame = saved_clickable_state.on_mouse_down;
        saved_clickable_state.on_mouse_down = false;
        if (!saved_clickable_state.clicking and !saved_clickable_state.hover) saved_clickable_state.focus = false;

        return ClickableState{
            .key = .{ .id = id.forSrc(@src()), .cb = callback(saved_clickable_state, onClickableClicked) },
            .focused = if (saved_clickable_state.focus) ClickableState.Focused{
                .hover = saved_clickable_state.hover,
                .click = is_mouse_up_frame and saved_clickable_state.hover,
                .on_mouse_down = is_mouse_down_frame,
            } else null,
        };
    }

    pub fn useScrollable(imev: *ImEvent, id_h: ID.Arg) ScrollableState {
        const id = id_h.id.forSrc(@src());
        return ScrollableState{
            .key = .{ .id = id },
            .scrolling = if (imev.persistent.scroll_focused) |scr| if (scr.id.eql(id)) ( //
                ScrollableState.Scrolling{ .delta = scr.delta } //
            ) else null else null,
        };
    }

    pub fn useFocusable(imev: *ImEvent, id_h: ID.Arg, reason: FocusableReason) FocusableState {
        const id = id_h.id.forSrc(@src());
        const focused = if (imev.persistent.focus) |f| f.id.eql(id) else false;
        return FocusableState{
            .key = .{ .id = id, .reason = reason },
            .focused = focused,
            .show_focus_ring = focused and if (imev.persistent.focus) |f| (@enumToInt(f.reason) >= @enumToInt(FocusableReason.keyboard)) else false, // if the focus was keyboard initiated (tab key)
        };
    }

    /// call this whenever you update state that cannot be displayed properly in this frame
    /// this will set a flag suggesting to rerender immediately rather than waiting for the
    /// next event.
    pub fn invalidate(imev: *ImEvent) void {
        imev.frame.request_rerender = true;
    }

    pub fn fmt(imev: *ImEvent, comptime text: []const u8, args: anytype) [:0]const u8 {
        return std.fmt.allocPrint0(imev.arena(), text, args) catch @panic("oom");
    }
};
pub const Src = ID.Src;

pub const ClickableKey = struct {
    id: ID.Ident,
    cb: Callback(MouseEvent, EventUsed),
    pub fn node(key: ClickableKey, imev: *ImEvent, wh: WH) RenderResult {
        var ctx = imev.render();
        ctx.putRenderNode(.{ .value = .{ .clickable = .{ .id = key.id, .wh = wh, .cb = key.cb } } });
        return ctx.result();
    }
    pub fn wrap(key: ClickableKey, imev: *ImEvent, widget: Widget) Widget {
        var ctx = imev.render();

        ctx.place(key.node(imev, widget.wh), Point.origin);
        ctx.place(widget.node, Point.origin);

        return .{
            .wh = widget.wh,
            .node = ctx.result(),
        };
    }
};
pub const ClickableState = struct {
    const Focused = struct {
        hover: bool,
        click: bool,
        on_mouse_down: bool,
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
pub const FocusableKey = struct {
    id: ID.Ident,
    reason: FocusableReason,

    pub fn node(key: FocusableKey, imev: *ImEvent) RenderResult {
        var ctx = imev.render();
        ctx.putRenderNode(.{ .value = .{ .focusable = .{ .id = key.id, .focusable_by = key.reason } } });
        // when the tab key is pressed and no one eats it, advance focus (or devance shift tab)
        // if a frame is rendered but no focused item was rendered, diff with the previous item
        // and select a new focused item and rerender. repeat the process if that happens again.
        return ctx.result();
    }

    pub fn focus(key: FocusableKey, imev: *ImEvent, reason: FocusableReason) void {
        imev.frame.next_frame_focus = .{ .id = key.id, .reason = reason };
        imev.invalidate();
    }
};
const FocusableReason = enum { mouse, keyboard, screenreader };
pub const FocusableState = struct {
    key: FocusableKey,
    focused: bool,
    show_focus_ring: bool,
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

        return ctx_outer.result();
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

/// any reason this has to be like this?
/// can't you just place a widget?
pub const RenderedSpan = union(enum) {
    empty: void,
    inline_value: struct {
        widget: Widget,
    },
    multi_line: struct {
        first_line: Widget,
        middle: Widget,
        last_line: Widget,
    },
};

pub const SpanPlacer = struct {
    ctx: RenderCtx,
    current_x: f64 = 0,
    current_y: f64 = 0,
    max_width: f64,
    current_line_height: f64 = 0,
    current_line_widgets: Queue(Widget),
    // TODO baseline maybe?

    pub fn init(imev: *ImEvent, max_w: f64) SpanPlacer {
        const alloc = imev.arena();
        return .{
            .ctx = imev.render(),
            .max_width = max_w,
            .current_line_widgets = Queue(Widget){},
        };
    }

    pub fn getArgs(sp: SpanPlacer) Args {
        return .{ .width = sp.max_width, .start_offset = sp.current_x };
    }
    pub fn endLine(sp: *SpanPlacer) void {
        const alloc = sp.ctx.imev.arena();
        var ox: f64 = 0;
        while (sp.current_line_widgets.shift(alloc)) |widget| {
            sp.ctx.place(widget.node, .{ .x = ox, .y = sp.current_y });
            ox += widget.wh.w;
        }

        sp.current_x = 0;
        sp.current_y += sp.current_line_height;
        sp.current_line_height = 0;
    }
    pub fn placeInlineNoOverflow(sp: *SpanPlacer, widget: Widget) void {
        const alloc = sp.ctx.imev.arena();
        if (widget.wh.w + sp.current_x > sp.max_width and sp.current_x != 0) {
            sp.endLine();
        }
        sp.current_line_widgets.push(alloc, widget) catch @panic("oom");
        sp.current_x += widget.wh.w;
        if (widget.wh.h > sp.current_line_height) {
            sp.current_line_height = widget.wh.h;
        }
    }
    pub fn placeInline(sp: *SpanPlacer, span: Widget) void {
        return sp.place(.{ .inline_value = .{ .widget = span } });
    }
    pub fn place(sp: *SpanPlacer, span: RenderedSpan) void {
        const alloc = sp.ctx.imev.arena();
        switch (span) {
            .empty => {},
            .inline_value => |ilspan| {
                if (ilspan.widget.wh.w + sp.current_x > sp.max_width and sp.current_x != 0) {
                    sp.endLine();
                }
                sp.placeInlineNoOverflow(ilspan.widget);
            },
            .multi_line => |mlspan| {
                sp.placeInlineNoOverflow(mlspan.first_line);
                sp.endLine();
                sp.ctx.place(mlspan.middle.node, .{ .x = 0, .y = sp.current_y });
                sp.current_y += mlspan.middle.wh.h;
                sp.placeInlineNoOverflow(mlspan.last_line);
            },
        }
    }
    pub fn finish(sp: *SpanPlacer) Widget {
        sp.endLine();
        return .{ .node = sp.ctx.result(), .wh = .{ .w = sp.max_width, .h = sp.current_y } };
    }

    pub const Args = struct { width: f64, start_offset: f64 };
};

pub const HLayoutManager = struct {
    ctx: RenderCtx,
    max_w: f64,
    gap_x: f64,
    gap_y: f64,

    x: f64 = 0,
    y: f64 = 0,
    highest_w: f64 = 0,
    overflow_widget: ?Widget = null,
    current_h: f64 = 0,

    over: bool = false,

    pub fn init(imev: *ImEvent, opts: struct { max_w: f64, gap_x: f64, gap_y: f64 }) HLayoutManager {
        return .{
            .ctx = imev.render(),
            .max_w = opts.max_w,
            .gap_x = opts.gap_x,
            .gap_y = opts.gap_y,
        };
    }
    pub fn overflow(hlm: *HLayoutManager, widget: Widget) void {
        hlm.overflow_widget = widget;
    }
    pub fn put(hlm: *HLayoutManager, widget: Widget) ?void {
        if (hlm.over) unreachable;
        if (hlm.overflow_widget) |overflow_w| {
            // TODO if (is_last), skip `- overflow.w`
            if (hlm.x + widget.wh.w > hlm.max_w - overflow_w.wh.w - hlm.gap_x) {
                hlm.ctx.place(overflow_w.node, .{ .x = hlm.x, .y = hlm.y });
                if (overflow_w.wh.h > hlm.current_h) hlm.current_h = overflow_w.wh.h;
                hlm.over = true;
                return null;
            }
        } else if (hlm.x > 0 and hlm.x + widget.wh.w > hlm.max_w) {
            hlm.y += hlm.current_h + hlm.gap_y;
            hlm.current_h = 0;
            if (hlm.highest_w < hlm.x - hlm.gap_x) hlm.highest_w = hlm.x - hlm.gap_x;
            hlm.x = 0;
        }
        hlm.ctx.place(widget.node, .{ .x = hlm.x, .y = hlm.y });
        if (widget.wh.h > hlm.current_h) hlm.current_h = widget.wh.h;
        hlm.x += widget.wh.w + hlm.gap_x;
        return {};
    }
    pub fn build(hlm: *HLayoutManager) VLayoutManager.Child {
        return VLayoutManager.Child{
            .h = hlm.current_h + hlm.y + if (hlm.current_h == 0) 0 else -hlm.gap_y,
            .node = hlm.ctx.result(),
        };
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

    if (false) {
        // debug stuff

        ctx.place(primitives.rect(imev, .{ .w = 25, .h = 25 }, .{ .bg = .red }), imev.persistent.mouse_position);
    }

    return ctx.result();
}

pub fn renderFrame(cr: backend.Context, rr: backend.RerenderRequest, data: ExecData) void {
    var timer = std.time.Timer.start() catch @panic("bad timer");
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

    const timer_end = timer.lap();
    // std.log.info("Rerender x{} in {}ns", .{ render_count, timer_end });

    imev.endFrameRender(renderBaseRoot(id, imev, root_state_cache, imev.persistent.screen_size, data));
    id.deinit();
    root_state_cache.cleanupUnused(imev);

    if (imev.frame.request_rerender) {
        rr.queueDraw();
    }

    // std.log.info("Draw in        {}ns", .{timer.read()});
}
pub fn pushEvent(ev: RawEvent, rr: backend.RerenderRequest, data: ExecData) void {
    const imev = data.imev;

    // why can't a frame be run here?
    // can't a frame be run just with render set to false?
    // or even with render set to true, just tell it to render the returned root
    // at the start of next frame rather than calling the fn thing
    // anyway probably not necessary but there may be some events where it's useful

    const req_rr = imev.addEvent(ev) catch @panic("oom");
    if (req_rr) rr.queueDraw();
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
