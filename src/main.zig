const std = @import("std");
const imgui = @import("imgui");
const app = @import("app.zig");
const generic = @import("generic.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const alloc = &gpa.allocator;

    var sample_arena = std.heap.ArenaAllocator.init(alloc);
    defer sample_arena.deinit();

    const content = generic.initSample(&sample_arena.allocator);

    try imgui.runUntilExit(alloc, content, app.renderRoot);
}
