const std = @import("std");
const cairo = @import("cairo.zig");
const generic = @import("generic.zig");

fn range(max: usize) []const void {
    return @as([]const void, &[_]void{}).ptr[0..max];
}

pub const Color = struct {
    r: f64,
    g: f64,
    b: f64,
    a: f64 = 1,
    pub fn hex(v: u24) Color {
        const r = (v & 0xFF0000) >> 16;
        const g = (v & 0x00FF00) >> 8;
        const b = (v & 0x0000FF) >> 0;
        return Color{
            .r = @intToFloat(f64, r) / 0xFF,
            .g = @intToFloat(f64, g) / 0xFF,
            .b = @intToFloat(f64, b) / 0xFF,
        };
    }
};
pub const RenderNode = struct { value: union(enum) {
    unfilled: void, // TODO store some debug info here
    rectangle: struct {
        rect: Rect,
        radius: f64,
        bg_color: Color,
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
    white, // #fff
    pub fn getColor(col: ThemeColor) Color {
        return switch (col) {
            .black => Color.hex(0x000000),
            .gray100 => Color.hex(0x131516),
            .gray200 => Color.hex(0x181a1b),
            .white => Color.hex(0xFFFFFF),
        };
    }
};

const FutureRender = struct {
    event: *ImEvent,
    index: ?usize, // if null, no actual rendering is happening so who cares
    pub fn setRenderNode(fr: FutureRender, render_node: RenderNode) void {
        const index = fr.index orelse return;
        if (fr.event.render_nodes.items[index].value != .unfilled) unreachable; // render node cannot be set twice
        fr.event.render_nodes.items[index] = render_node;
    }
    const RectOpts = struct {
        rounded: RoundedStyle = .none,
        bg: ThemeColor,
    };
    pub fn rect(fr: FutureRender, opts: RectOpts, area: Rect) void {
        fr.setRenderNode(RenderNode{ .value = .{ .rectangle = .{
            .rect = area,
            .radius = opts.rounded.getPx(),
            .bg_color = opts.bg.getColor(),
        } } });
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
const Rect = struct {
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
};
const WH = struct {
    w: f64,
    h: f64,
    // should this be float or int?
};
const ImEvent = struct { // pinned?
    unprocessed_events: Queue(cairo.RawEvent),
    render_nodes: std.ArrayList(RenderNode),
    pass: bool,
    should_render: bool,
    should_continue: bool,
    real_allocator: *std.mem.Allocator,
    arena_allocator: std.heap.ArenaAllocator,

    screen_size: Rect,

    cr: cairo.Context,
    // maybe split this out into values which are retained across frames and values which are not
    // to make init and startFrame easier

    pub fn arena(imev: *ImEvent) *std.mem.Allocator {
        return &imev.arena_allocator.allocator;
    }

    pub fn init(alloc: *std.mem.Allocator) ImEvent {
        return .{
            .unprocessed_events = Queue(cairo.RawEvent){},
            .render_nodes = undefined,
            .pass = undefined,
            .should_render = undefined,
            .real_allocator = alloc,
            .arena_allocator = undefined,
            .cr = undefined,
            .screen_size = .{ .x = 0, .y = 0, .w = 0, .h = 0 },
            .should_continue = undefined,
        };
    }
    pub fn deinit(imev: *ImEvent) void {
        while (imev.unprocessed_events.pop(imev.real_allocator)) |_| {}
    }
    pub fn addEvent(imev: *ImEvent, event: cairo.RawEvent) !void {
        // could use an arena allocator, unfortunately arena allocators are created at frame start
        // rather than on init 🙲 frame end.
        try imev.unprocessed_events.push(imev.real_allocator, event);
    }
    pub fn startFrame(imev: *ImEvent, cr: cairo.Context, should_render: bool) !void {
        const event = imev.unprocessed_events.pop(imev.real_allocator);

        imev.arena_allocator = std.heap.ArenaAllocator.init(imev.real_allocator);
        imev.* = .{
            .unprocessed_events = imev.unprocessed_events,
            .render_nodes = std.ArrayList(RenderNode).init(imev.arena()),
            .pass = true,
            .should_render = should_render,

            .real_allocator = imev.real_allocator,
            .arena_allocator = imev.arena_allocator,
            .cr = cr,
            .should_continue = event != null,

            .screen_size = imev.screen_size,
            // .real_allocator =
        };
        if (event) |ev| switch (ev) {
            .resize => |rsz| {
                imev.screen_size = .{
                    .x = @intToFloat(f64, rsz.x),
                    .y = @intToFloat(f64, rsz.y),
                    .w = @intToFloat(f64, rsz.w),
                    .h = @intToFloat(f64, rsz.h),
                };
            },
            else => {},
        };
    }
    pub fn endFrame(imev: *ImEvent) bool {
        if (!imev.pass) @panic("OOM while rendering");
        if (imev.should_render) {
            for (imev.render_nodes.items) |render_node| {
                imev.cr.renderNode(render_node);
            }
        }

        imev.arena_allocator.deinit();

        return !imev.should_continue; // rendering is over, do not execute more frames this frame
    }

    pub fn render(imev: *ImEvent) FutureRender {
        if (!imev.should_render) return .{ .event = imev, .index = null };
        return renderMayError(imev) catch |e| {
            imev.pass = false;
            imev.should_render = false;
            return .{ .event = imev, .index = null };
        }; // this is where that one zig proposal would be useful
    }
    pub fn renderMayError(imev: *ImEvent) !FutureRender {
        const index = imev.render_nodes.items.len;
        try imev.render_nodes.append(.{ .value = .unfilled });
        return FutureRender{ .event = imev, .index = index };
    }
};

const VLayoutManager = struct {
    top_rect: struct {
        x: f64,
        y: f64,
        w: f64,
    },
    uncommitted_gap: f64,
    pub fn fromRect(rect: Rect) VLayoutManager {
        return VLayoutManager{
            .top_rect = .{
                .x = rect.x,
                .y = rect.y,
                .w = rect.w,
            },
            .uncommitted_gap = 0,
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
            .uncommitted_gap = 0,
        };
    }
    pub fn take(lm: *VLayoutManager, opts: struct { h: f64, gap: f64 }) Rect {
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
};

fn renderApp(imev: *ImEvent, area: Rect) void {
    // next step is figuring out:
    // how consistent ids will work
    // +
    // text rendering (req. consistent IDs to cache text)
    // alternatively, text can be a global cache for now
    // a global cache is probably better anyway

    // or: make some rect helper fns now
    // so:
    // allow me to recreate the layout of threadreader easily and start putting some content in

    // also:
    // do some tailwind-like stuff
    // eg bg_color: color-gray-500 (like that)
    // and that allows for automatic dark/light modes and stuff

    imev.render().rect(.{ .bg = .gray100 }, area);

    const fullscreen = area.inset(20);

    const sidebar_width = 300;
    const cutoff = 1000;

    var layout = VLayoutManager.fromRect(fullscreen);

    if (area.w > 1000) {
        var sidebar = layout.cutRight(.{ .w = sidebar_width, .gap = 20 });

        imev.render().rect(.{ .rounded = .md, .bg = .gray200 }, sidebar.take(.{ .h = 244, .gap = 10 }));
        imev.render().rect(.{ .rounded = .md, .bg = .gray200 }, sidebar.take(.{ .h = 66, .gap = 10 }));
        imev.render().rect(.{ .rounded = .md, .bg = .gray200 }, sidebar.take(.{ .h = 172, .gap = 10 }));
        imev.render().rect(.{ .rounded = .md, .bg = .gray200 }, sidebar.take(.{ .h = 332, .gap = 10 }));
        imev.render().rect(.{ .rounded = .md, .bg = .gray200 }, sidebar.take(.{ .h = 128, .gap = 10 }));
        imev.render().rect(.{ .rounded = .md, .bg = .gray200 }, sidebar.take(.{ .h = 356, .gap = 10 }));
    }

    for (range(20)) |_| {
        imev.render().rect(.{ .rounded = .md, .bg = .gray200 }, layout.take(.{ .h = 92, .gap = 10 }));
    }
}

var content: generic.Page = undefined;
var global_imevent: ImEvent = undefined;
pub fn renderFrame(cr: cairo.Context) void {
    const imev = &global_imevent;

    while (true) {
        imev.startFrame(cr, false) catch @panic("Start frame error");
        renderApp(imev, imev.screen_size);
        if (imev.endFrame()) break;
    }

    imev.startFrame(cr, true) catch @panic("Start frame error");
    renderApp(imev, imev.screen_size);
    if (!imev.endFrame()) unreachable; // a render that was just complete is now incomplete. error.
}
pub fn pushEvent(ev: cairo.RawEvent) void {
    const imev = &global_imevent;

    imev.addEvent(ev) catch @panic("oom");

    // switch (ev) {
    //     .render => |cr| {
    //         roundedRectangle(cr, 10, 10, 80, 80, 10);
    //         cairo_set_source_rgb(cr, 0.5, 0.5, 1);
    //         cairo_fill(cr);

    //         const text = "Cairo Test. 🙋→⎋ يونيكود.\n";
    //         const font = "Monospace 12";

    //         if (layout == null) {
    //             layout = pango_cairo_create_layout(cr); // ?*PangoLayout, g_object_unref(layout)

    //             pango_layout_set_text(layout, text, -1);
    //             {
    //                 const description = pango_font_description_from_string(font);
    //                 defer pango_font_description_free(description);
    //                 pango_layout_set_font_description(layout, description);
    //             }
    //         }

    //         cairo_save(cr);
    //         cairo_move_to(cr, 50, 150);
    //         pango_cairo_show_layout(cr, layout);
    //         cairo_restore(cr);
    //     },
    //     .keypress => |kp| {
    //         std.debug.warn("Key↓: {}\n", .{kp.keyval});
    //         // these will call the render fn, but with a void value
    //     },
    //     .keyrelease => |kp| {
    //         std.debug.warn("Key↑: {}\n", .{kp.keyval});
    //     },
    //     .textcommit => |str| {
    //         std.debug.warn("On commit event `{s}`\n", .{str});
    //     },
    // }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const alloc = &gpa.allocator;

    content = generic.sample;
    global_imevent = ImEvent.init(alloc);
    defer global_imevent.deinit();

    try cairo.start();
}
