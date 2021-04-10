usingnamespace @cImport({
    @cInclude("cairo_cbind.h");
});
const std = @import("std");
const imgui = @import("../../imgui.zig"); // TODO structures.zig

pub fn renderRect(window: *const Window, color: Color, rect: Rect) ER!void {
    setClip(window);
    const cr = window.cairo orelse return;
    cairo_set_source_rgb(cr, color.r, color.g, color.b);
    cairo_set_line_width(cr, 0);
    cairo_rectangle(cr, rect.x, rect.y, rect.w, rect.h);
    cairo_stroke_preserve(cr);
    cairo_fill(cr);
}

pub fn init() RenderingError!void {
    if (start_gtk(0, undefined) != 0) return error.Unrecoverable;
}

pub fn deinit() void {}

pub fn time_() u64 {
    return @intCast(i64, std.time.milliTimestamp());
}

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
// https://gitlab.gnome.org/GNOME/gtk/blob/master/gdk/gdkkeysyms.h
const KeyMap = enum(guint) {
    f12 = GDK_KEY_F12,
    _,
    pub fn toKey(raw: KeyMap) Key {
        return switch (raw) {
            .f12 => .f12,
            _ => .unsupported,
        };
    }
};

// oh I can have user data I should use that
// pass it through the start fn
export fn zig_on_draw_event(widget: *GtkWidget, cr: *cairo_t, data: *OpaqueData) callconv(.C) gboolean {
    data.zig.renderFrame(Context{ .cr = cr, .widget = widget }, rrFrom(data.darea), data.zig.data);
    return 0;
}
export fn zig_on_resize_event(widget: *GtkWidget, rect: *GdkRectangle, data: *OpaqueData) callconv(.C) gboolean {
    data.zig.pushEvent(.{ .resize = .{ .x = rect.x, .y = rect.y, .w = rect.width, .h = rect.height } }, rrFrom(data.darea), data.zig.data);
    return 1;
}
export fn zig_button_press_event(widget: *GtkWidget, event: *GdkEventButton, data: *OpaqueData) callconv(.C) gboolean {
    // std.log.info("Button ↓{} at ({}, {})", .{ event.button, event.x, event.y });
    data.zig.pushEvent(.{ .mouse_click = .{ .down = true, .x = event.x, .y = event.y, .button = event.button } }, rrFrom(data.darea), data.zig.data);
    return 1;
}
export fn zig_button_release_event(widget: *GtkWidget, event: *GdkEventButton, data: *OpaqueData) callconv(.C) gboolean {
    // std.log.info("Button ↑{} at ({}, {})", .{ event.button, event.x, event.y });
    data.zig.pushEvent(.{ .mouse_click = .{ .down = false, .x = event.x, .y = event.y, .button = event.button } }, rrFrom(data.darea), data.zig.data);
    return 1;
}
export fn zig_motion_notify_event(widget: *GtkWidget, event: *GdkEventMotion, data: *OpaqueData) callconv(.C) gboolean {
    // std.log.info("Mouse to ({}, {})", .{ event.x, event.y });
    data.zig.pushEvent(.{ .mouse_move = .{ .x = event.x, .y = event.y } }, rrFrom(data.darea), data.zig.data);
    return 1;
}
const SCROLL_SPEED = 55;
// gtk does not appear to tell you the scroll speed + there does not appear to be a standard scroll speed
// setting on linux
export fn zig_scroll_event(widget: *GtkWidget, event: *GdkEventScroll, data: *OpaqueData) callconv(.C) gboolean {
    // https://bugzilla.gnome.org/show_bug.cgi?id=675959
    var delta_x: gdouble = undefined;
    var delta_y: gdouble = undefined;
    if (get_scroll_delta(event, &delta_x, &delta_y) == 0) unreachable;
    // TODO if shift key pressed && delta_x == 0, delta_x = delta_y, delta_y = 0;
    data.zig.pushEvent(.{ .scroll = .{ .scroll_x = delta_x * SCROLL_SPEED, .scroll_y = delta_y * SCROLL_SPEED } }, rrFrom(data.darea), data.zig.data);
    // this passes a mouse position event, I'm just going to hope that mouse motion handles that for me though
    return 1;
}
export fn zig_key_event(widget: *GtkWidget, event: *GdkEventKey, data: *OpaqueData) callconv(.C) gboolean {
    // check:
    // event.type == GDK_KEY_PRESS || GDK_KEY_RELEASE,
    // event.hardware_keycode, event.is_modifier == 1,
    // event.keyval, https://gitlab.gnome.org/GNOME/gtk/blob/master/gdk/gdkkeysyms.h

    var ev_type: GdkEventType = undefined;
    var keyval: guint = undefined; // https://gitlab.gnome.org/GNOME/gtk/blob/master/gdk/gdkkeysyms.h
    var modifiers: guint = undefined; // https://developer.gnome.org/gdk3/unstable/gdk3-Windows.html#GdkModifierType

    extract_key_event_fields(event, &ev_type, &keyval, &modifiers);

    const mapped = @intToEnum(KeyMap, keyval);

    const is_down = switch (ev_type) {
        .GDK_KEY_PRESS => true,
        .GDK_KEY_RELEASE => false,
        else => return 1,
    };

    // https://developer.gnome.org/gdk3/unstable/gdk3-Windows.html#GdkModifierType
    data.zig.pushEvent(.{ .key = .{ .down = is_down, .key = mapped.toKey(), .modifiers = .{
        .shift = modifiers & GDK_SHIFT_MASK != 0,
        .ctrl = modifiers & GDK_CONTROL_MASK != 0,
        .alt = modifiers & GDK_MOD1_MASK != 0,
        .win = modifiers & GDK_MOD4_MASK != 0,
        .caps = modifiers & GDK_LOCK_MASK != 0,
    } } }, rrFrom(data.darea), data.zig.data);
    return 1;
}
export fn zig_on_commit_event(context: *GtkIMContext, text: [*:0]const u8, data: *OpaqueData) callconv(.C) void {
    // note: to start recieving im events, you must request them:
    // gtk_im_context_focus_in / gtk_im_context_focus_out
    // https://developer.gnome.org/gtk3/stable/GtkIMContext.html#gtk-im-context-focus-out
    // so an input should, if it's focused, tell imev that next frame an input is focused.
    data.zig.pushEvent(.{ .textcommit = std.mem.span(text) }, rrFrom(data.darea), data.zig.data);
}

fn rrFrom(widget: *GtkWidget) RerenderRequest {
    return .{ .widget = widget };
}
pub const RerenderRequest = struct {
    widget: *GtkWidget,

    pub fn queueDraw(rr: RerenderRequest) void {
        gtk_widget_queue_draw(rr.widget);
    }
};

fn roundedRectangle(cr: *cairo_t, x: f64, y: f64, w: f64, h: f64, corner_radius_raw: f64) void {
    // TODO if radius == 0 skip this

    cairo_new_sub_path(cr);
    if (corner_radius_raw == 0) {
        cairo_rectangle(cr, x, y, w, h);
    } else {
        const corner_radius = std.math.min(w / 2, corner_radius_raw);

        const radius = corner_radius;
        const degrees = std.math.pi / 180.0;

        cairo_arc(cr, x + w - radius, y + radius, radius, -90 * degrees, 0 * degrees);
        cairo_arc(cr, x + w - radius, y + h - radius, radius, 0 * degrees, 90 * degrees);
        cairo_arc(cr, x + radius, y + h - radius, radius, 90 * degrees, 180 * degrees);
        cairo_arc(cr, x + radius, y + radius, radius, 180 * degrees, 270 * degrees);
    }
    cairo_close_path(cr);
}

pub const TextLayout = struct {
    layout: *PangoLayout,
    pub fn deinit(layout: TextLayout) void {
        g_object_unref(layout.layout);
    }
    pub fn getSize(layout: TextLayout) imgui.WH {
        var w: c_int = 0;
        var h: c_int = 0;
        pango_layout_get_size(layout.layout, &w, &h);
        return .{ .w = @intToFloat(f64, w) / @intToFloat(f64, PANGO_SCALE), .h = @intToFloat(f64, h) / @intToFloat(f64, PANGO_SCALE) };
    }
};

pub const CursorEnum = enum {
    // https://developer.gnome.org/gdk3/stable/gdk3-Cursors.html#gdk-cursor-new-from-name
    none,
    default,
    pointer,
    @"context-menu",
    progress,
    wait,
    cell,
    crosshair,
    text,
    @"vertical-text",
    alias,
    copy,
    @"no-drop",
    move,
    @"not-allowed",
    grab,
    grabbing,
    @"all-scroll",
    @"col-resize",
    @"row-resize",
    @"n-resize",
    @"e-resize",
    @"s-resize",
    @"w-resize",
    @"ne-resize",
    @"nw-resize",
    @"sw-resize",
    @"se-resize",
    @"ew-resize",
    @"ns-resize",
    @"nesw-resize",
    @"nwse-resize",
    @"zoom-in",
    @"zoom-out",
    help,
};

pub const Context = struct {
    cr: *cairo_t,
    widget: *GtkWidget,
    fn setRgba(ctx: Context, color: imgui.Color) void {
        const cr = ctx.cr;
        cairo_set_source_rgba(cr, color.r, color.g, color.b, color.a);
    }
    pub fn setCursor(ctx: Context, cursor_tag: CursorEnum) void {
        const display = gtk_widget_get_display(ctx.widget);
        const window = gtk_widget_get_window(ctx.widget);
        const cursor_tag_str0 = std.heap.c_allocator.dupeZ(u8, @tagName(cursor_tag)) catch @panic("oom");
        const cursor = gdk_cursor_new_from_name(display, cursor_tag_str0);
        // uuh TODO free this also maybe don't create duplicate cursors like
        // store a hashmap(CursorEnum, *GdkCursor) and then free them all at the end
        gdk_window_set_cursor(window, cursor);
    }
    pub fn renderRectangle(ctx: Context, color: imgui.Color, rect: imgui.Rect, radius: f64) void {
        const cr = ctx.cr;
        roundedRectangle(cr, rect.x, rect.y, rect.w, rect.h, radius);
        ctx.setRgba(color);
        cairo_fill(cr);
    }
    pub fn renderText(ctx: Context, point: imgui.Point, text: TextLayout, color: imgui.Color) void {
        const cr = ctx.cr;
        ctx.setRgba(color);
        cairo_save(cr);
        cairo_move_to(cr, point.x, point.y);
        pango_cairo_show_layout(cr, text.layout);
        cairo_restore(cr);
    }
    const TextLayoutOpts = struct {
        width: ?c_int, // pango scaled
    };
    pub fn layoutText(ctx: Context, font: [*:0]const u8, text: []const u8, opts: TextLayoutOpts) TextLayout {
        const cr = ctx.cr;
        // if (layout == null) {
        const layout = pango_cairo_create_layout(cr) orelse @panic("no layout"); // ?*PangoLayout, g_object_unref(layout)

        {
            const description = pango_font_description_from_string(font);
            defer pango_font_description_free(description);
            pango_layout_set_font_description(layout, description);
        }
        pango_layout_set_text(layout, text.ptr, @intCast(gint, text.len));

        if (opts.width) |w| pango_layout_set_width(layout, w);
        pango_layout_set_wrap(layout, .PANGO_WRAP_WORD_CHAR);

        return TextLayout{ .layout = layout };
        // }

        //     cairo_save(cr);
        //     cairo_move_to(cr, 50, 150);
        //     pango_cairo_show_layout(cr, layout);
        //     cairo_restore(cr);
    }
};

const OpaquePtrData = struct {
    data: usize,
    renderFrame: fn (cr: Context, rr: RerenderRequest, data: usize) void,
    pushEvent: fn (ev: RawEvent, rr: RerenderRequest, data: usize) void,
};

const OpaqueData = extern struct {
    zig: *OpaquePtrData,
    darea: *GtkWidget,
};

pub fn pangoScale(float: f64) c_int {
    return @floatToInt(gint, float * @intToFloat(f64, PANGO_SCALE));
}

pub fn start() !void {
    if (start_gtk(0, undefined, @ptrToInt("a")) != 0) return error.Failure;
}

pub fn runUntilExit(
    data_in: anytype,
    comptime renderFrame: fn (cr: Context, rr: RerenderRequest, data: @TypeOf(data_in)) void,
    comptime pushEvent: fn (ev: RawEvent, rr: RerenderRequest, data: @TypeOf(data_in)) void,
) !void {
    const data_ptr = @ptrToInt(&data_in);
    comptime const DataPtr = @TypeOf(&data_in);
    var opaque_ptr_data = OpaquePtrData{
        .data = data_ptr,
        .renderFrame = struct {
            fn a(cr: Context, rr: RerenderRequest, data: usize) void {
                return renderFrame(cr, rr, @intToPtr(DataPtr, data).*);
            }
        }.a,
        .pushEvent = struct {
            fn a(ev: RawEvent, rr: RerenderRequest, data: usize) void {
                return pushEvent(ev, rr, @intToPtr(DataPtr, data).*);
            }
        }.a,
    };

    if (start_gtk(0, undefined, @intToPtr(*c_void, @ptrToInt(&opaque_ptr_data))) != 0) return error.Failure;
}