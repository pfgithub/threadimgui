pub const Page = struct {
    content: []const PostContext,
    sidebar: []const SidebarNode,
    display_mode: DisplayMode,
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
};

pub const sample = Page{
    .display_mode = .centered,
    .content = &[_]PostContext{
        .{ .children = &[_]Post{}, .parents = &[_]Post{.{
            .title = "Community-run Zig forum!",
            .info = .{
                .time = 1615854551000,
                .author = .{ .username = "kristoff-it", .color_hash = "kristoff-it", .link = "/u/kristoff-it" },
                .in = .{ .link = "/r/Zig", .name = "r/Zig" },
            },
            .actions = &[_]Action{
                .{ .text = "Reply" },
                .{ .text = "5 comments" },
                .{ .text = "self.Zig" },
                .{ .text = "Delete" },
                .{ .text = "Save" },
                .{ .text = "Duplicates" },
                .{ .text = "Report" },
                .{ .text = "Extra" },
                .{ .text = "More" },
            },
        }} },
        .{ .children = &[_]Post{}, .parents = &[_]Post{.{
            .title = "Jakub Kona Hired Full Time",
            .info = .{
                .time = 1617670210000,
                .author = .{ .username = "kristoff-it", .color_hash = "kristoff-it", .link = "/u/kristoff-it" },
                .in = .{ .link = "/r/Zig", .name = "r/Zig" },
            },
            .actions = &[_]Action{
                .{ .text = "0 comments" },
                .{ .text = "Delete" },
                .{ .text = "Save" },
                .{ .text = "Duplicates" },
                .{ .text = "Report" },
            },
        }} },
    },
    .sidebar = &[_]SidebarNode{
        .{ .sample = .{ .title = "Sample Header", .body = "Cairo Test. 🙋→⎋ يونيكود.\nHow are you doing? This is a sample body." } },
        .{ .sample = .{ .title = "Another One", .body = "Rules:\n- No bad\n- Only good" } },
    },
};
