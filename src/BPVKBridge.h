//
//  BPVKBridge.h
//  BeeperTG
//
//  VK API client with Long Poll support.
//  NOTE: VK restricted 'messages' scope for new apps. You need either:
//        • A legacy app with messages approval, or
//        • A service token + user token obtained manually in dev console, or
//        • Use the unofficial VK Me reverse-engineered endpoints (advanced).
//

#import <Foundation/Foundation.h>

@interface BPVKBridge : NSObject

+ (instancetype)sharedInstance;

@property (nonatomic, copy, readonly) NSString *accessToken;
@property (nonatomic, assign, readonly) NSInteger vkUserId;
@property (nonatomic, assign, readonly, getter=isPolling) BOOL polling;

// ─── Auth ───
- (void)setAccessToken:(NSString *)token;
- (NSURL *)oauthURL; // Open this in SFSafariViewController or WKWebView

// ─── REST API ───
- (void)fetchConversationsWithCount:(NSInteger)count
                         completion:(void (^)(NSArray *conversations, NSError *error))completion;

- (void)fetchHistoryWithPeerId:(NSInteger)peerId
                        count:(NSInteger)count
                   completion:(void (^)(NSArray *messages, NSError *error))completion;

- (void)sendMessage:(NSString *)text
           toPeerId:(NSInteger)peerId
         completion:(void (^)(NSInteger messageId, NSError *error))completion;

// ─── Long Poll (real-time messages) ───
- (void)startLongPolling;
- (void)stopLongPolling;

@end
