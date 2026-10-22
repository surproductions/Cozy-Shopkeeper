import Foundation
@testable import ShopCore

let testNow = Date(timeIntervalSince1970: 1_790_000_000) // 2026-09-21
let utc = TimeZone(identifier: "UTC")!

func freshEngine(seed: UInt64 = 42) -> GameEngine {
    GameEngine.newGame(seed: seed, now: testNow)
}

/// A new game with the tutorial finished, so customers are random rather than scripted.
func playingEngine(seed: UInt64 = 42) -> GameEngine {
    var engine = freshEngine(seed: seed)
    engine.skipTutorial()
    return engine
}

extension GameEngine {
    /// Test helper: places a specific visit at the counter.
    mutating func forceVisit(customer: String, product: String, quantity: Int = 1, budget: Int, giftWrap: Bool = false) -> CustomerVisit {
        state.visitCounter += 1
        state.shopDay.customersArrived += 1
        if state.customers[customer] == nil { state.customers[customer] = CustomerRecord() }
        let visit = CustomerVisit(id: state.visitCounter, customerId: customer, productId: product, quantity: quantity,
                                  maxUnitPrice: budget, wantsGiftWrap: giftWrap, attemptsUsed: 0, greeting: "Hi",
                                  isTutorial: false, isFirstVisit: false)
        state.currentVisit = visit
        return visit
    }

    mutating func setCoins(_ coins: Int) { state.coins = coins }
    mutating func setStock(_ id: String, _ qty: Int) { state.inventory[id] = qty }
    mutating func setReputation(_ rep: Int) { state.reputation = rep }
    mutating func setRelationship(_ id: String, points: Int) {
        var record = state.customers[id] ?? CustomerRecord()
        record.relationshipPoints = points
        state.customers[id] = record
    }

    /// Plays out the rest of the current day by serving whoever arrives (turning away if out of stock).
    mutating func playOutDay() {
        while !state.shopDay.isFinished {
            if state.currentVisit == nil { _ = summonNextCustomer() }
            guard let visit = state.currentVisit else { break }
            if stock(of: visit.productId) >= visit.quantity {
                _ = try? setPrice(productId: visit.productId, price: visit.maxUnitPrice)
                _ = try? serve(visitId: visit.id)
                if state.currentVisit?.id == visit.id { try? turnAway(visitId: visit.id) }
            } else {
                try? turnAway(visitId: visit.id)
            }
        }
    }
}

func tempDirectory() -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("cozy-tests-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
