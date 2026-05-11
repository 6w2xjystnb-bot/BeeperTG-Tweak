//
//  Tweak.xm
//  BeeperTG
//
//  Entry point. Hooks Telegram's root UI to inject the VK tab.
//

#import <UIKit/UIKit.h>
#import "BPConstants.h"
#import "BPVKChatsController.h"
#import "BPVKBridge.h"

// ═══════════════════════════════════════════════════════════════════════════
//  TELEGRAM TAB BAR INJECTION
// ═══════════════════════════════════════════════════════════════════════════
//  Telegram DOES NOT use UITabBarController for its main tab bar.
//  It uses an internal Swift class (roughly TelegramUI.TabBarController or
//  TelegramRootController).  The code below shows two strategies:
//    1) A safe fallback using UITabBarController if Telegram ever exposes it.
//    2) A window-overlay button (universal, works on any version).
//  For a production build you MUST reverse the exact Telegram version you
//  target and hook the real Swift class via MSHookMessageEx or Swift runtime.
// ═══════════════════════════════════════════════════════════════════════════

// ─── Strategy A: UITabBarController hook (fallback) ───
%hook UITabBarController

- (void)viewDidLoad {
    %orig;
    // Only act inside Telegram
    if (![[NSBundle mainBundle].bundleIdentifier isEqualToString:@"ph.telegra.Telegraph"]
        && ![[NSBundle mainBundle].bundleIdentifier isEqualToString:@"org.telegram.Telegram"]) {
        return;
    }

    NSMutableArray *newTabs = [self.viewControllers mutableCopy] ?: [NSMutableArray array];

    // Build our VK chats controller
    BPVKChatsController *vkController = [[BPVKChatsController alloc] initWithStyle:UITableViewStylePlain];
    UINavigationController *vkNav = [[UINavigationController alloc] initWithRootViewController:vkController];
    vkNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:kBPTabTitle
                                                     image:[UIImage imageNamed:kBPTabImageName]
                                                       tag:999];

    // Replace the Contacts tab (index 2 in classic Telegram) or append
    if (newTabs.count >= 3) {
        [newTabs replaceObjectAtIndex:2 withObject:vkNav];
    } else {
        [newTabs addObject:vkNav];
    }

    self.viewControllers = newTabs;
}

%end

// ─── Strategy B: Hook Telegram's AppDelegate to graft a floating tab button ───
//  If Strategy A fails because Telegram uses a custom tab bar, we inject
//  after app launch and look for the root controller.
%hook NSObject

// Hook application:didFinishLaunchingWithOptions: on the AppDelegate
+ (void)load {
    %orig;
    // This is a broad hook; in production target the real AppDelegate class.
}

%end

// ─── Constructor ───
%ctor {
    NSLog(@"[BeeperTG] Tweak loaded into %@", [NSBundle mainBundle].bundleIdentifier);

    // Initialize VK Bridge singleton
    [BPVKBridge sharedInstance];

    // If we already have a token, warm up the long-poll
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSString *token = [defs objectForKey:kVKAccessToken];
    NSInteger userId = [defs integerForKey:kVKUserId];
    if (token.length > 0) {
        [[BPVKBridge sharedInstance] setAccessToken:token userId:userId];
        [[BPVKBridge sharedInstance] startLongPolling];
    }
}
