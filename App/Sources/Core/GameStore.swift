import SwiftUI
import UIKit
import ShopCore

/// A short-lived message shown at the top of the screen.
struct Toast: Identifiable, Equatable {
    enum Kind { case info, success, warning }
    let id = UUID()
    let text: String
    let kind: Kind
}

/// What the customer says after the player acts.
struct CustomerReaction: Identifiable, Equatable {
    enum Mood { case delighted, happy, hesitant, sad }
    let id = UUID()
    let text: String
    let mood: Mood
}

/// A coin burst animation triggered by a sale or reward.
struct CoinBurst: Identifiable, Equatable {
    let id = UUID()
    let amount: Int
    let tip: Int
    let delighted: Bool
}

enum ActiveSheet: String, Identifiable {
    case stockroom, upgrades, decor, journal, goals, map, settings
    var id: String { rawValue }
}

/// Bridges the pure `GameEngine` to SwiftUI, persistence, audio, haptics, analytics,
/// ads and purchases. Every mutation goes through `perform`.
@MainActor
final class GameStore: ObservableObject {
    @Published private(set) var engine: GameEngine
    @Published var toast: Toast?
    @Published var reaction: CustomerReaction?
    @Published var coinBurst: CoinBurst?
    @Published var activeSheet: ActiveSheet?
    @Published var showDailyReward = false
    @Published var isAdInProgress = false
    @Published private(set) var lastSaveAt: Date?
    @Published private(set) var lastSaveError: String?

    let analytics: LocalAnalytics
    let audio: AudioService
    let haptics: HapticsService
    let ads: AdProviding
    let purchases: PurchaseService
    let saveStore: FileSaveStore
    let loadSource: LoadSource
    let loadProblems: [String]
    let sessionId = UUID().uuidString
    let appVersion: String
    let buildNumber: String

    private var saveTask: Task<Void, Never>?
    private var arrivalTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    private var reactionTask: Task<Void, Never>?
    private var interstitialsThisSession = 0
    private var sessionStartedAt = Date()
    /// Set for screenshot capture so no pop-ups cover the scene.
    var suppressPopups = false
    private var dailyRewardPromptedThisSession = false

    var state: GameState { engine.state }
    var content: GameContent { engine.content }

    init(saveStore: FileSaveStore, ads: AdProviding, now: Date = Date(), initialState: GameState? = nil) {
        self.saveStore = saveStore
        self.ads = ads
        self.analytics = LocalAnalytics()
        self.audio = AudioService()
        self.haptics = HapticsService()
        self.purchases = PurchaseService()
        self.appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        self.buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"

        let result = initialState.map { LoadResult(state: $0, source: .primary, problems: []) } ?? saveStore.load()
        loadSource = result.source
        loadProblems = result.problems
        if let saved = result.state {
            engine = GameEngine(state: saved)
        } else {
            engine = GameEngine.newGame(seed: UInt64.random(in: 1...UInt64.max), now: now)
        }

        applySettingsToServices()
        purchases.onEntitlementChange = { [weak self] owned in
            self?.perform { $0.setRemoveAdsEntitlement(owned, verifiedAt: Date()) }
        }
        purchases.onEvent = { [weak self] event in
            guard let self else { return }
            self.analytics.record(event, context: self.eventContext)
        }
        for problem in loadProblems {
            analytics.record(AnalyticsEvent(.app_error, ["kind": "save_load", "detail": String(problem.prefix(120))]), context: eventContext)
        }
        if loadSource == .backup {
            showToast("Your last save was damaged, so we restored the backup.", kind: .warning)
        }
        flushEvents()
        scheduleSave()
    }

    // MARK: - Lifecycle

    private var isSessionActive = false

    func appBecameActive(now: Date = Date()) {
        guard !isSessionActive else { return }
        isSessionActive = true
        sessionStartedAt = now
        analytics.record(AnalyticsEvent(.session_start), context: eventContext)
        audio.setActive(true)
        purchases.start()
        perform { $0.refreshCalendarDay(now: now, timeZone: .current) }
        resumeCustomers()
        if state.tutorialStep == .done && !dailyRewardPromptedThisSession && !suppressPopups
            && engine.isDailyRewardAvailable(now: now, timeZone: .current) {
            dailyRewardPromptedThisSession = true
            showDailyReward = true
        }
    }

    func appWillResignActive() {
        guard isSessionActive else { return }
        isSessionActive = false
        let seconds = Int(Date().timeIntervalSince(sessionStartedAt))
        analytics.record(AnalyticsEvent(.session_end, ["duration_s": "\(seconds)"]), context: eventContext)
        audio.setActive(false)
        arrivalTask?.cancel()
        saveNow()
    }

    // MARK: - Core mutation helper

    @discardableResult
    func perform<T>(_ body: (inout GameEngine) throws -> T) -> Result<T, GameError> {
        var copy = engine
        do {
            let value = try body(&copy)
            engine = copy
            flushEvents()
            scheduleSave()
            return .success(value)
        } catch let error as GameError {
            return .failure(error)
        } catch {
            return .failure(.unknownItem)
        }
    }

    private func flushEvents() {
        let events = engine.drainEvents()
        for event in events { analytics.record(event, context: eventContext) }
    }

    var eventContext: [String: String] {
        ["session_id": sessionId, "shop_day": "\(state.shopDay.dayNumber)",
         "rep_level": "\(engine.reputationLevel)", "district": state.currentDistrict,
         "experiment": "baseline"]
    }

    // MARK: - Saving

    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await self?.writeSave()
        }
    }

    private func writeSave() async {
        let snapshot = state
        let store = saveStore
        let version = appVersion
        let error: String? = await Task.detached(priority: .utility) {
            do {
                try store.save(snapshot, appVersion: version)
                return nil
            } catch {
                return error.localizedDescription
            }
        }.value
        lastSaveError = error
        if error == nil { lastSaveAt = Date() } else {
            analytics.record(AnalyticsEvent(.app_error, ["kind": "save_write"]), context: eventContext)
        }
    }

    /// Synchronous save used when the app is backgrounded.
    func saveNow() {
        saveTask?.cancel()
        do {
            try saveStore.save(state, appVersion: appVersion)
            lastSaveAt = Date()
            lastSaveError = nil
        } catch {
            lastSaveError = error.localizedDescription
        }
    }

    // MARK: - Feedback

    func showToast(_ text: String, kind: Toast.Kind = .info) {
        toast = Toast(text: text, kind: kind)
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    private func react(_ text: String, mood: CustomerReaction.Mood) {
        reaction = CustomerReaction(text: text, mood: mood)
        reactionTask?.cancel()
        reactionTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard !Task.isCancelled else { return }
            self?.reaction = nil
        }
    }

    func applySettingsToServices() {
        audio.apply(musicVolume: state.settings.musicVolume, sfxVolume: state.settings.sfxVolume)
        haptics.isEnabled = state.settings.hapticsEnabled
    }

    func updateSettings(_ change: (inout GameSettings) -> Void) {
        var settings = state.settings
        change(&settings)
        perform { $0.updateSettings(settings) }
        applySettingsToServices()
    }

    func message(for error: GameError) -> String {
        switch error {
        case .notEnoughCoins: return "Not enough coins yet."
        case .capacityReached: return "Your stockroom shelf for that is full."
        case .notAvailableYet: return "You'll need more shelves for that."
        case .maxLevelReached: return "Already fully upgraded!"
        case .alreadyOwned: return "You already own that."
        case .notOwned: return "You don't own that yet."
        case .notForSale: return "That one can't be bought — it's a gift."
        case .locked: return "Not unlocked yet."
        case .notPlayable: return "That district isn't open yet."
        case .insufficientStock: return "Not enough in stock."
        case .customerWaiting: return "Finish helping your customer first."
        case .alreadyClaimed: return "Already claimed."
        case .notEligible: return "Not ready yet."
        case .invalidQuantity: return "Choose a quantity first."
        case .dayStillOpen: return "The shop is still open."
        case .adNotCompleted: return "The bonus needs the full video, so nothing was added."
        case .noActiveCustomer, .staleCustomer, .unknownItem, .dayAlreadyFinished: return "Something went wrong — please try again."
        }
    }

    private func handle<T>(_ result: Result<T, GameError>) -> T? {
        switch result {
        case .success(let value): return value
        case .failure(let error):
            haptics.warning()
            showToast(message(for: error), kind: .warning)
            return nil
        }
    }

    // MARK: - Customers

    private var reducedMotion: Bool { state.settings.reducedMotion || UIAccessibility.isReduceMotionEnabled }

    /// Whether customers may currently walk in (paused during parts of the tutorial).
    var customersFlowing: Bool {
        state.tutorialStep == .firstSale || state.tutorialStep == .done
    }

    func resumeCustomers() {
        guard state.currentVisit == nil, customersFlowing, engine.canSummonCustomer else { return }
        arrivalTask?.cancel()
        let delay: UInt64 = reducedMotion ? 500_000_000 : 1_300_000_000
        arrivalTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled, let self else { return }
            let result = self.perform { $0.summonNextCustomer() }
            if case .success(let visit?) = result {
                self.audio.play(.bell)
                if visit.isFirstVisit {
                    let name = self.content.customer(visit.customerId)?.name ?? "Someone new"
                    self.showToast("New face! \(name) added to your journal (+\(self.engine.config.discoveryRewardCoins) coins)", kind: .success)
                }
            }
        }
    }

    func serveCurrentCustomer() {
        guard let visit = state.currentVisit else { return }
        guard let outcome = handle(perform { try $0.serve(visitId: visit.id) }) else { return }
        switch outcome {
        case .sold(let receipt):
            audio.play(receipt.tip > 0 ? .tip : .coin)
            haptics.success()
            coinBurst = CoinBurst(amount: receipt.revenue, tip: receipt.tip, delighted: receipt.delighted)
            let customerName = content.customer(receipt.customerId)?.name.components(separatedBy: " ").first ?? "They"
            if receipt.delighted {
                react(receipt.giftWrapped ? "A bow, too? How lovely!" : "Wonderful, thank you!", mood: .delighted)
            } else {
                react("Thanks, see you soon!", mood: .happy)
            }
            if receipt.becameRegular {
                showToast("\(customerName) is now a regular — you can see their budget!", kind: .success)
            } else if let gift = receipt.heartGiftDecoration, let deco = content.decoration(gift) {
                showToast("\(customerName) left you a gift: \(deco.name)!", kind: .success)
                audio.play(.unlock)
            }
        case .tooExpensive(let attemptsLeft):
            audio.play(.decline)
            haptics.warning()
            react(attemptsLeft == 1 ? "Hmm… that's a bit much for me." : "Still a little pricey…", mood: .hesitant)
        case .walkedOut:
            audio.play(.decline)
            react("Maybe another time.", mood: .sad)
        }
        afterVisitChange()
    }

    func turnAwayCurrentCustomer() {
        guard let visit = state.currentVisit else { return }
        guard handle(perform { try $0.turnAway(visitId: visit.id) }) != nil else { return }
        haptics.tap()
        react(stock(visit.productId) < visit.quantity ? "Oh, sold out? Next time!" : "No worries, bye!", mood: .hesitant)
        afterVisitChange()
    }

    private func afterVisitChange() {
        if state.currentVisit == nil { resumeCustomers() }
    }

    func stock(_ productId: String) -> Int { engine.stock(of: productId) }

    // MARK: - Prices, stock, upgrades, decor

    func setPrice(_ productId: String, _ price: Int) {
        _ = handle(perform { try $0.setPrice(productId: productId, price: price) })
    }

    func adjustPrice(_ productId: String, by delta: Int) {
        haptics.tap()
        setPrice(productId, engine.price(of: productId) + delta)
    }

    func restock(_ productId: String, quantity: Int) {
        let wasTutorialRestock = state.tutorialStep == .restock
        guard let cost = handle(perform { try $0.restock(productId: productId, quantity: quantity) }) else { return }
        audio.play(.tap)
        haptics.tap()
        let name = content.product(productId)?.name ?? "stock"
        showToast("Restocked \(quantity) × \(name) for \(short(cost)) coins", kind: .success)
        if wasTutorialRestock {
            activeSheet = nil
            audio.play(.unlock)
        }
    }

    func buyUpgrade(_ id: String) {
        guard let level = handle(perform { try $0.buyUpgrade(id) }) else { return }
        audio.play(.upgrade)
        haptics.success()
        showToast("\(content.upgrade(id)?.name ?? "Upgrade") is now level \(level)!", kind: .success)
        resumeCustomers()
    }

    func buyDecoration(_ id: String) {
        guard handle(perform { try $0.buyDecoration(id) }) != nil else { return }
        audio.play(.upgrade)
        haptics.success()
        showToast("\(content.decoration(id)?.name ?? "Decoration") placed in your shop!", kind: .success)
    }

    func equipDecoration(_ id: String) {
        guard handle(perform { try $0.equipDecoration(id) }) != nil else { return }
        haptics.tap()
    }

    func clearSlot(_ slot: DecorSlot) {
        _ = handle(perform { try $0.clearDecorationSlot(slot) })
    }

    // MARK: - Progression

    func claimGoal(_ id: String) {
        guard let coins = handle(perform { try $0.claimGoal(id) }) else { return }
        rewardFeedback(coins)
    }

    func claimAchievement(_ id: String) {
        guard let coins = handle(perform { try $0.claimAchievement(id) }) else { return }
        rewardFeedback(coins)
    }

    func claimCollection(_ id: String) {
        guard let coins = handle(perform { try $0.claimCollection(id) }) else { return }
        rewardFeedback(coins)
        audio.play(.unlock)
    }

    func claimDailyReward() {
        let ownedBefore = state.ownedDecorations
        guard let reward = handle(perform { try $0.claimDailyReward(now: Date(), timeZone: .current) }) else { return }
        audio.play(.unlock)
        haptics.success()
        switch reward.kind {
        case .coins(let amount): coinBurst = CoinBurst(amount: amount, tip: 0, delighted: true)
        case .reputation(let amount): showToast("+\(amount) reputation!", kind: .success)
        case .decoration(let id, let fallback):
            if ownedBefore.contains(id) {
                coinBurst = CoinBurst(amount: fallback, tip: 0, delighted: true)
            } else {
                showToast("\(content.decoration(id)?.name ?? "A keepsake") added to your shop!", kind: .success)
            }
        }
    }

    private func rewardFeedback(_ coins: Int) {
        audio.play(.coin)
        haptics.success()
        coinBurst = CoinBurst(amount: coins, tip: 0, delighted: true)
    }

    func unlockDistrict(_ id: String) {
        guard handle(perform { try $0.unlockDistrict(id) }) != nil else { return }
        audio.play(.unlock)
        haptics.success()
        showToast("\(content.district(id)?.name ?? "District") is open for business!", kind: .success)
    }

    func travel(to id: String) {
        guard handle(perform { try $0.travel(to: id) }) != nil else { return }
        activeSheet = nil
        showToast("Welcome to \(content.district(id)?.name ?? "the district")!", kind: .info)
        resumeCustomers()
    }

    // MARK: - Tutorial

    func acknowledgeTutorial(_ step: TutorialStep) {
        haptics.tap()
        perform { $0.acknowledgeTutorial(step) }
        if state.tutorialStep == .done || state.tutorialStep == .firstSale { resumeCustomers() }
    }

    func skipTutorial() {
        perform { $0.skipTutorial() }
        resumeCustomers()
    }

    // MARK: - Shop day end

    var isDayFinished: Bool { state.shopDay.isFinished && state.currentVisit == nil }

    var canOfferRewardedBonus: Bool {
        engine.isRewardedDayBonusOffered && ads.isRewardedReady && !isAdInProgress
    }

    func watchRewardedBonus() {
        guard canOfferRewardedBonus else { return }
        isAdInProgress = true
        analytics.record(AnalyticsEvent(.ad_offer_accepted, ["placement": AdPlacement.dayBonus.rawValue]), context: eventContext)
        Task {
            let result = await ads.showRewarded(placement: .dayBonus)
            isAdInProgress = false
            if result == .completed {
                analytics.record(AnalyticsEvent(.ad_impression, ["placement": AdPlacement.dayBonus.rawValue]), context: eventContext)
            }
            switch perform({ try $0.grantRewardedDayBonus(result: result) }) {
            case .success(let amount):
                rewardFeedback(amount)
            case .failure(let error):
                showToast(result == .unavailable ? "No bonus video is available right now." : message(for: error), kind: .info)
            }
        }
    }

    func noteRewardedOfferShown() {
        analytics.record(AnalyticsEvent(.ad_offer_shown, ["placement": AdPlacement.dayBonus.rawValue]), context: eventContext)
    }

    func openNextDay() {
        guard let summary = handle(perform { try $0.closeDay() }) else { return }
        audio.play(.bell)
        if summary.reliefCoins > 0 {
            showToast("A kind neighbor left \(short(summary.reliefCoins)) coins to help restock.", kind: .info)
        }
        maybeShowInterstitial()
        resumeCustomers()
    }

    /// Interstitials are only considered at this natural break, and never if Remove Ads is owned.
    private func maybeShowInterstitial() {
        let policy = InterstitialPolicy(config: engine.config)
        guard policy.shouldShow(state: state, now: Date(), shownThisSession: interstitialsThisSession, adReady: ads.isInterstitialReady) else { return }
        interstitialsThisSession += 1
        Task {
            let result = await ads.showInterstitial(placement: .dayEndInterstitial)
            if result == .completed || result == .dismissedEarly {
                perform { $0.recordInterstitialShown(at: Date()) }
            }
        }
    }

    // MARK: - Purchases

    func buyRemoveAds() {
        Task {
            let outcome = await purchases.purchaseRemoveAds()
            switch outcome {
            case .verified: showToast("Thank you! Interruptive ads are removed.", kind: .success)
            case .userCancelled: break
            case .pending: showToast("Your purchase is pending approval.", kind: .info)
            case .unverified: showToast("The purchase couldn't be verified, so nothing was changed.", kind: .warning)
            case .failed(let reason): showToast("Purchase failed: \(reason)", kind: .warning)
            case .productUnavailable: showToast("This purchase isn't available right now.", kind: .warning)
            }
        }
    }

    func restorePurchases() {
        Task {
            let message = await purchases.restorePurchases()
            showToast(message, kind: .info)
        }
    }

    // MARK: - Data management

    func resetProgress() {
        arrivalTask?.cancel()
        try? saveStore.eraseAll()
        let settings = state.settings
        var fresh = GameEngine.newGame(seed: UInt64.random(in: 1...UInt64.max), now: Date())
        fresh.updateSettings(settings)
        fresh.setRemoveAdsEntitlement(purchases.ownsRemoveAds, verifiedAt: Date())
        engine = fresh
        flushEvents()
        saveNow()
        activeSheet = nil
        perform { $0.refreshCalendarDay(now: Date(), timeZone: .current) }
    }

    #if DEBUG
    func debugAddCoins(_ amount: Int) {
        perform { engine in engine.debugGrantCoins(amount) }
    }
    #endif

    /// Plain-text report the player can share when reporting a problem. Contains no personal data.
    var diagnosticReport: String {
        """
        Cozy Shopkeeper issue report
        Version \(appVersion) (\(buildNumber))
        iOS \(UIDevice.current.systemVersion), \(UIDevice.current.model)
        Shop day \(state.shopDay.dayNumber), reputation level \(engine.reputationLevel), district \(state.currentDistrict)
        Sales \(state.stats.totalSales), days completed \(state.stats.daysCompleted)
        Save loaded from: \(loadSource.rawValue); last save error: \(lastSaveError ?? "none")

        Describe what happened:
        """
    }
}
