// thing that has like a sidebar and lets you pick which app to run
// also an x button to clear the isc for the app

const std = @import("std");
const im = @import("imgui");

pub usingnamespace im.StartBackend;

const ActiveTab = enum {
    demo,
    threadimgui,
};

pub const Axis = enum {
    horizontal,
    vertical,
    pub fn x(axis: Axis) []const u8 {
        return switch (axis) {
            .horizontal => "x",
            .vertical => "y",
        };
    }
    pub fn w(axis: Axis) []const u8 {
        return switch (axis) {
            .horizontal => "w",
            .vertical => "h",
        };
    }
};

pub fn MajorLayout(axis: Axis) type {
    return struct {
        const Layout = @This();

        wh: im.WH, // size of the container

        const Partial = struct {
            ul: *im.Point,
            wh: *im.Point,
        };

        pub fn use(width: f64) Partial {
            //
        }
        pub fn dynamic() Partial {
            //
        }
    };
}

pub const VLayout = MajorLayout(.vertical);
pub const HLayout = MajorLayout(.horizontal);

pub fn renderSidebar(id_arg: im.ID.Arg, imev: *im.ImEvent, isc: *im.IdStateCache, wh: im.WH, active_tab: *ActiveTab, show_sidebar: *bool) im.RenderResult {
    const id = id_arg.id;
    var ctx = imev.render();

    var vlayout = VLayout{ .wh = wh };
    inline for (@typeInfo(ActiveTab).Enum.fields) |field| {
        // /
        // for now just a normal vertical placer but eventually this should be switched to a scrollable vertical placer
    }

    return ctx.result();
}

pub fn renderAppSelector(id_arg: im.ID.Arg, imev: *im.ImEvent, isc: *im.IdStateCache, wh: im.WH, content: u1) im.RenderResult {
    // tabs on the left
    // tab name, x button to clear isc if the tab is open (/ refresh button if it's focused)
    const id = id_arg.id;
    var ctx = imev.render();

    // so this will have a tab view on the left and a custom navbar thing on the top framing the app window
    // wondering if I can dynamically load the apps from a so file or something
    // that'd take a bit of effort but should be doable eventually. not going to yet though.
    // actually that could be really fun - you can rebuild the project and click the refresh button and it reloads
    // as long as you didn't make any edits to the imgui structure

    // renderDemoSelector();
    // maybe find some way to say if the inspector frame is open, don't render the navbar and stuff?

    const is_mobile = wh.w < 500;

    const sidebar_id = id.push(@src());
    const sidebar_isc = isc.useISC(id.push(@src()), imev);

    const content_id = id.push(@src()); // needs the content enum
    const content_isc = isc.useISC(id.push(@src()), imev);
    // content isc needs to be a map from the enum => the content isc

    const active_tab = isc.useStateDefault(id.push(@src()), imev, ActiveTab.demo);
    const show_sidebar = isc.useStateDefault(id.push(@src()), imev, true);

    if (is_mobile) {
        // #useState(false) : macro to fill in isc., id.push(@src()), …
        // after setting show_sidebar, call like imev.changed() or something
        // to note that the frame shouldn't be done yet; there's more to do
        if (show_sidebar.*) {
            ctx.place(renderSidebar(sidebar_id, imev, sidebar_isc, wh, active_tab, show_sidebar), im.Point.origin);
        } else {
            ctx.place(@import("demo/app.zig").renderRoot(content_id, imev, content_isc, wh, 0), im.Point.origin);
        }
    } else {
        // var hlayout = HLayout{ .wh = wh };
        // const left = hlayout.use(250); // wh is known but not ul
        // const right = hlayout.dynamic(); // neither ul nor wh are known
        // hlayout.finalize(); // wh and ul are now known for all

        const left: im.Rect = .{ .x = 0, .y = 0, .w = 250, .h = wh.h };
        const right = im.Rect{ .x = 250, .y = 0, .w = wh.w - 250, .h = wh.h };

        ctx.place(renderSidebar(sidebar_id, imev, sidebar_isc, left.wh(), active_tab, show_sidebar), left.ul());
        ctx.place(@import("demo/app.zig").renderRoot(content_id, imev, content_isc, right.wh(), 0), right.ul());
    }
    // wait I can make a full layout thing that has spacers, can't I:
    // const left = hlayout.use(250);
    // left.wh;
    // const right = hlayout.dynamic(1);
    // hlayout.finalize();
    // right.wh;

    // yeah that's doable if I want

    // ok the actual thing I need though:
    // the sidebar needs to be 250px if w≥500, else
    // there needs to be a toggle

    return ctx.result();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const alloc = &gpa.allocator;

    var sample_arena = std.heap.ArenaAllocator.init(alloc);
    defer sample_arena.deinit();

    // pointer to size 0 type has no address
    // that will be fixed by one of the zig things, but until then:
    try im.runUntilExit(alloc, @as(u1, 0), renderAppSelector);
}
