// const CGFloat = ; // switch(os) {.watchos => double, else => float}
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