import XCTest
@testable import ShopCore

final class PersistenceTests: XCTestCase {
    // 12. Save/load consistency
    func testRoundTripPreservesEverything() throws {
        var engine = playingEngine()
        engine.setCoins(900)
        try engine.buyUpgrade(ContentIDs.Upgrade.stockroom)
        try engine.buyDecoration("sage_stripes")
        try engine.setPrice(productId: "clay_mug", price: 21)
        _ = engine.refreshCalendarDay(now: testNow, timeZone: utc)
        _ = try engine.claimDailyReward(now: testNow, timeZone: utc)
        _ = engine.summonNextCustomer()
        var settings = engine.state.settings
        settings.musicVolume = 0.25
        settings.reducedMotion = true
        engine.updateSettings(settings)

        let data = try SaveCodec.encode(engine.state, appVersion: "1.0", now: testNow)
        let loaded = try SaveCodec.decode(data)
        XCTAssertEqual(loaded, engine.state)
    }

    func testFileStoreWritesAtomicallyAndKeepsBackup() throws {
        let dir = tempDirectory()
        let store = FileSaveStore(directory: dir)
        var engine = playingEngine()
        try store.save(engine.state, appVersion: "1.0")
        XCTAssertFalse(store.hasBackup)
        engine.setCoins(777)
        try store.save(engine.state, appVersion: "1.0")
        XCTAssertTrue(store.hasBackup)
        let result = store.load()
        XCTAssertEqual(result.source, .primary)
        XCTAssertEqual(result.state?.coins, 777)
    }

    // 13. Migrations and invalid-save recovery
    func testCorruptPrimaryFallsBackToBackup() throws {
        let dir = tempDirectory()
        let store = FileSaveStore(directory: dir)
        var engine = playingEngine()
        engine.setCoins(321)
        try store.save(engine.state, appVersion: "1.0")
        try store.save(engine.state, appVersion: "1.0")
        try Data("{ not json".utf8).write(to: store.primaryURL)
        let result = store.load()
        XCTAssertEqual(result.source, .backup)
        XCTAssertEqual(result.state?.coins, 321)
        XCTAssertFalse(result.problems.isEmpty)
    }

    func testMissingSaveStartsFresh() {
        let store = FileSaveStore(directory: tempDirectory())
        let result = store.load()
        XCTAssertNil(result.state)
        XCTAssertEqual(result.source, .fresh)
    }

    func testBareStateFromFormatZeroMigrates() throws {
        let engine = playingEngine()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let bare = try encoder.encode(engine.state)
        let loaded = try SaveCodec.decode(bare)
        XCTAssertEqual(loaded.coins, engine.state.coins)
        XCTAssertEqual(loaded.inventory, engine.state.inventory)
    }

    func testMissingFieldsUseDefaults() throws {
        let json = #"{"formatVersion":1,"savedAt":0,"appVersion":"1.0","state":{"coins":55,"inventory":{"honey_bun":3}}}"#
        let state = try SaveCodec.decode(Data(json.utf8))
        XCTAssertEqual(state.coins, 55)
        XCTAssertEqual(state.inventory["honey_bun"], 3)
        XCTAssertEqual(state.equippedDecorations["floor"], "oak_boards")
        XCTAssertEqual(state.currentDistrict, "maple_corner")
        XCTAssertEqual(state.settings, GameSettings())
    }

    func testFutureVersionIsRejectedNotMangled() {
        let json = #"{"formatVersion":99,"state":{"coins":5}}"#
        XCTAssertThrowsError(try SaveCodec.decode(Data(json.utf8))) { XCTAssertEqual($0 as? SaveError, .fromFutureVersion(99)) }
    }

    func testSanitizerRepairsImpossibleValues() throws {
        var state = playingEngine().state
        state.coins = -500
        state.reputation = -3
        state.inventory["honey_bun"] = 9999
        state.inventory["ghost_item"] = 4
        state.prices["honey_bun"] = -1
        state.upgradeLevels["stockroom"] = 99
        state.equippedDecorations["wallpaper"] = "midnight_stars" // not owned
        state.unlockedDistricts.insert("winter_village")
        state.currentDistrict = "winter_village"
        state.customers["ghost"] = CustomerRecord()
        let clean = SaveCodec.sanitize(state)
        XCTAssertEqual(clean.coins, 0)
        XCTAssertEqual(clean.reputation, 0)
        XCTAssertEqual(clean.upgradeLevels["stockroom"], 4)
        XCTAssertEqual(clean.inventory["honey_bun"], 40)
        XCTAssertNil(clean.inventory["ghost_item"])
        XCTAssertEqual(clean.prices["honey_bun"], 1)
        XCTAssertEqual(clean.equippedDecorations["wallpaper"], "cream_plaster")
        XCTAssertEqual(clean.currentDistrict, "maple_corner")
        XCTAssertFalse(clean.unlockedDistricts.contains("winter_village"))
        XCTAssertNil(clean.customers["ghost"])
    }

    func testSaveMidCustomerRestoresTheSameCustomer() throws {
        var engine = playingEngine()
        let visit = engine.summonNextCustomer()!
        let data = try SaveCodec.encode(engine.state, appVersion: "1.0", now: testNow)
        var restored = GameEngine(state: try SaveCodec.decode(data))
        XCTAssertEqual(restored.state.currentVisit, visit)
        XCTAssertNil(restored.summonNextCustomer(), "no duplicate customer after restart")
        _ = try restored.serve(visitId: visit.id)
    }

    // 17. Offline behavior — the whole loop runs with no services at all.
    func testFullLoopRunsWithoutAnyServices() throws {
        var engine = playingEngine()
        engine.playOutDay()
        try engine.closeDay()
        engine.playOutDay()
        try engine.closeDay()
        XCTAssertEqual(engine.state.stats.daysCompleted, 2)
    }

    // 20. Accessibility settings persist
    func testAccessibilitySettingsPersistAndClamp() throws {
        var engine = playingEngine()
        var settings = GameSettings()
        settings.reducedMotion = true
        settings.largerText = true
        settings.highContrast = true
        settings.hapticsEnabled = false
        engine.updateSettings(settings)
        let data = try SaveCodec.encode(engine.state, appVersion: "1", now: testNow)
        let loaded = try SaveCodec.decode(data)
        XCTAssertTrue(loaded.settings.reducedMotion)
        XCTAssertTrue(loaded.settings.largerText)
        XCTAssertFalse(loaded.settings.hapticsEnabled)

        let wild = #"{"formatVersion":1,"state":{"coins":1,"settings":{"musicVolume":7,"sfxVolume":-2}}}"#
        let clamped = try SaveCodec.decode(Data(wild.utf8))
        XCTAssertEqual(clamped.settings.musicVolume, 1)
        XCTAssertEqual(clamped.settings.sfxVolume, 0)
    }
}

final class MonetizationTests: XCTestCase {
    // 16. Ad completion versus early dismissal
    func testRewardedBonusOnlyOnCompletion() throws {
        var engine = playingEngine()
        XCTAssertThrowsError(try engine.grantRewardedDayBonus(result: .completed)) { XCTAssertEqual($0 as? GameError, .dayStillOpen) }
        engine.playOutDay()
        let coins = engine.state.coins
        for result in [AdResult.dismissedEarly, .unavailable, .failed("network")] {
            XCTAssertThrowsError(try engine.grantRewardedDayBonus(result: result)) { XCTAssertEqual($0 as? GameError, .adNotCompleted) }
        }
        XCTAssertEqual(engine.state.coins, coins)
        XCTAssertTrue(engine.isRewardedDayBonusOffered)
        let amount = try engine.grantRewardedDayBonus(result: .completed)
        XCTAssertGreaterThanOrEqual(amount, 15)
        XCTAssertEqual(engine.state.coins, coins + amount)
        XCTAssertThrowsError(try engine.grantRewardedDayBonus(result: .completed)) { XCTAssertEqual($0 as? GameError, .alreadyClaimed) }
        XCTAssertFalse(engine.isRewardedDayBonusOffered)
    }

    func testInterstitialPolicyIsConservative() {
        let policy = InterstitialPolicy()
        var state = playingEngine().state
        let later = testNow.addingTimeInterval(3600)
        XCTAssertFalse(policy.shouldShow(state: state, now: later, shownThisSession: 0, adReady: true), "too early in the game")
        state.stats.daysCompleted = 5
        XCTAssertTrue(policy.shouldShow(state: state, now: later, shownThisSession: 0, adReady: true))
        XCTAssertFalse(policy.shouldShow(state: state, now: later, shownThisSession: 0, adReady: false))
        XCTAssertFalse(policy.shouldShow(state: state, now: later, shownThisSession: 2, adReady: true), "session cap")
        XCTAssertFalse(policy.shouldShow(state: state, now: testNow.addingTimeInterval(60), shownThisSession: 0, adReady: true), "first-session grace")
        state.ads.lastInterstitialAt = later.addingTimeInterval(-60)
        XCTAssertFalse(policy.shouldShow(state: state, now: later, shownThisSession: 0, adReady: true), "cooldown")
        state.ads.lastInterstitialAt = nil
        state.tutorialStep = .goals
        XCTAssertFalse(policy.shouldShow(state: state, now: later, shownThisSession: 0, adReady: true), "never during tutorial")
        state.tutorialStep = .done
        state.entitlements.removeAds = true
        XCTAssertFalse(policy.shouldShow(state: state, now: later, shownThisSession: 0, adReady: true), "remove-ads purchase")
    }

    // 15. Purchase cancellation and verification failures
    func testEntitlementOnlyFromVerifiedPurchases() {
        XCTAssertTrue(EntitlementLedger.removeAdsOwned(afterOutcome: .verified(productId: StoreProductID.removeAds), previouslyOwned: false))
        for outcome in [PurchaseOutcome.userCancelled, .pending, .failed("x"), .productUnavailable,
                        .unverified(productId: StoreProductID.removeAds, reason: "bad signature")] {
            XCTAssertFalse(EntitlementLedger.removeAdsOwned(afterOutcome: outcome, previouslyOwned: false), "\(outcome)")
            XCTAssertTrue(EntitlementLedger.removeAdsOwned(afterOutcome: outcome, previouslyOwned: true), "never revoke on a failed retry")
        }
        XCTAssertFalse(EntitlementLedger.removeAdsOwned(afterOutcome: .verified(productId: "other"), previouslyOwned: false))
        XCTAssertTrue(EntitlementLedger.removeAdsOwned(verifiedProductIds: [StoreProductID.removeAds]))
        XCTAssertFalse(EntitlementLedger.removeAdsOwned(verifiedProductIds: []), "refund / revocation removes it")
    }
}

final class AnalyticsTests: XCTestCase {
    func testCoreEventsAreEmittedWithoutPersonalData() throws {
        var engine = freshEngine()
        engine.acknowledgeTutorial(.welcome)
        let visit = engine.summonNextCustomer()!
        _ = try engine.serve(visitId: visit.id)
        try engine.restock(productId: "honey_bun", quantity: 1)
        let names = Set(engine.drainEvents().map(\.name))
        for expected: AnalyticsEventName in [.first_open, .shop_day_start, .tutorial_step, .customer_arrive, .customer_request,
                                             .customer_discovered, .sale_complete, .first_sale, .product_restock] {
            XCTAssertTrue(names.contains(expected), "\(expected)")
        }
        XCTAssertTrue(engine.events.isEmpty, "drain clears the buffer")
    }
}
