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
    a: f64,
};
pub const RenderNode = struct { value: union(enum) {
    unfilled: void, // TODO store some debug info here
    rectangle: struct {
        rect: Rect,
        radius: f64,
        bg_color: Color,
    },
} };
const FutureRender = struct {
    event: *ImEvent,
    index: ?usize, // if null, no actual rendering is happening so who cares
    pub fn setRenderNode(fr: FutureRender, render_node: RenderNode) void {
        const index = fr.index orelse return;
        if (fr.event.render_nodes.items[index].value != .unfilled) unreachable; // render node cannot be set twice
        fr.event.render_nodes.items[index] = render_node;
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

    const fullscreen = area.inset(10);
    imev.render().setRenderNode(.{
        .value = .{
            .rectangle = .{
                .rect = fullscreen,
                .radius = 6,
                .bg_color = Color{ .r = 0.8, .g = 0.5, .b = 0.5, .a = 1 },
            },
        },
    });
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
