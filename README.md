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

how to have nice, clean size negotiation?

so : 1 is these functions will return "Widget"s. widgets may be rendered once each (you cannot render the same widget multiple times, must call the widget fn again).

modes of widget size negotiation:

fn(width) → widget(height) | fn(height) → widget(width) | fn(width, height) → widget() | fn() → widget(width, height)

so the current layout looks like this:

```
<rect bg-gray100 [
  <if display_mode == .centered : <hcenter-1200px .shrink #> : [
    <inset-20px [
      <if w-gt-1000 : <hcols 1fr 300px # [<v gap-10px [
        // sidebar
        …sidebar_nodes.map(sn => <SidebarNode sn>)
      ]>]> : [<v gap-10px [
        // main content
        …content_nodes.map(cn => <ContentNode cn>)
      ]>]>
    ]>
  ]>
]>
```

not sure if that makes sense
