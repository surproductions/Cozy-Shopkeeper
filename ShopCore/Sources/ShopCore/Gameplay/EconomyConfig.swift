import Foundation

/// Every tunable number in the game economy lives here, so balancing never
/// requires touching rules code.
public struct EconomyConfig: Sendable {
    // Starting state
    public var startingCoins = 150
    public var starterUnitsPerProduct = 4
    public var startingReputation = 0

    // Pricing
    /// Highest price a player may set, as a multiple of the recommended price.
    public var maxPriceMultiplier = 3.0
    public var minPrice = 1

    // Customer willingness to pay
    /// Bonus tolerance when the request is in one of the customer's favorite categories.
    public var favoriteToleranceBonus = 0.08
    /// Extra tolerance per relationship heart.
    public var heartToleranceBonus = 0.02
    /// How many price attempts a customer allows before leaving.
    public var patience = 2

    // Satisfaction (0...100)
    /// Price ratio (price / budget) at or below which a customer is fully happy with the price.
    public var bargainRatio = 0.8
    public var satisfactionAtBudget = 68
    public var favoriteSatisfactionBonus = 6
    public var giftWrapSatisfactionBonus = 10
    /// Each coziness point adds this much satisfaction, up to the cap.
    public var cozinessSatisfactionPerPoint = 0.5
    public var cozinessSatisfactionCap = 12
    public var delightedThreshold = 85
    public var tipThreshold = 60

    // Tips
    public var giftWrapTipBonus = 0.1

    // Reputation
    public var reputationLevelThresholds = [0, 30, 90, 180, 320, 500, 750, 1050, 1400, 1800]
    public var reputationLossOnWalkout = 1
    public var baseReputationPerSale = 1

    // Relationships
    public var relationshipPointsPerHeart = 4
    public var maxHearts = 5
    public var regularHearts = 2
    public var regularSpawnBoost = 1.5
    public var discoveryRewardCoins = 20
    /// Chance an in-stock product is preferred over out-of-stock when picking a request.
    public var inStockPreferenceWeight = 4.0
    public var rareWeightForCollectors = 3.0

    // Ads (policy only — no ad network is bundled)
    public var rewardedDayBonusFraction = 0.5
    public var rewardedDayBonusMinimum = 15
    public var interstitialMinCompletedDays = 3
    public var interstitialMinSecondsSinceFirstOpen: TimeInterval = 15 * 60
    public var interstitialCooldownSeconds: TimeInterval = 5 * 60
    public var interstitialSessionCap = 2

    // Daily goals
    public var dailyGoalCount = 3

    public init() {}

    public static let standard = EconomyConfig()

    public func reputationLevel(for points: Int) -> Int {
        var level = 0
        for (index, threshold) in reputationLevelThresholds.enumerated() where points >= threshold {
            level = index
        }
        return level
    }

    public func reputationFloor(for points: Int) -> Int {
        reputationLevelThresholds[reputationLevel(for: points)]
    }

    /// Progress (0...1) toward the next reputation level.
    public func reputationProgress(for points: Int) -> Double {
        let level = reputationLevel(for: points)
        guard level + 1 < reputationLevelThresholds.count else { return 1 }
        let lower = reputationLevelThresholds[level]
        let upper = reputationLevelThresholds[level + 1]
        return Double(points - lower) / Double(upper - lower)
    }

    public func maxPrice(for product: ProductDef) -> Int {
        max(minPrice, Int((Double(product.recommendedPrice) * maxPriceMultiplier).rounded()))
    }

    public func clampPrice(_ price: Int, for product: ProductDef) -> Int {
        min(max(price, minPrice), maxPrice(for: product))
    }
}
