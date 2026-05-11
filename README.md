# BeeperTG — Universal Messenger Bridge inside Telegram

**Status:** Phase 1 skeleton (VK integration scaffold).  
**Target:** Jailbroken iOS 15+ with official Telegram app (`ph.telegra.Telegraph` or `org.telegram.Telegram`).

---

## 🎯 What this is

A MobileSubstrate tweak that injects into the official Telegram app and replaces the **Contacts** tab with a **VK Messages** tab.  
Future phases will add WhatsApp, Messenger, Discord, etc., turning Telegram into a Beeper-like universal chat aggregator.

---

## 🏗 Architecture

```
Telegram.app
 └── TelegramUI (Swift) — custom TabBarController
        │
        ▼
   BeeperTG.dylib  (injected via MobileSubstrate)
        │
        ├── Tab Bar Hook
        │      └─ Swizzle / extend Telegram's root tab bar
        │         and insert BPVKChatsController
        │
        ├── VK Bridge (Objective-C)
        │      ├─ OAuth (token storage in NSUserDefaults)
        │      ├─ REST API (messages.getConversations, messages.getHistory, messages.send)
        │      └─ Long Poll loop (real-time incoming messages)
        │
        └── UI Module
               └─ BPVKChatsController (UITableViewController)
                  └─ BPVKChatDetailController (future)
```

### Why this is hard

1. **Telegram's tab bar is not `UITabBarController`.**  
   It is a fully custom Swift component inside `TelegramUI`.  
   The skeleton includes a `UITabBarController` hook as a fallback, but **you must reverse your exact Telegram build** and hook the real internal class (e.g. `_TtC10TelegramUI22TelegramRootController` or similar) via `MSHookMessageEx`.

2. **VK `messages` scope is restricted.**  
   VK no longer grants `messages` permission to new apps freely.  
   Workarounds:
   - Use a **legacy VK app ID** that already has messages approval.
   - Use an **unofficial / reverse-engineered** VK Me token.
   - Poll via **VK Bots Long Poll** (limited to bot dialogs).

3. **Telegram UI is SwiftUI + AsyncDisplayKit.**  
   Re-using Telegram's native message bubbles is extremely difficult.  
   The pragmatic approach is to embed a plain `UITableViewController` (as done here) and iterate toward native-looking cells later.

---

## 🚀 Build Instructions

### Prerequisites

- macOS with Xcode + Command Line Tools
- [Theos](https://theos.dev/docs/installation) installed (`$THEOS` env var set)
- iOS device with jailbreak (Dopamine, palera1n, unc0ver, checkra1n, …)
- SSH access to the device (set `THEOS_DEVICE_IP` in Makefile)

### 1. Configure

Open `src/BPConstants.h` and fill in your VK credentials:

```objc
static NSString * const kVKClientID     = @"YOUR_VK_APP_ID";
static NSString * const kVKClientSecret = @"YOUR_VK_APP_SECRET";
```

### 2. Build & Install

```bash
cd BeeperTG-Tweak
make package install
```

Theos will compile the tweak, pack it into a `.deb`, and install it on your device via SSH.  
Telegram will be killed and restarted automatically (`killall -9 Telegram`).

### 3. Auth

1. Open Telegram.
2. Tap the new **VK** tab.
3. Tap **Auth**.
4. The console (via `oslog` or Xcode Devices) prints an OAuth URL. Open it in Safari on the device.
5. After authorisation, copy the `access_token` from the redirect URL.
6. Save it to the device:
   ```bash
   defaults write ph.telegra.Telegraph BeeperTG_VKToken "your_token_here"
   ```
   Or implement the in-app WKWebView flow (left as an exercise).

---

## 📂 File Map

| File | Purpose |
|------|---------|
| `Tweak.xm` | Entry point, constructor, tab-bar injection hooks |
| `src/BPConstants.h` | API keys, NSUserDefaults keys, UI strings |
| `src/BPVKBridge.h/.m` | VK REST API + Long Poll client |
| `src/BPVKChatsController.h/.m` | UITableView list of VK conversations |
| `BeeperTG.plist` | Substrate bundle filter (Telegram bundle IDs) |
| `Makefile` | Theos build rules |
| `control` | Debian package metadata |

---

## 🔮 Roadmap

- [x] Phase 0 — Theos skeleton & Substrate injection
- [x] Phase 1 — VK OAuth + REST bridge + conversation list
- [ ] Phase 1b — VK Long Poll polish + unread badges
- [ ] Phase 1c — VK chat detail + send messages
- [ ] Phase 2 — Reverse Telegram's real Swift tab bar and graft the tab natively
- [ ] Phase 3 — WhatsApp Web bridge (via Multi-Device QR login)
- [ ] Phase 4 — Messenger / Instagram bridge
- [ ] Phase 5 — Matrix / Beeper native bridge (pipe dream)

---

## ⚠️ Disclaimers

- This is a **proof-of-concept skeleton**. It does not compile to a fully working product without additional reverse-engineering of the target Telegram version.
- Using unofficial VK API tokens may violate VK Terms of Service.
- Modifying the official Telegram client is against Telegram's ToS and may result in account suspension.
- Use at your own risk on a test account.
