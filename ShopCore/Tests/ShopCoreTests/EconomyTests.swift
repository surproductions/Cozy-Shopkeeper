import XCTest
@testable import ShopCore

final class ContentTests: XCTestCase {
    func testMinimumContentRequirements() {
        let c = GameContent.standard
        XCTAssertGreaterThanOrEqual(c.products.count, 20)
        XCTAssertGreaterThanOrEqual(c.customers.count, 10)
        XCTAssertGreaterThanOrEqual(c.decorations.filter { !$0.isDefault }.count, 8)
        XCTAssertGreaterThanOrEqual(c.upgrades.count, 5)
        XCTAssertGreaterThanOrEqual(c.achievements.count, 10)
        XCTAssertEqual(c.dailyRewards.count, 7)
        XCTAssertGreaterThanOrEqual(c.quests.count, 10)
        XCTAssertGreaterThanOrEqual(c.collections.count, 3)
        XCTAssertGreaterThanOrEqual(c.districts.filter(\.isPlayable).count, 2)
    }

    func testContentReferencesAreValid() {
        let c = GameContent.standard
        XCTAssertEqual(Set(c.products.map(\.id)).count, c.products.count, "duplicate product ids")
        XCTAssertEqual(Set(c.customers.map(\.id)).count, c.customers.count, "duplicate customer ids")
        XCTAssertEqual(Set(c.decorations.map(\.id)).count, c.decorations.count, "duplicate decoration ids")
        for product in c.products {
            XCTAssertGreaterThan(product.recommendedPrice, product.unitCost, "\(product.id) must be profitable")
            if let d = product.district { XCTAssertNotNil(c.district(d)) }
        }
        for customer in c.customers {
            XCTAssertFalse(customer.favorites.isEmpty)
            if let gift = customer.heartGiftDecoration { XCTAssertNotNil(c.decoration(gift)) }
            if let d = customer.district { XCTAssertNotNil(c.district(d)) }
        }
        for collection in c.collections {
            switch collection.requirement {
            case .sellProducts(let ids): ids.forEach { XCTAssertNotNil(c.product($0), $0) }
            case .ownDecorations(let ids): ids.forEach { XCTAssertNotNil(c.decoration($0), $0) }
            case .discoverCustomers(let n): XCTAssertLessThanOrEqual(n, c.customers.count)
            }
            if let deco = collection.rewardDecoration { XCTAssertNotNil(c.decoration(deco)) }
        }
        for slot in DecorSlot.allCases where slot.isRequired {
            XCTAssertEqual(c.decorations.filter { $0.slot == slot && $0.isDefault }.count, 1, "\(slot) needs one default")
        }
        // Every product is reachable: tier within the shelves upgrade range.
        XCTAssertTrue(c.products.allSatisfy { $0.tier >= 1 && $0.tier <= 4 })
    }

    func testEveryPurchasableItemIsAffordableInPrinciple() {
        let c = GameContent.standard
        for upgrade in c.upgrades { XCTAssertEqual(upgrade.values.count, upgrade.costs.count + 1, upgrade.id) }
    }
}

final class StartingStateTests: XCTestCase {
    // 1. Starting currency and initial inventory
    func testStartingCoinsAndInventory() {
        let engine = freshEngine()
        XCTAssertEqual(engine.state.coins, 150)
        let starter = engine.state.inventory.filter { $0.value > 0 }
        XCTAssertTrue((5...8).contains(starter.count), "5–8 starter products, got \(starter.count)")
        XCTAssertTrue(starter.values.allSatisfy { $0 == 4 })
        XCTAssertEqual(engine.state.tutorialStep, .welcome)
        XCTAssertEqual(engine.state.shopDay.dayNumber, 1)
        XCTAssertEqual(engine.state.shopDay.customersPlanned, 6)
        XCTAssertEqual(engine.state.equippedDecorations["wallpaper"], "cream_plaster")
        XCTAssertEqual(engine.availableProducts.count, 8)
    }

    func testFirstSessionTutorialFlow() throws {
        var engine = freshEngine()
        XCTAssertNil(engine.summonNextCustomer(), "no customers before the shop opens")
        engine.acknowledgeTutorial(.welcome)
        let visit = try XCTUnwrap(engine.summonNextCustomer())
        XCTAssertEqual(visit.customerId, "pip")
        XCTAssertEqual(visit.productId, "honey_bun")
        XCTAssertTrue(visit.isTutorial)
        guard case .sold(let receipt) = try engine.serve(visitId: visit.id) else { return XCTFail("first sale must succeed") }
        XCTAssertGreaterThan(receipt.tip, 0, "first sale should include a tip")
        XCTAssertEqual(engine.state.tutorialStep, .restock)
        try engine.restock(productId: "honey_bun", quantity: 2)
        XCTAssertEqual(engine.state.tutorialStep, .decorGift)
        XCTAssertTrue(engine.state.ownedDecorations.contains("potted_fern"))
        XCTAssertEqual(engine.state.equippedDecorations["plant"], "potted_fern")
        engine.acknowledgeTutorial(.decorGift)
        engine.acknowledgeTutorial(.goals)
        XCTAssertEqual(engine.state.tutorialStep, .done)
        XCTAssertTrue(engine.events.contains { $0.name == .tutorial_complete })
        XCTAssertTrue(engine.events.contains { $0.name == .first_sale })
    }
}

final class SalesTests: XCTestCase {
    // 2. Successful sales + 5. revenue, profit and tips
    func testSuccessfulSaleUpdatesEverything() throws {
        var engine = playingEngine()
        let coinsBefore = engine.state.coins
        let visit = engine.forceVisit(customer: "mabel", product: "honey_bun", quantity: 2, budget: 12)
        guard case .sold(let r) = try engine.serve(visitId: visit.id) else { return XCTFail() }
        XCTAssertEqual(r.unitPrice, 9)
        XCTAssertEqual(r.revenue, 18)
        XCTAssertEqual(engine.state.coins, coinsBefore + r.revenue + r.tip)
        XCTAssertEqual(engine.stock(of: "honey_bun"), 2)
        XCTAssertEqual(engine.state.stats.totalSales, 1)
        XCTAssertEqual(engine.state.stats.itemsSold, 2)
        XCTAssertEqual(engine.state.shopDay.revenue, 18)
        XCTAssertEqual(engine.state.shopDay.tips, r.tip)
        XCTAssertGreaterThan(engine.state.reputation, 0)
        XCTAssertNil(engine.state.currentVisit)
        XCTAssertTrue(engine.state.productsEverSold.contains("honey_bun"))
    }

    func testTipScalesWithSatisfactionAndCheckoutUpgrade() throws {
        var a = playingEngine()
        let v1 = a.forceVisit(customer: "reginald", product: "beeswax_candle", budget: 40)
        guard case .sold(let cheap) = try a.serve(visitId: v1.id) else { return XCTFail() }

        var b = playingEngine()
        b.setCoins(1000)
        try b.buyUpgrade(ContentIDs.Upgrade.checkout)
        let v2 = b.forceVisit(customer: "reginald", product: "beeswax_candle", budget: 40)
        guard case .sold(let upgraded) = try b.serve(visitId: v2.id) else { return XCTFail() }
        XCTAssertGreaterThan(upgraded.tip, cheap.tip, "Brass Register should raise tips")
    }

    func testPriceAtBudgetIsAcceptedButLessSatisfying() throws {
        var a = playingEngine()
        let visit = a.forceVisit(customer: "ollie", product: "leaf_notebook", budget: 12)
        try a.setPrice(productId: "leaf_notebook", price: 12)
        let atBudget = try XCTUnwrap(a.projectedSatisfaction(for: visit, unitPrice: 12))
        let bargain = try XCTUnwrap(a.projectedSatisfaction(for: visit, unitPrice: 8))
        XCTAssertLessThan(atBudget, bargain)
        XCTAssertNil(a.projectedSatisfaction(for: visit, unitPrice: 13))
        guard case .sold = try a.serve(visitId: visit.id) else { return XCTFail("at-budget price must sell") }
    }

    // 3. Rejected sales and invalid requests
    func testOverpricedSaleGetsSecondChanceThenWalkout() throws {
        var engine = playingEngine()
        engine.setReputation(40) // level 1 (floor 30)
        try engine.setPrice(productId: "clay_mug", price: 50)
        let visit = engine.forceVisit(customer: "ollie", product: "clay_mug", budget: 19)
        XCTAssertEqual(try engine.serve(visitId: visit.id), .tooExpensive(attemptsLeft: 1))
        XCTAssertEqual(engine.state.currentVisit?.id, visit.id, "customer waits after first refusal")
        XCTAssertEqual(engine.stock(of: "clay_mug"), 4)
        XCTAssertEqual(try engine.serve(visitId: visit.id), .walkedOut)
        XCTAssertNil(engine.state.currentVisit)
        XCTAssertEqual(engine.state.stats.walkouts, 1)
        XCTAssertEqual(engine.state.reputation, 39)
        XCTAssertEqual(engine.stock(of: "clay_mug"), 4, "no stock leaves on a failed sale")
    }

    func testLoweringPriceAfterRefusalCompletesSale() throws {
        var engine = playingEngine()
        try engine.setPrice(productId: "clay_mug", price: 30)
        let visit = engine.forceVisit(customer: "pip", product: "clay_mug", budget: 24)
        XCTAssertEqual(try engine.serve(visitId: visit.id), .tooExpensive(attemptsLeft: 1))
        try engine.setPrice(productId: "clay_mug", price: 20)
        guard case .sold = try engine.serve(visitId: visit.id) else { return XCTFail() }
    }

    func testSingleBadInteractionCannotDropReputationLevel() throws {
        var engine = playingEngine()
        engine.setReputation(30) // exactly the level-1 floor
        try engine.setPrice(productId: "clay_mug", price: 57)
        let visit = engine.forceVisit(customer: "ollie", product: "clay_mug", budget: 19)
        _ = try engine.serve(visitId: visit.id)
        _ = try engine.serve(visitId: visit.id)
        XCTAssertEqual(engine.state.reputation, 30)
        XCTAssertEqual(engine.reputationLevel, 1)
    }

    func testServeWithoutCustomerOrStaleIdFails() throws {
        var engine = playingEngine()
        XCTAssertThrowsError(try engine.serve(visitId: 1)) { XCTAssertEqual($0 as? GameError, .noActiveCustomer) }
        let visit = engine.forceVisit(customer: "pip", product: "honey_bun", budget: 20)
        XCTAssertThrowsError(try engine.serve(visitId: visit.id + 99)) { XCTAssertEqual($0 as? GameError, .staleCustomer) }
    }

    // 4. Inventory decrement and stock limits
    func testCannotSellMoreThanInStock() throws {
        var engine = playingEngine()
        engine.setStock("honey_bun", 1)
        let visit = engine.forceVisit(customer: "mabel", product: "honey_bun", quantity: 2, budget: 20)
        XCTAssertThrowsError(try engine.serve(visitId: visit.id)) { XCTAssertEqual($0 as? GameError, .insufficientStock) }
        XCTAssertEqual(engine.stock(of: "honey_bun"), 1)
        try engine.turnAway(visitId: visit.id)
        XCTAssertNil(engine.state.currentVisit)
        XCTAssertEqual(engine.state.reputation, 0, "turning away costs no reputation")
    }

    // 14. Repeated taps / duplicate transactions
    func testDoubleServeIsRejected() throws {
        var engine = playingEngine()
        let visit = engine.forceVisit(customer: "pip", product: "honey_bun", budget: 20)
        _ = try engine.serve(visitId: visit.id)
        let coins = engine.state.coins
        XCTAssertThrowsError(try engine.serve(visitId: visit.id))
        XCTAssertEqual(engine.state.coins, coins)
        XCTAssertEqual(engine.stock(of: "honey_bun"), 3)
    }

    func testGiftWrapBonusRequiresStation() throws {
        var without = playingEngine()
        let v1 = without.forceVisit(customer: "dottie", product: "clay_mug", budget: 26, giftWrap: true)
        guard case .sold(let r1) = try without.serve(visitId: v1.id) else { return XCTFail() }
        XCTAssertFalse(r1.giftWrapped)

        var with = playingEngine()
        with.setCoins(500)
        try with.buyUpgrade(ContentIDs.Upgrade.giftWrap)
        let v2 = with.forceVisit(customer: "dottie", product: "clay_mug", budget: 26, giftWrap: true)
        guard case .sold(let r2) = try with.serve(visitId: v2.id) else { return XCTFail() }
        XCTAssertTrue(r2.giftWrapped)
        XCTAssertGreaterThan(r2.tip, r1.tip)
    }
}

final class PricingTests: XCTestCase {
    // 6. Price bounds and customer price sensitivity
    func testPriceIsClamped() throws {
        var engine = playingEngine()
        XCTAssertEqual(try engine.setPrice(productId: "honey_bun", price: -5), 1)
        XCTAssertEqual(try engine.setPrice(productId: "honey_bun", price: 0), 1)
        XCTAssertEqual(try engine.setPrice(productId: "honey_bun", price: 10_000), 27)
        XCTAssertThrowsError(try engine.setPrice(productId: "nope", price: 5))
    }

    func testCustomerBudgetsReflectSensitivity() {
        let engine = playingEngine()
        var rng = SeededRandom(seed: 1)
        _ = rng.next()
        let bargain = GameContent.standard.customer("ollie")!
        let vip = GameContent.standard.customer("reginald")!
        XCTAssertLessThan(bargain.priceTolerance, vip.priceTolerance)
        // Generated visits never go below the minimum price and respect tolerance.
        var e = engine
        e.setReputation(1000)
        for _ in 0..<200 {
            e.state.shopDay = ShopDayState()
            e.state.shopDay.customersPlanned = 1
            guard let visit = e.summonNextCustomer() else { continue }
            let product = e.content.product(visit.productId)!
            let customer = e.content.customer(visit.customerId)!
            let maxTolerance = customer.priceTolerance + e.config.favoriteToleranceBonus + Double(e.config.maxHearts) * e.config.heartToleranceBonus
            XCTAssertLessThanOrEqual(Double(visit.maxUnitPrice), Double(product.recommendedPrice) * maxTolerance + 1)
            XCTAssertGreaterThanOrEqual(visit.maxUnitPrice, product.recommendedPrice, "recommended price should always be acceptable")
            try? e.turnAway(visitId: visit.id)
        }
    }

    func testRecommendedPriceSellsToEveryone() throws {
        for customer in GameContent.standard.customers {
            var engine = playingEngine()
            engine.setReputation(2000)
            let visit = engine.forceVisit(customer: customer.id, product: "honey_bun", budget: Int((9 * customer.priceTolerance).rounded()))
            guard case .sold = try engine.serve(visitId: visit.id) else { return XCTFail("\(customer.id) refused fair price") }
        }
    }
}

final class RestockAndUpgradeTests: XCTestCase {
    // 7. Insufficient currency
    func testRestockRequiresCoins() throws {
        var engine = playingEngine()
        engine.setCoins(5)
        XCTAssertThrowsError(try engine.restock(productId: "clay_mug", quantity: 1)) { XCTAssertEqual($0 as? GameError, .notEnoughCoins) }
        XCTAssertEqual(engine.state.coins, 5)
        XCTAssertEqual(engine.stock(of: "clay_mug"), 4)
    }

    func testRestockRespectsCapacityAndQuantity() throws {
        var engine = playingEngine()
        engine.setCoins(10_000)
        XCTAssertThrowsError(try engine.restock(productId: "honey_bun", quantity: 0)) { XCTAssertEqual($0 as? GameError, .invalidQuantity) }
        XCTAssertThrowsError(try engine.restock(productId: "honey_bun", quantity: -3))
        XCTAssertThrowsError(try engine.restock(productId: "honey_bun", quantity: 7)) { XCTAssertEqual($0 as? GameError, .capacityReached) }
        XCTAssertEqual(try engine.restock(productId: "honey_bun", quantity: 6), 24)
        XCTAssertEqual(engine.stock(of: "honey_bun"), 10)
        XCTAssertEqual(engine.maxRestockable(productId: "honey_bun"), 0)
        XCTAssertThrowsError(try engine.restock(productId: "fable_storybook", quantity: 1)) { XCTAssertEqual($0 as? GameError, .notAvailableYet) }
    }

    func testMaxRestockableIsLimitedByCoins() {
        var engine = playingEngine()
        engine.setCoins(20)
        engine.setStock("clay_mug", 0)
        XCTAssertEqual(engine.maxRestockable(productId: "clay_mug"), 2)
    }

    // 8. Upgrade purchase and effects
    func testUpgradesHaveMeasurableEffects() throws {
        var engine = playingEngine()
        engine.setCoins(100_000)
        XCTAssertEqual(engine.stockCapacity, 10)
        try engine.buyUpgrade(ContentIDs.Upgrade.stockroom)
        XCTAssertEqual(engine.stockCapacity, 15)

        XCTAssertEqual(engine.availableProducts.count, 8)
        try engine.buyUpgrade(ContentIDs.Upgrade.shelves)
        XCTAssertEqual(engine.availableProducts.count, 14)

        let before = engine.restockCost(productId: "clay_mug", quantity: 10)
        try engine.buyUpgrade(ContentIDs.Upgrade.supplier)
        XCTAssertLessThan(engine.restockCost(productId: "clay_mug", quantity: 10), before)

        let planned = engine.state.shopDay.customersPlanned
        try engine.buyUpgrade(ContentIDs.Upgrade.window)
        XCTAssertEqual(engine.state.shopDay.customersPlanned, planned + 1, "window display helps today too")
        XCTAssertEqual(engine.customersPerDay, 7)

        try engine.buyUpgrade(ContentIDs.Upgrade.nook)
        XCTAssertGreaterThan(engine.reputationBonus, 0)
        XCTAssertEqual(engine.state.stats.upgradesBought, 5)
    }

    func testUpgradeCostsAndMaxLevel() throws {
        var engine = playingEngine()
        engine.setCoins(10_000)
        let coins = engine.state.coins
        try engine.buyUpgrade(ContentIDs.Upgrade.giftWrap)
        XCTAssertEqual(engine.state.coins, coins - 140)
        XCTAssertThrowsError(try engine.buyUpgrade(ContentIDs.Upgrade.giftWrap)) { XCTAssertEqual($0 as? GameError, .maxLevelReached) }
        engine.setCoins(10)
        XCTAssertThrowsError(try engine.buyUpgrade(ContentIDs.Upgrade.stockroom)) { XCTAssertEqual($0 as? GameError, .notEnoughCoins) }
        XCTAssertEqual(engine.upgradeLevel(ContentIDs.Upgrade.stockroom), 0)
    }

    func testAllFourTiersUnlockEveryNonDistrictProduct() throws {
        var engine = playingEngine()
        engine.setCoins(100_000)
        for _ in 0..<3 { try engine.buyUpgrade(ContentIDs.Upgrade.shelves) }
        XCTAssertEqual(engine.availableProducts.count, GameContent.standard.products.filter { $0.district == nil }.count)
    }
}

final class DecorationTests: XCTestCase {
    // 9. Decoration ownership and selection
    func testBuyEquipAndSwapDecorations() throws {
        var engine = playingEngine()
        engine.setCoins(1000)
        let cozyBefore = engine.coziness
        try engine.buyDecoration("sage_stripes")
        XCTAssertTrue(engine.state.ownedDecorations.contains("sage_stripes"))
        XCTAssertEqual(engine.state.equippedDecorations["wallpaper"], "sage_stripes")
        XCTAssertGreaterThan(engine.coziness, cozyBefore)
        XCTAssertThrowsError(try engine.buyDecoration("sage_stripes")) { XCTAssertEqual($0 as? GameError, .alreadyOwned) }
        try engine.equipDecoration("cream_plaster")
        XCTAssertEqual(engine.state.equippedDecorations["wallpaper"], "cream_plaster")
        XCTAssertThrowsError(try engine.equipDecoration("midnight_stars")) { XCTAssertEqual($0 as? GameError, .notOwned) }
        XCTAssertThrowsError(try engine.buyDecoration("golden_teacup")) { XCTAssertEqual($0 as? GameError, .notForSale) }
        XCTAssertThrowsError(try engine.clearDecorationSlot(.wallpaper))
        try engine.clearDecorationSlot(.plant)
        XCTAssertNil(engine.state.equippedDecorations["plant"])
    }

    func testCannotBuyDecorationWithoutCoins() {
        var engine = playingEngine()
        engine.setCoins(10)
        XCTAssertThrowsError(try engine.buyDecoration("midnight_stars"))
        XCTAssertFalse(engine.state.ownedDecorations.contains("midnight_stars"))
        XCTAssertEqual(engine.state.coins, 10)
    }

    func testCozinessRaisesSatisfaction() throws {
        var plain = playingEngine()
        let v = plain.forceVisit(customer: "ollie", product: "clay_mug", budget: 20)
        let s1 = try XCTUnwrap(plain.projectedSatisfaction(for: v, unitPrice: 20))
        var cozy = playingEngine()
        cozy.setCoins(5000)
        try cozy.buyDecoration("midnight_stars")
        try cozy.buyDecoration("fairy_lights")
        let v2 = cozy.forceVisit(customer: "ollie", product: "clay_mug", budget: 20)
        let s2 = try XCTUnwrap(cozy.projectedSatisfaction(for: v2, unitPrice: 20))
        XCTAssertGreaterThan(s2, s1)
    }
}
