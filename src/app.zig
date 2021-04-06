const ui = @import("main.zig");
const ImEvent = ui.ImEvent;
const WH = ui.WH;
const Point = ui.Point;
const Rect = ui.Rect;
const primitives = ui.primitives;
const RenderResult = ui.RenderResult;
const VLayoutManager = ui.VLayoutManager;
const RoundedStyle = ui.RoundedStyle;
const Widget = ui.Widget;
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

fn inset(imev: *ImEvent, inset_v: f64, widget: Widget) Widget {
    var ctx = imev.render();
    ctx.place(widget.node, .{ .x = inset_v, .y = inset_v });
    return .{
        .wh = .{ .w = inset_v * 2 + widget.wh.w, .h = inset_v * 2 + widget.wh.h },
        .node = ctx.result(),
    };
}
fn renderAction(imev: *ImEvent, action: generic.Action) Widget {
    var ctx = imev.render();
    // <Inset 1rem [
    //    <Text sm [action.text]>
    // ]>
    const text = primitives.text(imev, .{ .size = .sm, .color = .white }, action.text);
    return inset(imev, 4, text);
}
fn renderExtraActionsMenu(imev: *ImEvent, actions: []const generic.Action) Widget {
    var ctx = imev.render();
    const text = primitives.text(imev, .{ .size = .sm, .color = .white }, "…");
    return inset(imev, 4, text);
}

fn renderPost(imev: *ImEvent, width: f64, node: generic.Post) VLayoutManager.Child {
    var ctx = imev.render();

    var layout = VLayoutManager.fromWidth(width);

    layout.place(&ctx, .{ .gap = 0 }, primitives.textV(imev, layout.top_rect.w, .{ .color = .white, .size = .base }, node.title));
    // now need a horizontal layout manager for this info bar
    // then another for action buttons
    {
        var toprect = layout.topRect();
        var btn_x = toprect.x;
        var btn_y = toprect.y;
        var max_h: f64 = 0;

        // render "…" button, likely to be discarded
        // render all buttons
        // if button is too wide, end rendering

        const extra_actions_menu = renderExtraActionsMenu(imev, node.actions);

        for (node.actions) |action| {
            const rendered = renderAction(imev, action);

            if (btn_x + rendered.wh.w > toprect.w - extra_actions_menu.wh.w) {
                ctx.place(extra_actions_menu.node, .{ .x = btn_x, .y = btn_y });
                if (extra_actions_menu.wh.h > max_h) max_h = rendered.wh.h;
                break;
            }

            ctx.place(rendered.node, .{ .x = btn_x, .y = btn_y });
            if (rendered.wh.h > max_h) max_h = rendered.wh.h;
            btn_x += rendered.wh.w;
            btn_x += 8;
        }
        layout.use(.{ .gap = 0, .h = max_h });
    }

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

pub fn topLevelContainer(imev: *ImEvent, width: f64, child: VLayoutManager.Child, opts: struct { rounded: bool }) VLayoutManager.Child {
    // return rectEncapsulating(rounding, .bg = .gray200,
    //    child
    // )
    var ctx = imev.render();

    const rounding: RoundedStyle = if (opts.rounded) .md else .none;

    ctx.place(primitives.rect(imev, .{ .w = width, .h = child.h }, .{ .rounded = rounding, .bg = .gray200 }), Point.origin);
    ctx.place(child.node, Point.origin);

    return VLayoutManager.Child{
        .node = ctx.result(),
        .h = child.h,
    };
}

pub fn renderApp(imev: *ImEvent, wh: WH) RenderResult {
    const page = generic.sample;
    var ctx = imev.render();

    ctx.place(primitives.rect(imev, wh, .{ .bg = .gray100 }), Point.origin);

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

            sidebar.place(&ctx, .{ .gap = 10 }, topLevelContainer(imev, sidebar.top_rect.w, sidebar_widget, .{ .rounded = true }));
        }

        for ([_]f64{ 244, 66, 172, 332, 128, 356 }) |height| {
            sidebar.place(&ctx, .{ .gap = 10 }, topLevelContainer(imev, sidebar.top_rect.w, VLayoutManager.Child{ .h = height, .node = null }, .{ .rounded = true }));
        }
    }

    const rounded = wh.w > mobile_cutoff;
    for (page.content) |context_node| {
        const box = imev.render();
        const context_widget = renderContextNode(imev, layout.top_rect.w, context_node);

        layout.place(&ctx, .{ .gap = 10 }, topLevelContainer(imev, layout.top_rect.w, context_widget, .{ .rounded = rounded }));
    }
    for (range(20)) |_| {
        layout.place(&ctx, .{ .gap = 10 }, topLevelContainer(imev, layout.top_rect.w, VLayoutManager.Child{ .h = 92, .node = null }, .{ .rounded = rounded }));
    }

    return ctx.result();
}
