import Foundation

public enum GameError: Error, Equatable, Sendable {
    case unknownItem
    case invalidQuantity
    case notEnoughCoins
    case capacityReached
    case notAvailableYet
    case maxLevelReached
    case alreadyOwned
    case notOwned
    case notForSale
    case locked
    case notPlayable
    case noActiveCustomer
    case staleCustomer
    case insufficientStock
    case customerWaiting
    case alreadyClaimed
    case notEligible
    case dayStillOpen
    case dayAlreadyFinished
    case adNotCompleted
}

/// The pure, deterministic rules of Cozy Shopkeeper. The app wraps one of these in
/// an observable store; tests drive it directly.
public struct GameEngine: Sendable {
    public internal(set) var state: GameState
    public let content: GameContent
    public let config: EconomyConfig
    public internal(set) var events: [AnalyticsEvent] = []

    public init(state: GameState, content: GameContent = .standard, config: EconomyConfig = .standard) {
        self.state = state
        self.content = content
        self.config = config
    }

    /// Creates a brand-new shop with starter money and stock.
    public static func newGame(seed: UInt64, now: Date, content: GameContent = .standard, config: EconomyConfig = .standard) -> GameEngine {
        var state = GameState()
        state.seed = seed
        state.firstOpenedAt = now
        state.coins = config.startingCoins
        state.reputation = config.startingReputation
        state.tutorialStep = .welcome
        for product in content.products where product.tier == 1 && product.district == nil {
            state.inventory[product.id] = config.starterUnitsPerProduct
        }
        for product in content.products {
            state.prices[product.id] = product.recommendedPrice
        }
        for decoration in content.decorations where decoration.isDefault {
            state.ownedDecorations.insert(decoration.id)
            state.equippedDecorations[decoration.slot.rawValue] = decoration.id
        }
        var engine = GameEngine(state: state, content: content, config: config)
        engine.state.shopDay.customersPlanned = engine.customersPerDay
        engine.emit(.first_open)
        engine.emit(.shop_day_start, ["day": "1"])
        return engine
    }

    /// Returns and clears pending analytics events.
    public mutating func drainEvents() -> [AnalyticsEvent] {
        defer { events.removeAll() }
        return events
    }

    mutating func emit(_ name: AnalyticsEventName, _ params: [String: String] = [:]) {
        events.append(AnalyticsEvent(name, params))
    }

    /// Developer diagnostics only (the button is compiled into Debug builds only).
    public mutating func debugGrantCoins(_ amount: Int) {
        earn(amount)
    }

    /// Replace transient settings without touching gameplay.
    public mutating func updateSettings(_ settings: GameSettings) {
        state.settings = settings
    }

    /// Records the authoritative StoreKit entitlement.
    public mutating func setRemoveAdsEntitlement(_ owned: Bool, verifiedAt: Date) {
        state.entitlements.removeAds = owned
        state.entitlements.lastVerifiedAt = verifiedAt
    }

    // MARK: - Derived values

    public func upgradeLevel(_ id: String) -> Int {
        state.upgradeLevels[id] ?? 0
    }

    func upgradeValue(_ effect: UpgradeEffect) -> Double {
        guard let def = content.upgrades.first(where: { $0.effect == effect }) else { return 0 }
        return def.value(at: upgradeLevel(def.id))
    }

    public var productTier: Int { Int(upgradeValue(.productTier)) }
    public var stockCapacity: Int { Int(upgradeValue(.stockCapacity)) }
    public var tipBonus: Double { upgradeValue(.tipBonus) }
    public var restockDiscount: Double { upgradeValue(.restockDiscount) }
    public var customersPerDay: Int { Int(upgradeValue(.customersPerDay)) }
    public var hasGiftWrap: Bool { upgradeValue(.giftWrap) > 0 }
    public var reputationBonus: Double { upgradeValue(.reputationBonus) }
    public var reputationLevel: Int { config.reputationLevel(for: state.reputation) }

    public var coziness: Int {
        state.equippedDecorations.values.reduce(0) { $0 + (content.decoration($1)?.coziness ?? 0) }
    }

    public func isProductAvailable(_ product: ProductDef) -> Bool {
        guard product.tier <= productTier else { return false }
        if let district = product.district { return state.unlockedDistricts.contains(district) }
        return true
    }

    public var availableProducts: [ProductDef] {
        content.products.filter(isProductAvailable)
    }

    public func stock(of productId: String) -> Int {
        state.inventory[productId] ?? 0
    }

    public func price(of productId: String) -> Int {
        if let price = state.prices[productId] { return price }
        return content.product(productId)?.recommendedPrice ?? config.minPrice
    }

    public func hearts(for customerId: String) -> Int {
        guard let record = state.customers[customerId] else { return 0 }
        return min(config.maxHearts, record.relationshipPoints / config.relationshipPointsPerHeart)
    }

    public func isRegular(_ customerId: String) -> Bool {
        hearts(for: customerId) >= config.regularHearts
    }

    public var regularCount: Int {
        state.customers.keys.filter(isRegular).count
    }

    public func isCustomerEligible(_ def: CustomerDef) -> Bool {
        guard reputationLevel >= def.minReputationLevel else { return false }
        if let district = def.district { return district == state.currentDistrict }
        return true
    }

    public func restockCost(productId: String, quantity: Int) -> Int {
        guard let product = content.product(productId), quantity > 0 else { return 0 }
        let raw = Double(product.unitCost * quantity) * (1 - restockDiscount)
        return Int(raw.rounded(.up))
    }

    /// Largest quantity the player could restock right now (capacity and coins).
    public func maxRestockable(productId: String) -> Int {
        guard let product = content.product(productId), isProductAvailable(product) else { return 0 }
        let room = max(0, stockCapacity - stock(of: productId))
        var quantity = room
        while quantity > 0 && restockCost(productId: productId, quantity: quantity) > state.coins {
            quantity -= 1
        }
        return quantity
    }

    // MARK: - Coins

    mutating func earn(_ amount: Int) {
        guard amount > 0 else { return }
        state.coins += amount
        state.stats.lifetimeCoins += amount
    }

    mutating func spend(_ amount: Int) throws {
        guard amount >= 0 else { throw GameError.invalidQuantity }
        guard state.coins >= amount else { throw GameError.notEnoughCoins }
        state.coins -= amount
        state.stats.coinsSpent += amount
    }

    mutating func addReputation(_ amount: Int) {
        state.reputation = max(0, state.reputation + amount)
    }

    /// Reputation never drops below the start of the player's current level.
    mutating func loseReputation(_ amount: Int) {
        let floor = config.reputationFloor(for: state.reputation)
        state.reputation = max(floor, state.reputation - amount)
    }

    mutating func grantDecoration(_ id: String) {
        guard let def = content.decoration(id), !state.ownedDecorations.contains(id) else { return }
        state.ownedDecorations.insert(id)
        if state.equippedDecorations[def.slot.rawValue] == nil || def.slot == .collectible {
            state.equippedDecorations[def.slot.rawValue] = id
        }
    }

    // MARK: - Pricing

    @discardableResult
    public mutating func setPrice(productId: String, price: Int) throws -> Int {
        guard let product = content.product(productId) else { throw GameError.unknownItem }
        let clamped = config.clampPrice(price, for: product)
        let old = self.price(of: productId)
        state.prices[productId] = clamped
        if old != clamped {
            emit(.price_changed, ["product_id": productId, "old": "\(old)", "new": "\(clamped)"])
        }
        return clamped
    }

    // MARK: - Restocking

    /// Buys stock from the wholesaler. Returns the coins spent.
    @discardableResult
    public mutating func restock(productId: String, quantity: Int) throws -> Int {
        guard let product = content.product(productId) else { throw GameError.unknownItem }
        guard isProductAvailable(product) else { throw GameError.notAvailableYet }
        guard quantity > 0 else { throw GameError.invalidQuantity }
        guard stock(of: productId) + quantity <= stockCapacity else { throw GameError.capacityReached }
        let cost = restockCost(productId: productId, quantity: quantity)
        try spend(cost)
        state.inventory[productId] = stock(of: productId) + quantity
        state.stats.unitsRestocked += quantity
        state.shopDay.restockSpend += cost
        progressGoals(.restockUnits, by: quantity)
        emit(.product_restock, ["product_id": productId, "quantity": "\(quantity)", "cost": "\(cost)"])
        if state.tutorialStep == .restock {
            grantDecoration(ContentIDs.tutorialGiftDecoration)
            setTutorialStep(.decorGift)
        }
        return cost
    }

    // MARK: - Upgrades

    @discardableResult
    public mutating func buyUpgrade(_ id: String) throws -> Int {
        guard let def = content.upgrade(id) else { throw GameError.unknownItem }
        let level = upgradeLevel(id)
        guard level < def.maxLevel else { throw GameError.maxLevelReached }
        try spend(def.costs[level])
        state.upgradeLevels[id] = level + 1
        state.stats.upgradesBought += 1
        if def.effect == .customersPerDay && !state.shopDay.isFinished {
            state.shopDay.customersPlanned = max(state.shopDay.customersPlanned, customersPerDay)
        }
        progressGoals(.buyUpgrades, by: 1)
        emit(.upgrade_purchased, ["upgrade_id": id, "level": "\(level + 1)", "cost": "\(def.costs[level])"])
        return level + 1
    }

    // MARK: - Decorations

    public mutating func buyDecoration(_ id: String) throws {
        guard let def = content.decoration(id) else { throw GameError.unknownItem }
        guard !state.ownedDecorations.contains(id) else { throw GameError.alreadyOwned }
        guard let price = def.price else { throw GameError.notForSale }
        try spend(price)
        state.ownedDecorations.insert(id)
        state.equippedDecorations[def.slot.rawValue] = id
        state.stats.decorationsBought += 1
        progressGoals(.buyDecorations, by: 1)
        emit(.decoration_purchased, ["decoration_id": id, "slot": def.slot.rawValue, "cost": "\(price)"])
    }

    public mutating func equipDecoration(_ id: String) throws {
        guard let def = content.decoration(id) else { throw GameError.unknownItem }
        guard state.ownedDecorations.contains(id) else { throw GameError.notOwned }
        state.equippedDecorations[def.slot.rawValue] = id
    }

    /// Clears an optional slot. Required slots (walls, floor, counter, shelves) cannot be emptied.
    public mutating func clearDecorationSlot(_ slot: DecorSlot) throws {
        guard !slot.isRequired else { throw GameError.notEligible }
        state.equippedDecorations[slot.rawValue] = nil
    }

    // MARK: - Districts

    public func canUnlockDistrict(_ id: String) -> Bool {
        guard let def = content.district(id), def.isPlayable, !state.unlockedDistricts.contains(id) else { return false }
        return reputationLevel >= def.requiredReputationLevel && state.coins >= def.unlockCost
    }

    public mutating func unlockDistrict(_ id: String) throws {
        guard let def = content.district(id) else { throw GameError.unknownItem }
        guard def.isPlayable else { throw GameError.notPlayable }
        guard !state.unlockedDistricts.contains(id) else { throw GameError.alreadyOwned }
        guard reputationLevel >= def.requiredReputationLevel else { throw GameError.locked }
        try spend(def.unlockCost)
        state.unlockedDistricts.insert(id)
        for product in content.products where product.district == id && state.prices[product.id] == nil {
            state.prices[product.id] = product.recommendedPrice
        }
        emit(.district_unlocked, ["district_id": id])
    }

    public mutating func travel(to id: String) throws {
        guard let def = content.district(id) else { throw GameError.unknownItem }
        guard def.isPlayable else { throw GameError.notPlayable }
        guard state.unlockedDistricts.contains(id) else { throw GameError.locked }
        guard state.currentVisit == nil else { throw GameError.customerWaiting }
        state.currentDistrict = id
    }

    // MARK: - Tutorial

    mutating func setTutorialStep(_ step: TutorialStep) {
        guard state.tutorialStep != step else { return }
        state.tutorialStep = step
        emit(.tutorial_step, ["step": step.rawValue])
        if step == .done { emit(.tutorial_complete) }
    }

    /// Acknowledges an informational tutorial step (welcome, gift, goals).
    public mutating func acknowledgeTutorial(_ step: TutorialStep) {
        guard state.tutorialStep == step else { return }
        switch step {
        case .welcome: setTutorialStep(.firstSale)
        case .decorGift: setTutorialStep(.goals)
        case .goals: setTutorialStep(.done)
        case .firstSale, .restock, .done: break
        }
    }

    public mutating func skipTutorial() {
        guard state.tutorialStep != .done else { return }
        grantDecoration(ContentIDs.tutorialGiftDecoration)
        setTutorialStep(.done)
    }

    public var isInTutorial: Bool { state.tutorialStep != .done }
}
