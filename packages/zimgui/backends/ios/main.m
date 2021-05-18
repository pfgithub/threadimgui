// TODO:
// https://stackoverflow.com/questions/11319170/c-as-principal-class-or-a-cocoa-app-without-objc

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

extern const char* zig_getstring(void);

struct CData;
typedef struct CData CData;
struct CRerenderKey;
typedef struct CRerenderKey CRerenderKey;

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

@interface MainView : UIView <UIGestureRecognizerDelegate>
@end

struct CData {
    CGContextRef context;
};
struct CRerenderKey {
    MainView* view;
};

extern void objc_request_rerender(CRerenderKey *rkey) {
    [rkey->view setNeedsDisplay];
}

extern void objc_draw_rect(CData *ref, CGFloat x, CGFloat y, CGFloat w, CGFloat h, CGFloat r, CGFloat g, CGFloat b, CGFloat a) {
    CGRect rectangle = CGRectMake(x, y, w, h);
    CGContextSetRGBFillColor(ref->context, r, g, b, a);
    CGContextFillRect(ref->context, rectangle);
}

extern void zig_render(CData *ref, CRerenderKey *rkey, CGFloat w, CGFloat h);
extern void zig_tap(CRerenderKey *rkey, CGFloat x, CGFloat y);

@implementation MainView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // initialize
        //   set up a UITapGestureRecognizer
        //   on tap: send a click and then a release event at the coords.
        //      in the future, these can be switched to proper tap events.
        //   also there's probably a gesture recognizer for scrolls, so
        //      use those for scrolls. alternatively, use scrollviews
        //      that are created by id and diffed and stuff.

        UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapFrom:)];
        [self addGestureRecognizer:tapGestureRecognizer];
        tapGestureRecognizer.delegate = self; // this is supposed to be the app delegate but nah
    }
    return self;
}

- (void)handleTapFrom:(UITapGestureRecognizer*)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        // handling code
        CGPoint location = [sender locationInView:self];

        CRerenderKey rkey = {.view = self};
        zig_tap(&rkey, location.x, location.y);
    }
    // exit(1);
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();

    CData data = {.context = context};
    CRerenderKey rkey = {.view = self};
    zig_render(&data, &rkey, self.frame.size.width, self.frame.size.height);
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
