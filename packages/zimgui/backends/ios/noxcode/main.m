// clang -isysroot (xcrun --sdk iphonesimulator --show-sdk-path) -framework Foundation -framework UIKit -lobjc -o Untitled.app/main main.m
// xcrun simctl boot 80D6FE0C-6920-484D-8B80-178E319BD077
// xcrun simctl install 80D6FE0C-6920-484D-8B80-178E319BD077 ./Untitled.app
// open (xcode-select --print-path)"/Applications/Simulator.app"
// Debug > Open System Log

#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(id)options {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    CGRect mainScreenBounds = [[UIScreen mainScreen] bounds];
    self.window = [[UIWindow alloc] initWithFrame:mainScreenBounds];
    UIViewController *viewController = [[UIViewController alloc] init];
    viewController.view.backgroundColor = [UIColor whiteColor];
    viewController.view.frame = mainScreenBounds;
    self.window.rootViewController = viewController;

    // Create a label
    UILabel *label  = [[UILabel alloc] init];
    label.text = @"Hello, world!";
    label.textColor = [UIColor blackColor];
    [viewController.view addSubview:label];

    // Create constraints that center the label in the middle of the superview.
    label.translatesAutoresizingMaskIntoConstraints = NO;
    NSLayoutConstraint *centerX = [NSLayoutConstraint constraintWithItem:label
            attribute:NSLayoutAttributeCenterX
            relatedBy:NSLayoutRelationEqual
            toItem:label.superview
            attribute:NSLayoutAttributeCenterX
            multiplier:1.f
            constant:0.f];
    NSLayoutConstraint *centerY = [NSLayoutConstraint constraintWithItem:label
            attribute:NSLayoutAttributeCenterY
            relatedBy:NSLayoutRelationEqual
            toItem:label.superview
            attribute:NSLayoutAttributeCenterY
            multiplier:1.f
            constant:0.f];

    [NSLayoutConstraint activateConstraints:@[centerX, centerY]];

    [self.window makeKeyAndVisible];

    return YES;
}

@end

int main(int argc, char *argv[]) {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"%s", "Application Launched!");
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
