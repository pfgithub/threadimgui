pub const Page = struct {
    title: []const u8,
    content: []const PostContext,
    sidebar: []const SidebarNode,
    display_mode: DisplayMode,

    pub fn fromJSON(vt: std.json.Value) !Page {
        switch (vt) {
            .Object => |obj| {
                return Page{
                    .title = try stringFromJSON(obj.get("title")),
                    .content = &[_]PostContext{},
                    .sidebar = &[_]SidebarNode{},
                    .display_mode = switch (try enumFromJSON(obj.get("display_style"), enum { @"fullscreen-view", @"comments-view" })) {
                        .@"fullscreen-view" => .fullscreen,
                        .@"comments-view" => .centered,
                    },
                };
            },
            else => return error.BadJSON,
        }
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
pub fn enumFromJSON(value_opt: ?std.json.Value, comptime Enum: type) !Enum {
    const value = value_opt orelse return error.BadJSON;
    return std.meta.stringToEnum(Enum, try stringFromJSON(value)) orelse return error.BadJSON;
}
pub fn stringFromJSON(value_opt: ?std.json.Value) ![]const u8 {
    const value = value_opt orelse return error.BadJSON;
    return switch (value) {
        .String => |str| return str,
        else => return error.BadJSON,
    };
}
pub const Action = struct {
    text: []const u8,
};
pub const SidebarNode = union(enum) {
    sample: struct {
        title: []const u8,
        body: []const u8,
    },
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

    return Page.fromJSON(json_res.root) catch |e| {
        std.log.emerg("JSON error: {}", .{e});
        @panic("error");
    };
}
