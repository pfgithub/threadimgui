# building

download a latest master binary of zig from [here](https://ziglang.org/download/)

supported platforms:

- linux
- windows (wip)
- (eventually) others

if you are on windows, use `-Dtarget=native-native-gnu` otherwise you need to install some sdk or something

if you are on linux, install these packages on your system: `cairo`, `gtk+-3.0`

run the application with `zig build run`

- open devtools with `f12`
- running the windows version on linux: `zig build run -Dtarget=x86_64-windows-gnu`

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
- nodes that are not in view do not need to be rendered
- the sidebar can track properly. like the twitter sidebar is supposed to but this can actually do it because it's not html.
- I can make an inspector similar to html "inspect element"
  - this seems like it could be really fun and I want to do it
  - it can't do some things eg you can't modify properties, but you can look through all the rendered things and see where they're
    drawing and hover them to display an outline and get size and stuff
  - if I do implement property modification support it will have to "pause" the content you're editing and once you resume, any
    modified properties will be cleared
  - I'm really excited to work on this it seems super fun
- it will be possible to mix this stuff with gtk widgets. eg if I need a textarea and haven't written one yet, or if I need
  a webview to play videos and embeds it will be possible to embed these.
- eventually I can add touch support and make this into a mobile application
- eventually I can build this to wasm and make a web application, but it won't fit in as well with other websites and performance
  will probably hurt

what imgui can do:

- layout of items, and often better and easier than retained gui can
  - imgui makes it easy to make a horizontal list of buttons that overflows into a "…" button rather than onto the next line
  - imgui makes it easy to center things, both vertically and horizontally
  - imgui makes it easy to make responsive layouts
- almost everything retained gui can
- it's very fun to program for

what imgui can't do:

- match optimal performance of retained gui
  - it is very difficult to get optimal performance out of retained gui, it is much easier to get optimal performance out of imgui
- super weird constraint setups that you often don't want and are slow to compute but the retained gui toolkit forces on you anyway

advantages of this specific imgui implementation:

- centering, drawing a background behind things, and other layout things that require knowing the size of widgets before rendering them
- can be made to look good
  - rounded boxes
  - backgrounds behind things
  - smooth transitions
- tailwind css-like styling to make interfaces more consistent and to add automatic dark mode support eventually
- id generation uses source locations which makes it much better than some other libraries

disadvantages of this specific imgui implementation:

- slow
- has a very low chance of randomly glitching. this is fixable but it means it will be slightly slower. it might be worth the
  performance cost to fix though

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

focus and the tab key is kind of complicated unfortunately. it is 100% doable though, just have to keep a few anchor points for
when the focused item gets unfocused.

# sample data

generated with

```js
copy(
  JSON.stringify(temp0, (key, value) => {
    if (key === "raw_value") return "TODO";
    if (typeof value === "object" && value && "encoding_symbol" in value)
      return "TODO";
    return value;
  })
);
```

eventually, this will be done automatically through one of: (node server | embedded javascript runtime)

# notes

- rename hook functions `useX()`? like react
- `const state = blk: {const state = useState(imev, @src(), StateType); if(!state.initialized) state.value.* = StateType.init(); break :blk &state.value;}`
- uuh
- `const state = useState(imev, @src(), StateType)`
- that's what I meant
- and same for buttons
- `const button = useButton(imev, @src());`
- `place(button.value("text"))`
- oh yeah, why does buttonkey not have the widget() fn on it? fix that
- also - maybe not but what about making imev a global variable so it can just be `useButton(@src())`

# notes

- add a scrollbar?
- a fake scrollbar like you can drag it up and down but it just moves the page and not the scrollbar
- and you can click to like pagedown and stuff
- (that might reveal a minor, easily fixable bug with the scrolling system but that's probably fine)

# notes

- also: probably worth it to switch ids to `[]const u8` rather than `u64` that can collide

# notes

- go back to double-rendering frames. just make sure things all work when single rendering
- I guess a frame delay could be used rather than a same frame double render, but that's more expensive
- why : specific issues
- click in a clickable area. drag to another clickable area. release the mouse. clicking now does nothing because there was no time for the
  click focus to be removed (the click focus is removed one frame after the mouse up)
- scroll down one tick. click focus is unchanged.
- stuff like that
- first:
- think about why these need double rendering and check if it's actually true

# notes

- it's _possible_ to multithread some rendering calculations. not the rendering itself, but widget functions can be called
  on different threads when there are things to render that are passed a width/height.

# notes

- for devtools: imev.render() should → imev.render(@src()) and when devtools is enabled it should save that in the
  object thing

# notes

- `imev.fmt("{}", .{25})` should return a formatted string valid for the current frame

# notes

- overlays like the right click menu or dropdowns that can go outside the window. you'd say that you want to render an overlay and
  then, at the end of the frame, the function would be called to render the overlay but it might even be a popup window thing

# notes

- for rerenders : a rerender doesn't have to be performed unless there is a reason to perform it.
- sample: if the mouse, last frame, was hovering over a mouse event handler that does not require motion events, and the mouse is moved,
  if the mouse event handler it's hovering doesn't change, there is no need to perform a rerender

# notes

- zig features this would be helped by
- [#6965](https://github.com/ziglang/zig/issues/6965). for useState and some other things.
- destructuring, so `fn thing({id}: ID.Arg, imev: *ImEvent) {` or some other way to remove
  a variable in the current scope
- a way to remove a variable in the current scope for `for(…) {const id = …}` when the
  parent scope has `const id`

# notes

- more scrolling stuff
- do a demo of scrolling that has those two things side by side in one segment and has a segment on top and a segment on bottom
- rather than allowing scrolling to have a vertical overflow, put a box of a certain size at the bottom of the scroll window
- that means behaviour will be slightly different but it's probably fine maybe

# notes

- for ios:
- since it's build-obj, we can call `@root().main` ourselves. just make sure the root file does like `comptime {_ = @import("imgui");}`
- actually wait we also need to provide some root things like `fn log` and possibly `const os` so maybe like `pub usingnamespace @import("imgui").backend` or
  similar.

# notes

- making virtual scrollers with static content

```zig
var scroller = VScroll{};

if(scroller.item(@src())) |itm| {
  // itm has stuff it needs like the idstatecache and id and stuff
}

// dynamic content
scroller.list(@src(), some_slice, renderItem);
```

sample:

a basic threadreader view.

```
[____________sticky_navbar____________]
[   ] [_________header__________] [   ]
[   ] [    content    ] [sidebar] [   ]
[   ] [               ] [       ] [   ]
[   ] [               ] [       ] [   ]
[   ] [               ] [       ] [   ]
[   ] [_______________]_[_______] [   ]
[   ] [_________footer__________] [   ]
```

content is a dynamic list, sidebar is a dynamic list. also, that content/sidebar thing - they are two horizontally stacked scroll views. if you
scroll down on one it should scroll down on the other but it acts like the twitter sidebar thing.

ok uuh

```
fn App() {
  var scroller = VScroller.new(imev);
  if(scroller.sticky(@src())) |itm| {
    itm.put(renderNavbar(itm.id.push(@src()), itm.isc, …));
  }
  if(scroller.node(@src())) |itm| {
    itm.put(hcenter(renderContent(itm), .xl)); // that might not be possible
  }
}
fn renderContent(scroller) {

}
```

uuh

how to do that horizontal centering without ending up in a subframe that doesn't know its y position relative to the top of the screen

maybe children can be told their y positions or something

how these functions work:

currently scroll is able to fetch the previous item, but with scroller.node() it must know before rendering any below items if it's needed

so : save the previous heights of all the nodes it comes across so if it says to scroll up 25 it knows "oh I should render 2 nodes above"

and if that turns out to not be enough and there's more to render, set the imev request frame flag so a rerender will be queued

# notes

- try recreating musicplayer
- also probably have to implement that scroll stuff
- likely the way to do it is using a vertical placer thing combined with those virtual scroll functions
- additional fun stuff that could be implemented, although a base implementation is enough:
  - make that log_analysis.js a ui feature, could be neat

# notes

- rather than trying to figure out skia, try getting a cairo glfw backend working
- skia is a huge dependency
- cairo probably is too but I don't know because it's installed by the system package manager
- https://github.com/preshing/cairo-windows
- https://www.cairographics.org/manual/cairo-Win32-Surfaces.html
- differentiate rendering backends from event backends? so that rendering code can be shared between
  gtk3-cairo and windows-cairo

# notes

- how to do keyboard events:
- two types of keyboard events. raw and ime.
- to get ime events, you must have focus and request keyboard events.
- on mobile, this will show the keyboard. on desktop, this will ask for ime events.

# notes

- windows:
- use direct2d instead of gdi. it makes it easy to draw rounded rectangles and is hardware accelerated
- use directwrite text rendering
- alternatively: use cairo or skia

# notes

- router?
- it would be nice to support standard ios navigation like with pushing screens and showing those things that
  come up from the bottom and stuff and do all that with system components so it matches the system rather
  than doing it all custom.

# notes

- current ios issue:
- replicate in desktop by disabling mouse motion events
- ok so
- click and release is simple, but we currently use 3 frames instead of the expected 2 to handle it

# notes

- test backend?
- for running tests
- like post a few events and then run and see what happens and if it does the right thing

# notes

- event handling v2
- an event is recieved and we got a draw request. what to do?
- 1: get the first event and:
- - loop over last frame's items and update the thing.
- nvm this works. event stuff does need some work though, the code is quite messy.

# notes

- https://github.com/nektro/zig-tracy todo
