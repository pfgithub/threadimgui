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
