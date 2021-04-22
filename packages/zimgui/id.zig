const std = @import("std");
const main = @import("main.zig");

const safety_enabled = switch (std.builtin.mode) {
    .Debug => true,
    else => false,
};

pub const ID2 = struct {
    root: *Root,
    prefix: []const []const u8,
    pub const Root = struct {
        const DebugSafety = struct {
            // seen: HashMap([]const []const u8)
            // // check if things are equal based on the pointers.
            // actually don't do that because if the same key is added
            // twice this won't find out. and that's the whole point. nvm.
        };
        alloc: *std.mem.Allocator,
        debug_safety: if (safety_enabled) *DebugSafety else void,
    };
    // fn key() []const u8 : returns the id string or something.
    // this is used in imev for keys. (a duplicate must be made usually)

    // fn push(…) ID2 {} returns a new ID2 with the value pushed.
    // shadowing is kinda needed here uuh…

    // use case: variable shadowing
    // {
    //    const id = id.push();
    //    for(range(25)) |_| {const id = id.push();}
    // }
};

pub const ID = struct {
    pub const Src = std.builtin.SourceLocation;
    const DebugSafety = struct {
        alloc: *std.mem.Allocator,
        seen: std.AutoHashMap(u64, void),
        pub fn create(alloc: *std.mem.Allocator) *DebugSafety {
            //
            var dbs = alloc.create(DebugSafety) catch @panic("oom");
            dbs.* = .{
                .alloc = alloc,
                .seen = std.AutoHashMap(u64, void).init(alloc),
            };
            return dbs;
        }
        pub fn destroy(dbs: *DebugSafety) void {
            dbs.seen.deinit();
            dbs.alloc.destroy(dbs);
        }
        // pub fn pushStr(str: []const u8) void {
        //     //
        // }

        pub fn seenID(dbs: *DebugSafety, id: u64) !void {
            if ((dbs.seen.getOrPut(id) catch @panic("oom")).found_existing) {
                return error.Seen;
            }
        }

        // basically this will keep
        // Map([]const []const u8 → Set(std.builtin.SourceLocation))
        // then whenever an id is generated(src_location)
        // check if the current map key has that source location already
        // if it does, @panic("id.pushString() is required in loops to prevent reusing IDs");

        // for now though I'm just keeping which ids have been generated before
        // this has a chance of false positives so it is disabled in release modes, even release-safe
        // chance: for 5 million ids (probably wouldn't be able to render in any resonable amount of time)
        // : 0.7% chance of collision
        // if user-inputted data is ever inputted into pushString(), it is possible to engineer a collision
        // that's probably not an issue as long as ids are only used for resonable things.

        // also this likely uses wyhash wrong (wyhash seems to have up to 32 bytes of data + a u64 for the
        // past data while this only has a u64 for the past data)
    };
    // this probably isn't how you use wyhash
    // there might be something else better for this use case / a correct way to use wyhash here
    seed: u64,
    debug_safety: if (safety_enabled) *DebugSafety else void,
    pub fn init(alloc: *std.mem.Allocator) ID {
        return ID{
            .seed = 0,
            .debug_safety = if (safety_enabled) DebugSafety.create(alloc) else {},
        };
    }
    pub fn deinit(id: ID) void {
        if (safety_enabled) {
            id.debug_safety.destroy();
        }
    }
    pub fn pushString(id: ID, src: std.builtin.SourceLocation, str: []const u8) ID {
        return id.pushSrc(src, str);
    }
    pub fn pushIndex(id: ID, src: std.builtin.SourceLocation, index: usize) ID {
        return id.pushSrc(src, std.mem.asBytes(&index));
    }
    pub const Arg = struct {
        /// get this at the top of your fn.
        id: ID,
    };
    pub fn push(id: ID, src: std.builtin.SourceLocation) Arg {
        return .{ .id = id.pushSrc(src, "") };
    }
    // src: comptime std.builtin.SourceLocation? so that `@ptrToInt(&src)` can be used to get a unique id for any source code line?
    // seems nice
    fn pushSrc(id: ID, src: std.builtin.SourceLocation, slice: []const u8) ID {
        const seed_start = id.seed;

        var hasher = std.hash.Wyhash.init(id.seed);
        std.hash.autoHash(&hasher, src.line);
        std.hash.autoHash(&hasher, src.column);
        hasher.update(src.file);
        hasher.update("#");
        hasher.update(slice);
        const seed = hasher.final();
        if (safety_enabled) {
            id.debug_safety.seenID(seed) catch |e| @panic(
                \\The same ID was generated twice for the same source location and scope.
                \\Make sure to use id.push in loops and at the start and end of functions.
            );
        }

        return .{ .seed = seed, .debug_safety = id.debug_safety };
    }
    pub fn forSrc(id: ID, src: std.builtin.SourceLocation) u64 {
        var hasher = std.hash.Wyhash.init(id.seed);

        std.hash.autoHash(&hasher, src.line);
        std.hash.autoHash(&hasher, src.column);
        hasher.update(src.file);

        const res = hasher.final();
        if (safety_enabled) {
            id.debug_safety.seenID(res) catch |e| @panic(
                \\The same ID was generated twice for the same source location and scope.
                \\Make sure to use id.push in loops and at the start and end of functions.
            );
        }
        return res;
    }
};
fn demoID(id: *ID, cond: bool) void {
    std.log.emerg("value: {}", .{id.forSrc(@src())});
    std.log.emerg("value: {}", .{id.forSrc(@src())});
    if (cond) {
        std.log.emerg("     - in_cond: {}", .{id.forSrc(@src())});
        std.log.emerg("     - in_cond: {}", .{id.forSrc(@src())});
    }
    std.log.emerg("value: {}", .{id.forSrc(@src())});
    std.log.emerg("value: {}", .{id.forSrc(@src())});
    std.log.emerg("value: {}", .{id.forSrc(@src())});
}
test "id" {
    const alloc = std.testing.allocator;
    // TODO test that all the emitted values are unique and the top level
    // values are the same with and without the pushed string
    {
        var id = ID.init(alloc);
        defer id.deinit();
        demoID(&id, false);
    }
    std.log.emerg("----", .{});
    {
        var id = ID.init(alloc);
        defer id.deinit();
        demoID(&id, true);
    }
    std.log.emerg("----", .{});
    // TODO test that id panics if you generate an id from the same source location twice with the same seed
    // uuh maybe don't panic there - it's *possible* to get the same seed from different keys so that would
    // mean your app might crash at any time if something bad happens to happen. instead test based on
    // the actual set of keys that were pushed

    {
        var id = ID.init(alloc);
        defer id.deinit();
        for (main.range(2)) |_, i| {
            const v = id.pushIndex(@src(), i);
            defer v.pop();
            std.log.emerg("id_loop (keyed): {}", .{id.forSrc(@src())});
        }
        for (main.range(2)) |_| {
            std.log.emerg("id_loop (unkeyed): {}", .{id.forSrc(@src())}); // this should panic the second time
        }
    }
}
