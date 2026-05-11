//
//  BPVKBridge.m
//  BeeperTG
//
//  VK API client with Direct Auth (Kate Mobile) + Long Poll.
//

#import "BPVKBridge.h"
#import "BPConstants.h"

@interface BPVKBridge ()
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, copy, readwrite) NSString *accessToken;
@property (nonatomic, assign, readwrite) NSInteger vkUserId;
@property (nonatomic, assign, readwrite, getter=isPolling) BOOL polling;
@property (nonatomic, strong) NSURLSessionDataTask *pollTask;

// Long Poll state
@property (nonatomic, copy) NSString *lpServer;
@property (nonatomic, copy) NSString *lpKey;
@property (nonatomic, assign) NSInteger lpTs;
@end

@implementation BPVKBridge

+ (instancetype)sharedInstance {
    static BPVKBridge *inst = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ inst = [[self alloc] init]; });
    return inst;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
        cfg.timeoutIntervalForRequest = 30;
        self.session = [NSURLSession sessionWithConfiguration:cfg];

        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        self.accessToken = [d objectForKey:kVKAccessToken] ?: @"";
        self.vkUserId    = [d integerForKey:kVKUserId];
    }
    return self;
}

#pragma mark - Auth

- (void)setAccessToken:(NSString *)token userId:(NSInteger)userId {
    _accessToken = [token copy];
    _vkUserId = userId;
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setObject:token forKey:kVKAccessToken];
    [d setInteger:userId forKey:kVKUserId];
    [d synchronize];
}

// ─── Direct Auth (Kate Mobile keys) ───
//  This hits https://oauth.vk.com/token with login+password.
//  Kate Mobile client_id/secret bypass scope restrictions for messages.
- (void)directAuthWithLogin:(NSString *)login
                   password:(NSString *)password
                 completion:(void (^)(BOOL success, NSError *error))completion {
    NSString *urlStr = [NSString stringWithFormat:
        @"%@?grant_type=password&client_id=%@&client_secret=%@&username=%@&password=%@&scope=%@&v=%@",
        kVKDirectAuthURL,
        kVKClientID,
        kVKClientSecret,
        [login stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]],
        [password stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]],
        kVKScopes,
        kVKAPIVersion];

    NSURL *url = [NSURL URLWithString:urlStr];
    NSURLSessionDataTask *task = [self.session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) { completion(NO, error); return; }
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (json[@"error"]) {
                NSString *msg = json[@"error_description"] ?: json[@"error"];
                NSError *err = [NSError errorWithDomain:@"VKDirectAuth" code:-1 userInfo:@{NSLocalizedDescriptionKey: msg}];
                completion(NO, err);
                return;
            }
            NSString *token = json[@"access_token"];
            NSInteger userId = [json[@"user_id"] integerValue];
            if (token.length > 0) {
                [self setAccessToken:token userId:userId];
                completion(YES, nil);
            } else {
                completion(NO, [NSError errorWithDomain:@"VKDirectAuth" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"No token in response"}]);
            }
        });
    }];
    [task resume];
}

// ─── Browser OAuth (fallback) ───
- (NSURL *)browserOAuthURL {
    NSString *url = [NSString stringWithFormat:
        @"%@?client_id=%@&display=mobile&redirect_uri=https://oauth.vk.com/blank.html&scope=%@&response_type=token&v=%@",
        kVKOAuthAuthorizeURL, kVKClientID, kVKScopes, kVKAPIVersion];
    return [NSURL URLWithString:url];
}

#pragma mark - REST helpers

- (NSURL *)methodURL:(NSString *)method params:(NSDictionary *)params {
    NSMutableString *url = [NSMutableString stringWithFormat:@"%@%@?v=%@&access_token=%@",
                            kVKAPIBaseURL, method, kVKAPIVersion, self.accessToken];
    [params enumerateKeysAndObjectsUsingBlock:^(NSString *k, NSString *v, BOOL *stop) {
        [url appendFormat:@"&%@=%@", k, v];
    }];
    return [NSURL URLWithString:[url stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
}

- (void)performGet:(NSString *)method params:(NSDictionary *)params completion:(void (^)(NSDictionary *json, NSError *err))completion {
    NSURL *url = [self methodURL:method params:params];
    NSURLSessionDataTask *task = [self.session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) { completion(nil, error); return; }
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (json[@"error"]) {
                NSError *apiErr = [NSError errorWithDomain:@"VKAPI"
                                                      code:[json[@"error"][@"error_code"] integerValue]
                                                  userInfo:@{NSLocalizedDescriptionKey: json[@"error"][@"error_msg"]}];
                completion(nil, apiErr);
                return;
            }
            completion(json, nil);
        });
    }];
    [task resume];
}

#pragma mark - Conversations

- (void)fetchConversationsWithCount:(NSInteger)count completion:(void (^)(NSArray *, NSError *))completion {
    if (self.accessToken.length == 0) { completion(nil, [self noTokenError]); return; }
    [self performGet:@"messages.getConversations"
              params:@{@"count": @(count).stringValue, @"offset": @"0"}
          completion:^(NSDictionary *json, NSError *err) {
        if (err) { completion(nil, err); return; }
        NSArray *items = json[@"response"][@"items"];
        completion(items, nil);
    }];
}

- (void)fetchHistoryWithPeerId:(NSInteger)peerId count:(NSInteger)count completion:(void (^)(NSArray *, NSError *))completion {
    if (self.accessToken.length == 0) { completion(nil, [self noTokenError]); return; }
    [self performGet:@"messages.getHistory"
              params:@{@"peer_id": @(peerId).stringValue, @"count": @(count).stringValue}
          completion:^(NSDictionary *json, NSError *err) {
        if (err) { completion(nil, err); return; }
        NSArray *items = json[@"response"][@"items"];
        completion(items, nil);
    }];
}

- (void)sendMessage:(NSString *)text toPeerId:(NSInteger)peerId completion:(void (^)(NSInteger, NSError *))completion {
    if (self.accessToken.length == 0) { completion(0, [self noTokenError]); return; }
    [self performGet:@"messages.send"
              params:@{@"peer_id": @(peerId).stringValue,
                       @"message": text,
                       @"random_id": @((NSInteger)(arc4random_uniform(INT32_MAX))).stringValue}
          completion:^(NSDictionary *json, NSError *err) {
        if (err) { completion(0, err); return; }
        NSInteger mid = [json[@"response"] integerValue];
        completion(mid, nil);
    }];
}

- (NSError *)noTokenError {
    return [NSError errorWithDomain:@"VKAPI" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"No VK access token"}];
}

#pragma mark - Long Poll (phase 2)

- (void)startLongPolling {
    if (self.polling || self.accessToken.length == 0) return;
    self.polling = YES;
    [self obtainLongPollServer];
}

- (void)stopLongPolling {
    self.polling = NO;
    [self.pollTask cancel];
}

- (void)obtainLongPollServer {
    [self performGet:@"messages.getLongPollServer" params:@{@"lp_version": @"3"} completion:^(NSDictionary *json, NSError *err) {
        if (!self.polling) return;
        if (err) { [self retryLongPollAfter:5]; return; }
        NSDictionary *resp = json[@"response"];
        self.lpServer = resp[@"server"];
        self.lpKey    = resp[@"key"];
        self.lpTs     = [resp[@"ts"] integerValue];
        [self pollLoop];
    }];
}

- (void)pollLoop {
    if (!self.polling) return;
    NSString *url = [NSString stringWithFormat:@"https://%@?act=a_check&key=%@&ts=%ld&wait=25&mode=2&version=3",
                     self.lpServer, self.lpKey, (long)self.lpTs];
    self.pollTask = [self.session dataTaskWithURL:[NSURL URLWithString:url]
                                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (!self.polling) return;
        if (error) { [self retryLongPollAfter:3]; return; }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (json[@"failed"]) {
            [self obtainLongPollServer];
            return;
        }
        self.lpTs = [json[@"ts"] integerValue];
        NSArray *updates = json[@"updates"];
        [self handleUpdates:updates];
        [self pollLoop];
    }];
    [self.pollTask resume];
}

- (void)retryLongPollAfter:(NSTimeInterval)seconds {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self obtainLongPollServer];
    });
}

- (void)handleUpdates:(NSArray *)updates {
    for (NSArray *upd in updates) {
        NSInteger code = [upd[0] integerValue];
        if (code == 4) {
            NSInteger peerId = [upd[3] integerValue];
            NSString *text   = upd.count > 5 ? upd[5] : @"";
            NSLog(@"[BeeperTG] VK new message from %ld: %@", (long)peerId, text);
            [[NSNotificationCenter defaultCenter] postNotificationName:@"BeeperTG.VKNewMessage"
                                                                object:nil
                                                              userInfo:@{@"peerId": @(peerId), @"text": text}];
        }
    }
}

@end
