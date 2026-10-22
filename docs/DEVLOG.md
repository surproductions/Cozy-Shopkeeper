# Development log

## 2026-10-18 — Initial implementation

- Repository `surproductions/Cozy-Shopkeeper` was empty (no commits). Chose native Swift/SwiftUI with a separate pure-Foundation `ShopCore` package so all game rules build and test on Linux as well as in Xcode.
- Build environment: Linux container (Swift 6.1.2 installed) — no macOS, Xcode or iOS SDK. iOS compilation, simulator tests and IPA packaging therefore run in GitHub Actions on `macos-15`.
- Implemented ShopCore: content (25 products, 13 customers, 7 upgrades, 30 decorations, 5 districts, 20 quests, 16 achievements, 5 collections, 7 daily rewards), economy config, deterministic customer generation, sales/pricing/tips/reputation, restock, upgrades, decor, districts, tutorial, daily goals, daily rewards with clock-rollback protection, collections, achievements, rewarded-ad grant rules, interstitial policy, entitlement ledger, versioned saves with migration/sanitizing/backup.
- 63 ShopCore unit tests passing on Linux (Swift 6.1.2).
- 30-day economy simulation: first upgrade on day 2, reputation level 3 by day 7, Flower Lane (1,200 coins, reputation 3) is a medium-term goal; no softlocks (a relief grant covers zero-stock + zero-coins).
- Built the SwiftUI app: shop scene, customer card with pricing, stockroom, upgrades, decor with preview, journal, goals/achievements/collections/daily gift, town map, settings, debug diagnostics, tutorial, toasts, coin bursts, StoreKit 2, audio, haptics.
- Generated original audio (7 SFX + 44 s music-box loop) and app icon from scripts.

## CI status

See the GitHub Releases page and `ci-logs/run-N` branches for each build's actual results.
