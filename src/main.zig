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
        x: f64,
        y: f64,
        w: f64,
        h: f64,
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
const ImEvent = struct { // pinned?
    render_nodes: std.ArrayList(RenderNode), // might be better as a linked list [n]RenderNode eg for example. this is fine for now though
    pass: bool,
    should_render: bool,
    real_allocator: *std.mem.Allocator,
    arena_allocator: std.heap.ArenaAllocator,
    cr: cairo.Context,

    pub fn arena(imev: *ImEvent) *std.mem.Allocator {
        return &imev.arena_allocator.allocator;
    }

    pub fn init(alloc: *std.mem.Allocator) ImEvent {
        return .{
            .render_nodes = undefined,
            .pass = undefined,
            .should_render = undefined,
            .real_allocator = alloc,
            .arena_allocator = undefined,
            .cr = undefined,
        };
    }
    pub fn addEvent(imev: *ImEvent, event: cairo.RawEvent) void {
        // TODO add this event to be processed at the start of next render frame
    }
    pub fn startFrame(imev: *ImEvent, cr: cairo.Context, should_render: bool) !void {
        imev.arena_allocator = std.heap.ArenaAllocator.init(imev.real_allocator);
        imev.* = .{
            .render_nodes = std.ArrayList(RenderNode).init(imev.arena()),
            .pass = true,
            .should_render = should_render,

            .real_allocator = imev.real_allocator,
            .arena_allocator = imev.arena_allocator,
            .cr = cr,
            // .real_allocator =
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

        return true; // rendering is over, do not execute more frames this frame
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

fn renderApp(imev: *ImEvent) void {
    imev.render().setRenderNode(.{
        .value = .{
            .rectangle = .{
                .x = 12,
                .y = 15,
                .w = 50,
                .h = 60,
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
        renderApp(imev);
        if (imev.endFrame()) break;
    }

    imev.startFrame(cr, true) catch @panic("Start frame error");
    renderApp(imev);
    if (!imev.endFrame()) unreachable; // a render that was just complete is now incomplete. error.
}
pub fn pushEvent(ev: cairo.RawEvent) void {
    const imev = &global_imevent;

    imev.addEvent(ev);

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

    try cairo.start();
}
