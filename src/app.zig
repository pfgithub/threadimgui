const ui = @import("imgui");
const ImEvent = ui.ImEvent;
const WH = ui.WH;
const Point = ui.Point;
const Rect = ui.Rect;
const primitives = ui.primitives;
const RenderResult = ui.RenderResult;
const VLayoutManager = ui.VLayoutManager;
const RoundedStyle = ui.RoundedStyle;
const Widget = ui.Widget;
const RenderCtx = ui.RenderCtx;
const range = ui.range;
const Src = ui.Src;
const IdStateCache = ui.IdStateCache;
const generic = @import("generic.zig");

// RenderResult : when both W and H are specified to the function you're calling
// VLayoutManager.Child : when only W is specified to the function you're calling
// HLayoutManager.Child : when only H is specified to the function you're calling

fn renderSidebarWidget(src: Src, imev: *ImEvent, isc: *IdStateCache, width: f64, node: generic.SidebarNode) VLayoutManager.Child {
    var ctx = imev.render(src);
    defer ctx.pop();

    switch (node) {
        .sample => |sample| {
            var layout = VLayoutManager.fromWidth(width);
            layout.inset(10);

            layout.place(&ctx, .{ .gap = 8 }, primitives.textV(@src(), imev, layout.top_rect.w, .{ .weight = .bold, .color = .gray500, .size = .base }, sample.title));
            layout.place(&ctx, .{ .gap = 8 }, primitives.textV(@src(), imev, layout.top_rect.w, .{ .color = .white, .size = .sm }, sample.body));

            return layout.result(&ctx);
        },
    }
}

fn inset(src: Src, imev: *ImEvent, inset_v: f64, widget: Widget) Widget {
    var ctx = imev.render(src);
    defer ctx.pop();

    ctx.place(widget.node, .{ .x = inset_v, .y = inset_v });
    return .{
        .wh = .{ .w = inset_v * 2 + widget.wh.w, .h = inset_v * 2 + widget.wh.h },
        .node = ctx.result(),
    };
}
fn vinset(src: Src, imev: *ImEvent, inset_v: f64, widget: VLayoutManager.Child) VLayoutManager.Child {
    var ctx = imev.render(src);
    defer ctx.pop();

    ctx.place(widget.node, .{ .x = 0, .y = inset_v });
    return .{
        .h = inset_v * 2 + widget.h,
        .node = ctx.result(),
    };
}
fn renderAction(src: Src, imev: *ImEvent, isc: *IdStateCache, action: generic.Action) Widget {
    var ctx = imev.render(src);
    defer ctx.pop();

    // gray-700: rgba(55, 65, 81)

    // bind click_state;
    // <Stacked [
    //     <if click_state : [
    //         <Rect rounded=.sm color=.gray-700 []>
    //     ]>
    //     <Inset 1rem <Stacked [
    //         <Text sm [action.text]>
    //     ]>
    //     <Clickable [&click_state]>
    // ]>
    const text = primitives.text(@src(), imev, .{ .size = .sm, .color = .white }, action.text);

    const insetv = inset(@src(), imev, 4, text);
    const clickable = imev.clickable(@src());

    if (clickable.focused) |mstate| {
        if (mstate.hover) {
            ctx.place(primitives.rect(@src(), imev, insetv.wh, .{ .bg = .gray700, .rounded = .sm }), Point.origin);
            mstate.setCursor(imev, .pointer);
        }
    }
    ctx.place(insetv.node, Point.origin);
    ctx.place(clickable.key.node(imev, insetv.wh), Point.origin);

    return .{
        .wh = insetv.wh,
        .node = ctx.result(),
    };
}
fn renderExtraActionsMenu(src: Src, imev: *ImEvent, isc: *IdStateCache, actions: []const generic.Action) Widget {
    var ctx = imev.render(src);
    defer ctx.pop();

    const text = primitives.text(@src(), imev, .{ .size = .sm, .color = .white }, "…");
    return inset(@src(), imev, 4, text);
}

const HLayoutManager = struct {
    ctx: RenderCtx,
    max_w: f64,
    gap_x: f64,
    gap_y: f64,

    x: f64 = 0,
    y: f64 = 0,
    overflow_widget: ?Widget = null,
    current_h: f64 = 0,

    over: bool = false,

    pub fn init(imev: *ImEvent, opts: struct { max_w: f64, gap_x: f64, gap_y: f64 }) HLayoutManager {
        return .{
            .ctx = imev.renderNoSrc(),
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

pub const ButtonKey = struct {
    hover: bool,
    clicked: bool,
    key: ui.ClickableState,
    pub fn render(key: ButtonKey, src: Src, imev: *ImEvent, text: []const u8) Widget {
        var ctx = imev.render(src);
        defer ctx.pop();

        const btn_widget = inset(@src(), imev, 4, primitives.text(@src(), imev, .{ .size = .sm, .color = .white }, text));

        if (key.key.focused) |mfocus| {
            if (mfocus.hover) {
                ctx.place(primitives.rect(@src(), imev, btn_widget.wh, .{ .bg = .gray700, .rounded = .sm }), Point.origin);
                mfocus.setCursor(imev, .pointer);
            }
        }
        ctx.place(key.key.key.node(imev, btn_widget.wh), Point.origin);
        ctx.place(btn_widget.node, Point.origin);

        return .{ .node = ctx.result(), .wh = btn_widget.wh };
    }
};

fn useButton(src: Src, imev: *ImEvent) ButtonKey {
    const pop = imev.frame.id.pushFunction(src);
    defer pop.pop();

    const clicked_state = imev.clickable(@src());
    return .{
        .hover = if (clicked_state.focused) |fxd| fxd.hover else false,
        .clicked = if (clicked_state.focused) |fxd| fxd.click else false,
        .key = clicked_state,
    };
}

const RenderedSpan = union(enum) {
    one_line: struct {
        widget: Widget,
    },
    multi_line: struct {
        first_line: Widget,
        middle: Widget,
        last_line: Widget,
    },
};

fn renderRichtextSpan(src: Src, imev: *ImEvent, isc: *IdStateCache, span: generic.RichtextSpan, width: f64, start_offset: f64) RenderedSpan {
    //
}

fn renderRichtextParagraph(src: Src, imev: *ImEvent, isc: *IdStateCache, paragraph: generic.RichtextParagraph, width: f64) VLayoutManager.Child {
    switch (paragraph) {
        .paragraph => |par| {
            // render the richtext spans, a bit complicated
        },
        .unsupported => |unsup_msg| {},
    }
}

fn renderBody(src: Src, imev: *ImEvent, isc: *IdStateCache, body: generic.Body, width: f64) VLayoutManager.Child {
    var ctx = imev.render(src);
    defer ctx.pop();

    var layout = VLayoutManager.fromWidth(width);

    switch (body) {
        .none => {},
        .array => |array| {
            for (array) |array_item| {
                if (array_item == .none) continue;
                layout.place(&ctx, .{ .gap = 4 }, renderBody(src, imev, isc, array_item, width));
            }
        },
        .richtext => {
            layout.place(&ctx, .{ .gap = 4 }, primitives.textV(@src(), imev, layout.top_rect.w, .{ .color = .red, .size = .sm }, "TODO richtext"));
        },
        .unsupported => |name| {
            layout.place(&ctx, .{ .gap = 4 }, primitives.textV(@src(), imev, layout.top_rect.w, .{ .color = .red, .size = .sm }, name));
        },
    }

    return layout.result(&ctx);
}

const PostState = struct {
    display_body: bool,
    pub fn init() PostState {
        return .{
            .display_body = false,
        };
    }
};

fn renderPost(src: Src, imev: *ImEvent, isc: *IdStateCache, width: f64, node: generic.Post) VLayoutManager.Child {
    var ctx = imev.render(src);
    defer ctx.pop();

    const state = isc.useState(@src(), imev, PostState, PostState.init); // |_| .{.display_body = node.default_open}

    var layout = VLayoutManager.fromWidth(width);

    if (node.title) |title| layout.place(&ctx, .{ .gap = 0 }, primitives.textV(@src(), imev, layout.top_rect.w, .{ .color = .white, .size = .base }, title));
    {
        var actions_lm = HLayoutManager.init(imev, .{ .max_w = layout.top_rect.w, .gap_x = 8, .gap_y = 0 });

        const btn_key = useButton(@src(), imev);
        actions_lm.put(btn_key.render(@src(), imev, if (state.display_body) "Hide" else "Show")) orelse unreachable;
        if (btn_key.clicked) {
            state.display_body = !state.display_body;
        }

        actions_lm.overflow(renderExtraActionsMenu(@src(), imev, isc, node.actions));
        for (node.actions) |action, i| {
            const k = imev.frame.id.pushIndex(@src(), i);
            defer k.pop();
            actions_lm.put(renderAction(@src(), imev, isc, action)) orelse break;
        }
        layout.place(&ctx, .{ .gap = 0 }, actions_lm.build());
    }

    if (state.display_body and node.body != .none) {
        layout.place(&ctx, .{ .gap = 0 }, vinset(@src(), imev, 4, renderBody(@src(), imev, isc, node.body, layout.top_rect.w)));
    }

    return layout.result(&ctx);
}

fn renderContextNode(src: Src, imev: *ImEvent, isc: *IdStateCache, width: f64, node: generic.PostContext) VLayoutManager.Child {
    var ctx = imev.render(src);
    defer ctx.pop();

    var layout = VLayoutManager.fromWidth(width);
    layout.inset(10);

    for (node.parents) |post| {
        layout.place(&ctx, .{ .gap = 8 }, renderPost(@src(), imev, isc, layout.top_rect.w, post));
    }

    return layout.result(&ctx);
}

pub fn topLevelContainer(src: Src, imev: *ImEvent, width: f64, child: VLayoutManager.Child, opts: struct { rounded: bool }) VLayoutManager.Child {
    // return rectEncapsulating(rounding, .bg = .gray200,
    //    child
    // )
    var ctx = imev.render(src);
    defer ctx.pop();

    const rounding: RoundedStyle = if (opts.rounded) .md else .none;

    ctx.place(primitives.rect(@src(), imev, .{ .w = width, .h = child.h }, .{ .rounded = rounding, .bg = .gray200 }), Point.origin);
    ctx.place(child.node, Point.origin);

    return VLayoutManager.Child{
        .node = ctx.result(),
        .h = child.h,
    };
}

// this is the state for a single navigation entry
// the reason for not storing this in the element tree is because in the element tree it will be lost on:
// - scrolling too far (nodes are virtual)
// - navigating away (the entire page is no longer rendered anymore so any saved data will be dropped)
// some things can be stored in the element tree:
// - transitions. I'll make an imev.transition(@src(), current, 100, .easeinout)
// : (src: Src, current: f64, duration: u64, easing: Easing): f64
pub const AppState = struct {
    scroll: f64, // TODO this will store the current top node (body and sidebar) and the scroll offset of that node
    // once virtual scrolling is implemented, this will have to storee off-screen IdStateCaches
    // also, eventually virtual scrolling will have to work on : comment trees and : context nodes
    // so basically this will have to do all the context node rendering
    pub fn init() AppState {
        return AppState{ .scroll = 0 };
    }
};

pub fn renderApp(src: Src, imev: *ImEvent, isc: *IdStateCache, wh: WH, page: generic.Page) RenderResult {
    var ctx = imev.render(src);
    defer ctx.pop();

    const state = isc.useState(@src(), imev, AppState, AppState.init); // |_| AppState.init()

    ctx.place(primitives.rect(@src(), imev, wh, .{ .bg = .gray100 }), Point.origin);

    const sidebar_width = 300;
    const cutoff = 1000;
    const mobile_cutoff = 600;

    const scrollable = imev.scrollable(@src());
    ctx.place(scrollable.key.node(imev, wh), Point.origin);

    if (scrollable.scrolling) |scrolling| {
        state.scroll += scrolling.delta.y;
    }
    if (state.scroll <= 0) {
        state.scroll = 0;
    }
    // TODO based on the maximum rendered height of all the items, limit the vertical scroll

    var layout = VLayoutManager.fromWidth(wh.w);
    if (wh.w > mobile_cutoff) layout.inset(20) //
    else layout.insetY(20);

    layout.top_rect.y -= state.scroll;

    switch (page.display_mode) {
        .fullscreen => {},
        .centered => {
            layout.maxWidth(1200, .center);
        },
    }

    if (wh.w > 1000) {
        var sidebar = layout.cutRight(.{ .w = sidebar_width, .gap = 20 });

        for (page.sidebar) |sidebar_node, i| {
            const v = imev.frame.id.pushIndex(@src(), i); // TODO once virtual scrolling is added this will have to no longer be pushIndex
            defer v.pop();

            const sidebar_widget = renderSidebarWidget(@src(), imev, isc, sidebar.top_rect.w, sidebar_node);

            sidebar.place(&ctx, .{ .gap = 10 }, topLevelContainer(@src(), imev, sidebar.top_rect.w, sidebar_widget, .{ .rounded = true }));
        }

        // for ([_]f64{ 244, 66, 172, 332, 128, 356 }) |height, i| {
        //     const v = imev.frame.id.pushIndex(@src(), i);
        //     defer v.pop();

        //     sidebar.place(&ctx, .{ .gap = 10 }, topLevelContainer(@src(), imev, sidebar.top_rect.w, VLayoutManager.Child{ .h = height, .node = null }, .{ .rounded = true }));
        // }
    }

    const rounded = wh.w > mobile_cutoff;
    switch (page.body) {
        .listing => |listing| {
            for (listing.items) |context_node, i| {
                const v = imev.frame.id.pushIndex(@src(), i); // TODO once virtual scrolling is added this will have to no longer be pushIndex
                defer v.pop();

                const context_widget = renderContextNode(@src(), imev, isc, layout.top_rect.w, context_node);

                layout.place(&ctx, .{ .gap = 10 }, topLevelContainer(@src(), imev, layout.top_rect.w, context_widget, .{ .rounded = rounded }));
            }
        },
    }
    // for (range(20)) |_, i| {
    //     const v = imev.frame.id.pushIndex(@src(), i);
    //     defer v.pop();

    //     layout.place(&ctx, .{ .gap = 10 }, topLevelContainer(@src(), imev, layout.top_rect.w, VLayoutManager.Child{ .h = 92, .node = null }, .{ .rounded = rounded }));
    // }

    return ctx.result();
}

pub fn renderRoot(src: Src, imev: *ImEvent, isc: *IdStateCache, wh: WH, content: generic.Page) RenderResult {
    return renderApp(src, imev, isc, wh, content);
}
