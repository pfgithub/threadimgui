pub const RawEvent = union(enum) {
    empty: void,
    key: struct { down: bool, key: Key, modifiers: KeyModifiers },
    textcommit: []const u8,
    resize: struct { x: c_int, y: c_int, w: c_int, h: c_int },
    mouse_click: struct { button: c_uint, x: f64, y: f64, down: bool },
    mouse_move: struct { x: f64, y: f64 },
    scroll: struct { scroll_x: f64, scroll_y: f64 },
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
};

pub const Point = struct {
    x: f64,
    y: f64,
    pub const origin = Point{ .x = 0, .y = 0 };
    pub fn toRectBR(pt: Point, wh: WH) Rect {
        return .{ .x = pt.x, .y = pt.y, .w = wh.w, .h = wh.h };
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
    width: struct { w: c_int },
};
