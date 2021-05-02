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
const ID = ui.ID;
const generic = @import("generic.zig");

pub fn renderRoot(id_arg: ID.Arg, imev: *ImEvent, isc: *IdStateCache, wh: WH, content: generic.Page) RenderResult {
    const id = id_arg.id;
    return renderApp(id.push(@src()), imev, isc, wh, content);
}
