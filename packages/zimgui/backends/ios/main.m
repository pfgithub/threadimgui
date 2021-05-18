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

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

@interface MainView : UIView
@end

struct CData {
    CGContextRef context;
};

extern void objc_draw_rect(CData *ref, CGFloat x, CGFloat y, CGFloat w, CGFloat h, CGFloat r, CGFloat g, CGFloat b, CGFloat a) {
    CGRect rectangle = CGRectMake(x, y, w, h);
    CGContextSetRGBFillColor(ref->context, r, g, b, a);
    CGContextFillRect(ref->context, rectangle);
}

extern void zig_render(CData *ref);

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

    CData data = {.context = context};
    zig_render(&data);
}

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

    MainView *mainView = [[MainView alloc] initWithFrame:mainScreenBounds];
    [viewController.view addSubview:mainView];

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
