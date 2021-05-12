import UIKit

class AppDelegate : UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("Your code here")

        let mainScreenBounds = UIScreen.main.bounds;

        window = UIWindow();
        var viewController = UIViewController();
        viewController.view.backgroundColor = .white;
        viewController.view.frame = mainScreenBounds;
        window!.rootViewController = viewController;

        window!.makeKeyAndVisible();

        return true
    }
}

UIApplicationMain(
    CommandLine.argc,
    CommandLine.unsafeArgv, 
    nil,
    NSStringFromClass(AppDelegate.self)
)