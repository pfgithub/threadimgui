// thing that has like a sidebar and lets you pick which app to run
// also an x button to clear the isc for the app

const std = @import("std");
const im = @import("imgui");

pub usingnamespace im.StartBackend;

pub fn renderAppSelector(id_arg: im.ID.Arg, imev: *im.ImEvent, isc: *im.IdStateCache, wh: im.WH, content: u1) im.RenderResult {
    // tabs on the left
    // tab name, x button to clear isc if the tab is open (/ refresh button if it's focused)
    const id = id_arg.id;
    var ctx = imev.render();
    return ctx.result();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const alloc = &gpa.allocator;

    var sample_arena = std.heap.ArenaAllocator.init(alloc);
    defer sample_arena.deinit();

    // pointer to size 0 type has no address
    // that will be fixed by one of the zig things, but until then:
    try im.runUntilExit(alloc, @as(u1, 0), renderAppSelector);
}
