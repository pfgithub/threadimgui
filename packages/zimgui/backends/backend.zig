const backend = @import("cairo/cairo.zig");
const structures = @import("../structures.zig");

pub const TextLayout = backend.TextLayout;
pub const pangoScale = backend.pangoScale;
pub const Context = backend.Context;
pub const RerenderRequest = backend.RerenderRequest;

pub const OpaquePtrData = struct {
    data: usize,
    renderFrame: fn (cr: Context, rr: RerenderRequest, data: usize) void,
    pushEvent: fn (ev: structures.RawEvent, rr: RerenderRequest, data: usize) void,
};

pub fn runUntilExit(
    data_in: anytype,
    comptime renderFrame: fn (cr: Context, rr: RerenderRequest, data: @TypeOf(data_in)) void,
    comptime pushEvent: fn (ev: structures.RawEvent, rr: RerenderRequest, data: @TypeOf(data_in)) void,
) error{Failure}!void {
    const data_ptr = @ptrToInt(&data_in);
    comptime const DataPtr = @TypeOf(&data_in);
    const opaque_ptr_data = OpaquePtrData{
        .data = data_ptr,
        .renderFrame = struct {
            fn a(cr: Context, rr: RerenderRequest, data: usize) void {
                return renderFrame(cr, rr, @intToPtr(DataPtr, data).*);
            }
        }.a,
        .pushEvent = struct {
            fn a(ev: structures.RawEvent, rr: RerenderRequest, data: usize) void {
                return pushEvent(ev, rr, @intToPtr(DataPtr, data).*);
            }
        }.a,
    };

    try backend.start(&opaque_ptr_data);
    // fn(data_ptr: *const OpaquePtrData) error{Failure}!void
}
