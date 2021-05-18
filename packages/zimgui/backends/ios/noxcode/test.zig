// const CGFloat = ; // switch(os) {.watchos => double, else => float}
const CGFloat = f64;
// should be able to get that from a cimport

export fn zig_getstring() [*]const u8 {
    return "Hello from Zig (1)!";
}

const std = @import("std");
extern fn objc_panic() noreturn;
pub fn panic(message: []const u8, trace: ?*std.builtin.StackTrace) noreturn {
    objc_panic();
}

extern fn c_main(argc: c_int, argv: [*]const [*]const u8, data: ?*opaque{}) c_int;

export fn main(argc: c_int, argv: [*]const [*]const u8) void {
    _ = c_main(argc, argv, null);
    unreachable; // I think?
}

const CData = opaque{
    extern fn objc_draw_rect(ref: *CData, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) void;
};

export fn zig_render(ref: *CData) void {
    ref.objc_draw_rect(25, 25, 100, 100, 1.0, 1.0, 0.0, 1.0);
}