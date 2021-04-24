const std = @import("std");
const ui = @import("imgui.zig");
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
const ID = ui.ID;

const MobileEmulationKey = struct {
    content_wh: WH,
    full_wh: WH,
    pub fn render(key: @This(), id_arg: ID.Arg, imev: *ImEvent, root_result: RenderResult) RenderResult {
        const id = id_arg.id;
        var ctx = imev.render();

        ctx.place(primitives.rect(imev, key.full_wh, .{ .bg = .gray300 }), Point.origin);
        ctx.place(root_result, .{ .x = @divFloor(key.full_wh.w, 4), .y = @divFloor(key.full_wh.h, 4) });

        return primitives.clippingRect(imev, key.full_wh, ctx.result());
    }
};

pub fn useMobileEmulation(id_arg: ID.Arg, imev: *ImEvent, isc: *IdStateCache, wh: WH) MobileEmulationKey {
    const id = id_arg.id;

    return MobileEmulationKey{ .content_wh = .{ .w = @divFloor(wh.w, 2), .h = @divFloor(wh.h, 2) }, .full_wh = wh };
}

const DevtoolsTab = enum {
    inspector,
    console,
    emulation, // mobile emulation, screenreader emulation, …

    // isc must be preserved
    pub fn render(id_arg: ID.Arg, imev: *ImEvent, isc: *IdStateCache, tab: DevtoolsTab, wh: WH) RenderResult {
        switch (tab) {
            .inspector => {},
            .console => {},
            .emulation => {},
        }
    }
};

const DevtoolsState = struct {
    tab: DevtoolsTab,
};

const DomTreeRender = struct {
    root: RenderResult,
    // uuh what is node_id. there needs to be some way to anchor
    // but the renderresult changes across frames
    // I think this requires diffing. compare the previous frame's result with
    // the current frame's result and use it to fix the root node and stuff. complicated.

    // ok here's what I need to do
    // I need to save a source location
    // then next frame, find the node with that source location
    // if it's gone, do some diffing or something

    // actually this is the exact reason to change IDs to []const IDSegment
    // that way this can just store an id and if it's lost it just goes up to the parent
};

pub fn renderDomTree(id_arg: ID.Arg, imev: *ImEvent, isc: *IdStateCache, wh: WH, root_result: RenderResult) RenderResult {
    var ctx = imev.render();

    ctx.place(primitives.rect(imev, wh, .{ .bg = .red }), Point.origin);
    // need to take the root_result and turn it into a flat array in order to do virtual scrolling well
    // actually it doesn't need to be a flat array it just needs to be flattened in the virtualscrollhelper
    // render info. that makes it easier.

    return ctx.result();
}

pub fn renderDevtools(id_arg: ID.Arg, imev: *ImEvent, isc: *IdStateCache, wh: WH, root_result: RenderResult) RenderResult {
    const id = id_arg.id;
    var ctx = imev.render();

    // 1: render the tab bar using a left to right item placer with an overflow "»" button
    // renderTabBar(id.push(@src()), imev);

    // HLayoutManager

    ctx.place(renderDomTree(id.push(@src()), imev, isc, wh, root_result), Point.origin);

    return ctx.result();
}
