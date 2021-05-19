// https://docs.gtk.org/Pango
// https://www.cairographics.org/manual/cairo-Paths.html

usingnamespace @cImport({
    @cInclude("cairo_cbind.h");
});
const std = @import("std");
const backend = @import("../backend.zig");
usingnamespace @import("../../structures.zig"); // a bug is causing this to leak public values even though it's not pub usingnamespace

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

    if (corner_radius_raw == 0) {
        cairo_rectangle(cr, x, y, w, h);
    } else {
        const corner_radius = std.math.min(w / 2, corner_radius_raw);

        const radius = corner_radius;
        const degrees = std.math.pi / 180.0;

        cairo_new_sub_path(cr);
        cairo_arc(cr, x + w - radius, y + radius, radius, -90 * degrees, 0 * degrees);
        cairo_arc(cr, x + w - radius, y + h - radius, radius, 0 * degrees, 90 * degrees);
        cairo_arc(cr, x + radius, y + h - radius, radius, 90 * degrees, 180 * degrees);
        cairo_arc(cr, x + radius, y + radius, radius, 180 * degrees, 270 * degrees);
        cairo_close_path(cr);
    }
}

pub const TextLayout = struct {
    layout: *PangoLayout,
    pub fn deinit(layout: TextLayout) void {
        g_object_unref(layout.layout);
    }
    pub fn getSize(layout: TextLayout) WH {
        var w: c_int = 0;
        var h: c_int = 0;
        pango_layout_get_size(layout.layout, &w, &h);
        return .{ .w = cairoScale(w), .h = cairoScale(h) };
    }
    pub fn lines(layout: TextLayout) TextLayoutLinesIter {
        return .{ .node = pango_layout_get_lines_readonly(layout.layout) };
    }
};
pub const TextLayoutLinesIter = struct {
    node: ?*GSList,
    pub fn next(this: *@This()) ?TextLayoutLine {
        const res = this.node orelse return null;
        this.node = res.next;
        return TextLayoutLine{ .line = @intToPtr(*PangoLayoutLine, @ptrToInt(res.data)) };
    }
    extern fn g_slist_next_c(slist: *GSList) ?*GSList;
    pub fn hasNext(this: @This()) bool {
        return this.node != null;
    }
};
pub const TextLayoutLine = struct {
    line: *PangoLayoutLine,
    pub fn getSize(this: @This()) BlWH {
        var ink_rect: PangoRectangle = undefined;
        var logical_rect: PangoRectangle = undefined;
        pango_layout_line_get_extents(this.line, &ink_rect, &logical_rect);
        // origin is at (h_origin, baseline)
        return .{ .bl = -cairoScale(logical_rect.y), .w = cairoScale(logical_rect.width), .h = cairoScale(logical_rect.height) };
    }
};

pub fn cursorString(cursor: CursorEnum) [:0]const u8 {
    // https://developer.gnome.org/gdk3/stable/gdk3-Cursors.html#gdk-cursor-new-from-name
    return switch (cursor) {
        .none => "none",
        .default => "default",
        .pointer => "pointer",

        .n_resize => "n-resize",
        .e_resize => "e-resize",
        .s_resize => "s-resize",
        .w_resize => "w-resize",
        .ne_resize => "ne-resize",
        .nw_resize => "nw-resize",
        .sw_resize => "sw-resize",
        .se_resize => "se-resize",

        .ns_resize => "ns-resize",
        .ew_resize => "ew-resize",
        .nesw_resize => "nesw-resize",
        .nwse_resize => "nwse-resize",

        // "help",
        // "context-menu",
        // "progress",
        // "wait",
        // "cell",
        // "crosshair",
        // "text",
        // "vertical-text",
        // "alias",
        // "copy",
        // "no-drop",
        // "move",
        // "not-allowed",
        // "grab",
        // "grabbing",
        // "all-scroll",
        // "col-resize",
        // "row-resize",
        // "zoom-in",
        // "zoom-out",
    };
}

const shape_indent_char = "\u{200b}";

pub const TextAttrList = struct {
    attr_list: *PangoAttrList,
    pub fn new() TextAttrList {
        return .{ .attr_list = pango_attr_list_new().? };
    }
    pub fn addRange(al: TextAttrList, start_usz: usize, end_usz: usize, format: TextAttr) void {
        const start = @intCast(guint, start_usz + shape_indent_char.len);
        const end = @intCast(guint, end_usz + shape_indent_char.len);
        switch (format) {
            .underline => {
                const attr = pango_attr_underline_new(.PANGO_UNDERLINE_SINGLE);
                attribute_set_range(attr, start, end);
                pango_attr_list_insert(al.attr_list, attr);
            },
        }
    }
};

pub const Context = struct {
    cr: *cairo_t,
    widget: *GtkWidget,
    fn setRgba(ctx: Context, color: Color) void {
        const cr = ctx.cr;
        cairo_set_source_rgba(cr, color.r, color.g, color.b, color.a);
    }
    pub fn setCursor(ctx: Context, cursor_tag: CursorEnum) void {
        const display = gtk_widget_get_display(ctx.widget);
        const window = gtk_widget_get_window(ctx.widget);
        const cursor = gdk_cursor_new_from_name(display, cursorString(cursor_tag));
        // uuh TODO free this also maybe don't create duplicate cursors like
        // store a hashmap(CursorEnum, *GdkCursor) and then free them all at the end
        gdk_window_set_cursor(window, cursor);
    }
    pub fn renderRectangle(ctx: Context, color: Color, rect: Rect, radius: f64) void {
        const cr = ctx.cr;
        roundedRectangle(cr, rect.x, rect.y, rect.w, rect.h, radius);
        ctx.setRgba(color);
        cairo_fill(cr);
    }
    pub fn renderText(ctx: Context, point: Point, text: TextLayout) void {
        const cr = ctx.cr;
        ctx.setRgba(color);
        cairo_save(cr);
        cairo_move_to(cr, point.x, point.y);
        pango_cairo_show_layout(cr, text.layout);
        cairo_restore(cr);
    }
    pub fn renderTextLine(ctx: Context, point: Point, text: TextLayoutLine, color: Color) void {
        const cr = ctx.cr;
        ctx.setRgba(color);
        cairo_save(cr);
        cairo_move_to(cr, point.x, point.y);
        pango_cairo_show_layout_line(cr, text.line);
        cairo_restore(cr);
    }
    pub fn pushClippingRect(ctx: Context, rect: Rect) void {
        const cr = ctx.cr;
        cairo_save(cr);
        cairo_rectangle(cr, rect.x, rect.y, rect.w, rect.h);
        cairo_clip(cr);
    }
    pub fn popState(ctx: Context) void {
        const cr = ctx.cr;
        cairo_restore(cr);
    }
    pub fn layoutText(ctx: Context, font: [*:0]const u8, text: []const u8, width: ?c_int, left_offset: c_int, attrs: TextAttrList) TextLayout {
        const cr = ctx.cr;
        // if (layout == null) {
        const layout = pango_cairo_create_layout(cr) orelse @panic("no layout"); // ?*PangoLayout, g_object_unref(layout)

        {
            const description = pango_font_description_from_string(font);
            defer pango_font_description_free(description);
            pango_layout_set_font_description(layout, description); // there is also a font description attribute, todo use this
        }
        const text_dupe = std.fmt.allocPrint(std.heap.c_allocator, shape_indent_char ++ "{s}", .{text}) catch @panic("oom");
        pango_layout_set_text(layout, text_dupe.ptr, @intCast(gint, text_dupe.len));

        const attr_l_dupe = pango_attr_list_copy(attrs.attr_list);
        defer pango_attr_list_unref(attr_l_dupe);

        if (left_offset != 0) {
            const rect = PangoRectangle{ .x = 0, .y = 0, .width = left_offset, .height = 1 };
            const attr = pango_attr_shape_new(&rect, &rect);
            attribute_set_range(attr, 0, shape_indent_char.len);
            pango_attr_list_insert(attr_l_dupe, attr);
        }
        pango_layout_set_attributes(layout, attr_l_dupe); // TODO unref the attr list maybe?

        if (width) |w| pango_layout_set_width(layout, w);
        pango_layout_set_wrap(layout, .PANGO_WRAP_WORD_CHAR);

        return TextLayout{ .layout = layout };
        // }

        //     cairo_save(cr);
        //     cairo_move_to(cr, 50, 150);
        //     pango_cairo_show_layout(cr, layout);
        //     cairo_restore(cr);
    }
};

const OpaqueData = extern struct {
    zig: *backend.OpaquePtrData,
    darea: *GtkWidget,
};

pub fn pangoScale(float: f64) c_int {
    return @floatToInt(gint, float * @intToFloat(f64, PANGO_SCALE));
}
pub fn cairoScale(int: c_int) f64 {
    return @intToFloat(f64, int) / @intToFloat(f64, PANGO_SCALE);
}

pub fn startBackend(data_ptr: *const backend.OpaquePtrData) error{Failure}!void {
    if (start_gtk(0, undefined, @intToPtr(*c_int, @ptrToInt(data_ptr))) != 0) return error.Failure;
}
