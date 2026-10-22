import XCTest
import ShopCore
@testable import CozyShopkeeper

@MainActor
final class GameStoreTests: XCTestCase {
    private func makeStore(directory: URL? = nil) -> (GameStore, URL) {
        let dir = directory ?? FileManager.default.temporaryDirectory.appendingPathComponent("store-tests-\(UUID().uuidString)")
        return (GameStore(saveStore: FileSaveStore(directory: dir), ads: NoAdNetworkProvider()), dir)
    }

    func testNewStoreStartsFreshTutorial() {
        let (store, _) = makeStore()
        XCTAssertEqual(store.state.coins, 150)
        XCTAssertEqual(store.state.tutorialStep, .welcome)
        XCTAssertEqual(store.loadSource, .fresh)
        XCTAssertFalse(store.customersFlowing)
    }

    func testFirstSaleThroughStoreUpdatesCoinsAndPersists() {
        let (store, dir) = makeStore()
        store.acknowledgeTutorial(.welcome)
        store.perform { $0.summonNextCustomer() }
        XCTAssertNotNil(store.state.currentVisit)
        let before = store.state.coins
        store.serveCurrentCustomer()
        XCTAssertGreaterThan(store.state.coins, before)
        XCTAssertEqual(store.state.tutorialStep, .restock)
        XCTAssertNotNil(store.coinBurst)
        store.saveNow()
        XCTAssertNil(store.lastSaveError)

        let (reloaded, _) = makeStore(directory: dir)
        XCTAssertEqual(reloaded.loadSource, .primary)
        XCTAssertEqual(reloaded.state.coins, store.state.coins)
        XCTAssertEqual(reloaded.state.stats.totalSales, 1)
    }

    func testFailedActionsShowFriendlyToastAndChangeNothing() {
        let (store, _) = makeStore()
        store.skipTutorial()
        let coins = store.state.coins
        store.buyUpgrade(ContentIDs.Upgrade.shelves) // 120 — affordable
        XCTAssertEqual(store.state.coins, coins - 120)
        store.buyDecoration("midnight_stars") // 400 — not affordable
        XCTAssertEqual(store.toast?.kind, .warning)
        XCTAssertFalse(store.state.ownedDecorations.contains("midnight_stars"))
    }

    func testRewardedBonusIsNeverOfferedWithoutAnAdNetwork() {
        let (store, _) = makeStore()
        store.skipTutorial()
        store.perform { engine in
            while !engine.state.shopDay.isFinished {
                guard let visit = engine.summonNextCustomer() else { break }
                try? engine.turnAway(visitId: visit.id)
            }
        }
        XCTAssertTrue(store.isDayFinished)
        XCTAssertFalse(store.canOfferRewardedBonus)
        let coins = store.state.coins
        store.watchRewardedBonus()
        XCTAssertEqual(store.state.coins, coins)
    }

    func testResetProgressKeepsSettings() {
        let (store, _) = makeStore()
        store.updateSettings { $0.musicVolume = 0.1 }
        store.skipTutorial()
        store.resetProgress()
        XCTAssertEqual(store.state.coins, 150)
        XCTAssertEqual(store.state.tutorialStep, .welcome)
        XCTAssertEqual(store.state.settings.musicVolume, 0.1, accuracy: 0.0001)
    }

    func testPriceVerdictBands() {
        XCTAssertEqual(PriceVerdict(price: 7, recommended: 10).label.hasPrefix("Bargain"), true)
        XCTAssertEqual(PriceVerdict(price: 10, recommended: 10).label, "Fair price")
        XCTAssertEqual(PriceVerdict(price: 13, recommended: 10).label.hasPrefix("Pricey"), true)
        XCTAssertEqual(PriceVerdict(price: 20, recommended: 10).label.hasPrefix("Steep"), true)
    }

    func testDiagnosticReportHasNoPersonalData() {
        let (store, _) = makeStore()
        let report = store.diagnosticReport
        XCTAssertTrue(report.contains("Version"))
        XCTAssertFalse(report.contains("@"))
    }
}
