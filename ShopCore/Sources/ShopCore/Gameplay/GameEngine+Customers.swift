import Foundation

public struct SaleReceipt: Equatable, Sendable {
    public let customerId: String
    public let productId: String
    public let quantity: Int
    public let unitPrice: Int
    public let revenue: Int
    public let tip: Int
    public let satisfaction: Int
    public let reputationGained: Int
    public let delighted: Bool
    public let giftWrapped: Bool
    public let heartsBefore: Int
    public let heartsAfter: Int
    public let becameRegular: Bool
    public let heartGiftDecoration: String?

    public var profit: Int { revenue + tip }
}

public enum SaleOutcome: Equatable, Sendable {
    case sold(SaleReceipt)
    /// The price was over budget; the customer will let you try again.
    case tooExpensive(attemptsLeft: Int)
    /// The customer ran out of patience and left.
    case walkedOut
}

public struct DaySummary: Equatable, Sendable {
    public let dayNumber: Int
    public let customersServed: Int
    public let customersMissed: Int
    public let revenue: Int
    public let tips: Int
    public let restockSpend: Int
    /// Coins a kind neighbor left so the shop can never get stuck with no stock and no money.
    public var reliefCoins: Int = 0
}

public extension GameEngine {

    // MARK: - Customer flow

    var canSummonCustomer: Bool {
        state.currentVisit == nil && !state.shopDay.isFinished
            && state.shopDay.customersArrived < state.shopDay.customersPlanned
            && state.tutorialStep != .welcome
    }

    /// Brings the next customer to the counter. Returns nil when none can arrive.
    @discardableResult
    mutating func summonNextCustomer() -> CustomerVisit? {
        guard canSummonCustomer else { return nil }
        state.visitCounter += 1
        var rng = SeededRandom(seed: state.seed ^ (UInt64(state.visitCounter) &* 0x9E37_79B9_7F4A_7C15))
        guard var visit = makeVisit(rng: &rng) else { return nil }

        state.shopDay.customersArrived += 1
        state.lastCustomerId = visit.customerId

        if state.customers[visit.customerId] == nil {
            state.customers[visit.customerId] = CustomerRecord(discoveredOnShopDay: state.shopDay.dayNumber)
            visit.isFirstVisit = true
            earn(config.discoveryRewardCoins)
            progressGoals(.discoverCustomers, by: 1)
            emit(.customer_discovered, ["customer_id": visit.customerId])
        }
        state.customers[visit.customerId]?.visits += 1
        state.currentVisit = visit

        let archetype = content.customer(visit.customerId)?.archetype.rawValue ?? "unknown"
        emit(.customer_arrive, ["customer_id": visit.customerId, "customer_type": archetype, "district": state.currentDistrict])
        emit(.customer_request, ["customer_id": visit.customerId, "product_id": visit.productId, "quantity": "\(visit.quantity)"])
        return visit
    }

    internal func makeVisit(rng: inout SeededRandom) -> CustomerVisit? {
        let id = state.visitCounter
        if state.tutorialStep == .firstSale,
           let pip = content.customer(ContentIDs.tutorialCustomer),
           let bun = content.product(ContentIDs.tutorialProduct) {
            return CustomerVisit(id: id, customerId: pip.id, productId: bun.id, quantity: 1,
                                 maxUnitPrice: bun.recommendedPrice * 2, wantsGiftWrap: false, attemptsUsed: 0,
                                 greeting: "Oh, a new shop! Could I get one of those honey buns?",
                                 isTutorial: true, isFirstVisit: false)
        }

        let eligible = content.customers.filter(isCustomerEligible)
        let weightedCustomers: [(CustomerDef, Double)] = eligible.map { def in
            var weight = def.spawnWeight
            if isRegular(def.id) { weight *= config.regularSpawnBoost }
            if state.customers[def.id] == nil { weight *= 1.3 }
            if def.id == state.lastCustomerId { weight *= 0.25 }
            return (def, weight)
        }
        guard let customer = rng.weightedPick(weightedCustomers) else { return nil }

        let products = availableProducts
        guard !products.isEmpty else { return nil }
        var candidates = products.filter { customer.favorites.contains($0.category) }
        if candidates.isEmpty { candidates = products }
        let weightedProducts: [(ProductDef, Double)] = candidates.map { product in
            var weight = stock(of: product.id) > 0 ? config.inStockPreferenceWeight : 1
            if customer.prefersRare && product.rarity != .common { weight *= config.rareWeightForCollectors }
            return (product, weight)
        }
        guard let product = rng.weightedPick(weightedProducts) else { return nil }

        var quantity = 1
        if rng.chance(customer.bulkChance) { quantity += 1 }
        if rng.chance(customer.bulkChance / 2) { quantity += 1 }

        let isFavorite = customer.favorites.contains(product.category)
        let tolerance = customer.priceTolerance
            + (isFavorite ? config.favoriteToleranceBonus : 0)
            + Double(hearts(for: customer.id)) * config.heartToleranceBonus
        let budget = max(config.minPrice, Int((Double(product.recommendedPrice) * tolerance).rounded()))
        let wantsWrap = rng.chance(customer.giftWrapChance)
        let greeting = customer.greetings.isEmpty ? "Hello!" : customer.greetings[Int(rng.next() % UInt64(customer.greetings.count))]

        return CustomerVisit(id: id, customerId: customer.id, productId: product.id, quantity: quantity,
                             maxUnitPrice: budget, wantsGiftWrap: wantsWrap, attemptsUsed: 0,
                             greeting: greeting, isTutorial: false, isFirstVisit: false)
    }

    /// Whether the player may see this customer's exact budget (regulars share it).
    func isBudgetRevealed(for visit: CustomerVisit) -> Bool {
        visit.isTutorial || isRegular(visit.customerId)
    }

    /// Satisfaction (0...100) the customer would feel at a given unit price. Nil if they would refuse.
    func projectedSatisfaction(for visit: CustomerVisit, unitPrice: Int) -> Int? {
        guard unitPrice <= visit.maxUnitPrice, let product = content.product(visit.productId),
              let customer = content.customer(visit.customerId) else { return nil }
        let ratio = Double(unitPrice) / Double(max(1, visit.maxUnitPrice))
        var score: Double
        if ratio <= config.bargainRatio {
            score = 100
        } else {
            let span = 1 - config.bargainRatio
            score = 100 - (ratio - config.bargainRatio) / span * Double(100 - config.satisfactionAtBudget)
        }
        if customer.favorites.contains(product.category) { score += Double(config.favoriteSatisfactionBonus) }
        if visit.wantsGiftWrap && hasGiftWrap { score += Double(config.giftWrapSatisfactionBonus) }
        score += min(Double(config.cozinessSatisfactionCap), Double(coziness) * config.cozinessSatisfactionPerPoint)
        return Int(min(100, max(0, score)).rounded())
    }

    // MARK: - Selling

    /// Offers the requested goods at the current shelf price.
    mutating func serve(visitId: Int) throws -> SaleOutcome {
        guard var visit = state.currentVisit else { throw GameError.noActiveCustomer }
        guard visit.id == visitId else { throw GameError.staleCustomer }
        guard let product = content.product(visit.productId),
              let customer = content.customer(visit.customerId) else { throw GameError.unknownItem }
        guard stock(of: product.id) >= visit.quantity else { throw GameError.insufficientStock }

        let unitPrice = price(of: product.id)
        guard let satisfaction = projectedSatisfaction(for: visit, unitPrice: unitPrice) else {
            visit.attemptsUsed += 1
            if visit.attemptsUsed >= config.patience {
                loseReputation(config.reputationLossOnWalkout)
                state.stats.walkouts += 1
                state.shopDay.customersMissed += 1
                emit(.sale_failed, ["customer_id": customer.id, "product_id": product.id, "reason": "too_expensive", "price": "\(unitPrice)"])
                endVisit()
                return .walkedOut
            }
            state.currentVisit = visit
            emit(.sale_failed, ["customer_id": customer.id, "product_id": product.id, "reason": "too_expensive_retry", "price": "\(unitPrice)"])
            return .tooExpensive(attemptsLeft: config.patience - visit.attemptsUsed)
        }

        let wasRegular = isRegular(customer.id)
        let heartsBefore = hearts(for: customer.id)
        let revenue = unitPrice * visit.quantity
        let giftWrapped = visit.wantsGiftWrap && hasGiftWrap
        let delighted = satisfaction >= config.delightedThreshold

        var tip = 0
        if satisfaction >= config.tipThreshold {
            var raw = Double(revenue) * customer.tipRate * (Double(satisfaction) / 100) * (1 + tipBonus)
            if giftWrapped { raw += Double(revenue) * config.giftWrapTipBonus }
            tip = Int(raw.rounded())
            if delighted { tip = max(tip, 1) }
        }

        let repRaw = Double(config.baseReputationPerSale + satisfaction / 25) * (1 + reputationBonus)
        let repGain = max(1, Int(repRaw.rounded()))

        state.inventory[product.id] = stock(of: product.id) - visit.quantity
        earn(revenue + tip)
        state.stats.lifetimeTips += tip
        state.stats.totalSales += 1
        state.stats.itemsSold += visit.quantity
        if delighted { state.stats.delightedSales += 1 }
        state.shopDay.revenue += revenue
        state.shopDay.tips += tip
        state.shopDay.customersServed += 1
        state.productsEverSold.insert(product.id)
        addReputation(repGain)

        var record = state.customers[customer.id] ?? CustomerRecord(discoveredOnShopDay: state.shopDay.dayNumber)
        record.purchases += 1
        record.totalSatisfaction += satisfaction
        record.relationshipPoints += delighted ? 2 : 1
        var heartGift: String?
        let heartsAfterValue = min(config.maxHearts, record.relationshipPoints / config.relationshipPointsPerHeart)
        if heartsAfterValue >= config.maxHearts, let gift = customer.heartGiftDecoration, !record.heartGiftClaimed {
            record.heartGiftClaimed = true
            heartGift = gift
        }
        state.customers[customer.id] = record
        if let heartGift { grantDecoration(heartGift) }

        progressGoals(.sellItems, by: visit.quantity)
        progressGoals(.sellCategory(product.category), by: visit.quantity)
        progressGoals(.earnCoins, by: revenue)
        if tip > 0 { progressGoals(.receiveTips, by: tip) }
        if delighted { progressGoals(.delightCustomers, by: 1) }
        if wasRegular { progressGoals(.serveRegulars, by: 1) }

        if state.stats.totalSales == 1 {
            emit(.first_core_action, ["action": "sale"])
            emit(.first_sale, ["product_id": product.id, "revenue": "\(revenue)"])
        }
        emit(.sale_complete, ["customer_id": customer.id, "customer_type": customer.archetype.rawValue,
                              "product_id": product.id, "quantity": "\(visit.quantity)", "revenue": "\(revenue)",
                              "tip": "\(tip)", "satisfaction": "\(satisfaction)", "district": state.currentDistrict])
        if state.tutorialStep == .firstSale { setTutorialStep(.restock) }

        endVisit()
        let heartsAfter = hearts(for: customer.id)
        return .sold(SaleReceipt(customerId: customer.id, productId: product.id, quantity: visit.quantity,
                                 unitPrice: unitPrice, revenue: revenue, tip: tip, satisfaction: satisfaction,
                                 reputationGained: repGain, delighted: delighted, giftWrapped: giftWrapped,
                                 heartsBefore: heartsBefore, heartsAfter: heartsAfter,
                                 becameRegular: heartsBefore < config.regularHearts && heartsAfter >= config.regularHearts,
                                 heartGiftDecoration: heartGift))
    }

    /// Politely sends the customer away (e.g. when the item is out of stock). Costs no reputation.
    mutating func turnAway(visitId: Int) throws {
        guard let visit = state.currentVisit else { throw GameError.noActiveCustomer }
        guard visit.id == visitId else { throw GameError.staleCustomer }
        state.shopDay.customersMissed += 1
        emit(.sale_failed, ["customer_id": visit.customerId, "product_id": visit.productId,
                            "reason": stock(of: visit.productId) < visit.quantity ? "out_of_stock" : "turned_away"])
        endVisit()
    }

    internal mutating func endVisit() {
        state.currentVisit = nil
        if state.shopDay.customersArrived >= state.shopDay.customersPlanned {
            state.shopDay.isFinished = true
        }
    }

    // MARK: - Shop days

    var currentDaySummary: DaySummary {
        DaySummary(dayNumber: state.shopDay.dayNumber, customersServed: state.shopDay.customersServed,
                   customersMissed: state.shopDay.customersMissed, revenue: state.shopDay.revenue,
                   tips: state.shopDay.tips, restockSpend: state.shopDay.restockSpend)
    }

    /// If the player has no stock and cannot afford to restock anything, a neighbor helps out.
    internal mutating func grantReliefIfStuck() -> Int {
        let totalStock = availableProducts.reduce(0) { $0 + stock(of: $1.id) }
        guard totalStock == 0 else { return 0 }
        let cheapest = availableProducts.map { restockCost(productId: $0.id, quantity: 3) }.min() ?? 0
        guard state.coins < cheapest else { return 0 }
        let relief = cheapest - state.coins + 10
        earn(relief)
        return relief
    }

    /// Closes a finished day and opens the next one.
    @discardableResult
    mutating func closeDay() throws -> DaySummary {
        guard state.currentVisit == nil else { throw GameError.customerWaiting }
        guard state.shopDay.isFinished else { throw GameError.dayStillOpen }
        var summary = currentDaySummary
        summary.reliefCoins = grantReliefIfStuck()
        state.stats.daysCompleted += 1
        progressGoals(.completeShopDays, by: 1)
        emit(.shop_day_complete, ["day": "\(summary.dayNumber)", "revenue": "\(summary.revenue)", "tips": "\(summary.tips)",
                                  "served": "\(summary.customersServed)", "missed": "\(summary.customersMissed)"])
        var next = ShopDayState()
        next.dayNumber = summary.dayNumber + 1
        next.customersPlanned = customersPerDay
        state.shopDay = next
        emit(.shop_day_start, ["day": "\(next.dayNumber)"])
        return summary
    }
}
