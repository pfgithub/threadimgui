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
- running the windows version on linux: `zig build -Dtarget=x86_64-windows-gnu` `wine zig-cache/bin/threadimgui.exe`

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

- !! decouple id push/pop from render ctx
- there's no reason id push/pop should be in imev.render()
- at the start of a function you _must_ id push/pop, but you should not be required to imev.render()
- also: probably worth it to switch ids to `[]const u8` rather than `u64` that can collide
- this allows two things:
- pop() no longer needs a variable (zig doesn't enjoy that variable very much, it needs to be named and comes with no safety features to ensure you pop so what's the point)
- the devtools can get like super detailed information about specific things. like "oh this was rendered by this function, here's the stacktrace" eg
- I can stop being worried about id collisions
- :
- maybe make it clearer what the `@src()` does
- like imev.descend(@src()) and then the function defer calls ascend
- or something
- adding onto this, it would make it easier to put keys on things
- or about the same actually
- but like either on the individual thing renderThing(imev.descendId(@src(), index))
- or scoped {imev.descendId(@src(), index) defer undescend}
