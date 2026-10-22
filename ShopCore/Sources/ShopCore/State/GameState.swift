import Foundation

// All persistent player state. Every field decodes leniently (missing keys fall
// back to defaults) so older saves keep loading as the game grows.

public struct CustomerRecord: Codable, Equatable, Sendable {
    public var visits: Int = 0
    public var purchases: Int = 0
    public var relationshipPoints: Int = 0
    public var totalSatisfaction: Int = 0
    public var discoveredOnShopDay: Int = 1
    public var heartGiftClaimed: Bool = false

    public init(discoveredOnShopDay: Int = 1) {
        self.discoveredOnShopDay = discoveredOnShopDay
    }

    public var averageSatisfaction: Int {
        purchases == 0 ? 0 : totalSatisfaction / purchases
    }

    enum CodingKeys: String, CodingKey { case visits, purchases, relationshipPoints, totalSatisfaction, discoveredOnShopDay, heartGiftClaimed }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        visits = c.lenient(.visits, 0)
        purchases = c.lenient(.purchases, 0)
        relationshipPoints = c.lenient(.relationshipPoints, 0)
        totalSatisfaction = c.lenient(.totalSatisfaction, 0)
        discoveredOnShopDay = c.lenient(.discoveredOnShopDay, 1)
        heartGiftClaimed = c.lenient(.heartGiftClaimed, false)
    }
}

/// A customer currently standing at the counter.
public struct CustomerVisit: Codable, Equatable, Sendable, Identifiable {
    public var id: Int
    public var customerId: String
    public var productId: String
    public var quantity: Int
    /// Highest unit price this customer will accept (hidden until they become a regular).
    public var maxUnitPrice: Int
    public var wantsGiftWrap: Bool
    public var attemptsUsed: Int
    public var greeting: String
    public var isTutorial: Bool
    public var isFirstVisit: Bool
}

public struct ShopDayState: Codable, Equatable, Sendable {
    public var dayNumber: Int = 1
    public var customersPlanned: Int = 6
    public var customersArrived: Int = 0
    public var customersServed: Int = 0
    public var customersMissed: Int = 0
    public var revenue: Int = 0
    public var tips: Int = 0
    public var restockSpend: Int = 0
    /// True once every planned customer has come and gone; the summary is waiting to be closed.
    public var isFinished: Bool = false

    public init() {}

    enum CodingKeys: String, CodingKey { case dayNumber, customersPlanned, customersArrived, customersServed, customersMissed, revenue, tips, restockSpend, isFinished }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dayNumber = c.lenient(.dayNumber, 1)
        customersPlanned = c.lenient(.customersPlanned, 6)
        customersArrived = c.lenient(.customersArrived, 0)
        customersServed = c.lenient(.customersServed, 0)
        customersMissed = c.lenient(.customersMissed, 0)
        revenue = c.lenient(.revenue, 0)
        tips = c.lenient(.tips, 0)
        restockSpend = c.lenient(.restockSpend, 0)
        isFinished = c.lenient(.isFinished, false)
    }
}

public struct GoalProgress: Codable, Equatable, Sendable, Identifiable {
    public var id: String { questId }
    public var questId: String
    public var progress: Int
    public var claimed: Bool
}

public struct DailyState: Codable, Equatable, Sendable {
    /// Calendar day the goals belong to ("yyyy-MM-dd").
    public var dayKey: String = ""
    public var goals: [GoalProgress] = []
    /// Latest calendar day ever observed; protects against clock rollback.
    public var latestSeenDayKey: String = ""

    public init() {}

    enum CodingKeys: String, CodingKey { case dayKey, goals, latestSeenDayKey }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dayKey = c.lenient(.dayKey, "")
        goals = c.lenient(.goals, [])
        latestSeenDayKey = c.lenient(.latestSeenDayKey, "")
    }
}

public struct DailyRewardState: Codable, Equatable, Sendable {
    /// Number of rewards claimed so far (the next reward is index `claimedCount % 7`).
    public var claimedCount: Int = 0
    public var lastClaimDayKey: String? = nil

    public init() {}

    enum CodingKeys: String, CodingKey { case claimedCount, lastClaimDayKey }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        claimedCount = c.lenient(.claimedCount, 0)
        lastClaimDayKey = try? c.decodeIfPresent(String.self, forKey: .lastClaimDayKey)
    }
}

public enum TutorialStep: String, Codable, Sendable, CaseIterable {
    case welcome, firstSale, restock, decorGift, goals, done
}

public struct PlayerStats: Codable, Equatable, Sendable {
    public var totalSales: Int = 0
    public var itemsSold: Int = 0
    public var delightedSales: Int = 0
    public var walkouts: Int = 0
    public var daysCompleted: Int = 0
    public var unitsRestocked: Int = 0
    public var upgradesBought: Int = 0
    public var decorationsBought: Int = 0
    public var lifetimeCoins: Int = 0
    public var lifetimeTips: Int = 0
    public var coinsSpent: Int = 0

    public init() {}

    enum CodingKeys: String, CodingKey { case totalSales, itemsSold, delightedSales, walkouts, daysCompleted, unitsRestocked, upgradesBought, decorationsBought, lifetimeCoins, lifetimeTips, coinsSpent }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalSales = c.lenient(.totalSales, 0)
        itemsSold = c.lenient(.itemsSold, 0)
        delightedSales = c.lenient(.delightedSales, 0)
        walkouts = c.lenient(.walkouts, 0)
        daysCompleted = c.lenient(.daysCompleted, 0)
        unitsRestocked = c.lenient(.unitsRestocked, 0)
        upgradesBought = c.lenient(.upgradesBought, 0)
        decorationsBought = c.lenient(.decorationsBought, 0)
        lifetimeCoins = c.lenient(.lifetimeCoins, 0)
        lifetimeTips = c.lenient(.lifetimeTips, 0)
        coinsSpent = c.lenient(.coinsSpent, 0)
    }
}

public struct GameSettings: Codable, Equatable, Sendable {
    public var musicVolume: Double = 0.6
    public var sfxVolume: Double = 0.8
    public var hapticsEnabled: Bool = true
    public var reducedMotion: Bool = false
    public var largerText: Bool = false
    public var highContrast: Bool = false

    public init() {}

    enum CodingKeys: String, CodingKey { case musicVolume, sfxVolume, hapticsEnabled, reducedMotion, largerText, highContrast }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        musicVolume = min(max(c.lenient(.musicVolume, 0.6), 0), 1)
        sfxVolume = min(max(c.lenient(.sfxVolume, 0.8), 0), 1)
        hapticsEnabled = c.lenient(.hapticsEnabled, true)
        reducedMotion = c.lenient(.reducedMotion, false)
        largerText = c.lenient(.largerText, false)
        highContrast = c.lenient(.highContrast, false)
    }
}

/// Cached copy of StoreKit entitlements. StoreKit's verified transactions remain authoritative;
/// this cache only lets the game behave correctly before StoreKit answers at launch.
public struct EntitlementCache: Codable, Equatable, Sendable {
    public var removeAds: Bool = false
    public var lastVerifiedAt: Date? = nil

    public init() {}

    enum CodingKeys: String, CodingKey { case removeAds, lastVerifiedAt }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        removeAds = c.lenient(.removeAds, false)
        lastVerifiedAt = try? c.decodeIfPresent(Date.self, forKey: .lastVerifiedAt)
    }
}

public struct AdPacingState: Codable, Equatable, Sendable {
    public var lastInterstitialAt: Date? = nil
    public var totalInterstitials: Int = 0
    /// Rewarded bonuses already granted, keyed by placement + context (e.g. "dayBonus-12").
    public var rewardedClaims: Set<String> = []

    public init() {}

    enum CodingKeys: String, CodingKey { case lastInterstitialAt, totalInterstitials, rewardedClaims }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lastInterstitialAt = try? c.decodeIfPresent(Date.self, forKey: .lastInterstitialAt)
        totalInterstitials = c.lenient(.totalInterstitials, 0)
        rewardedClaims = c.lenient(.rewardedClaims, [])
    }
}

public struct GameState: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int = GameState.currentSchemaVersion
    public var seed: UInt64 = 0
    public var firstOpenedAt: Date = Date(timeIntervalSince1970: 0)
    public var coins: Int = 0
    public var reputation: Int = 0
    public var inventory: [String: Int] = [:]
    public var prices: [String: Int] = [:]
    public var productsEverSold: Set<String> = []
    public var upgradeLevels: [String: Int] = [:]
    public var ownedDecorations: Set<String> = []
    public var equippedDecorations: [String: String] = [:]
    public var customers: [String: CustomerRecord] = [:]
    public var currentDistrict: String = ContentIDs.startingDistrict
    public var unlockedDistricts: Set<String> = [ContentIDs.startingDistrict]
    public var shopDay = ShopDayState()
    public var currentVisit: CustomerVisit? = nil
    public var visitCounter: Int = 0
    public var lastCustomerId: String? = nil
    public var stats = PlayerStats()
    public var daily = DailyState()
    public var dailyReward = DailyRewardState()
    public var claimedAchievements: Set<String> = []
    public var claimedCollections: Set<String> = []
    public var tutorialStep: TutorialStep = .welcome
    public var settings = GameSettings()
    public var entitlements = EntitlementCache()
    public var ads = AdPacingState()

    public init() {}

    enum CodingKeys: String, CodingKey {
        case schemaVersion, seed, firstOpenedAt, coins, reputation, inventory, prices, productsEverSold
        case upgradeLevels, ownedDecorations, equippedDecorations, customers, currentDistrict, unlockedDistricts
        case shopDay, currentVisit, visitCounter, lastCustomerId, stats, daily, dailyReward, claimedAchievements
        case claimedCollections, tutorialStep, settings, entitlements, ads
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = c.lenient(.schemaVersion, 1)
        seed = c.lenient(.seed, 0)
        firstOpenedAt = c.lenient(.firstOpenedAt, Date(timeIntervalSince1970: 0))
        // Coins are the one field we refuse to guess: a save without coins is invalid.
        coins = try c.decode(Int.self, forKey: .coins)
        reputation = c.lenient(.reputation, 0)
        inventory = c.lenient(.inventory, [:])
        prices = c.lenient(.prices, [:])
        productsEverSold = c.lenient(.productsEverSold, [])
        upgradeLevels = c.lenient(.upgradeLevels, [:])
        ownedDecorations = c.lenient(.ownedDecorations, [])
        equippedDecorations = c.lenient(.equippedDecorations, [:])
        customers = c.lenient(.customers, [:])
        currentDistrict = c.lenient(.currentDistrict, ContentIDs.startingDistrict)
        unlockedDistricts = c.lenient(.unlockedDistricts, [ContentIDs.startingDistrict])
        shopDay = c.lenient(.shopDay, ShopDayState())
        currentVisit = try? c.decodeIfPresent(CustomerVisit.self, forKey: .currentVisit)
        visitCounter = c.lenient(.visitCounter, 0)
        lastCustomerId = try? c.decodeIfPresent(String.self, forKey: .lastCustomerId)
        stats = c.lenient(.stats, PlayerStats())
        daily = c.lenient(.daily, DailyState())
        dailyReward = c.lenient(.dailyReward, DailyRewardState())
        claimedAchievements = c.lenient(.claimedAchievements, [])
        claimedCollections = c.lenient(.claimedCollections, [])
        tutorialStep = c.lenient(.tutorialStep, .done)
        settings = c.lenient(.settings, GameSettings())
        entitlements = c.lenient(.entitlements, EntitlementCache())
        ads = c.lenient(.ads, AdPacingState())
    }
}

extension KeyedDecodingContainer {
    /// Decodes a value, falling back to `fallback` if the key is missing or malformed.
    func lenient<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        ((try? decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
    }
}
