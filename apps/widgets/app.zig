const std = @import("std");
const im = @import("imgui");

// widgets with focus

const ButtonKey = struct {
    active: bool,
    clicked: bool,

    mouse: im.ClickableState,
    focus: im.FocusableState,
    hotkey: ?im.HotkeyState,

    pub const Opts = struct {};
    pub fn render(
        key: ButtonKey,
        id_arg: im.ID.Arg,
        imev: *im.ImEvent,
        isc: *im.IdStateCache,
        opts: ButtonOpts,
        text: []const u8,
    ) im.Widget {
        // render

        // - render the text (and make it screenreader-usable)
        // - how to make trees? like the text is inside the button
        //   so to go letter by letter do you have to actually
        //   the screenreader might do that automatically I need
        //   to look more at the apis

        if (im.hotkey) |hk| {
            ctx.place(hk.render(), im.Point.origin);
        }

        if (key.focus.display_focus_ring) { // true if the focus was initiated via keyboard or screenreader or through
            ctx.place(key.focus.postPosition(.{ .w = 0, .h = 0 }, .visible));
            // displays a default focus ring. also used for screenreaders.
        }
    }
};
pub fn useButton(id_arg: im.ID.Arg) ButtonKey {
    //
    var clicked_this_frame = false;

    if (key.mouse.focused) |mfocus| {
        if (mfocus.mouse_down) {
            key.focus.focus(.mouse); // .mouse = don't show focus ring, .keyboard = show focus ring
        }
        if (mfocus.mouse_up and mfocus.hover) {
            clicked_this_frame = true;
        }
    }
    if (key.focus.focused) |ffocus| {
        // for key repeat and stuff, but this doesn't open a keyboard on mobile or get ime events
        const hotkey = imev.useHotkey(id.push(@src()), .enter);
        // should you just be able to useHotkey anywhere or should it be like ffocus.useHotkey?
        // - I think ffocus.useIME() should be a thing but not useHotkey
        if (hotkey.press) {
            clicked_this_frame = true;
        }
    }

    const focus = imev.useFocusable(id.push(@src()));

    return .{ .clicked = clicked_this_frame };
}

pub fn renderRoot(id_arg: im.ID.Arg, imev: *im.ImEvent, isc: *im.IdStateCache, wh: im.WH, unused: u1) im.RenderResult {
    const id_a = id_arg.id;
    var ctx = imev.render();

    ctx.place(im.primitives.rect(imev, wh, .{ .bg = .gray100 }), im.Point.origin);

    // const btn = useButton(id.push(@src()));

    // if (btn.clicked) {
    //     std.log.info("Button clicked!");
    // }

    var items_lm = im.HLayoutManager.init(imev, .{ .max_w = wh.w - 16, .gap_x = 8, .gap_y = 8 });

    for (im.range(100)) |_, i| {
        const id = id_a.pushIndex(@src(), i);
        var sctx = imev.render();

        const clicked_key = imev.useClickable(id.push(@src()));
        //const focused_key = imev.useFocus(id.push(@src()), .keyboard);
        // focused_key.render(); position doesn't matter
        // if(clicked_key.mouse down this frame) focused_key.setFocused()

        var hovering: bool = false;
        if (clicked_key.focused) |f| {
            if (f.hover) {
                f.setCursor(imev, .pointer);
                hovering = true;
            }
            if (f.click) {
                std.log.info("clicked {d} with mouse", .{i});
            }
        }

        const item_wh: im.WH = .{ .w = 25, .h = 25 };

        sctx.place(im.primitives.rect(imev, .{ .w = 25, .h = 25 }, .{ .bg = if (hovering) .gray300 else .gray200, .rounded = .sm }), im.Point.origin);
        const stxt = im.primitives.text(imev, .{ .size = .sm, .color = .white }, imev.fmt("{d}", .{i}));
        sctx.place(stxt.node, item_wh.setUL(im.Point.origin).positionCenter(stxt.wh).ul());
        sctx.place(clicked_key.key.node(imev, item_wh), im.Point.origin);

        // <size=25x25|
        //   <rect .bg-gray200.rounded-sm>
        //   <center| <text .font-sm.text-white "{d}" .{i}> |>
        //   <clicked_key.render>
        // |>

        items_lm.put(.{ .wh = item_wh, .node = sctx.result() }) orelse break;
    }

    const built_v = items_lm.build();
    ctx.place(built_v.node, .{ .x = 8, .y = 8 });

    // there needs to be a way so:
    // buttons inset their content by some amount
    // to make a button that's sized the width of the parent, the content needs to know its size
    // wait why can't you just render a button and then add the content after
    // you should be able to do that
    // just say renderButton().setContent()

    // right because uuh
    // if the height isn't known can you render the button?
    // that's why uuh
    // ok this makes it into a 3-step then. it's doable if needed.
    // like you can say prepare to render a button with width x and unknown height
    // then get its content width and render the child node with that size
    // then render the button around the content node
    // the useButton() could probably make that size itself so it doesn't have to be 3-step
    // but you may need to have the result from useButton before you have the size, nvm

    // const content = im.primitives.text(imev, .{ .size = .sm, .color = .white }, "Click!");
    // const rendered = btn.render(.{ .content_size = .{ .w = content.wh.w, .h = content.wh.h } });
    // rendered.setContent(content.node, content.wh); // rendered.content_wh
    // ctx.place(btn_rendered.node, im.Point.origin);

    // ok yeah so if you want uuh
    // if you want to make a button with content sized to the width of the content area
    // content = btn.render();

    // focusable thing
    // const clicked = imev.useClickable();
    // const focused = imev.useFocusable(.interactive); // .interactive gives it keyboard focus with tab, .static makes it screenreader focusable
    //                                                  // how to make screenreader things eg in text you need to be able to enter the text and read
    //                                                  // character by character and paragraph by paragraph?
    // if(clicked.mousedown) focused.focus();
    // if(focused) |f| {
    //     if(imev.screenreader()) f.screenreaderMsg("", .{}, "", .{}, "", .{}); // have to figure out gtk's accessability api to see what is needed
    //     const commit_msg = f.useKeyboard();
    // }

    return ctx.result();
}
