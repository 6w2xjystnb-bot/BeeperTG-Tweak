# BeeperTG — Universal Messenger Bridge inside Telegram

**Status:** Phase 1 skeleton (VK via Kate Mobile auth).  
**Target:** Jailbroken iOS 15+ with official Telegram app.

---

## 🎯 What this is

A MobileSubstrate tweak that injects into the official Telegram app and replaces the **Contacts** tab with a **VK Messages** tab.

**Phase 1** uses **Kate Mobile** credentials (`client_id=2684578`) to obtain a VK `messages`-scope token via **Direct Auth** (login+password → token instantly, no browser).

Future phases: WhatsApp, Messenger, Discord, etc.

---

## 🔑 Kate Mobile Auth (why it works)

VK restricted the `messages` scope for new apps.  
**Kate Mobile** is a legacy unofficial client whose app ID still has messages approval.

```
client_id     = 2684578
client_secret = lbzoEXrB9XHP5l8l5x5E
auth endpoint = https://oauth.vk.com/token (Direct/Password flow)
```

The tweak calls the Direct Auth endpoint directly with your login+password and receives an `access_token` + `user_id` in one shot.  
If VK requires 2FA, a fallback browser OAuth URL is also provided.

---

## 🏗 Architecture

```
Telegram.app
 └── TelegramUI (Swift)
        │
        ▼
   BeeperTG.dylib  ← MobileSubstrate
        │
        ├── Tab Bar Hook (UITabBarController fallback)
        │      └─ Inserts BPVKChatsController into tab index 2
        │
        ├── VK Bridge (Objective-C)
        │      ├─ Direct Auth (Kate Mobile keys)
        │      ├─ REST API (getConversations, getHistory, send)
        │      └─ Long Poll loop (real-time incoming messages)
        │
        └── UI Module
               └─ BPVKChatsController (UITableViewController)
                  ├─ Auth sheet (login/pass or browser)
                  └─ Conversation list with unread badges
```

---

## 🚀 GitHub Actions Build

This repo builds automatically via **GitHub Actions** on every push.

### Workflow
- **Runner:** `macos-latest`
- **Action:** [`Randomblock1/theos-action@v1`](https://github.com/Randomblock1/theos-action)
- **Output:** `.deb` package uploaded as artifact

### Trigger build manually
1. Push any commit to `main`.
2. Go to **Actions** tab → **Build BeeperTG Tweak** → wait ~2-3 min.
3. Download `BeeperTG-deb` artifact.
4. Install on jailbroken device via Filza / Sileo / Zebra.

---

## 🛠 Local Build (if you have a Mac)

```bash
git clone https://github.com/6w2xjystnb-bot/BeeperTG-Tweak.git
cd BeeperTG-Tweak
export THEOS=~/theos
make package FINALPACKAGE=1
```

Requires Theos + iOS SDKs.

---

## ⚠️ Disclaimers

- Kate Mobile credentials are **community-sourced**; VK may revoke them at any time.
- Direct Auth sends your password to `oauth.vk.com` over HTTPS. The tweak itself does **not** store your password.
- Modifying the official Telegram client violates Telegram's ToS.
- Use a test VK/Telegram account.

---

## 🔮 Roadmap

- [x] Kate Mobile Direct Auth
- [x] GitHub Actions CI
- [x] VK conversation list + Long Poll
- [ ] VK chat detail + send UI
- [ ] Reverse Telegram's real Swift tab bar (native integration)
- [ ] WhatsApp Web bridge
- [ ] Messenger / Instagram bridge
