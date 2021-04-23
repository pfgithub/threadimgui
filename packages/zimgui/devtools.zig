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

        ctx.place(root_result, .{ .x = @divFloor(key.full_wh.w, 4), .y = @divFloor(key.full_wh.h, 4) });

        return ctx.result();
    }
};

pub fn useMobileEmulation(id_arg: ID.Arg, imev: *ImEvent, isc: *IdStateCache, wh: WH) MobileEmulationKey {
    const id = id_arg.id;

    return MobileEmulationKey{ .content_wh = .{ .w = @divFloor(wh.w, 2), .h = @divFloor(wh.h, 2) }, .full_wh = wh };
}

pub fn renderDevtools(id_arg: ID.Arg, imev: *ImEvent, isc: *IdStateCache, wh: WH, root_result: RenderResult) RenderResult {
    const id = id_arg.id;
    var ctx = imev.render();

    ctx.place(primitives.rect(imev, wh, .{ .bg = .red }), Point.origin);

    return ctx.result();
}
