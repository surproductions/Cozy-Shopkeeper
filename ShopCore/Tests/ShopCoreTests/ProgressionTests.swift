import XCTest
@testable import ShopCore

final class CustomerTests: XCTestCase {
    func testCustomerGenerationIsDeterministic() {
        var a = playingEngine(seed: 7)
        var b = playingEngine(seed: 7)
        for _ in 0..<5 {
            let va = a.summonNextCustomer()
            let vb = b.summonNextCustomer()
            XCTAssertEqual(va, vb)
            if let va { try? a.turnAway(visitId: va.id) }
            if let vb { try? b.turnAway(visitId: vb.id) }
        }
    }

    func testRequestsAreAlwaysForAvailableProductsAndEligibleCustomers() {
        var engine = playingEngine(seed: 99)
        for _ in 0..<300 {
            if engine.state.shopDay.isFinished { _ = try? engine.closeDay() }
            guard let visit = engine.summonNextCustomer() else { continue }
            let product = engine.content.product(visit.productId)!
            XCTAssertTrue(engine.isProductAvailable(product))
            XCTAssertTrue(engine.isCustomerEligible(engine.content.customer(visit.customerId)!))
            XCTAssertTrue((1...3).contains(visit.quantity))
            try? engine.turnAway(visitId: visit.id)
        }
    }

    func testDiscoveryGrantsRewardOnce() {
        var engine = playingEngine(seed: 3)
        let coins = engine.state.coins
        let visit = engine.summonNextCustomer()!
        XCTAssertTrue(visit.isFirstVisit)
        XCTAssertEqual(engine.state.coins, coins + engine.config.discoveryRewardCoins)
        XCTAssertNotNil(engine.state.customers[visit.customerId])
        XCTAssertTrue(engine.events.contains { $0.name == .customer_discovered })
    }

    func testRelationshipsBecomeRegularsAndRevealBudget() throws {
        var engine = playingEngine()
        engine.setRelationship("mabel", points: 7)
        XCTAssertFalse(engine.isRegular("mabel"))
        let visit = engine.forceVisit(customer: "mabel", product: "honey_bun", budget: 12)
        XCTAssertFalse(engine.isBudgetRevealed(for: visit))
        guard case .sold(let r) = try engine.serve(visitId: visit.id) else { return XCTFail() }
        XCTAssertTrue(r.becameRegular)
        XCTAssertTrue(engine.isRegular("mabel"))
        let next = engine.forceVisit(customer: "mabel", product: "honey_bun", budget: 12)
        XCTAssertTrue(engine.isBudgetRevealed(for: next))
    }

    func testMaxHeartsGrantsKeepsakeOnce() throws {
        var engine = playingEngine()
        engine.setReputation(2000)
        engine.setRelationship("marlowe", points: 19)
        let visit = engine.forceVisit(customer: "marlowe", product: "berry_cordial", budget: 30)
        guard case .sold(let r) = try engine.serve(visitId: visit.id) else { return XCTFail() }
        XCTAssertEqual(r.heartGiftDecoration, "brass_compass")
        XCTAssertTrue(engine.state.ownedDecorations.contains("brass_compass"))
        let again = engine.forceVisit(customer: "marlowe", product: "berry_cordial", budget: 30)
        guard case .sold(let r2) = try engine.serve(visitId: again.id) else { return XCTFail() }
        XCTAssertNil(r2.heartGiftDecoration)
    }

    func testVipOnlyAppearsAtHighReputation() {
        let low = playingEngine()
        XCTAssertFalse(low.isCustomerEligible(low.content.customer("reginald")!))
        var high = playingEngine()
        high.setReputation(400)
        XCTAssertTrue(high.isCustomerEligible(high.content.customer("reginald")!))
    }
}

final class DayCycleTests: XCTestCase {
    func testDayEndsAfterPlannedCustomersAndCloses() throws {
        var engine = playingEngine()
        XCTAssertThrowsError(try engine.closeDay()) { XCTAssertEqual($0 as? GameError, .dayStillOpen) }
        engine.playOutDay()
        XCTAssertTrue(engine.state.shopDay.isFinished)
        XCTAssertNil(engine.summonNextCustomer())
        let summary = try engine.closeDay()
        XCTAssertEqual(summary.dayNumber, 1)
        XCTAssertEqual(summary.customersServed + summary.customersMissed, 6)
        XCTAssertEqual(engine.state.shopDay.dayNumber, 2)
        XCTAssertFalse(engine.state.shopDay.isFinished)
        XCTAssertEqual(engine.state.stats.daysCompleted, 1)
        XCTAssertThrowsError(try engine.closeDay(), "can't close the same day twice")
    }

    func testReliefPreventsSoftlock() throws {
        var engine = playingEngine()
        for id in engine.state.inventory.keys { engine.setStock(id, 0) }
        engine.playOutDay()
        engine.setCoins(0) // discovery rewards during the day don't count here
        let summary = try engine.closeDay()
        XCTAssertGreaterThan(summary.reliefCoins, 0)
        XCTAssertTrue(engine.availableProducts.contains { engine.maxRestockable(productId: $0.id) >= 3 })
    }

    func testEconomySimulationStaysHealthy() throws {
        // A simple strategy (fair prices, restock what sold, buy cheapest upgrade) should grow the shop.
        var engine = playingEngine(seed: 2026)
        for _ in 0..<20 {
            engine.playOutDay()
            try engine.closeDay()
            for product in engine.availableProducts {
                let qty = min(engine.maxRestockable(productId: product.id), 6)
                if qty > 0 { try engine.restock(productId: product.id, quantity: qty) }
                try engine.setPrice(productId: product.id, price: product.recommendedPrice)
            }
            if let cheapest = engine.content.upgrades
                .filter({ engine.upgradeLevel($0.id) < $0.maxLevel })
                .min(by: { $0.costs[engine.upgradeLevel($0.id)] < $1.costs[engine.upgradeLevel($1.id)] }),
               engine.state.coins >= cheapest.costs[engine.upgradeLevel(cheapest.id)] + 60 {
                try engine.buyUpgrade(cheapest.id)
            }
        }
        XCTAssertGreaterThanOrEqual(engine.state.stats.upgradesBought, 3, "player should afford several upgrades in 20 days")
        XCTAssertGreaterThanOrEqual(engine.reputationLevel, 2)
        XCTAssertGreaterThan(engine.state.stats.totalSales, 60)
        XCTAssertFalse(engine.canUnlockDistrict(ContentIDs.secondDistrict) && engine.state.stats.daysCompleted < 5,
                       "second district should be a medium-term goal")
    }
}

final class QuestTests: XCTestCase {
    // 10. Quest completion and reward claiming
    func testDailyGoalsGenerateProgressAndClaimOnce() throws {
        var engine = playingEngine()
        XCTAssertTrue(engine.refreshCalendarDay(now: testNow, timeZone: utc))
        XCTAssertEqual(engine.state.daily.goals.count, 3)
        XCTAssertEqual(Set(engine.state.daily.goals.map(\.questId)).count, 3)
        for goal in engine.state.daily.goals {
            XCTAssertTrue(engine.isGoalFeasible(engine.content.quest(goal.questId)!), goal.questId)
        }
        XCTAssertFalse(engine.refreshCalendarDay(now: testNow.addingTimeInterval(60), timeZone: utc), "same day keeps goals")

        engine.state.daily.goals = [GoalProgress(questId: "sell_5", progress: 0, claimed: false)]
        XCTAssertThrowsError(try engine.claimGoal("sell_5")) { XCTAssertEqual($0 as? GameError, .notEligible) }
        for _ in 0..<5 {
            let v = engine.forceVisit(customer: "pip", product: "honey_bun", budget: 20)
            if engine.stock(of: "honey_bun") == 0 { engine.setStock("honey_bun", 5) }
            _ = try engine.serve(visitId: v.id)
        }
        XCTAssertEqual(engine.state.daily.goals[0].progress, 5)
        let coins = engine.state.coins
        XCTAssertEqual(try engine.claimGoal("sell_5"), 40)
        XCTAssertEqual(engine.state.coins, coins + 40)
        XCTAssertThrowsError(try engine.claimGoal("sell_5")) { XCTAssertEqual($0 as? GameError, .alreadyClaimed) }
        XCTAssertEqual(engine.state.coins, coins + 40)
    }

    func testInfeasibleGoalsAreNeverGenerated() {
        let engine = playingEngine()
        for offset in 0..<60 {
            let key = DayClock.dayKey(for: testNow.addingTimeInterval(Double(offset) * 86_400), timeZone: utc)
            for quest in engine.generateGoals(for: key) {
                if case .sellCategory(let cat) = quest.kind {
                    XCTAssertTrue(engine.availableProducts.contains { $0.category == cat }, "\(quest.id) on \(key)")
                }
                XCTAssertNotEqual(quest.kind, .serveRegulars, "no regulars yet")
            }
        }
    }

    func testAchievementsClaimOnlyWhenEarnedAndOnce() throws {
        var engine = playingEngine()
        XCTAssertThrowsError(try engine.claimAchievement("first_sale")) { XCTAssertEqual($0 as? GameError, .notEligible) }
        let v = engine.forceVisit(customer: "pip", product: "honey_bun", budget: 20)
        _ = try engine.serve(visitId: v.id)
        XCTAssertEqual(try engine.claimAchievement("first_sale"), 25)
        XCTAssertThrowsError(try engine.claimAchievement("first_sale")) { XCTAssertEqual($0 as? GameError, .alreadyClaimed) }
    }

    func testCollectionsTrackProgressAndReward() throws {
        var engine = playingEngine()
        engine.setCoins(1000)
        let def = engine.content.collections.first { $0.id == "cozy_corner" }!
        XCTAssertEqual(engine.collectionProgress(def).have, 1, "tutorial fern counts")
        try engine.buyDecoration("paper_lantern")
        try engine.buyDecoration("woven_rug")
        XCTAssertEqual(engine.collectionProgress(def).missing, ["hand_sign"])
        XCTAssertThrowsError(try engine.claimCollection("cozy_corner"))
        try engine.buyDecoration("hand_sign")
        XCTAssertTrue(engine.collectionProgress(def).isComplete)
        XCTAssertEqual(try engine.claimCollection("cozy_corner"), 150)
        XCTAssertThrowsError(try engine.claimCollection("cozy_corner"))
        XCTAssertTrue(engine.isAchieved(engine.content.achievements.first { $0.id == "first_collection" }!))
    }
}

final class DailyRewardTests: XCTestCase {
    // 11. Daily reward eligibility + 18. timezone and reset handling
    func testDailyRewardOncePerDayAndCycle() throws {
        var engine = playingEngine()
        XCTAssertTrue(engine.isDailyRewardAvailable(now: testNow, timeZone: utc))
        let coins = engine.state.coins
        XCTAssertEqual(try engine.claimDailyReward(now: testNow, timeZone: utc).day, 1)
        XCTAssertEqual(engine.state.coins, coins + 60)
        XCTAssertThrowsError(try engine.claimDailyReward(now: testNow.addingTimeInterval(3600), timeZone: utc))
        for day in 1..<7 {
            _ = try engine.claimDailyReward(now: testNow.addingTimeInterval(Double(day) * 86_400), timeZone: utc)
        }
        XCTAssertTrue(engine.state.ownedDecorations.contains("lucky_clover_jar"))
        XCTAssertEqual(engine.dailyRewardIndex, 0, "cycle wraps after seven claims")
        // Second cycle: clover jar already owned, so coins instead.
        for day in 7..<10 {
            _ = try engine.claimDailyReward(now: testNow.addingTimeInterval(Double(day) * 86_400), timeZone: utc)
        }
        XCTAssertEqual(engine.state.dailyReward.claimedCount, 10)
    }

    func testMissedDaysDoNotResetProgress() throws {
        var engine = playingEngine()
        _ = try engine.claimDailyReward(now: testNow, timeZone: utc)
        _ = try engine.claimDailyReward(now: testNow.addingTimeInterval(86_400), timeZone: utc)
        // Skip a whole week.
        let reward = try engine.claimDailyReward(now: testNow.addingTimeInterval(9 * 86_400), timeZone: utc)
        XCTAssertEqual(reward.day, 3)
    }

    func testClockRollbackCannotFarmRewards() throws {
        var engine = playingEngine()
        let future = testNow.addingTimeInterval(5 * 86_400)
        _ = try engine.claimDailyReward(now: future, timeZone: utc)
        XCTAssertFalse(engine.isDailyRewardAvailable(now: testNow, timeZone: utc))
        XCTAssertThrowsError(try engine.claimDailyReward(now: testNow.addingTimeInterval(86_400), timeZone: utc))
        let goals = engine.state.daily.goals
        XCTAssertFalse(engine.refreshCalendarDay(now: testNow, timeZone: utc), "rolling back doesn't regenerate goals")
        XCTAssertEqual(engine.state.daily.goals, goals)
        XCTAssertTrue(engine.isDailyRewardAvailable(now: future.addingTimeInterval(86_400), timeZone: utc))
    }

    func testTimezoneChangeDoesNotGrantExtraDay() throws {
        var engine = playingEngine()
        let tokyo = TimeZone(identifier: "Asia/Tokyo")!
        let la = TimeZone(identifier: "America/Los_Angeles")!
        // 2026-09-21 23:30 in Tokyo is still 2026-09-21 07:30 in LA.
        let moment = DayClock.dayKey(for: testNow, timeZone: tokyo) >= DayClock.dayKey(for: testNow, timeZone: la)
        XCTAssertTrue(moment)
        _ = try engine.claimDailyReward(now: testNow, timeZone: tokyo)
        // Flying "back" a day by changing zone must not unlock another claim.
        XCTAssertFalse(engine.isDailyRewardAvailable(now: testNow, timeZone: la))
    }

    func testDayKeyBoundaries() {
        let ny = TimeZone(identifier: "America/New_York")!
        let justBefore = ISO8601DateFormatter().date(from: "2026-10-19T03:59:59Z")! // 23:59:59 EDT
        let justAfter = ISO8601DateFormatter().date(from: "2026-10-19T04:00:00Z")!  // 00:00 EDT
        XCTAssertEqual(DayClock.dayKey(for: justBefore, timeZone: ny), "2026-10-18")
        XCTAssertEqual(DayClock.dayKey(for: justAfter, timeZone: ny), "2026-10-19")
    }
}

final class DistrictTests: XCTestCase {
    // 19. Progression unlock requirements
    func testFlowerLaneRequiresReputationAndCoins() throws {
        var engine = playingEngine()
        engine.setCoins(5000)
        XCTAssertThrowsError(try engine.unlockDistrict("flower_lane")) { XCTAssertEqual($0 as? GameError, .locked) }
        engine.setReputation(180)
        engine.setCoins(100)
        XCTAssertThrowsError(try engine.unlockDistrict("flower_lane")) { XCTAssertEqual($0 as? GameError, .notEnoughCoins) }
        engine.setCoins(1500)
        XCTAssertTrue(engine.canUnlockDistrict("flower_lane"))
        try engine.unlockDistrict("flower_lane")
        XCTAssertEqual(engine.state.coins, 300)
        XCTAssertTrue(engine.availableProducts.contains { $0.id == "rose_bouquet" })
        try engine.travel(to: "flower_lane")
        XCTAssertEqual(engine.state.currentDistrict, "flower_lane")
        XCTAssertTrue(engine.isCustomerEligible(engine.content.customer("fern")!))
        XCTAssertFalse(playingEngine().isCustomerEligible(engine.content.customer("fern")!))
    }

    func testPreviewDistrictsCannotBeEntered() {
        var engine = playingEngine()
        engine.setCoins(100_000)
        engine.setReputation(10_000)
        XCTAssertThrowsError(try engine.unlockDistrict("seaside_promenade")) { XCTAssertEqual($0 as? GameError, .notPlayable) }
        XCTAssertThrowsError(try engine.travel(to: "winter_village"))
        XCTAssertThrowsError(try engine.travel(to: "flower_lane")) { XCTAssertEqual($0 as? GameError, .locked) }
    }

    func testCannotTravelWithCustomerWaiting() throws {
        var engine = playingEngine()
        engine.setCoins(5000)
        engine.setReputation(500)
        try engine.unlockDistrict("flower_lane")
        _ = engine.forceVisit(customer: "pip", product: "honey_bun", budget: 20)
        XCTAssertThrowsError(try engine.travel(to: "flower_lane")) { XCTAssertEqual($0 as? GameError, .customerWaiting) }
    }
}
