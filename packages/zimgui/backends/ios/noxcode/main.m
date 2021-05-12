// TODO:
// https://stackoverflow.com/questions/11319170/c-as-principal-class-or-a-cocoa-app-without-objc

#import <UIKit/UIKit.h>

extern const char* zig_getstring(void);
extern void objc_panic(void) {
    // panic
}

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(id)options {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    CGRect mainScreenBounds = [[UIScreen mainScreen] bounds];
    self.window = [[UIWindow alloc]  initWithFrame:mainScreenBounds];
    UIViewController *viewController = [[UIViewController alloc] init];
    viewController.view.backgroundColor = [UIColor whiteColor];
    viewController.view.frame = mainScreenBounds;
    self.window.rootViewController = viewController;

    // // Create a label
    // UILabel *label  = [[UILabel alloc] init];
    // label.text = @(zig_getstring());
    // label.textColor = [UIColor blackColor];
    // [viewController.view addSubview:label];

    // // Create constraints that center the label in the middle of the superview.
    // label.translatesAutoresizingMaskIntoConstraints = NO;
    // NSLayoutConstraint *centerX = [NSLayoutConstraint constraintWithItem:label
    //         attribute:NSLayoutAttributeCenterX
    //         relatedBy:NSLayoutRelationEqual
    //         toItem:label.superview
    //         attribute:NSLayoutAttributeCenterX
    //         multiplier:1.f
    //         constant:0.f];
    // NSLayoutConstraint *centerY = [NSLayoutConstraint constraintWithItem:label
    //         attribute:NSLayoutAttributeCenterY
    //         relatedBy:NSLayoutRelationEqual
    //         toItem:label.superview
    //         attribute:NSLayoutAttributeCenterY
    //         multiplier:1.f
    //         constant:0.f];

    // [NSLayoutConstraint activateConstraints:@[centerX, centerY]];

    // CAShapeLayer* shapeLayer = [CAShapeLayer layer];
    // [circleLayer setPath:[[UIBezierPath bezierPathWithOvalInRect:CGRectMake(50, 50, 100, 100)] CGPath]];
    // [shapeLayer  ]

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
