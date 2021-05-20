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
    CGFloat w;
    CGFloat h;
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

typedef struct {
    CTFramesetterRef framesetter;
    CTFrameRef frame;
    CGMutablePathRef path;
    CGFloat width;
    CGFloat height;
    CGFloat width_constraint;
    CGFloat height_constraint;
} CTextLayout;

typedef struct {
    CFMutableAttributedStringRef masr;
} CAttributedString;

extern CAttributedString *objc_new_attrstring(const UInt8 *in_string_ptr, long in_string_len) {
    CAttributedString* attrstr = malloc(sizeof(CAttributedString));

    CFStringRef textString = CFStringCreateWithBytes(kCFAllocatorDefault, in_string_ptr, in_string_len, kCFStringEncodingUTF8, false);

    // Create a mutable attributed string with a max length of 0.
    // The max length is a hint as to how much internal storage to reserve.
    // 0 means no hint.
    CFMutableAttributedStringRef attrString =
        CFAttributedStringCreateMutable(kCFAllocatorDefault, 0)
    ;
    
    // Copy the textString into the newly created attrString
    CFAttributedStringReplaceString(
        attrString, CFRangeMake(0, 0), textString
    );
    CFRelease(textString);

    attrstr->masr = attrString;

    return attrstr;
}
extern void objc_drop_attrstring(CAttributedString *attrstr) {
    CFRelease(attrstr->masr);
    free(attrstr);
}
// note the range is in utf-16 code pairs so glhf
extern void objc_addattr_color(CAttributedString *attrstr, CGFloat r, CGFloat g, CGFloat b, CGFloat a) {
    // Create a color that will be added as an attribute to the attrString.
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat components[] = { r, g, b, a };
    CGColorRef red = CGColorCreate(rgbColorSpace, components);
    CGColorSpaceRelease(rgbColorSpace);

    // Set the color of the first 12 chars to red.
    CFAttributedStringSetAttribute(attrstr->masr, CFRangeMake(0, CFAttributedStringGetLength(attrstr->masr)),
        kCTForegroundColorAttributeName, red
    );
}

// bytes: u8, index: c_long
extern CTextLayout *objc_layout(CAttributedString* attrstr, CGFloat width_constraint, CGFloat height_constraint) {
    CTextLayout* tl = malloc(sizeof(CTextLayout));

    CTFramesetterRef framesetter =
        CTFramesetterCreateWithAttributedString(attrstr->masr)
    ;
    objc_drop_attrstring(attrstr);

    CGMutablePathRef path = CGPathCreateMutable();
    CGRect bounds = CGRectMake(0.0, 0.0, width_constraint, height_constraint);
    CGPathAddRect(path, NULL, bounds);

    CTFrameRef frame = CTFramesetterCreateFrame(
        framesetter, CFRangeMake(0, 0), path, NULL
    );
    // I should be able to drop the path and framesetter now right? no reason to keep them

    CFArrayRef lineArray = CTFrameGetLines(frame);
    CFIndex j = 0;
    CFIndex lineCount = CFArrayGetCount(lineArray);
    CGFloat total_height = 0;
    CGFloat h = 0;
    CGFloat ascent;
    CGFloat descent;
    CGFloat leading;
    CGFloat max_w = 0;

    for (j=0; j < lineCount; j++)
    {
        CTLineRef currentLine = (CTLineRef)CFArrayGetValueAtIndex(lineArray, j);
        double line_w = CTLineGetTypographicBounds(currentLine, &ascent, &descent, &leading);
        h = ascent + descent + leading;
        if(line_w > max_w) max_w = line_w;
        total_height += h;
    }

    // return the frame, path, framesetter
    tl->frame = frame;
    tl->framesetter = framesetter;
    tl->path = path;
    tl->width = max_w;
    tl->height = total_height;
    tl->width_constraint = width_constraint;
    tl->height_constraint = height_constraint;

    return tl;
}
extern void objc_measure_layout(CTextLayout *layout, CGFloat *w, CGFloat *h) {
    *w = layout->width;
    *h = layout->height;
}
extern void objc_display_text(CTextLayout *layout, CData *cref, CGFloat x, CGFloat y) {
    CGContextRef context = cref->context;
    // Draw the specified frame in the given context.
    CGContextSaveGState(context);

    // TODO
    CGFloat layout_height = 0.0;
    CGContextTranslateCTM(context, x, y + layout->height_constraint);
    CGContextScaleCTM(context, 1.0, -1.0);
    
    // for some reason, the text is being placed
    // in the middle of the screen? not sure why

    CTFrameDraw(layout->frame, context);

    CGContextRestoreGState(context);
}
extern void objc_drop_layout(CTextLayout *layout) {
    CFRelease(layout->frame);
    CFRelease(layout->path);
    CFRelease(layout->framesetter);
    free(layout);
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

    CData data = {.context = context, .w = self.frame.size.width, .h = self.frame.size.height};
    CRerenderKey rkey = {.view = self};
    zig_render(&data, &rkey, data.w, data.h);
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
