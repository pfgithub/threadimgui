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

pub fn renderRoot(id_arg: im.ID.Arg, imev: *im.ImEvent, isc: *im.IdStateCache, wh: im.WH, content: u1) im.RenderResult {
    const id = id_arg.id;
    var ctx = imev.render();

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
