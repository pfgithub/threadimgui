// zig build-obj test.zig -target aarch64-ios (or native-ios for the simulator)
const std = @import("std");

extern fn objCPrint(str: [*:0]const u8) void;
extern fn objCPanic() noreturn;

export fn zigEntry() void {
    objCPrint("Hello, World!");
    @panic("test");
    // std.log.info("Hello from zig!", .{}); // TODO pub const log
}

pub fn panic(message: []const u8, trace: ?*std.builtin.StackTrace) noreturn {
    objCPanic();
    // the default panic fn has a linking error missing
    // __zig_probe_stack
}
