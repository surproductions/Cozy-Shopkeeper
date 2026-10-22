import Foundation

public struct CollectionProgress: Equatable, Sendable {
    public let have: Int
    public let total: Int
    /// Item ids still missing (empty for count-based collections).
    public let missing: [String]
    public var isComplete: Bool { have >= total }
}

public extension GameEngine {

    // MARK: - Daily goals

    /// Rolls the calendar forward. Generates fresh goals on a new day. Moving the clock
    /// backwards never regenerates goals or re-enables rewards.
    @discardableResult
    mutating func refreshCalendarDay(now: Date, timeZone: TimeZone) -> Bool {
        let today = DayClock.dayKey(for: now, timeZone: timeZone)
        if today > state.daily.latestSeenDayKey {
            state.daily.latestSeenDayKey = today
        }
        guard today > state.daily.dayKey, today >= state.daily.latestSeenDayKey else { return false }
        state.daily.dayKey = today
        state.daily.goals = generateGoals(for: today).map { GoalProgress(questId: $0.id, progress: 0, claimed: false) }
        for goal in state.daily.goals {
            emit(.quest_started, ["quest_id": goal.questId, "day_key": today])
        }
        return true
    }

    func isGoalFeasible(_ quest: QuestDef) -> Bool {
        switch quest.kind {
        case .sellCategory(let category):
            return availableProducts.contains { $0.category == category }
        case .serveRegulars:
            return regularCount >= 1
        case .buyUpgrades:
            return content.upgrades.contains { upgradeLevel($0.id) < $0.maxLevel }
        case .buyDecorations:
            return content.decorations.contains { $0.price != nil && $0.price! > 0 && !state.ownedDecorations.contains($0.id) }
        case .discoverCustomers:
            return content.customers.contains { isCustomerEligible($0) && state.customers[$0.id] == nil }
        case .sellItems, .earnCoins, .receiveTips, .restockUnits, .completeShopDays, .delightCustomers:
            return true
        }
    }

    /// Deterministically picks one feasible goal per group for a calendar day.
    func generateGoals(for dayKey: String) -> [QuestDef] {
        var rng = SeededRandom(seed: SeededRandom.hash(dayKey) ^ state.seed)
        var picked: [QuestDef] = []
        for group in [QuestGroup.selling, .earning, .shopkeeping] {
            let options = content.quests.filter { $0.group == group && isGoalFeasible($0) }
            if let choice = rng.weightedPick(options.map { ($0, 1.0) }) {
                picked.append(choice)
            }
        }
        if picked.count < config.dailyGoalCount {
            let fillers = content.quests.filter { quest in isGoalFeasible(quest) && !picked.contains(where: { $0.id == quest.id }) }
            for quest in fillers where picked.count < config.dailyGoalCount {
                picked.append(quest)
            }
        }
        return Array(picked.prefix(config.dailyGoalCount))
    }

    internal mutating func progressGoals(_ kind: QuestKind, by amount: Int) {
        guard amount > 0 else { return }
        for index in state.daily.goals.indices {
            let goal = state.daily.goals[index]
            guard !goal.claimed, let quest = content.quest(goal.questId), quest.kind == kind else { continue }
            let before = goal.progress
            let after = min(quest.target, before + amount)
            state.daily.goals[index].progress = after
            if before < quest.target && after >= quest.target {
                emit(.quest_completed, ["quest_id": quest.id])
            }
        }
    }

    @discardableResult
    mutating func claimGoal(_ questId: String) throws -> Int {
        guard let index = state.daily.goals.firstIndex(where: { $0.questId == questId }),
              let quest = content.quest(questId) else { throw GameError.unknownItem }
        guard !state.daily.goals[index].claimed else { throw GameError.alreadyClaimed }
        guard state.daily.goals[index].progress >= quest.target else { throw GameError.notEligible }
        state.daily.goals[index].claimed = true
        earn(quest.rewardCoins)
        return quest.rewardCoins
    }

    // MARK: - Daily rewards

    var nextDailyReward: DailyRewardDef {
        content.dailyRewards[state.dailyReward.claimedCount % content.dailyRewards.count]
    }

    /// Index (0...6) of the next reward in the 7-day strip.
    var dailyRewardIndex: Int { state.dailyReward.claimedCount % content.dailyRewards.count }

    func isDailyRewardAvailable(now: Date, timeZone: TimeZone) -> Bool {
        let today = DayClock.dayKey(for: now, timeZone: timeZone)
        // A clock set earlier than a day already seen cannot claim.
        guard today >= state.daily.latestSeenDayKey else { return false }
        guard let last = state.dailyReward.lastClaimDayKey else { return true }
        return today > last
    }

    @discardableResult
    mutating func claimDailyReward(now: Date, timeZone: TimeZone) throws -> DailyRewardDef {
        refreshCalendarDay(now: now, timeZone: timeZone)
        guard isDailyRewardAvailable(now: now, timeZone: timeZone) else { throw GameError.alreadyClaimed }
        let reward = nextDailyReward
        switch reward.kind {
        case .coins(let amount):
            earn(amount)
        case .reputation(let amount):
            addReputation(amount)
        case .decoration(let id, let fallback):
            if state.ownedDecorations.contains(id) { earn(fallback) } else { grantDecoration(id) }
        }
        state.dailyReward.claimedCount += 1
        state.dailyReward.lastClaimDayKey = DayClock.dayKey(for: now, timeZone: timeZone)
        emit(.daily_reward_claimed, ["day": "\(reward.day)", "streak_total": "\(state.dailyReward.claimedCount)"])
        return reward
    }

    // MARK: - Collections

    func collectionProgress(_ def: CollectionDef) -> CollectionProgress {
        switch def.requirement {
        case .sellProducts(let ids):
            let missing = ids.filter { !state.productsEverSold.contains($0) }
            return CollectionProgress(have: ids.count - missing.count, total: ids.count, missing: missing)
        case .ownDecorations(let ids):
            let missing = ids.filter { !state.ownedDecorations.contains($0) }
            return CollectionProgress(have: ids.count - missing.count, total: ids.count, missing: missing)
        case .discoverCustomers(let count):
            return CollectionProgress(have: min(count, state.customers.count), total: count, missing: [])
        }
    }

    var completedCollectionCount: Int {
        content.collections.filter { collectionProgress($0).isComplete }.count
    }

    @discardableResult
    mutating func claimCollection(_ id: String) throws -> Int {
        guard let def = content.collections.first(where: { $0.id == id }) else { throw GameError.unknownItem }
        guard !state.claimedCollections.contains(id) else { throw GameError.alreadyClaimed }
        let progress = collectionProgress(def)
        guard progress.isComplete else { throw GameError.notEligible }
        state.claimedCollections.insert(id)
        earn(def.rewardCoins)
        if let deco = def.rewardDecoration { grantDecoration(deco) }
        emit(.collection_progress, ["collection_id": id, "have": "\(progress.have)", "total": "\(progress.total)", "claimed": "true"])
        return def.rewardCoins
    }

    // MARK: - Achievements

    func isAchieved(_ def: AchievementDef) -> Bool {
        switch def.condition {
        case .totalSales(let n): return state.stats.totalSales >= n
        case .daysCompleted(let n): return state.stats.daysCompleted >= n
        case .upgradesBought(let n): return state.stats.upgradesBought >= n
        case .decorationsBought(let n): return state.stats.decorationsBought >= n
        case .regulars(let n): return regularCount >= n
        case .reputationLevel(let n): return reputationLevel >= n
        case .lifetimeCoins(let n): return state.stats.lifetimeCoins >= n
        case .collectionsCompleted(let n): return completedCollectionCount >= n
        case .districtUnlocked(let id): return state.unlockedDistricts.contains(id)
        case .customersDiscovered(let n): return state.customers.count >= n
        case .delightedSales(let n): return state.stats.delightedSales >= n
        }
    }

    @discardableResult
    mutating func claimAchievement(_ id: String) throws -> Int {
        guard let def = content.achievements.first(where: { $0.id == id }) else { throw GameError.unknownItem }
        guard !state.claimedAchievements.contains(id) else { throw GameError.alreadyClaimed }
        guard isAchieved(def) else { throw GameError.notEligible }
        state.claimedAchievements.insert(id)
        earn(def.rewardCoins)
        return def.rewardCoins
    }

    /// Number of goals, achievements and collections ready to claim (for badges).
    var claimableCount: Int {
        let goals = state.daily.goals.filter { goal in
            guard let quest = content.quest(goal.questId) else { return false }
            return !goal.claimed && goal.progress >= quest.target
        }.count
        let achievements = content.achievements.filter { !state.claimedAchievements.contains($0.id) && isAchieved($0) }.count
        let collections = content.collections.filter { !state.claimedCollections.contains($0.id) && collectionProgress($0).isComplete }.count
        return goals + achievements + collections
    }

    /// The most useful next thing for the player to aim for.
    var nextGoalHint: String {
        if let goal = state.daily.goals.first(where: { goal in
            guard let quest = content.quest(goal.questId) else { return false }
            return !goal.claimed && goal.progress < quest.target
        }), let quest = content.quest(goal.questId) {
            return "\(quest.title) (\(goal.progress)/\(quest.target))"
        }
        if let upgrade = content.upgrades.first(where: { upgradeLevel($0.id) < $0.maxLevel }) {
            return "Save up for \(upgrade.name) — \(upgrade.costs[upgradeLevel(upgrade.id)]) coins"
        }
        return "Keep your regulars happy!"
    }
}
