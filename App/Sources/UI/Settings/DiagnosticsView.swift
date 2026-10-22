#if DEBUG
import SwiftUI
import ShopCore

/// Developer-only panel. Compiled into Debug builds only; never present in Release.
struct DiagnosticsView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var adBehavior: DebugSimulatedAdProvider.Behavior = .off

    var body: some View {
        let s = store.state
        let engine = store.engine
        NavigationStack {
            List {
                Section("Player") {
                    row("Coins", "\(s.coins)")
                    row("Reputation", "\(s.reputation) (level \(engine.reputationLevel))")
                    row("Shop day", "\(s.shopDay.dayNumber) · \(s.shopDay.customersArrived)/\(s.shopDay.customersPlanned)")
                    row("District", s.currentDistrict)
                    row("Tutorial", s.tutorialStep.rawValue)
                    row("Sales / walkouts", "\(s.stats.totalSales) / \(s.stats.walkouts)")
                    row("Lifetime coins", "\(s.stats.lifetimeCoins)")
                    row("Inventory units", "\(s.inventory.values.reduce(0, +))")
                    row("Coziness", "\(engine.coziness)")
                }
                Section("Save health") {
                    row("Loaded from", store.loadSource.rawValue)
                    row("Load problems", store.loadProblems.isEmpty ? "none" : store.loadProblems.joined(separator: "; "))
                    row("Last save", store.lastSaveAt.map { $0.formatted(date: .omitted, time: .standard) } ?? "pending")
                    row("Last error", store.lastSaveError ?? "none")
                    row("Backup present", store.saveStore.hasBackup ? "yes" : "no")
                }
                Section("Monetization") {
                    row("Remove Ads (StoreKit)", store.purchases.ownsRemoveAds ? "owned" : "not owned")
                    row("Cached entitlement", s.entitlements.removeAds ? "owned" : "not owned")
                    row("Ad network", store.ads.networkName)
                    row("Rewarded ready", store.ads.isRewardedReady ? "yes" : "no")
                    if let simulator = store.ads as? DebugSimulatedAdProvider {
                        Picker("Simulated ads", selection: $adBehavior) {
                            ForEach(DebugSimulatedAdProvider.Behavior.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .onChange(of: adBehavior) { _, value in simulator.behavior = value }
                    }
                }
                Section("Build") {
                    row("Version", "\(store.appVersion) (\(store.buildNumber))")
                    row("Session", String(store.sessionId.prefix(8)))
                    row("Analytics", store.analytics.destinationName)
                }
                Section("Cheats (debug only)") {
                    Button("+500 coins") { store.debugAddCoins(500) }
                    Button("+5,000 coins") { store.debugAddCoins(5000) }
                }
                Section("Recent events (\(store.analytics.recent.count))") {
                    ForEach(store.analytics.recent.prefix(60)) { event in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.name).font(.system(.footnote, design: .monospaced).weight(.semibold))
                            Text(event.parameters.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " "))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Diagnostics")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .onAppear {
                if let simulator = store.ads as? DebugSimulatedAdProvider { adBehavior = simulator.behavior }
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
        }
        .font(.footnote)
    }
}
#endif
