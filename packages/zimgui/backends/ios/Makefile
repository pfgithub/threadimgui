all:
	rm -rf Untitled.app
	mkdir -p Untitled.app
	mkdir -p zig-out
	plutil -convert binary1 -o Untitled.app/Info.plist Info.json
	cd ../../../../ && zig build -Dtarget=aarch64-ios
	cp ../../../../zig-out/lib/libapp_selector.a zig-out/zig.aarch64.a
	cd ../../../../ && zig build -Dtarget=native-ios
	cp ../../../../zig-out/lib/libapp_selector.a zig-out/zig.native.a
	# clang -isysroot $(shell xcrun --sdk iphonesimulator --show-sdk-path) -framework Foundation -framework UIKit -framework QuartzCore -framework CoreGraphics -framework CoreText -lobjc -o Untitled.app/main main.m zig-out/zig.native.a
	xcrun  -sdk iphonesimulator clang \
		-framework Foundation -framework UIKit -framework QuartzCore -framework CoreGraphics -framework CoreText \
		-lobjc -o Untitled.app/main main.m zig-out/zig.native.a
	xcrun -sdk iphoneos clang -target arm64-apple-ios13.0 \
		-framework Foundation -framework UIKit -framework QuartzCore -framework CoreGraphics -framework CoreText \
		-lobjc -o zig-out/main.ios main.m zig-out/zig.aarch64.a
run: all
	xcrun simctl install 80D6FE0C-6920-484D-8B80-178E319BD077 ./Untitled.app