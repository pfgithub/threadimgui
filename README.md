# overview

imgui rewrite of the threadreader frontend

goals: not much for now. display some basic content.

# notes

neat imgui stuff:

- completely virtual scrolling. no scrollbar. when you get to the bottom, more can be loaded.
- the super nice imgui thing you can do with virtual things is :: render one node above, current node, and below until off-screen
- nodes that are not in view do not need to be rendered
- there are some additional considerations that come along with that : these offscreen nodes need to retain state, so seperate state has to be passed around
  - I haven't figured out state yet but I will
- it's really easy to do fun stuff like :: actions, rather than wrapping, can go into a "…" button when they are too wide
  - (ok, this requires double-rendering actions unfortunately, but still pretty neat)
- here's the simplest way to store state: just store it along with initial data
- I'll probably, instead, just have two structures that are passed everywhere : initial data, item state
  - and that should work fine
  - some things will need some form of global state, eg counters when you click the counter it has to retain its value on different screens
  - that's fine and not too difficult
- huh, it might not be necessary to have a super complicated id system

# other

- sometimes, threadreader requires webviews.
- for example:
- sidebar widgets might be an embed
- youtube videos must play in a webview
- other videos will probably be put in a webview because I don't think I want to deal with implementing a video player
- suggested embeds must be a webview

how it works:

this will likely be accomplished using a gtk webview that gets rendered in with the rest of the content

for a web build (html5 canvas rather than cairo as the rendering backend | some way to render cairo to canvas?)

fixed-positioned iframes will be used I guess

# notes

how to implement horizontal stacking

here's a sample: action buttons should horizontally stack and once they go offscreen, the remaining buttons should be hidden under a "…" menu | go to the next line

```zig
// the idea is:
const mark = imev.mark();
const size = renderActionButton();
if(cpos + size > …) {
    // too big;
    mark.drop();
}else{
    mark.render(pos);
}
```

WOAH ok if this is doable we can drop a lot of things actually

like if this is doable `renderActionButton` can return its complete size and the caller can place it themselves

if this is doable there is a lot of neat stuff

the difficult part is dealing with click events - since they're frame delayed it feels like it should be doable though

ok wait this is actually really neat oh wow

another mockup:

```zig
const action_button = renderActionButton();
if(action_button.w + something > …) {
    action_button.drop();
}else{
    action_button.place(x, y);
}
```

ok so that would be amazing

also a note : it's not actually super expensive to do, you'd just put a "transform" marker in the render array and then "place" would set the transform, while "drop"
would say to skip to the specified id while rendering

so that's easy and trivial and all, but

how do click events work

so here is how click events work in the previous imgui I did

```zig
const click_state = imev.interactable(unique_consistent_id, .{.hover, .click});
if(click_state.hover) {
    … render some way idk
}
```

that's nice

but

ok so when interactable is called it can add to some array

actually it can even be mixed in with the render array

and then at the end of the frame, loop over that and determine what the event should be passed to

ok wait that's 100% doable ok nice

ok so basically

currently it's like this

```
imev.render().rect()
```

ok so a sample here I want to render some text at 10,10

```
imev.render().text("hi!").place(10, 10);
```

`.text()` returns its size

then it can be placed

so now rendering sidebar widgets is like this

```
const widget = renderSidebarWidget(… width, top …);
const loc = layout.take(widget height);
renderBackground(loc)
widget.place(loc.topLeft())
```

and since events go through this same array

ok this is really nice

ok wait how will primative rendering look

ideally

```
imev.rect(w, h).place(x, y);
imev.text("hello").place(x, y);
```

ok that's how

what does rect do

```
fn rect(wh: WH) RenderResult {
    const offset = addOffsetNode();
    addRenderNode(wh);
    return RenderNode.from(wh, offset);
}
```

then that would mean renderWidget would

```
const offset = addOffsetNode();
renderStuff…
return renderNode.from(…, offset);
```

alternatively we can have it make a little container thing

```
var node = newNode();
node.rect();
return node;
```
