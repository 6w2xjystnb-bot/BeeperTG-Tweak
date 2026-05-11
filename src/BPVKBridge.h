//
//  BPVKBridge.h
//  BeeperTG
//
//  VK API client with Long Poll support.
//  Uses Kate Mobile credentials for Direct auth (login+password → token).
//

#import <Foundation/Foundation.h>

@interface BPVKBridge : NSObject

+ (instancetype)sharedInstance;

@property (nonatomic, copy, readonly) NSString *accessToken;
@property (nonatomic, assign, readonly) NSInteger vkUserId;
@property (nonatomic, assign, readonly, getter=isPolling) BOOL polling;

// ─── Auth ───
- (void)setAccessToken:(NSString *)token userId:(NSInteger)userId;

// Direct auth with Kate Mobile creds (no browser needed)
- (void)directAuthWithLogin:(NSString *)login
                   password:(NSString *)password
                 completion:(void (^)(BOOL success, NSError *error))completion;

// Browser OAuth URL (fallback if direct auth fails / 2FA required)
- (NSURL *)browserOAuthURL;

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
