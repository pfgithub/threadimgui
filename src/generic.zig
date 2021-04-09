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
    pub fn asOptString(jh: JsonHelper) !?[]const u8 {
        const value = jh.value orelse return null;
        return switch (value) {
            .String => |str| return str,
            else => return error.BadJSON,
        };
    }
    pub fn asString(jh: JsonHelper) ![]const u8 {
        return (try jh.asOptString()) orelse return error.BadJSON;
    }
    pub fn asEnum(jh: JsonHelper, comptime Enum: type) !Enum {
        return std.meta.stringToEnum(Enum, try jh.asString()) orelse return error.BadJSON;
    }
    // I'd rather use non-exhaustive enums so this can be done in asEnum but unfortunately "non-exhaustive enum must specify size"
    pub fn asEnumDefaulted(jh: JsonHelper, comptime Enum: type, default: Enum) !Enum {
        return std.meta.stringToEnum(Enum, try jh.asString()) orelse return default;
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
    body: PageBody,
    sidebar: []const SidebarNode,
    display_mode: DisplayMode,

    pub fn fromJSON(jh: JsonHelper) !Page {
        return Page{
            .title = try jh.get("title").asString(),
            .body = try PageBody.fromJSON(jh.get("body")),
            .sidebar = try jh.get("sidebar").asArray(SidebarNode.fromJSON),
            .display_mode = switch (try jh.get("display_style").asEnum(enum { @"fullscreen-view", @"comments-view" })) {
                .@"fullscreen-view" => .fullscreen,
                .@"comments-view" => .centered,
            },
        };
    }
};
pub const PageBody = union(enum) {
    listing: struct {
        items: []PostContext,
    },
    pub fn fromJSON(jh: JsonHelper) !PageBody {
        return switch (try jh.get("kind").asEnum(std.meta.TagType(PageBody))) {
            .listing => PageBody{ .listing = .{
                .items = try jh.get("items").asArray(PostContext.fromJSON),
            } },
        };
    }
};

pub const DisplayMode = enum { fullscreen, centered };
pub const PostContext = struct {
    parents: []const Post,
    children: []const Post,
    pub fn fromJSON(jh: JsonHelper) !PostContext {
        return PostContext{
            .parents = try jh.get("parents").asArray(Post.fromJSON),
            .children = try jh.get("replies").asArray(Post.fromJSON),
        };
    }
};
pub const Post = struct {
    title: ?[]const u8,
    // info: struct {
    //     time: u64,
    //     author: struct {
    //         username: []const u8,
    //         color_hash: []const u8,
    //         link: []const u8,
    //     },
    //     in: struct {
    //         link: []const u8,
    //         name: []const u8,
    //     },
    // },
    actions: []const Action,

    pub fn fromJSON(jh: JsonHelper) !Post {
        return switch (try jh.get("kind").asEnum(enum { thread })) {
            .thread => Post{
                .title = try jh.get("title").get("text").asOptString(),
                .actions = try jh.get("actions").asArray(Action.fromJSON),
            },
        };
    }
};
pub const Action = struct {
    text: []const u8,
    pub fn fromJSON(jh: JsonHelper) !Action {
        return switch (try jh.get("kind").asEnum(enum { link, reply, counter, delete, report, login, act, flair, code })) {
            .link => Action{ .text = try jh.get("text").asString() },
            .reply => Action{ .text = try jh.get("text").asString() },
            .counter => Action{ .text = "TODO counter" },
            .delete => Action{ .text = "Delete" },
            .report => Action{ .text = "Report" },
            .login => Action{ .text = "Log In" },
            .act => Action{ .text = try jh.get("text").asString() },
            .flair => Action{ .text = "Flair" },
            .code => Action{ .text = "Code" },
        };
    }
};
pub const SidebarNode = union(enum) {
    sample: struct {
        title: []const u8,
        body: []const u8,
    },
    pub fn fromJSON(jh: JsonHelper) !SidebarNode {
        return switch (try jh.get("kind").asEnum(enum { widget, thread })) {
            .widget => {
                const content = jh.get("widget_content");
                return SidebarNode{
                    .sample = .{
                        .title = try jh.get("title").asString(),
                        .body = switch (try content.get("kind").asEnumDefaulted(enum { @"community-details", unsupported }, .unsupported)) {
                            .@"community-details" => try content.get("description").asString(),
                            .unsupported => "TODO",
                        },
                    },
                };
            },
            .thread => return SidebarNode{ .sample = .{ .title = "TODO", .body = "unsupported `thread` sidebar node" } },
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
