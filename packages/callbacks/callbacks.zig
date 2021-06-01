pub fn callback(ctx: anytype, comptime cb_fn: anytype) CallbackReturnType(@TypeOf(cb_fn)) {
    // ctx can be anything as long as it fits in a usize
    // I'll just bitcast for now
    const ReturnType = CallbackReturnType(@TypeOf(cb_fn));
    comptime const CtxType = @TypeOf(ctx);
    return ReturnType{
        .data_ptr = @ptrToInt(ctx), // todo allow any data ≤ usize
        .cb_ptr = (struct {
            fn cb(data: usize, arg: ReturnType.ArgType) ReturnType.ReturnType {
                return cb_fn(@intToPtr(CtxType, data), arg);
            }
        }).cb,
    };
}

/// fn CallbackReturnType<ArgType, ReturnType>(
///     ctx: fn(a: unknown, b: ArgType) ReturnType
/// ) Callback(ArgType, ReturnType);
fn CallbackReturnType(comptime CBType: type) type {
    const cb_ti = @typeInfo(CBType);
    const args = cb_ti.Fn.args;
    if (args.len != 2) @compileError("req. 2 fn args");
    return Callback(args[1].arg_type.?, cb_ti.Fn.return_type.?);
}

pub fn Callback(comptime ArgTypeArg: type, comptime ReturnTypeArg: type) type {
    return struct {
        pub const ArgType = ArgTypeArg;
        pub const ReturnType = ReturnTypeArg;
        data_ptr: usize,
        cb_ptr: fn (usize, ArgType) ReturnType,
        pub fn call(self: @This(), arg: ArgType) ReturnType {
            return self.cb_ptr(self.data_ptr, arg);
        }
    };
}

// CallbackReturnType is Callback(arg_type, return_type)

const Event = struct {
    value: u64,
};

const DemoCB = struct {
    number: usize,
    pub fn cb(this: *@This(), arg: Event) void {
        @import("std").log.emerg("cb called! num: {}, ev: {}", .{ this.number, arg.value });
    }
};

test "" {
    var demo_data = DemoCB{ .number = 24 };
    const demo: Callback(Event, void) = callback(&demo_data, DemoCB.cb);
    demo.call(.{ .value = 54 });
    // actually DemoCB{} maybe not; maybe should uuh
    // like the callback only gets one usize of data
    // so you should be able to put a pointer there
}
