//
//  Tweak.m
//  BeeperTG
//
//  Entry point using pure Objective-C runtime swizzling.
//  NO Cydia Substrate / Logos required — works when injected via
//  ESign, KSign, Scarlet, TrollStore, or any sideloading tool.
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "BPConstants.h"
#import "BPVKChatsController.h"
#import "BPVKBridge.h"

#pragma mark - Runtime Class Discovery

static Class FindTabBarControllerClass(void) {
    int numClasses = objc_getClassList(NULL, 0);
    if (numClasses <= 0) return Nil;

    Class *classes = (Class *)malloc(sizeof(Class) * numClasses);
    numClasses = objc_getClassList(classes, numClasses);

    Class viewControllerClass = NSClassFromString(@"ViewController");
    if (!viewControllerClass) {
        for (int i = 0; i < numClasses; i++) {
            if (strcmp(class_getName(classes[i]), "ViewController") == 0) {
                viewControllerClass = classes[i];
                break;
            }
        }
    }

    Class tabBarClass = Nil;
    for (int i = 0; i < numClasses; i++) {
        const char *name = class_getName(classes[i]);
        if (strstr(name, "TabBarController") == NULL) continue;

        Class superClass = class_getSuperclass(classes[i]);
        BOOL inheritsFromVC = NO;
        while (superClass != Nil) {
            if (superClass == [UIViewController class]) {
                inheritsFromVC = YES;
                break;
            }
            if (viewControllerClass && superClass == viewControllerClass) {
                inheritsFromVC = YES;
                break;
            }
            if (strcmp(class_getName(superClass), "ViewController") == 0) {
                inheritsFromVC = YES;
                break;
            }
            superClass = class_getSuperclass(superClass);
        }
        if (inheritsFromVC) {
            tabBarClass = classes[i];
            NSLog(@"[BeeperTG] Found TabBarController class: %s", name);
            break;
        }
    }

    free(classes);
    return tabBarClass;
}

#pragma mark - Floating Action Button (FAB)

static UIButton *g_bpFabButton = nil;

static void BPAddFABToWindow(UIWindow *window) {
    if (!window || !window.rootViewController) return;
    if (g_bpFabButton && g_bpFabButton.superview == window) return;

    // Skip non-app windows (keyboard, text effects, alert, etc.)
    NSString *clsName = NSStringFromClass([window class]);
    if ([clsName hasPrefix:@"UI"]) {
        if ([clsName isEqualToString:@"UIRemoteKeyboardWindow"] ||
            [clsName isEqualToString:@"UITextEffectsWindow"] ||
            [clsName isEqualToString:@"UIAlertControllerShimPresenterWindow"] ||
            [clsName isEqualToString:@"UIStatusBarWindow"]) {
            return;
        }
    }

    UIButton *fab = [UIButton buttonWithType:UIButtonTypeCustom];
    fab.translatesAutoresizingMaskIntoConstraints = NO;
    fab.backgroundColor = [UIColor colorWithRed:0.26 green:0.52 blue:0.96 alpha:1.0]; // VK blue
    fab.layer.cornerRadius = 28;
    fab.layer.shadowColor = [UIColor blackColor].CGColor;
    fab.layer.shadowOffset = CGSizeMake(0, 3);
    fab.layer.shadowRadius = 6;
    fab.layer.shadowOpacity = 0.30;
    fab.layer.borderWidth = 2.0;
    fab.layer.borderColor = [UIColor whiteColor].CGColor;
    [fab setTitle:@"VK" forState:UIControlStateNormal];
    [fab setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    fab.titleLabel.font = [UIFont boldSystemFontOfSize:16];

    [window addSubview:fab];
    g_bpFabButton = fab;

    id<UILayoutGuide> guide = window.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [fab.widthAnchor  constraintEqualToConstant:56],
        [fab.heightAnchor constraintEqualToConstant:56],
        [fab.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor constant:-16],
        [fab.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor constant:-16]
    ]];

    fab.transform = CGAffineTransformMakeScale(0.01, 0.01);
    fab.alpha = 0;
    [UIView animateWithDuration:0.4 delay:0.2
         usingSpringWithDamping:0.6 initialSpringVelocity:0.3
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         fab.transform = CGAffineTransformIdentity;
                         fab.alpha = 1.0;
                     } completion:nil];
}

static void BPRemoveFAB(void) {
    if (g_bpFabButton) {
        [g_bpFabButton removeFromSuperview];
        g_bpFabButton = nil;
    }
}

#pragma mark - FAB Action Target

@interface BPTarget : NSObject
@end
@implementation BPTarget
- (void)bp_fabTapped:(UIButton *)sender {
    UIWindow *window = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                    if (w.isKeyWindow) { window = w; break; }
                }
            }
            if (window) break;
        }
    } else {
        window = [[UIApplication sharedApplication] keyWindow];
    }
    if (!window) return;

    UIViewController *topVC = window.rootViewController;
    while (topVC.presentedViewController) topVC = topVC.presentedViewController;

    BPVKChatsController *chatsVC = [[BPVKChatsController alloc] initWithStyle:UITableViewStylePlain];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:chatsVC];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [topVC presentViewController:nav animated:YES completion:nil];
}
@end

#pragma mark - Swizzling Helpers

static IMP BPSwizzleMethod(Class cls, SEL origSel, IMP newImp) {
    Method origMethod = class_getInstanceMethod(cls, origSel);
    if (!origMethod) {
        NSLog(@"[BeeperTG] Method %@ not found on %@", NSStringFromSelector(origSel), cls);
        return NULL;
    }
    IMP origIMP = method_getImplementation(origMethod);
    method_setImplementation(origMethod, newImp);
    return origIMP;
}

#pragma mark - Hooks

static void (*orig_viewDidLoad)(id, SEL);
static void (*orig_viewDidAppear)(id, SEL, BOOL);
static void (*orig_windowMakeKeyAndVisible)(id, SEL);

static BOOL BPIsTelegramBundle(void) {
    NSString *bid = [[NSBundle mainBundle] bundleIdentifier];
    if ([bid isEqualToString:@"ph.telegra.Telegraph"]) return YES;
    if ([bid isEqualToString:@"org.telegram.Telegram"]) return YES;
    if ([bid hasPrefix:@"org.telegram."]) return YES;
    if ([bid hasPrefix:@"ph.telegra."]) return YES;
    return NO;
}

static void hooked_viewDidLoad(id self, SEL _cmd) {
    orig_viewDidLoad(self, _cmd);
    if (!BPIsTelegramBundle()) return;

    UIWindow *window = self.view.window;
    if (window && window.rootViewController == self) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            BPAddFABToWindow(window);
        });
    }
}

static void hooked_viewDidAppear(id self, SEL _cmd, BOOL animated) {
    orig_viewDidAppear(self, _cmd, animated);
    if (!BPIsTelegramBundle()) return;

    static Class s_tabBarClass = Nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ s_tabBarClass = FindTabBarControllerClass(); });

    if (s_tabBarClass && [self isKindOfClass:s_tabBarClass]) {
        SEL setControllersSel = NSSelectorFromString(@"setControllers:selectedIndex:");
        if ([self respondsToSelector:setControllersSel]) {
            NSLog(@"[BeeperTG] TabBarController responds to setControllers:selectedIndex:");
            // Swift [ViewController] array is not constructible from ObjC easily.
            // The FAB serves as the primary entry point.
        }
        UIWindow *window = self.view.window;
        if (window) BPAddFABToWindow(window);
    }
}

static void hooked_windowMakeKeyAndVisible(id self, SEL _cmd) {
    orig_windowMakeKeyAndVisible(self, _cmd);
    if (!BPIsTelegramBundle()) return;

    UIWindow *window = (UIWindow *)self;
    if (window.rootViewController) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            BPAddFABToWindow(window);
        });
    }
}

#pragma mark - Window Become Key Observer

static void BPWindowDidBecomeKey(NSNotification *note) {
    if (!BPIsTelegramBundle()) return;
    UIWindow *window = note.object;
    if ([window isKindOfClass:[UIWindow class]]) {
        BPAddFABToWindow(window);
    }
}

#pragma mark - Constructor

__attribute__((constructor))
static void bp_tweak_init() {
    @autoreleasepool {
        if (!BPIsTelegramBundle()) {
            NSLog(@"[BeeperTG] Not Telegram, skipping hooks. Bundle: %@", [NSBundle mainBundle].bundleIdentifier);
            return;
        }
        NSLog(@"[BeeperTG] Loading into Telegram bundle: %@", [NSBundle mainBundle].bundleIdentifier);

        // Swizzle UIViewController
        orig_viewDidLoad = (void (*)(id, SEL))BPSwizzleMethod([UIViewController class],
                                                               @selector(viewDidLoad),
                                                               (IMP)hooked_viewDidLoad);
        orig_viewDidAppear = (void (*)(id, SEL, BOOL))BPSwizzleMethod([UIViewController class],
                                                                      @selector(viewDidAppear:),
                                                                      (IMP)hooked_viewDidAppear);
        // Swizzle UIWindow
        orig_windowMakeKeyAndVisible = (void (*)(id, SEL))BPSwizzleMethod([UIWindow class],
                                                                           @selector(makeKeyAndVisible),
                                                                           (IMP)hooked_windowMakeKeyAndVisible);

        // Listen for window key changes
        [[NSNotificationCenter defaultCenter] addObserverForName:UIWindowDidBecomeKeyNotification
                                                            object:nil
                                                             queue:[NSOperationQueue mainQueue]
                                                        usingBlock:^(NSNotification *note) {
                                                            BPWindowDidBecomeKey(note);
                                                        }];

        // Init VK Bridge
        [BPVKBridge sharedInstance];
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        NSString *token = [defs objectForKey:kVKAccessToken];
        NSInteger userId = [defs integerForKey:kVKUserId];
        if (token.length > 0) {
            [[BPVKBridge sharedInstance] setAccessToken:token userId:userId];
            [[BPVKBridge sharedInstance] startLongPolling];
        }

        NSLog(@"[BeeperTG] Runtime hooks installed. FAB will appear shortly.");
    }
}
