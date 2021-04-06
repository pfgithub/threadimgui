usingnamespace @cImport({
    @cInclude("cairo_cbind.h");
});
const std = @import("std");
const main = @import("main.zig"); // TODO remove this (using the user data gpointer args provided to pass info around)

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

// has bitfield
const GdkEventKey_f = extern struct {
    type_: GdkEventType,
    window: *GdkWindow,
    send_event: gint8,
    time: gint32,
    state: guint,
    keyval: guint,
    length: gint,
    string: [*]gchar,
    hardware_keycode: guint16,
    group: guint8,
    is_modifier: u8, // bitfield u1
    fn c(me: *GdkEventKey_f) *GdkEventKey {
        return @ptrCast(*GdkEventKey, me);
    }
};

pub const RawEvent = union(enum) {
    empty: void,
    keypress: *GdkEventKey_f,
    keyrelease: *GdkEventKey_f,
    textcommit: []const u8,
    resize: struct { x: c_int, y: c_int, w: c_int, h: c_int },
};

// oh I can have user data I should use that
// pass it through the start fn
export fn zig_on_draw_event(cr: *cairo_t) callconv(.C) void {
    main.renderFrame(Context{ .cr = cr });
}
export fn zig_on_keypress_event(evk: *GdkEventKey_f, im_context: *GtkIMContext) callconv(.C) gboolean {
    main.pushEvent(.{ .keypress = evk });
    return gtk_im_context_filter_keypress(im_context, evk.c()); // don't do this for modifier keys obv
}
export fn zig_on_keyrelease_event(evk: *GdkEventKey_f) callconv(.C) void {
    main.pushEvent(.{ .keyrelease = evk });
}
export fn zig_on_commit_event(context: *GtkIMContext, str: [*:0]gchar, user_data: gpointer) callconv(.C) void {
    main.pushEvent(.{ .textcommit = std.mem.span(str) });
}
export fn zig_on_delete_surrounding_event(context: *GtkIMContext, offset: gint, n_chars: gint, user_data: gpointer) callconv(.C) gboolean {
    @panic("TODO implement IME support");
}
export fn zig_on_preedit_changed_event(context: *GtkIMContext, user_data: gpointer) callconv(.C) void {
    @panic("TODO implement IME support");
}
export fn zig_on_retrieve_surrounding_event(context: *GtkIMContext, user_data: gpointer) callconv(.C) gboolean {
    @panic("TODO implement IME support");
}
export fn zig_on_resize_event(widget: *GtkWidget, rect: *GdkRectangle, user_data: gpointer) callconv(.C) gboolean {
    main.pushEvent(.{ .resize = .{ .x = rect.x, .y = rect.y, .w = rect.width, .h = rect.height } });
    return 1;
}

fn roundedRectangle(cr: *cairo_t, x: f64, y: f64, w: f64, h: f64, corner_radius: f64) void {
    // TODO if radius == 0 skip this
    const radius = corner_radius;
    const degrees = std.math.pi / 180.0;

    cairo_new_sub_path(cr);
    cairo_arc(cr, x + w - radius, y + radius, radius, -90 * degrees, 0 * degrees);
    cairo_arc(cr, x + w - radius, y + h - radius, radius, 0 * degrees, 90 * degrees);
    cairo_arc(cr, x + radius, y + h - radius, radius, 90 * degrees, 180 * degrees);
    cairo_arc(cr, x + radius, y + radius, radius, 180 * degrees, 270 * degrees);
    cairo_close_path(cr);
}

pub const TextLayout = struct {
    layout: *PangoLayout,
    pub fn deinit(layout: TextLayout) void {
        g_object_unref(layout.layout);
    }
    pub fn getSize(layout: TextLayout) main.WH {
        var w: c_int = 0;
        var h: c_int = 0;
        pango_layout_get_size(layout.layout, &w, &h);
        return .{ .w = @intToFloat(f64, w) / @intToFloat(f64, PANGO_SCALE), .h = @intToFloat(f64, h) / @intToFloat(f64, PANGO_SCALE) };
    }
};

pub const Context = struct {
    cr: *cairo_t,
    fn setRgba(ctx: Context, color: main.Color) void {
        const cr = ctx.cr;
        cairo_set_source_rgba(cr, color.r, color.g, color.b, color.a);
    }
    pub fn renderNode(ctx: Context, node: main.RenderNode) void {
        const cr = ctx.cr;
        switch (node.value) {
            .unfilled => unreachable, // unfilled node exists. TODO additional debug info here.
            .rectangle => |rect| {
                roundedRectangle(cr, rect.rect.x, rect.rect.y, rect.rect.w, rect.rect.h, rect.radius);
                ctx.setRgba(rect.bg_color);
                cairo_fill(cr);
            },
            .text => |text| {
                ctx.setRgba(text.color);
                cairo_save(cr);
                cairo_move_to(cr, text.position.x, text.position.y);
                pango_cairo_show_layout(cr, text.layout.layout);
                cairo_restore(cr);
            },
        }
    }
    const TextLayoutOpts = struct {
        width: c_int,
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

        pango_layout_set_width(layout, opts.width * PANGO_SCALE);
        pango_layout_set_wrap(layout, .PANGO_WRAP_WORD_CHAR);

        return TextLayout{ .layout = layout };
        // }

        //     cairo_save(cr);
        //     cairo_move_to(cr, 50, 150);
        //     pango_cairo_show_layout(cr, layout);
        //     cairo_restore(cr);
    }
};

pub fn start() !void {
    if (start_gtk(0, undefined) != 0) return error.Failure;
}
