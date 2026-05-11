#import <UIKit/UIKit.h>
#import <objc/runtime.h>

__attribute__((constructor))
static void bp_init() {
    NSLog(@"[BeeperTG] Loaded");
}
