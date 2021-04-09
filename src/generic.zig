const JsonHelper = struct {
    value: ?std.json.Value,
    alloc: *std.mem.Allocator,

    pub fn subvalue(jh: JsonHelper, value: ?std.json.Value) JsonHelper {
        return JsonHelper{ .value = value, .alloc = jh.alloc };
    }

    pub fn get(jh: JsonHelper, field: []const u8) JsonHelper {
        return switch (jh.value orelse return jh.subvalue(null)) {
            .Object => |obj| jh.subvalue(obj.get(field)),
            else => jh.subvalue(null),
        };
    }
    pub fn asString(jh: JsonHelper) ![]const u8 {
        const value = jh.value orelse return error.BadJSON;
        return switch (value) {
            .String => |str| return str,
            else => return error.BadJSON,
        };
    }
    pub fn asEnum(jh: JsonHelper, comptime Enum: type) !Enum {
        return std.meta.stringToEnum(Enum, try jh.asString()) orelse return error.BadJSON;
    }
    fn ReturnValueType(comptime fnc: anytype) type {
        return @typeInfo(@typeInfo(@TypeOf(fnc)).Fn.return_type orelse unreachable).ErrorUnion.payload;
    }
    pub fn asArray(jh: JsonHelper, comptime fromJSON: anytype) ![]ReturnValueType(fromJSON) {
        return switch (jh.value orelse return error.BadJSON) {
            .Array => |arr| {
                var res_array = try jh.alloc.alloc(ReturnValueType(fromJSON), arr.items.len);
                for (arr.items) |itm, i| res_array[i] = try fromJSON(jh.subvalue(itm));
                return res_array;
            },
            else => return error.BadJSON,
        };
    }
};

pub const Page = struct {
    title: []const u8,
    content: []const PostContext,
    sidebar: []const SidebarNode,
    display_mode: DisplayMode,

    pub fn fromJSON(jh: JsonHelper) !Page {
        return Page{
            .title = try jh.get("title").asString(),
            .content = &[_]PostContext{},
            .sidebar = try jh.get("sidebar").asArray(SidebarNode.fromJSON),
            .display_mode = switch (try jh.get("display_style").asEnum(enum { @"fullscreen-view", @"comments-view" })) {
                .@"fullscreen-view" => .fullscreen,
                .@"comments-view" => .centered,
            },
        };
    }
};

pub const DisplayMode = enum { fullscreen, centered };
pub const PostContext = struct {
    parents: []const Post,
    children: []const Post,
};
pub const Post = struct {
    title: []const u8,
    info: struct {
        time: u64,
        author: struct {
            username: []const u8,
            color_hash: []const u8,
            link: []const u8,
        },
        in: struct {
            link: []const u8,
            name: []const u8,
        },
    },
    actions: []const Action,
};
pub const Action = struct {
    text: []const u8,
};
pub const SidebarNode = union(enum) {
    sample: struct {
        title: []const u8,
        body: []const u8,
    },
    pub fn fromJSON(jh: JsonHelper) !SidebarNode {
        return switch (try jh.get("kind").asEnum(enum { widget, thread })) {
            .widget => return SidebarNode{ .sample = .{ .title = "sample", .body = "sample" } },
            .thread => return SidebarNode{ .sample = .{ .title = "sample", .body = "sample" } },
        };
    }
};

const std = @import("std");
const json_source = @embedFile("sample_data.json");
pub fn initSample(alloc: *std.mem.Allocator) Page {
    //
    var json_token_stream = std.json.TokenStream.init(json_source);
    var json_parser = std.json.Parser.init(alloc, false);
    defer json_parser.deinit();

    var json_res = json_parser.parse(json_source) catch |e| {
        std.log.emerg("JSON parsing error: {}", .{e});
        @panic("error");
    };

    return Page.fromJSON(JsonHelper{ .value = json_res.root, .alloc = alloc }) catch |e| {
        std.log.emerg("JSON error: {}", .{e});
        @panic("error");
    };
}
