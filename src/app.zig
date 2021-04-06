const ui = @import("main.zig");
const ImEvent = ui.ImEvent;
const WH = ui.WH;
const Point = ui.Point;
const Rect = ui.Rect;
const primitives = ui.primitives;
const RenderResult = ui.RenderResult;
const VLayoutManager = ui.VLayoutManager;
const RoundedStyle = ui.RoundedStyle;
const range = ui.range;
const generic = @import("generic.zig");

// RenderResult : when both W and H are specified to the function you're calling
// VLayoutManager.Child : when only W is specified to the function you're calling
// HLayoutManager.Child : when only H is specified to the function you're calling

fn renderSidebarWidget(imev: *ImEvent, width: f64, node: generic.SidebarNode) VLayoutManager.Child {
    var ctx = imev.render();

    switch (node) {
        .sample => |sample| {
            var layout = VLayoutManager.fromWidth(width);
            layout.inset(10);

            layout.place(&ctx, .{ .gap = 8 }, primitives.textV(imev, layout.top_rect.w, .{ .weight = .bold, .color = .gray500, .size = .base }, sample.title));
            layout.place(&ctx, .{ .gap = 8 }, primitives.textV(imev, layout.top_rect.w, .{ .color = .white, .size = .sm }, sample.body));

            return layout.result(&ctx);
        },
    }
}

fn renderPost(imev: *ImEvent, width: f64, node: generic.Post) VLayoutManager.Child {
    var ctx = imev.render();

    var layout = VLayoutManager.fromWidth(width);

    layout.place(&ctx, .{ .gap = 0 }, primitives.textV(imev, layout.top_rect.w, .{ .color = .white, .size = .base }, node.title));
    // now need a horizontal layout manager for this info bar
    // then another for action buttons

    return layout.result(&ctx);
}

fn renderContextNode(imev: *ImEvent, width: f64, node: generic.PostContext) VLayoutManager.Child {
    var ctx = imev.render();

    var layout = VLayoutManager.fromWidth(width);
    layout.inset(10);

    for (node.parents) |post| {
        layout.place(&ctx, .{ .gap = 8 }, renderPost(imev, layout.top_rect.w, post));
    }

    return layout.result(&ctx);
}

pub fn renderApp(imev: *ImEvent, wh: WH) RenderResult {
    const page = generic.sample;
    var ctx = imev.render();

    ctx.place(primitives.rect(imev, wh, .{ .bg = .gray100 }), Point{ .x = 0, .y = 0 });

    const sidebar_width = 300;
    const cutoff = 1000;
    const mobile_cutoff = 600;

    var layout = VLayoutManager.fromWidth(wh.w);
    if (wh.w > mobile_cutoff) layout.inset(20) //
    else layout.insetY(20);

    switch (page.display_mode) {
        .fullscreen => {},
        .centered => {
            layout.maxWidth(1200, .center);
        },
    }

    if (wh.w > 1000) {
        var sidebar = layout.cutRight(.{ .w = sidebar_width, .gap = 20 });

        for (page.sidebar) |sidebar_node| {
            const sidebar_widget = renderSidebarWidget(imev, sidebar.top_rect.w, sidebar_node);

            const placement_rect = sidebar.take(.{ .h = sidebar_widget.h, .gap = 10 });
            ctx.place(primitives.rect(imev, placement_rect.wh(), .{ .rounded = .md, .bg = .gray200 }), placement_rect.ul());
            ctx.place(sidebar_widget.node, placement_rect.ul());
        }

        for ([_]f64{ 244, 66, 172, 332, 128, 356 }) |height| {
            const placement_rect = sidebar.take(.{ .h = height, .gap = 10 });
            ctx.place(primitives.rect(imev, placement_rect.wh(), .{ .rounded = .md, .bg = .gray200 }), placement_rect.ul());
        }
    }

    const rounding: RoundedStyle = if (wh.w > mobile_cutoff) .md else .none;
    for (page.content) |context_node| {
        const box = imev.render();
        const context_widget = renderContextNode(imev, layout.top_rect.w, context_node);

        const placement_rect = layout.take(.{ .h = context_widget.h, .gap = 10 });
        ctx.place(primitives.rect(imev, placement_rect.wh(), .{ .rounded = rounding, .bg = .gray200 }), placement_rect.ul());
        ctx.place(context_widget.node, placement_rect.ul());
    }
    for (range(20)) |_| {
        const placement_rect = layout.take(.{ .h = 92, .gap = 10 });
        ctx.place(primitives.rect(imev, placement_rect.wh(), .{ .rounded = .md, .bg = .gray200 }), placement_rect.ul());
    }

    return ctx.result();
}
