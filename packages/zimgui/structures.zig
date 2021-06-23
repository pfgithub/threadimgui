const std = @import("std");

pub const RawEvent = union(enum) {
    empty: void,
    key: struct { down: bool, key: Key, modifiers: KeyModifiers },
    /// sent when keyboard input is requested when a key is pressed or the ime commits text
    textcommit: []const u8,
    resize: struct { x: c_int, y: c_int, w: c_int, h: c_int },
    // either this or one unified mouse event. I think this is fine
    mouse_down: struct { button: MouseButton, x: f64, y: f64 },
    mouse_up: struct { button: MouseButton, x: f64, y: f64 },
    mouse_move: struct { x: f64, y: f64 },
    // mouse_doubleclick, // event order: press, release, …, press, dblpress, release
    scroll: struct { scroll_x: f64, scroll_y: f64 },
};

pub const MouseButton = enum {
    left,
    middle,
    right,
    unsupported,
};

pub const KeyModifiers = packed struct {
    shift: bool,
    ctrl: bool,
    alt: bool,
    win: bool,
    caps: bool,
    // maybe remove alt, win, and caps? they're not all that useful
};
pub const Key = enum {
    f12,
    tab,
    left_tab,
    unsupported,
};

pub const Color = struct {
    r: f64,
    g: f64,
    b: f64,
    a: f64 = 1,
    pub fn rgb(r: u8, g: u8, b: u8) Color {
        return Color{
            .r = @intToFloat(f64, r) / 0xFF,
            .g = @intToFloat(f64, g) / 0xFF,
            .b = @intToFloat(f64, b) / 0xFF,
        };
    }
    pub fn hex(v: u24) Color {
        const r = @intCast(u8, (v & 0xFF0000) >> 16);
        const g = @intCast(u8, (v & 0x00FF00) >> 8);
        const b = @intCast(u8, (v & 0x0000FF) >> 0);
        return Color.rgb(r, g, b);
    }
};

pub const WH = struct {
    w: f64,
    h: f64,
    // should this be float or int?
    pub fn setUL(wh: WH, ul: Point) Rect {
        return .{ .x = ul.x, .y = ul.y, .w = wh.w, .h = wh.h };
    }
};
/// represents a rectangle with its upper left at the origin with a baseline
pub const BlWH = struct {
    bl: f64,
    w: f64,
    h: f64,
};

pub const Point = struct {
    x: f64,
    y: f64,
    pub const origin = Point{ .x = 0, .y = 0 };
    pub fn toRectBR(pt: Point, wh: WH) Rect {
        return .{ .x = pt.x, .y = pt.y, .w = wh.w, .h = wh.h };
    }
    pub fn min(lhs: @This(), rhs: @This()) @This() {
        return .{ .x = std.math.min(lhs.x, rhs.x), .y = std.math.min(lhs.y, rhs.y) };
    }
    pub fn max(lhs: @This(), rhs: @This()) @This() {
        return .{ .x = std.math.max(lhs.x, rhs.x), .y = std.math.max(lhs.y, rhs.y) };
    }
};
pub const Rect = struct {
    x: f64,
    y: f64,
    w: f64,
    h: f64,
    pub fn inset(rect: Rect, distance: f64) Rect {
        return .{
            .x = rect.x + distance,
            .y = rect.y + distance,
            .w = rect.w - distance * 2,
            .h = rect.h - distance * 2,
        };
    }
    pub fn wh(rect: Rect) WH {
        return .{ .w = rect.w, .h = rect.h };
    }
    pub fn ul(rect: Rect) Point {
        return .{ .x = rect.x, .y = rect.y };
    }
    pub fn ur(rect: Rect) Point {
        return .{ .x = rect.x + rect.w, .y = rect.y };
    }
    pub fn bl(rect: Rect) Point {
        return .{ .x = rect.x, .y = rect.y + rect.h };
    }
    pub fn br(rect: Rect) Point {
        return .{ .x = rect.x + rect.w, .y = rect.y + rect.h };
    }
    pub fn containsPoint(rect: Rect, point: Point) bool {
        return point.x >= rect.x and point.x < rect.x + rect.w and
            point.y >= rect.y and point.y < rect.y + rect.h //
        ;
    }
    pub fn overlap(lhs: Rect, rhs: Rect) Rect {
        return Rect.fromULBR(
            lhs.ul().max(rhs.ul()),
            lhs.br().min(rhs.br()),
        );
    }
    pub fn fromULBR(ul_: Point, br_: Point) Rect {
        return .{ .x = ul_.x, .y = ul_.y, .w = br_.x - ul_.x, .h = br_.y - ul_.y };
    }
    pub fn positionCenter(rect: Rect, inner: WH) Rect {
        return Rect{
            .x = rect.x + @divFloor(rect.w, 2) - @divFloor(inner.w, 2),
            .y = rect.y + @divFloor(rect.h, 2) - @divFloor(inner.h, 2),
            .w = inner.w,
            .h = inner.h,
        };
    }
};

pub const TopRect = struct {
    x: f64,
    y: f64,
    w: f64,
};

pub const CursorEnum = enum {
    none,
    default,
    pointer,

    n_resize,
    e_resize,
    s_resize,
    w_resize,
    ne_resize,
    nw_resize,
    sw_resize,
    se_resize,

    ns_resize,
    ew_resize,
    nesw_resize,
    nwse_resize,
};

pub const TextAttr = union(enum) {
    underline,
    color: Color,
};
