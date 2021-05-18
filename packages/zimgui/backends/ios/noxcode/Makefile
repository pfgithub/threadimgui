all:
	rm -rf Untitled.app
	mkdir Untitled.app
	plutil -convert xml1 -o Untitled.app/Info.plist Info.json
	cd ../../../../ && zig build -Dtarget=native-ios
	clang -isysroot $(shell xcrun --sdk iphonesimulator --show-sdk-path) -framework Foundation -framework UIKit -framework QuartzCore -framework CoreGraphics -lobjc -o Untitled.app/main main.m ../../../../../zig-out/lib/libapp_selector.a
run: all
	xcrun simctl install 80D6FE0C-6920-484D-8B80-178E319BD077 ./Untitled.app