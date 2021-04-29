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

1: build the code

```
rm -rf Untitled.app && mkdir Untitled.app && cp ./Info.plist Untitled.app/ && zig build-obj -Dtarget=native-ios test.zig && clang -isysroot (xcrun --sdk iphonesimulator --show-sdk-path) -framework Foundation -framework UIKit -lobjc -o Untitled.app/main main.m test.o
```

2: install the app on the simulator

```
xcrun simctl install 80D6FE0C-6920-484D-8B80-178E319BD077 ./Untitled.app
```
