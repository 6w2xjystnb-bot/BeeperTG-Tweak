//
//  BPVKChatsController.h
//  BeeperTG
//
//  UITableViewController that renders VK conversations inside Telegram.
//

#import <UIKit/UIKit.h>

@interface BPVKChatsController : UITableViewController

// Call this when Long Poll receives a new message so the list re-sorts
- (void)refreshConversations;

@end
