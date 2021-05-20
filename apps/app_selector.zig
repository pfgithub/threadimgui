// thing that has like a sidebar and lets you pick which app to run
// also an x button to clear the isc for the app

const std = @import("std");
const im = @import("imgui");

pub usingnamespace im.StartBackend;

const ActiveTab = enum {
    demo,
    widgets,
    threadimgui,
    pub fn item(at: ActiveTab) SidebarItem {
        return switch (at) {
            .demo => .{
                .title = "Demo",
                .desc = "A hello world demo",
            },
            .widgets => .{
                .title = "Widgets",
                .desc = "Demonstrate the builtin widgets",
            },
            .threadimgui => .{
                .title = "ThreadReader",
                .desc = "An implementation of ThreadReader in zimgui",
            },
        };
    }
};

pub const Axis = enum {
    horizontal,
    vertical,
    pub fn x(axis: Axis) []const u8 {
        return switch (axis) {
            .horizontal => "x",
            .vertical => "y",
        };
    }
    pub fn w(axis: Axis) []const u8 {
        return switch (axis) {
            .horizontal => "w",
            .vertical => "h",
        };
    }
};

fn inset(imev: *im.ImEvent, inset_v: f64, widget: im.Widget) im.Widget {
    var ctx = imev.render();

    ctx.place(widget.node, .{ .x = inset_v, .y = inset_v });
    return .{
        .wh = .{ .w = inset_v * 2 + widget.wh.w, .h = inset_v * 2 + widget.wh.h },
        .node = ctx.result(),
    };
}
fn rectaround(imev: *im.ImEvent, rectopts: im.primitives.RectOpts, widget: im.Widget) im.Widget {
    var ctx = imev.render();

    ctx.place(im.primitives.rect(imev, widget.wh, rectopts), im.Point.origin);
    ctx.place(widget.node, im.Point.origin);

    return .{
        .wh = widget.wh,
        .node = ctx.result(),
    };
}

fn enumFields(comptime Type: type) []const Type {
    var res: []const Type = &[_]Type{};
    for (std.meta.fields(Type)) |field| {
        res = res ++ &[_]Type{@field(Type, field.name)};
    }
    return res;
}

const SidebarItem = struct {
    title: []const u8,
    desc: []const u8,
};

const SidebarRender = struct {
    width: f64,
    active_tab: *ActiveTab,
    show_sidebar: *bool,

    const items: []const ActiveTab = enumFields(ActiveTab);

    pub fn renderNode(anr: @This(), id_arg: im.ID.Arg, imev: *im.ImEvent, isc: *im.IdStateCache, node_id: u64) im.VLayoutManager.Child {
        const id = id_arg.id;
        var ctx = imev.render();

        const key = items[node_id];
        const item = key.item();

        const click_state = imev.useClickable(id.push(@src()));
        const hovering = if (click_state.focused) |f| f.hover else false;

        if (click_state.focused) |f| {
            if (f.hover) f.setCursor(imev, .pointer);
            if (f.click) {
                anr.active_tab.* = key;
                anr.show_sidebar.* = false;
                imev.invalidate();
            }
        }

        var span_placer = im.SpanPlacer.init(imev, anr.width - (8 * 2 * 2));
        // actually this should be done properly to support wrapping uuh
        // the current implementation for that is 50loc so that needs to be generalized before it can be used here
        span_placer.placeInline(im.primitives.text(imev, .{ .size = .base, .color = .white }, item.title));
        span_placer.endLine();
        span_placer.placeInline(im.primitives.text(imev, .{ .size = .sm, .color = .white }, item.desc));

        const res = inset(imev, 8, span_placer.finish());
        ctx.place(click_state.key.wrap(
            imev,
            rectaround(imev, .{ .bg = if (hovering) .gray300 else .gray200, .rounded = .sm }, res),
        ).node, .{ .x = 8, .y = 8 });

        // can even have like a heading and a short description or something
        // layout is
        // [  Title                      ]
        // [                          ×  ]
        // [                             ]
        // where × might be ⟳ instead
        // also make sure to set proper alt text for screenreaders because "multiplication sign" isn't very useful

        return .{ .h = res.wh.h + 8, .node = ctx.result() };
    }
    pub fn existsNode(anr: @This(), node_id: u64) bool {
        return node_id < items.len;
    }
    pub fn getNextNode(anr: @This(), node_id: u64) ?u64 {
        if (!existsNode(anr, node_id + 1)) return null;
        return node_id + 1;
    }
    pub fn getPreviousNode(anr: @This(), node_id: u64) ?u64 {
        if (node_id == 0) return null;
        return node_id - 1;
    }
};

pub fn renderSidebar(
    id_arg: im.ID.Arg,
    imev: *im.ImEvent,
    isc: *im.IdStateCache,
    wh: im.WH,
    active_tab: *ActiveTab,
    show_sidebar: *bool,
) im.RenderResult {
    const id = id_arg.id;
    var ctx = imev.render();

    ctx.place(im.primitives.rect(imev, wh, .{ .bg = .gray100 }), im.Point.origin);

    var y: f64 = 25; // put a "open devtools" button here or something

    const hline = renderHLine(imev, .gray300, wh.w);
    ctx.place(hline.node, .{ .x = 0, .y = y });
    y += hline.h;

    const wh_rem: im.WH = .{ .w = wh.w, .h = wh.h - y };

    const scroll_state = isc.useStateCustomInit(id.push(@src()), im.VirtualScrollHelper);
    if (!scroll_state.initialized) scroll_state.ptr.* = im.VirtualScrollHelper.init(imev.persistentAlloc(), 0);

    const scrollable = imev.useScrollable(id.push(@src()));
    ctx.place(scrollable.key.node(imev, wh), im.Point.origin);

    if (scrollable.scrolling) |scrolling| {
        scroll_state.ptr.scroll(scrolling.delta.y);
    }

    const sbo = SidebarRender{ .width = wh_rem.w, .active_tab = active_tab, .show_sidebar = show_sidebar };
    const content_render = scroll_state.ptr.render(id.push(@src()), imev, sbo, wh_rem.h, 0);
    ctx.place(content_render, .{ .x = 0, .y = y });

    // var vlayout = VLayout{ .wh = wh_rem };
    // inline for (@typeInfo(ActiveTab).Enum.fields) |field| {
    //     // /
    //     // for now just a normal vertical placer but eventually this should be switched to a scrollable vertical placer
    // }

    return ctx.result();
}

pub fn renderContent(id_arg: im.ID.Arg, imev: *im.ImEvent, isc: *im.IdStateCache, wh: im.WH, tab: ActiveTab) im.RenderResult {
    const id = id_arg.id;

    switch (tab) {
        .demo => return @import("demo/app.zig").renderRoot(id.push(@src()), imev, isc, wh, 0),
        .widgets => return @import("widgets/app.zig").renderRoot(id.push(@src()), imev, isc, wh, 0),
        .threadimgui => {
            const arena = isc.useStateCustomInit(id.push(@src()), std.heap.ArenaAllocator);
            if (!arena.initialized) arena.ptr.* = std.heap.ArenaAllocator.init(imev.persistentAlloc());

            const sample = isc.useStateCustomInit(id.push(@src()), @import("threadimgui/generic.zig").Page);
            if (!sample.initialized) sample.ptr.* = @import("threadimgui/generic.zig").initSample(&arena.ptr.allocator);

            return @import("threadimgui/app.zig").renderRoot(id.push(@src()), imev, isc, wh, sample.ptr.*);
        },
    }
}

pub fn renderNavbar(
    id_arg: im.ID.Arg,
    imev: *im.ImEvent,
    isc: *im.IdStateCache,
    width: f64,
    active_tab: ActiveTab,
    show_sidebar: *bool,
) im.VLayoutManager.Child {
    const id = id_arg.id;
    var ctx = imev.render();

    // 1: inset by 8px
    // 2: render [spacer] [text] [spacer]
    // 3: put a background rect
    // there are no good helpers for this yet

    const click_key = imev.useClickable(id.push(@src()));

    var vplacer = im.VLayoutManager.fromWidth(width);

    vplacer.inset(8);

    const text = im.primitives.text(imev, .{ .size = .base, .color = .white }, imev.fmt("{s} ▾", .{active_tab.item().title}));
    const tr = vplacer.take(.{ .gap = 4, .h = text.wh.h });

    const height = vplacer.height();

    ctx.place(im.primitives.rect(imev, .{ .w = width, .h = height }, .{ .bg = .gray100 }), im.Point.origin);

    const textpos = tr.positionCenter(text.wh);
    if (click_key.focused) |f| {
        if (f.hover) {
            f.setCursor(imev, .pointer);
            ctx.place(im.primitives.rect(imev, .{ .w = textpos.w + 8, .h = textpos.h + 8 }, .{ .bg = .gray300, .rounded = .sm }), .{ .x = textpos.x - 4, .y = textpos.y - 4 });
        }
        if (f.click) {
            show_sidebar.* = true;
            imev.invalidate();
        }
    }
    ctx.place(click_key.key.node(imev, textpos.wh()), textpos.ul());
    ctx.place(text.node, textpos.ul());

    return .{ .node = ctx.result(), .h = height };
}

pub fn renderHLine(imev: *im.ImEvent, color: im.ThemeColor, width: f64) im.VLayoutManager.Child {
    return .{ .node = im.primitives.rect(imev, .{ .w = width, .h = 1 }, .{ .bg = color }), .h = 1 };
}

pub fn renderAppSelector(id_arg: im.ID.Arg, imev: *im.ImEvent, isc: *im.IdStateCache, wh: im.WH, content: u1) im.RenderResult {
    // tabs on the left
    // tab name, x button to clear isc if the tab is open (/ refresh button if it's focused)
    const id = id_arg.id;
    var ctx = imev.render();

    // so this will have a tab view on the left and a custom navbar thing on the top framing the app window
    // wondering if I can dynamically load the apps from a so file or something
    // that'd take a bit of effort but should be doable eventually. not going to yet though.
    // actually that could be really fun - you can rebuild the project and click the refresh button and it reloads
    // as long as you didn't make any edits to the imgui structure

    // renderDemoSelector();
    // maybe find some way to say if the inspector frame is open, don't render the navbar and stuff?

    const is_mobile = wh.w < 800;

    const sidebar_id = id.push(@src());
    const sidebar_isc = isc.useISC(id.push(@src()), imev);

    const active_tab = isc.useStateDefault(id.push(@src()), ActiveTab.demo);
    const show_sidebar = isc.useStateDefault(id.push(@src()), true);

    const content_id = id.push(@src()); // needs the content enum
    const content_isc = isc.useISC(id.push(@src()), imev);
    // content isc needs to be a map from the enum => the content isc

    if (is_mobile) {
        // #useState(false) : macro to fill in isc., id.push(@src()), …
        // after setting show_sidebar, call like imev.changed() or something
        // to note that the frame shouldn't be done yet; there's more to do
        if (show_sidebar.*) {
            sidebar_isc.cleanupUnused(imev);

            ctx.place(renderSidebar(sidebar_id, imev, sidebar_isc, wh, active_tab, show_sidebar), im.Point.origin);
        } else {
            content_isc.cleanupUnused(imev);

            var y: f64 = 0;

            const navbar = renderNavbar(id.push(@src()), imev, isc, wh.w, active_tab.*, show_sidebar);
            ctx.place(navbar.node, .{ .x = 0, .y = y });
            y += navbar.h;

            const hline = renderHLine(imev, .gray300, wh.w);
            ctx.place(hline.node, .{ .x = 0, .y = y });
            y += hline.h;

            const rest = im.Rect{ .x = 0, .y = y, .w = wh.w, .h = wh.h - y };

            ctx.place(im.primitives.clippingRect(imev, rest.wh(), renderContent(content_id, imev, content_isc, rest.wh(), active_tab.*)), rest.ul());
        }
    } else {
        sidebar_isc.cleanupUnused(imev);
        content_isc.cleanupUnused(imev);

        // var hlayout = HLayout{ .wh = wh };
        // const left = hlayout.use(250); // wh is known but not ul
        // const right = hlayout.dynamic(); // neither ul nor wh are known
        // hlayout.finalize(); // wh and ul are now known for all

        const left: im.Rect = .{ .x = 0, .y = 0, .w = 249, .h = wh.h };
        const right = im.Rect{ .x = 250, .y = 0, .w = wh.w - 250, .h = wh.h };

        ctx.place(renderSidebar(sidebar_id, imev, sidebar_isc, left.wh(), active_tab, show_sidebar), left.ul());
        ctx.place(renderContent(content_id, imev, content_isc, right.wh(), active_tab.*), right.ul());
        ctx.place(im.primitives.rect(imev, .{ .w = 1, .h = wh.h }, .{ .bg = .gray300 }), .{ .x = 249, .y = 0 });
    }
    // wait I can make a full layout thing that has spacers, can't I:
    // const left = hlayout.use(250);
    // left.wh;
    // const right = hlayout.dynamic(1);
    // hlayout.finalize();
    // right.wh;

    // yeah that's doable if I want

    // ok the actual thing I need though:
    // the sidebar needs to be 250px if w≥500, else
    // there needs to be a toggle

    return ctx.result();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());
    const alloc = &gpa.allocator;

    var sample_arena = std.heap.ArenaAllocator.init(alloc);
    defer sample_arena.deinit();

    // pointer to size 0 type has no address
    // that will be fixed by one of the zig things, but until then:
    try im.runUntilExit(alloc, @as(u1, 0), renderAppSelector);
}
