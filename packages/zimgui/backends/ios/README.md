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

TODO make it possible to specify which simulator to run with

# notes:

- is it possible to use build-exe with this and have the entrypoint in zig?

it looks like it should be

# notes

swift: `swiftc -target x86_64-apple-ios13.0-simulator -sdk $(shell xcrun --sdk iphonesimulator --show-sdk-path) -o Untitled.app/main main.swift main.o`

c: `clang -isysroot $(shell xcrun --sdk iphonesimulator --show-sdk-path) -framework Foundation -framework UIKit -lobjc -o Untitled.app/main main.c`

neither  work

# notes

currently there are those black bars around the app because it's emulating a smaller screen size

to fix this, a launch image is needed

unfortunately, that seems difficult

xcode builds one in  `Base.lproj/LaunchScreen.storyboardc` which has an Info.plist and two nib files

```json
{
    "UIViewControllerIdentifiersToNibNames": {
        "UIViewController-01J-lp-oVM": "UIViewController-01J-lp-oVM"
    },
    "UIStoryboardDesignatedEntryPointIdentifier": "UIViewController-01J-lp-oVM",
    "UIStoryboardVersion": 1
}
```

and it also uses some scene thing in the plist

```json
{"UIApplicationSceneManifest": {
    "UIApplicationSupportsMultipleScenes": false,
    "UISceneConfigurations": {
        "UIWindowSceneSessionRoleApplication": [
            {
                "UISceneConfigurationName": "Default Configuration",
                "UISceneDelegateClassName": "export_sample.SceneDelegate",
                "UISceneStoryboardFile": "Main",
                "UILaunchStoryboardName": "LaunchScreen"
            }
        ]
    }
}}
```

not sure how that interacts with my current setup

there's some documentation here https://developer.apple.com/documentation/bundleresources/information_property_list/uiapplicationscenemanifest?language=objc