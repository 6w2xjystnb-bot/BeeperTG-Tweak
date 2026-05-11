//
//  BPConstants.h
//  BeeperTG
//
//  Architecture constants & VK API config
//

#ifndef BPConstants_h
#define BPConstants_h

// ═══ KATE MOBILE VK API CREDENTIALS ═══
// Kate Mobile is an unofficial VK client that has legacy 'messages' scope approval.
// These credentials are community-known values used for Direct auth flows.
// If they stop working, grab fresh ones from the latest Kate Mobile APK reverse.
static NSString * const kVKClientID       = @"2684578";
static NSString * const kVKClientSecret   = @"lbzoEXrB9XHP5l8l5x5E";
static NSString * const kVKAPIVersion     = @"5.199";
static NSString * const kVKAPIBaseURL     = @"https://api.vk.com/method/";

// Browser implicit flow (fallback)
static NSString * const kVKOAuthAuthorizeURL = @"https://oauth.vk.com/authorize";
// Direct auth endpoint (login + password → token). Works with Kate Mobile keys.
static NSString * const kVKDirectAuthURL     = @"https://oauth.vk.com/token";

// Full scope for everything we need (messages + friends + offline for no-expiry token)
static NSString * const kVKScopes         = @"messages,friends,offline,photos,docs";

// ─── NSUserDefaults keys ───
static NSString * const kBPTabEnabled     = @"BeeperTG_TabEnabled";
static NSString * const kVKAccessToken    = @"BeeperTG_VKToken";
static NSString * const kVKUserId         = @"BeeperTG_VKUserId";
static NSString * const kVKChatsCache    = @"BeeperTG_VKChatsCache";

// ─── UI Constants ───
static NSString * const kBPTabTitle       = @"VK";
static NSString * const kBPTabImageName   = @"vk_tab_icon"; // Add to BeeperTG.bundle

#endif /* BPConstants_h */
