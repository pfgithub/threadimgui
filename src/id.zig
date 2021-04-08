const std = @import("std");
const main = @import("main.zig");

pub const ID = struct {
    const DebugSafety = struct {
        alloc: *std.mem.Allocator,
        seen: std.AutoHashMap(u64, void),
        push_count: usize,
        pub fn create(alloc: *std.mem.Allocator) *DebugSafety {
            //
            var dbs = alloc.create(DebugSafety) catch @panic("oom");
            dbs.* = .{
                .alloc = alloc,
                .seen = std.AutoHashMap(u64, void).init(alloc),
                .push_count = 0,
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

        // what you should do:
        // loop {
        //     const pushed = id.key(«key»);
        //     defer pushed.pop();
        //     now you can do stuff
        // }

        // for now though I'm just keeping which ids have been generated before
        // this has a chance of false positives so it is disabled in release modes, even release-safe
        // chance: for 5 million ids (probably wouldn't be able to render in any resonable amount of time)
        // : 0.7% chance of collision
        // if user-inputted data is ever inputted into pushString(), it is possible to engineer a collision
        // that's probably not an issue as long as ids are only used for resonable things.

        // also this likely uses wyhash wrong (wyhash seems to have up to 32 bytes of data + a u64 for the
        // past data while this only has a u64 for the past data)
    };
    const safety_enabled = switch (std.builtin.mode) {
        .Debug => true,
        else => false,
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
    pub fn deinit(id: *ID) void {
        if (safety_enabled) {
            if (id.debug_safety.push_count != 0) unreachable;
            id.debug_safety.destroy();
        }
    }
    const PopID = struct {
        id: *ID,
        seed: u64,
        // TODO track and make sure all of these are popped
        // because there is currently no way to check that in
        // the zig type system
        pub fn pop(popid: PopID) void {
            if (safety_enabled) popid.id.debug_safety.push_count -= 1;
            popid.id.seed = popid.seed;
        }
    };
    pub fn pushString(id: *ID, src: std.builtin.SourceLocation, str: []const u8) PopID {
        return id.pushSrc(src, str);
    }
    pub fn pushIndex(id: *ID, src: std.builtin.SourceLocation, index: usize) PopID {
        return id.pushSrc(src, std.mem.asBytes(&index));
    }
    fn pushSrc(id: *ID, src: std.builtin.SourceLocation, slice: []const u8) PopID {
        if (safety_enabled) id.debug_safety.push_count += 1;

        const seed_start = id.seed;

        var hasher = std.hash.Wyhash.init(id.seed);
        std.hash.autoHash(&hasher, src.line);
        std.hash.autoHash(&hasher, src.column);
        hasher.update(src.file);
        hasher.update("#");
        hasher.update(slice);
        id.seed = hasher.final();

        return PopID{ .id = id, .seed = seed_start };
    }
    // if nextid is called twice from the same seed with the same source location, error
    // "id.push…(…) is required in loops"
    pub fn forSrc(id: *ID, src: std.builtin.SourceLocation) u64 {
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
