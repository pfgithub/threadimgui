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