# overview

imgui rewrite of the threadreader frontend

goals: not much for now. display some basic content.

# imgui

it's like react but for native code

hopefully it won't end up as slow as react. there are many perf advantages this has that may help with that.

renders using cairo.

unlike other imgui implementations, you can get the size of a widget before placing it on the screen. this allows for making
almost anything you could make using html/css and it is often much easier to make things because you don't have to deal with
a layout manager that's actively trying to prevent you from doing what you want.

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

MAYBE:

change `RenderResult` → `Widget` and add back the width/height properties

# notes

interaction

some methods are needed for user interaction

- clicks. things can mask other things and stuff
- tab key. pressing tab should advance to the next thing, shift-tab to the previous
- touch. touch should be supported including multitouch gestures. animations triggered by touch gestures be user-controlled
  (a "swipe left" gesture should show progress by moving an object on the screen directly rather than waiting for the gesture
  to be completed and then playing an animation)
- screenreaders. similar to the tab key but a bit different. focused items need to be able to post a text description of
  themselves, similar to setting cursors.

clicks are "easy" : consistent ids and that's it you're done

tabs: the focused object needs to be a list of ids rather than a single id

here's how it works:

say you render

```
<id=12 [
  <id=13 []>
  <id=24 []>
  <id=34 []>
]>
```

id=24 is focused

say next frame, id=24 is gone. id=34 should be loosely focused. wait how do you do that?
might take two ticks to process that. 1: uh oh that id was never used this frame. go find where the focus should be. 2: rerender, the exact same ids will be used this
frame as last frame because there were no changes (even the timestamp of this frame should be the same as the timestamp of last frame). now this time the new selection
can be rendered focused and necessary changes can be made

notes: what happens when a focused object is in a virtual scroll thing : the object loses focus when it leaves scroll unfortunately probably

"loose focus" : the "focus cursor" thing is there so next time you press tab it starts from there but there's no visual indication of the focus or anything

I'll probably ignore tab focus for now

touch will be interesting to handle, there are a bunch of things you have to do with touch you don't have to do with normal mice

---

ok so the actual idea for interaction

every rendernode will have a consistent id

? maybe

either that or special rendernodes will be created with ids

alternatively (the js approach) : callbacks

callbacks seem like a kind of bad solution though

the idea with callbacks is the callback would update a bit of persistent data. but if you need persistent data you might as well just generate an id and store it persistently
like why make a mess out of callbacks
