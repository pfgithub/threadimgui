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
        const SeenHM = std.HashMapUnmanaged(Ident, void, Ident.hash, Ident.eql, std.hash_map.default_max_load_percentage);
        alloc: *std.mem.Allocator,
        seen: SeenHM,
        pub fn create(alloc: *std.mem.Allocator) *DebugSafety {
            //
            var dbs = alloc.create(DebugSafety) catch @panic("oom");
            dbs.* = .{
                .alloc = alloc,
                .seen = SeenHM{},
            };
            return dbs;
        }
        pub fn destroy(dbs: *DebugSafety) void {
            dbs.seen.deinit(dbs.alloc);
            dbs.alloc.destroy(dbs);
        }

        pub fn seenID(dbs: *DebugSafety, id: Ident) !void {
            if ((dbs.seen.getOrPut(dbs.alloc, id) catch @panic("oom")).found_existing) {
                return error.Seen;
            }
        }
    };
    pub const Segment = struct {
        src_loc: *const Src, // comptime &src
        data: union(enum) {
            none,
            text: []const u8,
            index: usize,
        },

        pub fn hash(seg: Segment) u64 {
            var hasher = std.hash.Wyhash.init(0);
            hasher.update(&std.mem.toBytes(seg.src_loc));
            switch (seg.data) {
                .none => {},
                .text => |txt| hasher.update(txt),
                .index => |idx| hasher.update(&std.mem.toBytes(idx)),
            }
            return hasher.final();
        }
        pub fn eql(s1: Segment, s2: Segment) bool {
            return s1.src_loc == s2.src_loc and switch (s1.data) {
                .none => s2.data == .none,
                .text => |txt| s2.data == .text and std.mem.eql(u8, txt, s2.data.text),
                .index => |idx| s2.data == .index and s2.data.index == idx,
            };
        }
        pub fn dupe(seg: Segment, alloc: *std.mem.Allocator) Segment {
            return .{
                .src_loc = seg.src_loc,
                .data = switch (seg.data) {
                    .none => |v| .{ .none = v },
                    .index => |i| .{ .index = i },
                    .text => |txt| .{ .text = alloc.dupe(u8, txt) catch @panic("oom") },
                },
            };
        }
        pub fn deinit(seg: Segment, alloc: *std.mem.Allocator) void {
            switch (seg.data) {
                .none, .index => {},
                .text => |txt| alloc.free(txt),
            }
        }
    };
    // TODO
    // const Ident
    // pub const IdentFrame (fn value() Ident)
    // pub const IdentStored (fn value() Ident)
    // also offer an id map thing that maps from IdentStored => value
    //   but lets you getOrPut IdentFrame things.
    // alternatively, switch to rust. oh wait, it doesn't have good
    //   support for arena allocators which is what this issue is about.
    pub const Ident = struct {
        segments: []const Segment,
        pub fn hash(ident: Ident) u64 {
            var hasher = std.hash.Wyhash.init(0);
            for (ident.segments) |segment| hasher.update(&std.mem.toBytes(segment.hash()));
            return hasher.final();
        }
        pub fn eql(id1: Ident, id2: Ident) bool {
            if (id1.segments.len != id2.segments.len) return false;
            if (id1.segments.ptr == id2.segments.ptr) return true;
            for (id1.segments) |segment, index| {
                if (!segment.eql(id2.segments[index])) return false;
            }
            return true;
        }
        // oh no
        // for storage across frames,
        // it needs to be possible to: dupe and free idents
        pub fn dupe(ident: Ident, alloc: *std.mem.Allocator) Ident {
            const acpy = alloc.alloc(Segment, ident.segments.len) catch @panic("oom");
            for (acpy) |*v, i| v.* = ident.segments[i].dupe(alloc);
            return .{ .segments = acpy };
        }
        pub fn deinit(ident: Ident, alloc: *std.mem.Allocator) void {
            for (ident.segments) |segment| segment.deinit(alloc);
            alloc.free(ident.segments);
        }
        pub fn format(ident: Ident, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            try writer.writeAll("<");
            for (ident.segments) |segment, i| {
                if (i != 0) try writer.writeAll(", ");
                try writer.print("@{s}:{}.{}", .{ segment.src_loc.fn_name, segment.src_loc.line, segment.src_loc.column });
                // try writer.print("@{x}", .{@ptrToInt(segment.src_loc)});
                switch (segment.data) {
                    .none => {},
                    .index => |idx| try writer.print("[{}]", .{idx}),
                    .text => |txt| try writer.print("[\"{}\"]", .{std.fmt.fmtSliceEscapeUpper(txt)}),
                }
            }
            try writer.writeAll(">");
            // try writer.print("@{}", .{ident.hash()});
        }
    };
    // this probably isn't how you use wyhash
    // there might be something else better for this use case / a correct way to use wyhash here

    debug_safety: if (safety_enabled) *DebugSafety else void,
    ident: Ident,
    arena: *std.mem.Allocator,

    pub fn init(alloc: *std.mem.Allocator, arena: *std.mem.Allocator) ID {
        return ID{
            .ident = .{ .segments = &[_]Segment{} },
            .debug_safety = if (safety_enabled) DebugSafety.create(alloc) else {},
            .arena = arena,
        };
    }
    pub fn deinit(id: ID) void {
        if (safety_enabled) {
            id.debug_safety.destroy();
        }
    }
    // this is a place where custom arg handlers would be nice. src would be runtime but
    // when the argument is passed in, casted to usize. eg:
    //
    // src: Src
    //
    // fn Src(comptime in_src: std.builtin.SourceLocation) usize { return @ptrToInt(comptime &src); }
    pub fn pushString(id: ID, comptime src: std.builtin.SourceLocation, str: []const u8) ID {
        const duped_str = id.arena.dupe(str) catch @panic("oom");
        return id.pushSegment(.{ .src_loc = comptime &src, .data = .{ .text = duped_str } });
    }
    pub fn pushIndex(id: ID, comptime src: std.builtin.SourceLocation, index: usize) ID {
        return id.pushSegment(.{ .src_loc = comptime &src, .data = .{ .index = index } });
    }
    pub const Arg = struct {
        /// get this at the top of your fn.
        id: ID,
    };
    pub fn push(id: ID, comptime src: std.builtin.SourceLocation) Arg {
        return .{ .id = id.pushSegment(.{ .src_loc = comptime &src, .data = .none }) };
    }
    fn pushSegment(id: ID, segment: Segment) ID {
        const itmdupe = id.arena.alloc(Segment, id.ident.segments.len + 1) catch @panic("oom");
        std.mem.copy(Segment, itmdupe, id.ident.segments);
        itmdupe[itmdupe.len - 1] = segment;
        const ident: Ident = .{ .segments = itmdupe };
        if (safety_enabled) id.debug_safety.seenID(ident) catch @panic(
            \\This ID was used multiple times. Make sure loops pushIndex or pushString.
        );
        return .{ .ident = ident, .debug_safety = id.debug_safety, .arena = id.arena };
    }
    pub fn forSrc(id: ID, comptime src: std.builtin.SourceLocation) Ident {
        return id.push(src).id.ident;
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
