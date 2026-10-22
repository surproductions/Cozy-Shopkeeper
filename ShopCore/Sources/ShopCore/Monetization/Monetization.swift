import Foundation

// MARK: - Ads

public enum AdPlacement: String, Sendable {
    case dayBonus = "day_bonus"
    case dayEndInterstitial = "day_end_interstitial"
}

/// Result reported by an ad provider. Only `.completed` may unlock a reward.
public enum AdResult: Equatable, Sendable {
    case completed
    case dismissedEarly
    case unavailable
    case failed(String)
}

public extension GameEngine {
    /// Bonus offered after a finished day: a share of the day's tips, with a floor.
    var rewardedDayBonusAmount: Int {
        max(config.rewardedDayBonusMinimum, Int((Double(state.shopDay.tips) * config.rewardedDayBonusFraction).rounded()))
    }

    var rewardedDayBonusKey: String { "dayBonus-\(state.shopDay.dayNumber)" }

    var isRewardedDayBonusOffered: Bool {
        state.shopDay.isFinished && !state.ads.rewardedClaims.contains(rewardedDayBonusKey)
    }

    /// Grants the optional day bonus — only when the ad network reported a completed view.
    @discardableResult
    mutating func grantRewardedDayBonus(result: AdResult) throws -> Int {
        guard state.shopDay.isFinished else { throw GameError.dayStillOpen }
        guard !state.ads.rewardedClaims.contains(rewardedDayBonusKey) else { throw GameError.alreadyClaimed }
        guard result == .completed else { throw GameError.adNotCompleted }
        let amount = rewardedDayBonusAmount
        state.ads.rewardedClaims.insert(rewardedDayBonusKey)
        earn(amount)
        emit(.ad_completed, ["placement": AdPlacement.dayBonus.rawValue, "reward": "\(amount)"])
        return amount
    }

    mutating func recordInterstitialShown(at date: Date) {
        state.ads.lastInterstitialAt = date
        state.ads.totalInterstitials += 1
        emit(.ad_impression, ["placement": AdPlacement.dayEndInterstitial.rawValue])
    }
}

/// Conservative rules for when an interruptive ad may appear. Pure so it can be tested.
public struct InterstitialPolicy: Sendable {
    public let config: EconomyConfig

    public init(config: EconomyConfig = .standard) {
        self.config = config
    }

    /// Interstitials are only ever considered at the natural break after closing a shop day.
    public func shouldShow(state: GameState, now: Date, shownThisSession: Int, adReady: Bool) -> Bool {
        guard adReady else { return false }
        guard !state.entitlements.removeAds else { return false }
        guard state.tutorialStep == .done else { return false }
        guard state.stats.daysCompleted >= config.interstitialMinCompletedDays else { return false }
        guard now.timeIntervalSince(state.firstOpenedAt) >= config.interstitialMinSecondsSinceFirstOpen else { return false }
        guard shownThisSession < config.interstitialSessionCap else { return false }
        if let last = state.ads.lastInterstitialAt, now.timeIntervalSince(last) < config.interstitialCooldownSeconds {
            return false
        }
        return true
    }
}

// MARK: - In-app purchases

public enum StoreProductID {
    /// Non-consumable that removes interruptive (interstitial) ads. Rewarded ads stay optional.
    public static let removeAds = "com.surproductions.cozyshopkeeper.removeads"
    public static let all: [String] = [removeAds]
}

/// Platform-neutral description of what happened during a purchase attempt.
public enum PurchaseOutcome: Equatable, Sendable {
    case verified(productId: String)
    case unverified(productId: String, reason: String)
    case userCancelled
    case pending
    case failed(String)
    case productUnavailable
}

/// Decides entitlements from purchase outcomes and verified transaction lists.
/// Unverified, cancelled, pending or failed purchases never grant anything.
public enum EntitlementLedger {
    public static func removeAdsOwned(afterOutcome outcome: PurchaseOutcome, previouslyOwned: Bool) -> Bool {
        switch outcome {
        case .verified(let productId):
            return previouslyOwned || productId == StoreProductID.removeAds
        case .unverified, .userCancelled, .pending, .failed, .productUnavailable:
            return previouslyOwned
        }
    }

    /// Rebuilds entitlements from the verified, unrevoked product ids StoreKit reports.
    public static func removeAdsOwned(verifiedProductIds: Set<String>) -> Bool {
        verifiedProductIds.contains(StoreProductID.removeAds)
    }
}
