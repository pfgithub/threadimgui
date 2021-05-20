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

trying to get an ios build working but

- linking the zig thing directly in xcode doesn't work
  ("building for iOS, but linking in object file ... built for , for architecture arm64")
  not sure what this means or why I don't get this error when building it myself
- compiling -c doesn't link the zig thing in. also it needs like -fembed-bitcode or something
- compiling without -c links and stuff but the output doesn't link in xcode
- it may be possible to run the build without xcode but I'm not sure how. also I need to upgrade my system to run
  anything on a real ios device anyway.

the build command xcode uses

```
cd /Users/pfg/Dev/Xcode/exportsample2 &&
/Users/pfg/Downloads/Xcode-beta.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang
-target arm64-apple-ios13.0
-isysroot /Users/pfg/Downloads/Xcode-beta.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS13.0.sdk
-L/Users/pfg/Library/Developer/Xcode/DerivedData/exportsample2-ddyhedczthitqsgeevlawlmolrqo/Build/Products/Debug-iphoneos
-F/Users/pfg/Library/Developer/Xcode/DerivedData/exportsample2-ddyhedczthitqsgeevlawlmolrqo/Build/Products/Debug-iphoneos
-filelist /Users/pfg/Library/Developer/Xcode/DerivedData/exportsample2-ddyhedczthitqsgeevlawlmolrqo/Build/Intermediates.noindex/exportsample2.build/Debug-iphoneos/exportsample2.build/Objects-normal/arm64/exportsample2.LinkFileList
-Xlinker -rpath -Xlinker @executable_path/Frameworks
-dead_strip
-Xlinker -object_path_lto -Xlinker /Users/pfg/Library/Developer/Xcode/DerivedData/exportsample2-ddyhedczthitqsgeevlawlmolrqo/Build/Intermediates.noindex/exportsample2.build/Debug-iphoneos/exportsample2.build/Objects-normal/arm64/exportsample2_lto.o
-Xlinker -export_dynamic -Xlinker -no_deduplicate
-fembed-bitcode-marker
-fobjc-arc
-fobjc-link-runtime
/Users/pfg/Dev/Node/threadimgui/packages/zimgui/backends/ios/zig-out/zig.aarch64.a
-Xlinker -dependency_info -Xlinker /Users/pfg/Library/Developer/Xcode/DerivedData/exportsample2-ddyhedczthitqsgeevlawlmolrqo/Build/Intermediates.noindex/exportsample2.build/Debug-iphoneos/exportsample2.build/Objects-normal/arm64/exportsample2_dependency_info.dat
-o /Users/pfg/Library/Developer/Xcode/DerivedData/exportsample2-ddyhedczthitqsgeevlawlmolrqo/Build/Products/Debug-iphoneos/exportsample2.app/exportsample2
```

Why does this one error?

```
ld: in /Users/pfg/Dev/Node/threadimgui/packages/zimgui/backends/ios/zig-out/zig.aarch64.a(/Users/pfg/Dev/Node/threadimgui/zig-cache/o/f5e6423dfb0573f67a3bb8e56e836da5/app_selector.o), building for iOS, but linking in object file (/Users/pfg/Dev/Node/threadimgui/packages/zimgui/backends/ios/zig-out/zig.aarch64.a(/Users/pfg/Dev/Node/threadimgui/zig-cache/o/f5e6423dfb0573f67a3bb8e56e836da5/app_selector.o)) built for , for architecture arm64
clang: error: linker command failed with exit code 1 (use -v to see invocation)
```

verbose:

```
Apple clang version 11.0.0 (clang-1100.0.20.17)
Target: arm64-apple-ios13.0
Thread model: posix
InstalledDir: /Users/pfg/Downloads/Xcode-beta.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin

"/Users/pfg/Downloads/Xcode-beta.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/ld"
-demangle
-lto_library /Users/pfg/Downloads/Xcode-beta.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/libLTO.dylib
-dynamic
-arch arm64
-dead_strip
-iphoneos_version_min 13.0.0
-bitcode_bundle
-bitcode_process_mode marker
-syslibroot /Users/pfg/Downloads/Xcode-beta.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS13.0.sdk
-o /Users/pfg/Library/Developer/Xcode/DerivedData/exportsample2-ddyhedczthitqsgeevlawlmolrqo/Build/Products/Debug-iphoneos/exportsample2.app/exportsample2
-L/Users/pfg/Library/Developer/Xcode/DerivedData/exportsample2-ddyhedczthitqsgeevlawlmolrqo/Build/Products/Debug-iphoneos
-filelist /Users/pfg/Library/Developer/Xcode/DerivedData/exportsample2-ddyhedczthitqsgeevlawlmolrqo/Build/Intermediates.noindex/exportsample2.build/Debug-iphoneos/exportsample2.build/Objects-normal/arm64/exportsample2.LinkFileList
-rpath @executable_path/Frameworks
-object_path_lto /Users/pfg/Library/Developer/Xcode/DerivedData/exportsample2-ddyhedczthitqsgeevlawlmolrqo/Build/Intermediates.noindex/exportsample2.build/Debug-iphoneos/exportsample2.build/Objects-normal/arm64/exportsample2_lto.o
-export_dynamic
-no_deduplicate
/Users/pfg/Dev/Node/threadimgui/packages/zimgui/backends/ios/zig-out/zig.aarch64.a
-dependency_info /Users/pfg/Library/Developer/Xcode/DerivedData/exportsample2-ddyhedczthitqsgeevlawlmolrqo/Build/Intermediates.noindex/exportsample2.build/Debug-iphoneos/exportsample2.build/Objects-normal/arm64/exportsample2_dependency_info.dat
-framework Foundation
-lobjc
-lSystem /Users/pfg/Downloads/Xcode-beta.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/clang/11.0.0/lib/darwin/libclang_rt.ios.a
-F/Users/pfg/Library/Developer/Xcode/DerivedData/exportsample2-ddyhedczthitqsgeevlawlmolrqo/Build/Products/Debug-iphoneos

ld: in /Users/pfg/Dev/Node/threadimgui/packages/zimgui/backends/ios/zig-out/zig.aarch64.a(/Users/pfg/Dev/Node/threadimgui/zig-cache/o/f5e6423dfb0573f67a3bb8e56e836da5/app_selector.o), building for iOS, but linking in object file (/Users/pfg/Dev/Node/threadimgui/packages/zimgui/backends/ios/zig-out/zig.aarch64.a(/Users/pfg/Dev/Node/threadimgui/zig-cache/o/f5e6423dfb0573f67a3bb8e56e836da5/app_selector.o)) built for , for architecture arm64
clang: error: linker command failed with exit code 1 (use -v to see invocation)
```

Why does that error but my own build doesn't?

Mine:

```
xcrun  -sdk iphoneos clang -arch arm64 \
    -framework Foundation -framework UIKit -framework QuartzCore -framework CoreGraphics -framework CoreText \
    -lobjc -o zig-out/main.ios zig-out/zig.aarch64.a main.m -v

Apple LLVM version 10.0.1 (clang-1001.0.46.4)
Target: aarch64-apple-darwin18.5.0
Thread model: posix
InstalledDir: /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin

"/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"
-cc1
-triple arm64-apple-ios12.2.0
-Wdeprecated-objc-isa-usage
-Werror=deprecated-objc-isa-usage
-Werror=implicit-function-declaration
-emit-obj
-mrelax-all
-disable-free
-disable-llvm-verifier
-discard-value-names
-main-file-name main.m
-mrelocation-model pic
-pic-level 2
-mthread-model posix
-mdisable-fp-elim
-fno-strict-return
-masm-verbose
-munwind-tables
-target-sdk-version=12.2
-target-cpu cyclone
-target-feature +fp-armv8
-target-feature +neon
-target-feature +crypto
-target-feature +zcm
-target-feature +zcz
-target-abi darwinpcs
-fallow-half-arguments-and-returns
-dwarf-column-info
-debugger-tuning=lldb
-target-linker-version 450.3
-v
-resource-dir /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/clang/10.0.1
-isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS12.2.sdk
-Wno-atomic-implicit-seq-cst
-Wno-framework-include-private-from-public
-Wno-atimport-in-framework-header
-Wno-quoted-include-in-framework-header
-fdebug-compilation-dir /Users/pfg/Dev/Node/threadimgui/packages/zimgui/backends/ios
-ferror-limit 19
-fmessage-length 80
-stack-protector 1
-fblocks
-fencode-extended-block-signature
-fregister-global-dtors-with-atexit
-fobjc-runtime=ios-12.2.0
-fobjc-exceptions
-fexceptions
-fmax-type-align=16
-fdiagnostics-show-option
-fcolor-diagnostics
-o /var/folders/6p/zg64wfdj0g9chm1hlsj_j8q80000gn/T/main-38c148.o
-x objective-c main.m

clang -cc1 version 10.0.1 (clang-1001.0.46.4) default target x86_64-apple-darwin18.5.0
ignoring nonexistent directory "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS12.2.sdk/usr/local/include"
ignoring nonexistent directory "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS12.2.sdk/Library/Frameworks"
#include "..." search starts here:
#include <...> search starts here:
 /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/clang/10.0.1/include
 /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/include
 /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS12.2.sdk/usr/include
 /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS12.2.sdk/System/Library/Frameworks (framework directory)
End of search list.
 "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/ld" -demangle -lto_library /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/libLTO.dylib -no_deduplicate -dynamic -arch arm64 -iphoneos_version_min 12.2.0 -syslibroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS12.2.sdk -o zig-out/main.ios -framework Foundation -framework UIKit -framework QuartzCore -framework CoreGraphics -framework CoreText -lobjc zig-out/zig.aarch64.a /var/folders/6p/zg64wfdj0g9chm1hlsj_j8q80000gn/T/main-38c148.o -lSystem /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/clang/10.0.1/lib/darwin/libclang_rt.ios.a
```

Looks like getting this to run on a real ios device might have to be put off until self-hosted -ofmt=c