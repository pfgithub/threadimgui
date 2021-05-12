#include <stdio.h>
#include <stdlib.h>

#include <objc/runtime.h>
#include <objc/message.h>

extern id NSApp;

struct AppDel {
    Class isa;
    id window;
};


// This is a strong reference to the class of the AppDelegate
// (same as [AppDelegate class])
Class AppDelClass;

BOOL AppDel_didFinishLaunching(struct AppDel *self, SEL _cmd, id notification) {
    self->window = objc_msgSend(objc_getClass("NSWindow"),
        sel_getUid("alloc")
    );

    self->window = objc_msgSend(self->window, 
        sel_getUid("init")
    );

    objc_msgSend(self->window, 
        sel_getUid("makeKeyAndOrderFront:"),
        self
    );

    return YES;
}

static void initAppDel(void) 
{
    AppDelClass = objc_allocateClassPair(
        (Class) objc_getClass("NSObject"),
        "AppDelegate", 0
    );

    class_addMethod(AppDelClass, 
        sel_getUid("applicationDidFinishLaunching:"), 
        (IMP) AppDel_didFinishLaunching,
        "i@:@"
    );

    objc_registerClassPair(AppDelClass);
}

void init_app(void) {
    // objc_msgSend(
    //     objc_getClass("NSApplication"), 
    //     sel_getUid("sharedApplication")
    // );

    // if (NSApp == NULL) {
    //     fprintf(stderr,"Failed to initialized NSApplication...  terminating...\n");
    //     return;
    // }

    // id appDelObj = objc_msgSend(
    //     objc_getClass("AppDelegate"), 
    //     sel_getUid("alloc")
    // );
    // appDelObj = objc_msgSend(appDelObj, sel_getUid("init"));

    // objc_msgSend(NSApp, sel_getUid("setDelegate:"), appDelObj);
    // objc_msgSend(NSApp, sel_getUid("run"));
}


int main(int argc, char** argv) {
    initAppDel();
    // init_app();
    UIApplicationMain(argc, argv, 0, NSStringFromClass(objc_getClass("AppDelegate")))
    return EXIT_SUCCESS;
}