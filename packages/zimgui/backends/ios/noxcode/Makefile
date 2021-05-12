all:
	rm -rf Untitled.app
	mkdir Untitled.app
	cp ./Info.plist Untitled.app/
	zig build-obj -Dtarget=native-ios test.zig
	clang -isysroot $(shell xcrun --sdk iphonesimulator --show-sdk-path) -framework Foundation -framework UIKit -framework QuartzCore -lobjc -o Untitled.app/main main.m test.o
run: all
	xcrun simctl install 80D6FE0C-6920-484D-8B80-178E319BD077 ./Untitled.app