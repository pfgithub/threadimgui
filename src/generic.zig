pub const Page = struct {
    content: void,
    sidebar: []const SidebarNode,
};
pub const SidebarNode = union(enum) {
    sample: struct {
        title: []const u8,
        body: []const u8,
    },
};

pub const sample = Page{
    .content = {},
    .sidebar = &[_]SidebarNode{
        .{ .sample = .{ .title = "Sample Header", .body = "Cairo Test. 🙋→⎋ يونيكود.\nHow are you doing? This is a sample body." } },
        .{ .sample = .{ .title = "Another One", .body = "Rules:\n- No bad\n- Only good" } },
    },
};
