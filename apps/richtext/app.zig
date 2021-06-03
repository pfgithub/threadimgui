const RichtextParagraph = union(enum) {
    paragraph: SpanEditor(RichtextSpan),
    code_block: struct {
        language: []const u8, // do a dropdown menu with a search thing
        code: ParagraphEditor(CodeLine), // syn hl based on language
    },
    image: struct {
        url: []const u8,
        alt: ?[]const u8,
        title: ?[]const u8,
    },
    table: struct {
        // headings
        // alignments
        // data
    },
    list: struct {
        items: List(ParagraphEditor(RichtextParagraph)),
        ordered: bool,
    },
    blockquote: struct {
        content: ParagraphEditor(RichtextParagraph),
    },
};

const RichtextSpan = union(enum) {
    link: struct {
        href: []const u8,
        title: ?[]const u8,
        content: RichtextSpanText,
    },
    rest: RichtextSpanText,
};
const RichtextSpanText = union(enum) {
    emoji: struct {
        kind: []const u8,
    },
    text: TextLine,
};

fn selectEmojiNode(data: SelectEmojiData) void {
    // basically
    //   if mouse_x > w/2:
    //    index = 1
    //   else
    //    index = 0
    // also, respond to cursor moves
    //   onCursorMove(crsr) if(index == 0 && crsr.left) crsr.goLeft(); if(index == 0 && crsr.right) crsr.post(1);
    //   if(index == 1 && crsr.left) crsr.post(0); if(index == 1 && crsr.right) crsr.goRight();
    // and then renderEmojiNode should do a background using the selection color if the emoji node is selected
}

fn renderEmojiNode(left_offset: f64) RenderedRichtextSpan {
    const selxn_state = useSpanSelection();

    startRectangle(.{ .w = 10, .h = 10 }); // scale with font, eg if this is in a heading do like larger.
    renderImage(id.push(@src()), imev, .{ .alt = "image alt text", .aspect = 1.0 }, b.bounds);
    endRectangle();

    return .{ .key = selxn_state, .callback = callback(imev.arenaDupe(SelectEmojiData{ .w = 10 }), selectEmojiNode) };
}

// ok text selection
//
// when you click, it goes to the root RichtextEditor and that then dispatches the click to
// you (eg the text span)
//
// then you, the text span, choose where inside yourself the cursor goes based on the mouse
// location.
//
// if you're eg an embedded component like a button, you can respond to click events yourself
// but you still need to respond to the RichtextEditor dispatched selection events. those will
// come if a click and drag was started left of you and went over you. also you need to draw
// what it looks like when you're selected. also you need to handle cursor move events and
// report the cursor location and stuff
//
//
//
// how do these richtext editor-dispatched events work? - this is part of the reason to switch
// to callbacks. selection should never change anything's layout so it can all be done in event
// handlers. (but obviously the event handlers will invalidate because the selection needs to be drawn)
//
// ok how do these events work
//
// so with keys it's kinda complicated because stuff needs to be passed up and down and you make
// a mess
//
// it seems relatively easy with callbacks

// the richtext editor
// an array of paragraphs, kinda similar to google forms but very different
// some notes for making a good wyswig markdown editor using this
// - pressing enter should make a <br>. pressing enter on an empty line should cut the paragraph in two and put your cursor at the start of the
//   second half w/ an empty line
// - when you have a paragraph element of any kind focused (eg image, paragraph, blockquote) there should be a thing on the right you can drag
//   to reorder it. this should have a max 100ms animation to collapse everything down into one line descriptions of what they are and keep the
//   dragging one in its same position on screen. this should have 0 lag and feel amazing to use to compensate for how frequently these are done
//   badly. it should be possible on mobile to drag that with one finger and scroll with another finger. it should be possible on desktop to use
//   arrow keys to reorder rather than the mouse.
// - some things eg typing `- ` on the start of a line should make a list paragraph. deleting a bullet point in a list paragraph should split
//   the list in half and put a paragraph in the middle.
// - text selection should work over paragraphs, spans, …. you should be able to select from midway through a paragraph into a paragraph
//   inside a list inside a blockquote and typing should replace text and behave as expected
// - undo/redo. everything needs it.
// - code editor. it should syntax highlight based on the specified language. if it just supports zig and json, for now the syntax highlighting
//   can just be per-line tokenization. syntax highlighting should not split things into spans. or should it? I don't think it should.
// - the richtext editor is a core component of zimgui. everyone needs a richtext editor. it should be exposed through an api similar to slate's
//   api to allow for complete control with a strong core. the richtext editor should power all built in text editing components in zimgui,
//   eg: single line plaintext inputs, multi-line plaintext inputs, those dropdown menus with a search field, ….
// - the richtext editor should use virtual scrolling as much as possible, including in component trees (paragraph > paragraph > span).
// - the richtext editor should only ever support root > paragraph[] > span. if someone wants paragraphs in a span, they must make a span item
//   containing another richtext editor. text selection will not work across this border. it should be possible to make undo work across this
//   border, but that may require doing a centralized data storage core thing which would be *very useful* but I probably won't do.
