# Cozy Shopkeeper

A cozy, offline iPhone shopkeeping game. Welcome neighbors, set fair prices, restock your shelves, decorate, befriend regulars, and grow from one little shop in Maple Corner to a second shop on Flower Lane.

Native **Swift / SwiftUI**, iOS 17+, portrait iPhone. No backend, no accounts, no third-party SDKs. All characters, products, art, sound and music are original (art is drawn in code; audio is synthesized by `scripts/generate_audio.py`).

## What's in the game

- **Shop scene** — illustrated interior that changes with your decorations, stocked shelves, a window whose light shifts through the day, and customers who walk up with a request.
- **Selling** — set the price per product; customers buy, hesitate (one more try), or leave. Fair prices sell, cheap prices sell with thin profit, steep prices get refused. Tips depend on happiness, coziness, gift wrapping and your register upgrade.
- **Stockroom** — 25 products in 8 categories and 3 rarities, restock costs, fair price, profit per unit, capacity limits.
- **7 upgrades** with visible effects (shelf tiers, stock capacity, customers per day, tips, supplier discount, gift wrapping, reputation).
- **Decor** — 30 decorations across 10 slots with live preview before buying; keepsakes earned from friendships, collections and daily gifts.
- **Customer journal** — 13 original customers (shoppers, regulars, a bargain hunter, gift buyers, collectors, a scholar, travelers, a VIP) with hearts, regular status (their budget is revealed) and friendship gifts.
- **Goals** — 3 daily goals per calendar day (always achievable), 16 achievements/milestones, 5 collections, 7-day daily gift strip that never resets if you miss a day.
- **Town map** — Maple Corner and Flower Lane are playable; Book Quarter, Seaside Promenade and Winter Village are shown as locked "future update" previews and cannot be entered.
- **Settings** — music/SFX volume, haptics, reduce motion, larger text, high contrast, restore purchases, privacy, credits, issue reporting, reset progress, version/build.

## Project layout

```
ShopCore/          Swift package: all game rules (pure Foundation, builds/tests on Linux & macOS)
  Content/         Products, customers, upgrades, decor, districts, quests, achievements
  Gameplay/        GameEngine, EconomyConfig (every tunable number), seeded RNG, day clock
  Progression/     Daily goals, daily gifts, collections, achievements
  Persistence/     Versioned save format, migrations, sanitizer, atomic file store + backup
  Monetization/    Rewarded-ad grant rules, interstitial policy, entitlement ledger
  Analytics/       Event schema
  Tests/           63 unit tests
App/
  Sources/App      App entry + scene lifecycle
  Sources/Core     GameStore (engine ↔ SwiftUI ↔ services), theme
  Sources/UI       Shop, Inventory, Upgrades, Decor, Customers, Quests, Map, Settings, Art
  Sources/Services Audio, Ads (abstraction), Purchases (StoreKit 2), Analytics (local only)
  Resources        Asset catalog (icon), audio
  Tests, UITests   App-level unit tests and a first-session UI smoke test
project.yml        XcodeGen spec (the .xcodeproj is generated, not committed)
scripts/           Audio/icon generators, CI signing/export helpers
docs/              Development log and release checklist
```

## Build

Requirements: macOS with Xcode 16+, and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
swift test --package-path ShopCore     # core rules — also runs on Linux
xcodegen generate                      # creates CozyShopkeeper.xcodeproj
open CozyShopkeeper.xcodeproj          # run on a simulator or device
```

The scheme uses `App/CozyShopkeeper.storekit`, so the Remove Ads purchase works in the simulator with StoreKit testing.

## CI and the IPA

`.github/workflows/ios.yml` runs on every push to `main` on a GitHub-hosted macOS runner:

1. Runs the ShopCore tests.
2. Generates the project and archives a Release build.
3. Packages **`Cozy-Shopkeeper-unsigned.ipa`** and publishes it on a GitHub Release with SHA-256 checksums.
4. If signing secrets exist, also exports a **signed `Cozy-Shopkeeper.ipa`**.
5. Runs simulator unit + UI tests and records the result on the release.
6. Pushes the build logs to a `ci-logs/run-N` branch.

### Installing the unsigned IPA

An unsigned IPA cannot be installed as-is. Sign it on install with a sideloading tool (Sideloadly or AltStore) using your Apple ID. With a free Apple ID the app expires after 7 days.

### App Store signing and TestFlight upload

When these repository secrets exist, CI also archives with Xcode automatic (cloud-managed) signing, exports **`Cozy-Shopkeeper-AppStore.ipa`**, and uploads it to App Store Connect, where it shows up in TestFlight:

| Secret | Value |
|---|---|
| `APPLE_TEAM_ID` | Your 10-character Team ID |
| `ASC_KEY_ID` | App Store Connect API key ID |
| `ASC_ISSUER_ID` | App Store Connect issuer ID |
| `ASC_KEY_P8` | Contents of `AuthKey_XXXX.p8` (raw text or base64) |

The API key needs the **Admin** role so Xcode can create the distribution certificate and provisioning profile. The upload only succeeds once the app record exists in App Store Connect (see `docs/APP_STORE.md`). The App Store IPA cannot be sideloaded; use the unsigned one for that.

## In-app purchase setup

Product ID: `com.surproductions.cozyshopkeeper.removeads` (non-consumable, "Remove Ads"), defined in `ShopCore/Sources/ShopCore/Monetization/Monetization.swift`. To sell it for real, create the same product in App Store Connect. Until then the Settings screen shows "This purchase isn't available right now" on device. Purchases are granted only from StoreKit-verified transactions; restore uses `AppStore.sync()`.

## Ads

No ad SDK is bundled, so **Release builds never show ads** (`NoAdNetworkProvider`). The rules are ready for one: rewarded bonuses are granted only on a confirmed completion, and interstitials only appear after a closed shop day, never during the tutorial or first 15 minutes, after 3+ completed days, with a 5-minute cooldown and 2-per-session cap, and never for Remove Ads owners. To integrate a network, implement `AdProviding` in `App/Sources/Services/Ads/AdService.swift`. Debug builds include a simulator for testing these flows from the diagnostics panel.

## Analytics

Events (first_open, sale_complete, upgrade_purchased, …) are defined in `ShopCore/Analytics` and recorded **locally only** — nothing is uploaded. Plug a real service into `AnalyticsSink`. No personal data is included.

## Diagnostics (Debug builds only)

Settings → long-press the version number: player state, save health, entitlements, ad state, recent events and coin cheats. Compiled out of Release.

## Saves

JSON in Application Support, written atomically after each change (debounced) and when the app backgrounds, with a last-good backup. Saves are versioned with migrations; missing fields fall back to defaults and impossible values are repaired on load. Daily rewards use the latest calendar day ever seen, so moving the clock back or changing time zone can't farm rewards.
