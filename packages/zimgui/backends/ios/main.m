// TODO:
// https://stackoverflow.com/questions/11319170/c-as-principal-class-or-a-cocoa-app-without-objc

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>

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

extern void objc_layout_text(void) {
    // here's the complete sample

    // Initialize a graphics context in iOS.
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGContextSaveGState(context);
    
    // Flip the context coordinates, in iOS only.
    CGContextTranslateCTM(context, 0, 500); // TODO height
    CGContextScaleCTM(context, 1.0, -1.0);
    
    // Set the text matrix.
    CGContextSetTextMatrix(context, CGAffineTransformIdentity);
    
    // Create a path which bounds the area where you will be drawing text.
    // The path need not be rectangular.
    CGMutablePathRef path = CGPathCreateMutable();
    
    // In this simple example, initialize a rectangular path.
    CGRect bounds = CGRectMake(10.0, 10.0, 200.0, 200.0);
    CGPathAddRect(path, NULL, bounds);
    
    // Initialize a string.
    CFStringRef textString = CFSTR("Hello, World! I know nothing in the world that has as much power as a word.");
    
    // Create a mutable attributed string with a max length of 0.
    // The max length is a hint as to how much internal storage to reserve.
    // 0 means no hint.
    CFMutableAttributedStringRef attrString =
            CFAttributedStringCreateMutable(kCFAllocatorDefault, 0);
    
    // Copy the textString into the newly created attrString
    CFAttributedStringReplaceString (attrString, CFRangeMake(0, 0),
            textString);
    
    // Create a color that will be added as an attribute to the attrString.
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat components[] = { 1.0, 0.0, 0.0, 0.8 };
    CGColorRef red = CGColorCreate(rgbColorSpace, components);
    CGColorSpaceRelease(rgbColorSpace);
    
    // Set the color of the first 12 chars to red.
    CFAttributedStringSetAttribute(attrString, CFRangeMake(0, 12),
            kCTForegroundColorAttributeName, red);
    
    // Create the framesetter with the attributed string.
    CTFramesetterRef framesetter =
            CTFramesetterCreateWithAttributedString(attrString);
    CFRelease(attrString);
    
    // Create a frame.
    CTFrameRef frame = CTFramesetterCreateFrame(framesetter,
            CFRangeMake(0, 0), path, NULL);
    
    // Draw the specified frame in the given context.
    CTFrameDraw(frame, context);

    CGContextRestoreGState(context);
    
    // Release the objects we used.
    CFRelease(frame);
    CFRelease(path);
    CFRelease(framesetter);
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

    objc_layout_text();
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
