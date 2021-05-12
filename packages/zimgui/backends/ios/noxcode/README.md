# steps after reboot:

1: start the simulator (if it's not started yet)

list simulators: `xcrun simctl list`

```
xcrun simctl boot 80D6FE0C-6920-484D-8B80-178E319BD077
```

2: open the simulator (if it's not already open)

```
open (xcode-select --print-path)"/Applications/Simulator.app"
```

# steps every time:

```
make all run
```

# notes:

- is it possible to use build-exe with this and have the entrypoint in zig?

it looks like it should be

# notes

swift: `swiftc -target x86_64-apple-ios13.0-simulator -sdk $(shell xcrun --sdk iphonesimulator --show-sdk-path) -o Untitled.app/main main.swift main.o`
