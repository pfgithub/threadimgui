const std = @import("std");
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
const SpanPlacer = ui.SpanPlacer;
const HLayoutManager = ui.HLayoutManager;
const RenderedSpan = ui.RenderedSpan;
const ID = ui.ID;
const generic = @import("generic.zig");

// RenderResult : when both W and H are specified to the function you're calling
// VLayoutManager.Child : when only W is specified to the function you're calling
// HLayoutManager.Child : when only H is specified to the function you're calling

fn renderSidebarWidget(id_arg: ID.Arg, imev: *ImEvent, isc: *IdStateCache, width: f64, node: generic.SidebarNode) VLayoutManager.Child {
    const id = id_arg.id;
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

fn inset(id_arg: ID.Arg, imev: *ImEvent, inset_v: f64, widget: Widget) Widget {
    const id = id_arg.id;
    var ctx = imev.render();

    ctx.place(widget.node, .{ .x = inset_v, .y = inset_v });
    return .{
        .wh = .{ .w = inset_v * 2 + widget.wh.w, .h = inset_v * 2 + widget.wh.h },
        .node = ctx.result(),
    };
}
fn vinset(id_arg: ID.Arg, imev: *ImEvent, inset_v: f64, widget: VLayoutManager.Child) VLayoutManager.Child {
    const id = id_arg.id;
    var ctx = imev.render();

    ctx.place(widget.node, .{ .x = 0, .y = inset_v });
    return .{
        .h = inset_v * 2 + widget.h,
        .node = ctx.result(),
    };
}
fn renderAction(id_arg: ID.Arg, imev: *ImEvent, isc: *IdStateCache, action: generic.Action) Widget {
    const id = id_arg.id;
    var ctx = imev.render();

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
    const text = primitives.text(imev, .{ .size = .sm, .color = .white }, action.text);

    const insetv = inset(id.push(@src()), imev, 4, text);
    const clickable = imev.useClickable(id.push(@src()));

    if (clickable.focused) |mstate| {
        if (mstate.hover) {
            ctx.place(primitives.rect(imev, insetv.wh, .{ .bg = .gray700, .rounded = .sm }), Point.origin);
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
fn renderExtraActionsMenu(id_arg: ID.Arg, imev: *ImEvent, isc: *IdStateCache, actions: []const generic.Action) Widget {
    const id = id_arg.id;
    var ctx = imev.render();

    const text = primitives.text(imev, .{ .size = .sm, .color = .white }, "…");
    return inset(id.push(@src()), imev, 4, text);
}

pub const ButtonKey = struct {
    hover: bool,
    clicked: bool,
    key: ui.ClickableState,
    pub fn render(key: ButtonKey, id_arg: ID.Arg, imev: *ImEvent, text: []const u8) Widget {
        const id = id_arg.id;
        var ctx = imev.render();

        const btn_widget = inset(id.push(@src()), imev, 4, primitives.text(imev, .{ .size = .sm, .color = .white }, text));

        if (key.key.focused) |mfocus| {
            if (mfocus.hover) {
                ctx.place(primitives.rect(imev, btn_widget.wh, .{ .bg = .gray700, .rounded = .sm }), Point.origin);
                mfocus.setCursor(imev, .pointer);
            }
        }
        ctx.place(key.key.key.node(imev, btn_widget.wh), Point.origin);
        ctx.place(btn_widget.node, Point.origin);

        return .{ .node = ctx.result(), .wh = btn_widget.wh };
    }
};

fn useButton(id_arg: ID.Arg, imev: *ImEvent) ButtonKey {
    const id = id_arg.id;
    const clicked_state = imev.useClickable(id.push(@src()));
    return .{
        .hover = if (clicked_state.focused) |fxd| fxd.hover else false,
        .clicked = if (clicked_state.focused) |fxd| fxd.click else false,
        .key = clicked_state,
    };
}

fn renderRichtextSpan(id_arg: ID.Arg, imev: *ImEvent, isc: *IdStateCache, span: generic.RichtextSpan, args: SpanPlacer.Args) RenderedSpan {
    const id = id_arg.id;
    var ctx = imev.render();

    // TODO:
    // baseline support.
    // render lines centered at their baseline
    // tell the span placer how far apart to place them (pango_layout_get_height)
    //

    switch (span) {
        .text => |txt| {
            const placed_text = primitives.textLayout(imev, args.width, .{ .color = .white, .size = .sm, .left_offset = args.start_offset }, txt.str);
            // get lines
            // pango_cairo_show_layout_line https://docs.gtk.org/PangoCairo/func.show_layout_line.html
            var lines_iter = placed_text.lines();
            // place the first line (0 - args.start_offset, 0, w - args.start_offset, h)
            // if there are no more lines, return an inline value

            const first_line = lines_iter.next() orelse return .empty;
            var fl_ctx = imev.render();
            const fl_size = first_line.getSize();
            const fl_wh: WH = .{ .w = fl_size.w - args.start_offset, .h = fl_size.h };
            {
                // const hov = imev.clickable(id.push(@src()));
                // fl_ctx.place(hov.key.node(imev, fl_wh), .{ .x = 0, .y = 0 });
                // fl_ctx.place(primitives.rect(imev, fl_wh, .{ .bg = if (hov.focused) |_| .white else .red }), .{ .x = 0, .y = 0 });
                // fl_ctx.place(primitives.rect(imev, .{ .w = fl_wh.w - 2, .h = fl_wh.h - 2 }, .{ .bg = .black }), .{ .x = 1, .y = 1 });
                fl_ctx.place(primitives.textLine(imev, first_line, .white), .{ .x = -args.start_offset, .y = fl_size.bl });
                // text lines appear to render from the baseline rather than the upper left logical extent
            }
            const fl_widget = Widget{
                .wh = fl_wh,
                .node = fl_ctx.result(),
            };

            if (!lines_iter.hasNext()) return .{
                .inline_value = .{ .widget = fl_widget },
            };

            var cy: f64 = 0;
            var cl_ctx = imev.render();
            var line_index: usize = 0;

            const last_line = while (lines_iter.next()) |line| : (line_index += 1) {
                if (!lines_iter.hasNext()) break line;

                const lp_id = id.pushIndex(@src(), line_index);

                //
                // pango_layout_get_height(PangoLayoutLine* line, &height)
                // "Computes the height of the line, i.e. the distance between this and the previous lines baseline"
                // I think that's needed, along with span support for baselines

                const cl_size = line.getSize();
                cl_ctx.place(primitives.textLine(imev, line, .white), .{ .x = 0, .y = cy + cl_size.bl });
                cy += cl_size.h;
            } else unreachable;

            const cl_widget = Widget{
                .wh = .{ .w = args.width, .h = cy },
                .node = cl_ctx.result(),
            };

            var ll_ctx = imev.render();
            const ll_size = last_line.getSize();
            // ll_ctx.place(primitives.rect(imev, .{ .w = ll_size.w, .h = ll_size.h }, .{ .bg = .red }), .{ .x = 0, .y = 0 });
            // ll_ctx.place(primitives.rect(imev, .{ .w = ll_size.w - 2, .h = ll_size.h - 2 }, .{ .bg = .black }), .{ .x = 1, .y = 1 });
            ll_ctx.place(primitives.textLine(imev, last_line, .white), .{ .x = 0, .y = ll_size.bl });
            const ll_widget = Widget{
                .wh = .{ .w = ll_size.w, .h = ll_size.h },
                .node = ll_ctx.result(),
            };

            return .{
                .multi_line = .{
                    .first_line = fl_widget,
                    .middle = cl_widget,
                    .last_line = ll_widget,
                }, // TODO multi_line
            };

            //if(!lines_iter.hasNext()) return inline_value

            // var cline = lines_iter.next() orelse unreachable
            // while (lines_iter.hasNext()) : (cline = lines_iter.next()) {
            //     pushIndex(id.push(@src()), index)
            // }
            // const last_line =
            // uuh how do you do this control flow properly this isn't it

            // gslist is just {ptr data, next}
            // so an iter is really easy to make
        },
        .unsupported => |unsup| {
            const res = useButton(id.push(@src()), imev);
            const btn_text = std.fmt.allocPrint(imev.arena(), "TODO {s}", .{unsup}) catch @panic("oom");
            return .{ .inline_value = .{ .widget = res.render(id.push(@src()), imev, btn_text) } };
        },
    }
}

fn renderRichtextParagraph(id_arg: ID.Arg, imev: *ImEvent, isc: *IdStateCache, paragraph: generic.RichtextParagraph, width: f64) VLayoutManager.Child {
    const id = id_arg.id;
    var ctx = imev.render();

    switch (paragraph) {
        .paragraph => |par| {
            // check "zig not working on mac" for a sample of everything being bad and broken
            var span_placer = SpanPlacer.init(imev, width);
            for (par) |span, i| {
                const lp_id = id.pushIndex(@src(), i);

                span_placer.place(renderRichtextSpan(lp_id.push(@src()), imev, isc, span, span_placer.getArgs()));
            }
            const res = span_placer.finish();
            ctx.place(res.node, Point.origin);
            return .{ .h = res.wh.h, .node = ctx.result() };
        },
        .code_block => |cb| {
            const is_thin = width < 600;
            const w_inset_size: f64 = if (width < 600) 0 else 8;
            const text = primitives.textV(imev, width - (w_inset_size * 2), .{ .size = .sm, .family = .monospace, .color = .white }, cb);
            const inset_size: WH = .{ .w = if (is_thin) width + 16 else width, .h = text.h + 16 };
            ctx.place(primitives.rect(imev, inset_size, .{ .bg = .gray300, .rounded = if (is_thin) .none else .sm }), .{ .x = if (is_thin) -8 else 0, .y = 0 });
            ctx.place(text.node, .{ .x = w_inset_size, .y = 8 });
            return .{ .h = @floor(inset_size.h), .node = ctx.result() };
        },
        .unsupported => |unsup_msg| {
            const rt_component = std.fmt.allocPrint(imev.arena(), "TODO Paragraph.{s}", .{unsup_msg}) catch @panic("oom");
            const widget = primitives.textV(imev, width, .{ .color = .red, .size = .sm }, rt_component);
            ctx.place(widget.node, Point.origin);
            return .{ .h = widget.h, .node = ctx.result() };
        },
    }
}

fn renderBody(id_arg: ID.Arg, imev: *ImEvent, isc: *IdStateCache, body: generic.Body, width: f64) VLayoutManager.Child {
    const id = id_arg.id;
    var ctx = imev.render();

    var layout = VLayoutManager.fromWidth(width);

    switch (body) {
        .none => {},
        .link => |link| {
            // render a link → a RenderedSpan
            // render the span with the spanrenderer thing
            // layout.place(&ctx, .{.gap = 8}); // place the rendered span
            const clicked = imev.useClickable(id.push(@src()));
            const hovering = if (clicked.focused) |fc| fc.hover else false;
            if (clicked.focused) |fc| if (fc.hover) fc.setCursor(imev, .pointer);
            const text = primitives.textV(imev, layout.top_rect.w, .{ .size = .sm, .color = .blue500, .underline = hovering }, link.url);

            const area = layout.take(.{ .h = text.h, .gap = 8 });
            ctx.place(text.node, area.ul());
            ctx.place(clicked.key.node(imev, area.wh()), area.ul());
            // layout.place(&ctx, .{ .gap = 8 }, text);

            // TODO display preview body using the preview client
        },
        .array => |array| {
            for (array) |array_item, i| {
                const scope_index = id.pushIndex(@src(), i);

                if (array_item == .none) continue;
                layout.place(&ctx, .{ .gap = 8 }, renderBody(scope_index.push(@src()), imev, isc, array_item, width));
            }
        },
        .richtext => |paragraphs| {
            for (paragraphs) |paragraph, i| {
                const scope_index = id.pushIndex(@src(), i);

                layout.place(&ctx, .{ .gap = 8 }, renderRichtextParagraph(scope_index.push(@src()), imev, isc, paragraph, width));
            }
        },
        .unsupported => |name| {
            layout.place(&ctx, .{ .gap = 8 }, primitives.textV(imev, layout.top_rect.w, .{ .color = .red, .size = .sm }, name));
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

fn renderPost(id_arg: ID.Arg, imev: *ImEvent, isc: *IdStateCache, width: f64, node: generic.Post) VLayoutManager.Child {
    const id = id_arg.id;
    var ctx = imev.render();

    const state = isc.useState(id.push(@src()), PostState, PostState.init); // |_| .{.display_body = node.default_open}

    var layout = VLayoutManager.fromWidth(width);

    if (node.title) |title| layout.place(&ctx, .{ .gap = 0 }, primitives.textV(imev, layout.top_rect.w, .{ .color = .white, .size = .base }, title));
    {
        var actions_lm = HLayoutManager.init(imev, .{ .max_w = layout.top_rect.w, .gap_x = 8, .gap_y = 0 });

        const btn_key = useButton(id.push(@src()), imev);
        if (btn_key.clicked) {
            state.display_body = !state.display_body;
        }
        actions_lm.put(btn_key.render(id.push(@src()), imev, if (state.display_body) "Hide" else "Show")) orelse unreachable;

        actions_lm.overflow(renderExtraActionsMenu(id.push(@src()), imev, isc, node.actions));
        for (node.actions) |action, i| {
            const lp_id = id.pushIndex(@src(), i);

            actions_lm.put(renderAction(lp_id.push(@src()), imev, isc, action)) orelse break;
        }
        layout.place(&ctx, .{ .gap = 0 }, actions_lm.build());
    }

    if (state.display_body and node.body != .none) {
        layout.place(&ctx, .{ .gap = 0 }, vinset(id.push(@src()), imev, 4, renderBody(id.push(@src()), imev, isc, node.body, layout.top_rect.w)));
    }

    return layout.result(&ctx);
}

fn renderContextNode(id_arg: ID.Arg, imev: *ImEvent, isc: *IdStateCache, width: f64, node: generic.PostContext) VLayoutManager.Child {
    const id = id_arg.id;
    var ctx = imev.render();

    var layout = VLayoutManager.fromWidth(width);
    layout.inset(8);

    for (node.parents) |post| {
        layout.place(&ctx, .{ .gap = 8 }, renderPost(id.push(@src()), imev, isc, layout.top_rect.w, post));
    }

    return layout.result(&ctx);
}

pub fn topLevelContainer(id_arg: ID.Arg, imev: *ImEvent, width: f64, child: VLayoutManager.Child, opts: struct { rounded: bool }) VLayoutManager.Child {
    // return rectEncapsulating(rounding, .bg = .gray200,
    //    child
    // )
    const id = id_arg.id;
    var ctx = imev.render();

    const rounding: RoundedStyle = if (opts.rounded) .md else .none;

    ctx.place(primitives.rect(imev, .{ .w = width, .h = child.h }, .{ .rounded = rounding, .bg = .gray200 }), Point.origin);
    ctx.place(child.node, Point.origin);

    return VLayoutManager.Child{
        .node = ctx.result(),
        .h = child.h,
    };
}

const AppNodeRenderer = struct {
    page: *const generic.Page,
    width: f64,
    rounded: bool,

    pub fn renderNode(anr: @This(), id_arg: ID.Arg, imev: *ImEvent, isc: *IdStateCache, node_id: u64) VLayoutManager.Child {
        const id = id_arg.id;
        var ctx = imev.render();

        const page = anr.page;
        if (page.body != .listing) @panic("todo");
        const listing_items = page.body.listing.items;

        const context_node = listing_items[@intCast(usize, node_id)];

        const content_v = renderContextNode(id.push(@src()), imev, isc, anr.width, context_node);
        const res_v = topLevelContainer(id.push(@src()), imev, anr.width, content_v, .{ .rounded = anr.rounded });
        ctx.place(res_v.node, Point.origin);

        return .{ .h = res_v.h + 8, .node = ctx.result() };
    }
    pub fn existsNode(anr: @This(), node_id: u64) bool {
        const page = anr.page;
        if (page.body != .listing) @panic("todo");
        const listing_items = page.body.listing.items;

        if (listing_items.len == 0) return false;
        return true;
    }
    pub fn getNextNode(anr: @This(), node_id: u64) ?u64 {
        const page = anr.page;
        if (page.body != .listing) @panic("todo");
        const listing_items = page.body.listing.items;

        if (node_id + 1 == listing_items.len) return null;
        return node_id + 1;
    }
    pub fn getPreviousNode(anr: @This(), node_id: u64) ?u64 {
        if (node_id == 0) return null;
        return node_id - 1;
    }
};

const AppSidebarRender = struct {
    sidebar: []const generic.SidebarNode,
    width: f64,
    rounded: bool,

    pub fn renderNode(anr: @This(), id_arg: ID.Arg, imev: *ImEvent, isc: *IdStateCache, node_id: u64) VLayoutManager.Child {
        const id = id_arg.id;
        var ctx = imev.render();

        const sidebar_node = anr.sidebar[@intCast(usize, node_id)];

        const content_v = renderSidebarWidget(id.push(@src()), imev, isc, anr.width, sidebar_node);
        const res_v = topLevelContainer(id.push(@src()), imev, anr.width, content_v, .{ .rounded = anr.rounded });
        ctx.place(res_v.node, Point.origin);

        return .{ .h = res_v.h + 8, .node = ctx.result() };
    }
    pub fn existsNode(anr: @This(), node_id: u64) bool {
        if (anr.sidebar.len == 0) return false;
        return true;
    }
    pub fn getNextNode(anr: @This(), node_id: u64) ?u64 {
        if (node_id + 1 == anr.sidebar.len) return null;
        return node_id + 1;
    }
    pub fn getPreviousNode(anr: @This(), node_id: u64) ?u64 {
        if (node_id == 0) return null;
        return node_id - 1;
    }
};

pub const AppState = struct {
    content: ui.VirtualScrollHelper,
    sidebar: ui.VirtualScrollHelper,

    pub fn init(
        alloc: *std.mem.Allocator,
        top_content_node: u64,
        top_sidebar_node: u64,
    ) AppState {
        return AppState{
            .content = ui.VirtualScrollHelper.init(alloc, top_content_node),
            .sidebar = ui.VirtualScrollHelper.init(alloc, top_sidebar_node),
        };
    }
    pub fn deinit(astate: *AppState) void {
        astate.content.deinit();
        astate.sidebar.deinit();
    }
};

pub fn renderApp(id_arg: ID.Arg, imev: *ImEvent, isc: *IdStateCache, wh: WH, page: generic.Page) RenderResult {
    const id = id_arg.id;
    var ctx = imev.render();

    const state_frame = isc.useStateCustomInit(id.push(@src()), AppState);
    if (!state_frame.initialized) state_frame.ptr.* = AppState.init(imev.persistentAlloc(), 0, 0);
    const state = state_frame.ptr;

    ctx.place(primitives.rect(imev, wh, .{ .bg = .gray100 }), Point.origin);

    const sidebar_width = 300;
    const cutoff = 1000;
    const mobile_cutoff = 600;

    const scrollable = imev.useScrollable(id.push(@src()));
    ctx.place(scrollable.key.node(imev, wh), Point.origin);

    if (scrollable.scrolling) |scrolling| {
        state.content.scroll(scrolling.delta.y);
        state.sidebar.scroll(scrolling.delta.y);
    }

    // todo make it possible to put a, also virtualized, header thing above both scroll helpers somehow

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

        const areaa = sidebar.take(.{ .gap = 8, .h = 1 });
        const sidebar_render = state.sidebar.render(id.push(@src()), imev, AppSidebarRender{ .sidebar = page.sidebar, .width = areaa.w, .rounded = true }, wh.h, areaa.y);
        ctx.place(sidebar_render, .{ .x = areaa.x, .y = areaa.y });
    }

    const rounded = wh.w > mobile_cutoff;

    {
        const areaa = layout.take(.{ .gap = 8, .h = 1 });
        const content_render = state.content.render(id.push(@src()), imev, AppNodeRenderer{ .page = &page, .width = areaa.w, .rounded = rounded }, wh.h, areaa.y);
        ctx.place(content_render, .{ .x = areaa.x, .y = areaa.y });
    }

    return ctx.result();
}

pub fn renderRoot(id_arg: ID.Arg, imev: *ImEvent, isc: *IdStateCache, wh: WH, content: generic.Page) RenderResult {
    const id = id_arg.id;
    return renderApp(id.push(@src()), imev, isc, wh, content);
}
