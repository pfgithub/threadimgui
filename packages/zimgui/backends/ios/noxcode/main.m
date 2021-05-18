// TODO:
// https://stackoverflow.com/questions/11319170/c-as-principal-class-or-a-cocoa-app-without-objc

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

extern const char* zig_getstring(void);
extern void objc_panic(void) {
    // panic
}

struct CData;
typedef struct CData CData;

extern void objc_draw_rect(CGFloat x, CGFloat y, CGFloat w, CGFloat h, CGFloat r, CGFloat g, CGFloat b, CGFloat a) {
    // [[UIColor initWithRed: r, green: g, blue: b, alpha: a] CGColor]
}

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

@interface MainView : UIView
@end

@implementation MainView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // initialize
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGContextSetLineWidth(context, 2.0);

    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();

    CGFloat components[] = {0.0, 0.0, 1.0, 1.0};

    CGColorRef color = CGColorCreate(colorspace, components);

    CGContextSetStrokeColorWithColor(context, color);

    CGContextMoveToPoint(context, 0, 0);
    CGContextAddLineToPoint(context, 300, 400);

    CGContextStrokePath(context);
    CGColorSpaceRelease(colorspace);
    CGColorRelease(color);
}

@end

struct CData {
    AppDelegate* app_delegate;
};

@implementation AppDelegate

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(id)options {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    CGRect mainScreenBounds = [[UIScreen mainScreen] bounds];
    self.window = [[UIWindow alloc]  initWithFrame:mainScreenBounds];
    UIViewController *viewController = [[UIViewController alloc] init];
    viewController.view.backgroundColor = [UIColor whiteColor];
    viewController.view.frame = mainScreenBounds;
    self.window.rootViewController = viewController;

    MainView *mainView = [[MainView alloc] initWithFrame:mainScreenBounds];
    [viewController.view addSubview:mainView];

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

    //zig_render(&c_data);

    // CAShapeLayer *circleLayer = [CAShapeLayer layer];
    // [circleLayer setPath:[[UIBezierPath bezierPathWithOvalInRect:CGRectMake(50, 50, 100, 100)] CGPath]];
    // [circleLayer setStrokeColor:[[UIColor redColor] CGColor]];
    // [circleLayer setFillColor:[[UIColor clearColor] CGColor]];
    // [[viewController.view layer] addSublayer:circleLayer];

    // CGContextRef context = UIGraphicsGetCurrentContext();
    // CGContextSetLineWidth(context, 2.0);
    // CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    // CGFloat components[] = {1.0, 0.0, 1.0, 1.0};
    // CGColorRef color = CGColorCreate(colorspace, components);
    // CGContextSetStrokeColorWithColor(context, color);
    // CGContextMoveToPoint(context, 0, 0);
    // CGContextAddLineToPoint(context, 300, 400);
    // CGContextStrokePath(context);
    // CGColorSpaceRelease(colorspace);
    // CGColorRelease(color);

    // https://developer.apple.com/documentation/uikit/uiview/1622529-drawrect?language=objc

    // maybe I should make a custom view?
    // yeah it has stuff like  setNeedsDisplay
    // and I can draw stuff with  quartz2d

    [self.window makeKeyAndVisible];

    return YES;
}

@end

int c_main(int argc, char *argv[], void *data) {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"%s", "Application Launched!");
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
