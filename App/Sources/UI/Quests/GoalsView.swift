import SwiftUI
import ShopCore

struct GoalsView: View {
    @EnvironmentObject private var store: GameStore
    @State private var tab: Tab = .today

    enum Tab: String, CaseIterable, Identifiable {
        case today = "Today", achievements = "Achievements", collections = "Collections"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Goals", subtitle: "Daily goals, milestones and collections.") {
                store.activeSheet = nil
            }
            Picker("Section", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            ScrollView {
                VStack(spacing: 12) {
                    switch tab {
                    case .today: todaySection
                    case .achievements: achievementsSection
                    case .collections: collectionsSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
        .background(ParchmentBackground())
    }

    // MARK: Today

    @ViewBuilder
    private var todaySection: some View {
        DailyRewardStrip()
        Text("Today's goals")
            .font(Theme.headline).foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
        if store.state.daily.goals.isEmpty {
            EmptyStateView(symbol: "sun.haze", title: "Goals are on their way", message: "Fresh goals appear each morning.")
        }
        ForEach(store.state.daily.goals) { goal in
            if let quest = store.content.quest(goal.questId) {
                GoalRow(title: quest.title, progress: goal.progress, target: quest.target, reward: quest.rewardCoins, claimed: goal.claimed) {
                    store.claimGoal(quest.id)
                }
            }
        }
        SoftText("Goals refresh at midnight. Missing a day never resets your progress.", font: Theme.caption)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Achievements

    @ViewBuilder
    private var achievementsSection: some View {
        let engine = store.engine
        let milestones = store.content.achievements.filter(\.isMilestone)
        let others = store.content.achievements.filter { !$0.isMilestone }
        Text("Shop milestones").font(Theme.headline).foregroundStyle(Theme.ink).frame(maxWidth: .infinity, alignment: .leading)
        ForEach(milestones) { def in achievementRow(def, engine: engine) }
        Text("Achievements").font(Theme.headline).foregroundStyle(Theme.ink).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6)
        ForEach(others) { def in achievementRow(def, engine: engine) }
    }

    private func achievementRow(_ def: AchievementDef, engine: GameEngine) -> some View {
        let done = engine.isAchieved(def)
        let claimed = store.state.claimedAchievements.contains(def.id)
        return Panel(padding: 12) {
            HStack(spacing: 12) {
                Image(systemName: claimed ? "medal.fill" : done ? "gift.fill" : "lock.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(claimed ? Theme.gold : done ? Theme.terracotta : Theme.cardEdge)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(def.title).font(Theme.headline).foregroundStyle(Theme.ink)
                    SoftText(def.detail, font: Theme.caption)
                }
                Spacer(minLength: 4)
                claimControl(done: done, claimed: claimed, reward: def.rewardCoins) { store.claimAchievement(def.id) }
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Collections

    @ViewBuilder
    private var collectionsSection: some View {
        ForEach(store.content.collections) { def in
            let progress = store.engine.collectionProgress(def)
            let claimed = store.state.claimedCollections.contains(def.id)
            Panel {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(def.title).font(Theme.headline).foregroundStyle(Theme.ink)
                            SoftText(def.detail, font: Theme.caption)
                        }
                        Spacer()
                        claimControl(done: progress.isComplete, claimed: claimed, reward: def.rewardCoins) { store.claimCollection(def.id) }
                    }
                    collectionItems(def, progress: progress)
                    HStack {
                        CozyProgressBar(value: Double(progress.have) / Double(max(1, progress.total)), tint: Theme.teal)
                        Text("\(progress.have)/\(progress.total)").font(Theme.caption.weight(.bold)).foregroundStyle(Theme.inkSoft)
                    }
                    if let deco = def.rewardDecoration.flatMap({ store.content.decoration($0) }) {
                        SoftText("Bonus keepsake: \(deco.name)", font: Theme.caption)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func collectionItems(_ def: CollectionDef, progress: CollectionProgress) -> some View {
        switch def.requirement {
        case .sellProducts(let ids):
            HStack(spacing: 6) {
                ForEach(ids, id: \.self) { id in
                    if let product = store.content.product(id) {
                        ProductIcon(product: product, size: 34, faded: progress.missing.contains(id))
                            .overlay(alignment: .bottomTrailing) {
                                if !progress.missing.contains(id) {
                                    Image(systemName: "checkmark.circle.fill").font(.system(size: 11)).foregroundStyle(Theme.deepSage)
                                }
                            }
                            .accessibilityLabel("\(product.name), \(progress.missing.contains(id) ? "not sold yet" : "sold")")
                    }
                }
            }
        case .ownDecorations(let ids):
            HStack(spacing: 6) {
                ForEach(ids, id: \.self) { id in
                    if let deco = store.content.decoration(id) {
                        Swatch(decoration: deco)
                            .scaleEffect(0.7)
                            .frame(width: 38, height: 38)
                            .opacity(progress.missing.contains(id) ? 0.35 : 1)
                            .accessibilityLabel("\(deco.name), \(progress.missing.contains(id) ? "missing" : "owned")")
                    }
                }
            }
        case .discoverCustomers:
            SoftText("Customers met: \(store.state.customers.count)", font: Theme.caption)
        }
    }

    @ViewBuilder
    private func claimControl(done: Bool, claimed: Bool, reward: Int, claim: @escaping () -> Void) -> some View {
        if claimed {
            Tag(text: "Claimed", color: Theme.deepSage)
        } else if done {
            Button(action: claim) {
                HStack(spacing: 4) {
                    Text("Claim")
                    CoinAmount(amount: reward, font: Theme.callout.weight(.bold), size: 13)
                }
            }
            .buttonStyle(.cozy(.secondary, compact: true))
        } else {
            CoinAmount(amount: reward, font: Theme.callout, size: 13).opacity(0.6)
        }
    }
}

struct GoalRow: View {
    let title: String
    let progress: Int
    let target: Int
    let reward: Int
    let claimed: Bool
    let claim: () -> Void

    var body: some View {
        let done = progress >= target
        Panel(padding: 12) {
            HStack(spacing: 12) {
                Image(systemName: claimed ? "checkmark.circle.fill" : done ? "star.circle.fill" : "circle.dotted")
                    .font(.system(size: 24))
                    .foregroundStyle(claimed ? Theme.deepSage : done ? Theme.gold : Theme.sage)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(Theme.headline).foregroundStyle(Theme.ink)
                    HStack {
                        CozyProgressBar(value: Double(progress) / Double(max(1, target)), height: 8)
                        Text("\(progress)/\(target)").font(Theme.caption.weight(.bold)).foregroundStyle(Theme.inkSoft).monospacedDigit()
                    }
                }
                if claimed {
                    Tag(text: "Done", color: Theme.deepSage)
                } else if done {
                    Button(action: claim) {
                        HStack(spacing: 4) { Text("Claim"); CoinAmount(amount: reward, font: Theme.callout.weight(.bold), size: 13) }
                    }
                    .buttonStyle(.cozy(.secondary, compact: true))
                } else {
                    CoinAmount(amount: reward, font: Theme.callout, size: 13).opacity(0.7)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// The 7-day welcome-back strip. Progress never resets when a day is missed.
struct DailyRewardStrip: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        let engine = store.engine
        let available = engine.isDailyRewardAvailable(now: Date(), timeZone: .current)
        let index = engine.dailyRewardIndex
        Panel {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "calendar").foregroundStyle(Theme.terracotta)
                    Text("Daily gift").font(Theme.headline).foregroundStyle(Theme.ink)
                    Spacer()
                    SoftText(available ? "Ready to open!" : "Come back tomorrow", font: Theme.caption)
                }
                HStack(spacing: 5) {
                    ForEach(Array(store.content.dailyRewards.enumerated()), id: \.offset) { offset, reward in
                        let isNext = offset == index
                        let past = offset < index
                        VStack(spacing: 3) {
                            Text("Day \(reward.day)").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(Theme.inkSoft)
                            rewardGlyph(reward.kind)
                                .frame(height: 22)
                            Text(rewardLabel(reward.kind)).font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.6)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 10).fill(isNext ? Theme.gold.opacity(0.25) : past ? Theme.sage.opacity(0.2) : Theme.parchment))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(isNext ? Theme.gold : .clear, lineWidth: 2))
                        .overlay(alignment: .topTrailing) {
                            if past { Image(systemName: "checkmark.circle.fill").font(.system(size: 10)).foregroundStyle(Theme.deepSage).offset(x: 2, y: -2) }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Day \(reward.day): \(rewardLabel(reward.kind))\(past ? ", collected" : isNext ? ", next" : "")")
                    }
                }
                Button {
                    store.claimDailyReward()
                } label: {
                    Text(available ? "Open today's gift" : "Already opened today").frame(maxWidth: .infinity)
                }
                .buttonStyle(.cozy(available ? .primary : .quiet, compact: true))
                .disabled(!available)
                .accessibilityIdentifier("claimDailyReward")
            }
        }
    }

    @ViewBuilder
    private func rewardGlyph(_ kind: DailyRewardKind) -> some View {
        switch kind {
        case .coins: CoinGlyph(size: 18)
        case .decoration: Image(systemName: "gift.fill").foregroundStyle(Theme.terracotta)
        case .reputation: Image(systemName: "star.fill").foregroundStyle(Theme.gold)
        }
    }

    private func rewardLabel(_ kind: DailyRewardKind) -> String {
        switch kind {
        case .coins(let n): return "\(n)"
        case .decoration: return "Keepsake"
        case .reputation(let n): return "+\(n) rep"
        }
    }
}

/// Popped up once per session when a daily gift is waiting.
struct DailyRewardSheet: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 14) {
            Text("Welcome back!").font(Theme.title(26)).foregroundStyle(Theme.ink)
            SoftText("A little gift for stopping by today.", font: Theme.callout)
            DailyRewardStrip()
            Button("Maybe later") { dismiss() }
                .font(Theme.callout)
                .foregroundStyle(Theme.inkSoft)
                .frame(minHeight: 44)
        }
        .padding(20)
        .background(ParchmentBackground())
        .onChange(of: store.state.dailyReward.claimedCount) { _, _ in
            Task {
                try? await Task.sleep(nanoseconds: 900_000_000)
                dismiss()
            }
        }
    }
}
