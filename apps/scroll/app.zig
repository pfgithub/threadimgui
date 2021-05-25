const std = @import("std");
const ui = @import("imgui");

const ID = ui.ID;
const ImEvent = ui.ImEvent;
const IdStateCache = ui.IdStateCache;

const Bounds = struct {
    w: ?f64, // null = unrestrained
    h: ?f64, // null = unrestrained
};
// <T> completion_fn: fn(id_arg: ID.Arg, content: PlacedWidget, data: T) ProgressWidget
fn ProgressWidget(comptime completionFn: anytype) type {
    const DataType = @typeInfo(@TypeOf(completionFn)).Fn.args[3].arg_type.?;
    return struct {
        bounds: Bounds,
        data: DataType,
        imev: *ImEvent,
        id_arg: ID.Arg,
        pub fn end(progress: @This(), content: PlacedWidget) PlacedWidget {
            return completionFn(progress.id_arg, progress.imev, content, progress.data);
        }
    };
}
const PlacedWidget = struct {
    size: ui.WH,
    node: ui.RenderResult,
};

const ObjectFit = enum{
    contain,
    cover,
};
const ImagePlaceholderOptions = struct {
    /// null → image is decorative, screenreaders should ignore. "" → image is important but alt text is unknown.
    alt: ?[]const u8,
    /// if this is incorrect, content will move around once the image is loaded. this should be avoided.
    aspect: ?f64,
    /// this is only used when both a width and height is provided.
    object_fit: ObjectFit = .contain,
};
fn renderImage(id_arg: ID.Arg, imev: *ImEvent, options: ImagePlaceholderOptions, bounds: Bounds) PlacedWidget {
    const id = id_arg.id;
    var ctx = imev.render();

    if(bounds.w == null or bounds.h != null) @panic("TODO renderImage");
    
    const final_w = bounds.w.?;
    const final_h = @floor(final_w / (options.aspect orelse 1.0));
    const final_wh = ui.WH{.w = final_w, .h = final_h};

    const text = ui.primitives.text(imev, .{ .size = .sm, .color = .white }, options.alt orelse "");
    ctx.place(text.node, final_wh.setUL(ui.Point.origin).positionCenter(text.wh).ul());

    return .{.size = final_wh, .node = ctx.result()};
}

const Inset = struct {
    inset_u: f64 = 0,
    inset_r: f64 = 0,
    inset_b: f64 = 0,
    inset_l: f64 = 0,
    // pub fn
    // Inset.start().y(.d1).l(.d2).r(.d3)
};
const RectAroundOptions = struct {
    inset: Inset = Inset{},
    bg: ui.ThemeColor,
    rounded: ui.RoundedStyle = .none,
};
fn renderRectAround(id_arg: ID.Arg, imev: *ImEvent, opts: RectAroundOptions, bounds: Bounds) ProgressWidget(completeRectAround) {
    return .{
        .data = opts,
        .bounds = bounds,
        .imev = imev,
        .id_arg = id_arg,
    };
}
fn completeRectAround(id_arg: ID.Arg, imev: *ImEvent, content: PlacedWidget, opts: RectAroundOptions) PlacedWidget {
    const id = id_arg.id;
    var ctx = imev.render();
    
    ctx.place(ui.primitives.rect(imev, content.size, .{.bg = opts.bg, .rounded = opts.rounded}), ui.Point.origin);
    ctx.place(content.node, .{.x = opts.inset.inset_u, .y = opts.inset.inset_l});

    return .{.size = content.size, .node = ctx.result()};
}

pub fn renderRoot(id_arg: ID.Arg, imev: *ImEvent, isc: *IdStateCache, wh: ui.WH, content: u1) ui.RenderResult {
    const id = id_arg.id;
    var ctx = imev.render();

    const root_bounds: Bounds = .{.w = wh.w, .h = null};

    const final = a: {
        const b = renderRectAround(id.push(@src()), imev, .{ .bg = .gray100, .rounded = .md }, root_bounds);
        break :a b.end(b: {
            break :b renderImage(id.push(@src()), imev, .{ .alt = "image alt text", .aspect = 1.77 }, b.bounds);
        });
    };

    ctx.place(final.node, ui.Point.origin);

    return ctx.result();
}

fn renderTestScroller() void {
    // make some sample content
    //
    //   Heading (.text-lg)
    //
    //   Content (.text-base)

    // ooh, make it draggable. uuh
    // that needs a custom scroller nvm. shouldn't be *too* hard though

    var scroller = Scroller{ .content = .{ .margin = .m1 } };

    if (scroller.put(id.push(@src()))) |slot| {
        const content_size = slot.style(.{ .margin_y = .m2 });
        slot.put(renderLabel(id.push(@src()), "Heading! Amazing.", content_size, .{ .size = .lg, .weight = .black }));
    }
    if (scroller.put(id.push(@src()))) |slot| {
        const content_size = slot.style(.{});
        slot.put(renderLabel(id.push(@src()), "Here is my non-blod text-base content that goes below this heading.", .{ .size = .base }, content_size));
    }
    if (scroller.put(id.push(@src()))) |slot| {
        // const content_size = slot.style(.{ .margin = .none });
        // slot.put(blk: {
        //     const rect = renderRect(.{ .bg = .gray100, .rounded = .md, .margin = .m0 }, content_size);
        //     break :blk blk2: {
        //         break :blk2 rect.around(renderImage(id.push(@src()), .{ .alt = "image alt text", .aspect = 1.77 }, rect.size));
        //     };
        // });

        const a = slot.style(id.push(@src()), .{ .margin_x = .none });
        a.end(a: {
            const b = renderRectAround(id.push(@src()), .{ .bg = .gray100, .rounded = .md }, a.size);
            break :a b.end(b: {
                break :b renderImage(id.push(@src()), .{ .alt = "image alt text", .aspect = 1.77 }, b.size);
            });
        });

        // zxg time
        //
        //  <Slot .{.margin = .none}
        //    <RectAround .{.bg = .gray100, .rounded = .md, .margin = .m0}
        //      <RenderImage .{.alt = "image alt text", .aspect = 1.77} />
        //    />
        //  />
        //
        // alternatively, stack-capturing macros + allowshadow
        //
        //  slot.style(id.push(@src()), .{.margin = .none}).around(|allowshadow size| (
        //    renderRect(id.push(@src()), .{.bg = .gray100, .rounded = .md}, size).around(|allowshadow size| (
        //      renderImage(id.push(@src()), .{.alt = "image alt text", .aspect = 1.77}, size);
        //    ));
        //  ));
        //
        // alternatively, status quo zig
        //
        //  const a = slot.style(id.push(@src()), .{.margin = .none});
        //  a.end(a: {
        //    const b = renderRect(id.push(@src()), .{.bg = .gray100, .rounded = .md}, a.size);
        //    b.end(b: {
        //      break :b renderImage(id.push(@src()), .{.alt = "image alt text", .aspect = 1.77}, b.size);
        //    });
        //  });
        //
        // alternatively, status quo zig w/ threadlocals
        //
        //  pushContent(slot.style(id.push(@src()), .{.margin = .none})); {
        //    pushContent(renderRect(id.push(@src()), .{.bg = .gray100, .rounded = .md}, size)); {
        //      returnContent(renderImage(id.push(@src()), .{.alt = "image alt text", .aspect = 1.77}, b.size));
        //    }; popReturnContent();
        //  }; popReturnContent();
        //
        // alternatively, allowshadow
        //
        //  allowshadow const itm = slot.style(id.push(@src()), .{.margin = .none});
        //  itm.end(allowshadow itm: {
        //    allowshadow const itm = renderRect(id.push(@src()), .{.bg = .gray100, .rounded = .md}, itm.size);
        //    break :itm itm.end(allowshadow itm: {
        //      break :itm renderImage(id.push(@src()), .{.alt = "image alt text", .aspect = 1.77}, itm.size);
        //    });
        //  });
        //
        // in all of these, interactive things require a "key"
        // (unless I decide to do callbacks for event handling)
        //
        // const btn_key = getButtonKey();
        //
        //  <btn_key.Button .{.bg = some color, …}
        //    <Label "Hi!" />
        //  />
    }
    if (scroller.put(id.push(@src()))) |slot| {
        const content_size = slot.style(.{});
        slot.put(renderLabel(id.push(@src()), "Wow, this is amazing! Time for uuh idk what else goes here.", .{ .size = .base }, content_size));
    }
    if (scroller.put(id.push(@src()))) |slot| {
        const content_size = slot.style(.{});
        slot.put(renderLabel(id.push(@src()), "Oh, here is my fully virtualized scrollable list of 100 items inside a container:", .{ .size = .base }, content_size));
    }
    if (scroller.putVirtualContent(id.push(@src()))) |slot| {
        // slot gives some info that should be passed to the virtual content scroller
        // the virtual content scroller needs to know :: where am I on the screen (approx., with some margin for error eg
        // if it is not yet known if an overscroll needs to be handled yet it should report extra space just in case an
        // overscroll is handled)
        // the child scroller needs some way to tell the parent that it has overscrolled vertically, afterwhich
        // the parent will apply scroll immediately for this frame and invalidate b/c it may not have drawn
        // any stuff above

        var child_scroller = VirtualScroller{};

        slot.put(child_scroller.report()); // a report on overscroll. eg : you scrolled to the top in the child scroller, the
        // parent scroller needs to hear about this and scroll up.
    }

    root_scroller.put(scroller.report());
}
