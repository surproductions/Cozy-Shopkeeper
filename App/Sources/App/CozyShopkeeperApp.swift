import SwiftUI
import ShopCore

@main
struct CozyShopkeeperApp: App {
    @StateObject private var store: GameStore
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let isUITest = ProcessInfo.processInfo.arguments.contains("-ui-testing")
        let directory: URL
        if isUITest {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent("ui-test-\(UUID().uuidString)")
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            directory = base.appendingPathComponent("CozyShopkeeper", isDirectory: true)
        }
        #if DEBUG
        let ads: AdProviding = DebugSimulatedAdProvider()
        #else
        let ads: AdProviding = NoAdNetworkProvider()
        #endif
        _store = StateObject(wrappedValue: GameStore(saveStore: FileSaveStore(directory: directory), ads: ads))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: store.appBecameActive()
            case .inactive, .background: store.appWillResignActive()
            @unknown default: break
            }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        let settings = store.state.settings
        ShopView()
            .sheet(item: $store.activeSheet) { sheet in
                sheetContent(sheet)
                    .environmentObject(store)
                    .environment(\.cozyHighContrast, settings.highContrast)
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $store.showDailyReward) {
                DailyRewardSheet()
                    .environmentObject(store)
                    .presentationDetents([.medium])
            }
            .environment(\.cozyHighContrast, settings.highContrast)
            .dynamicTypeSize(settings.largerText ? DynamicTypeSize.xLarge ... DynamicTypeSize.accessibility2 : DynamicTypeSize.xSmall ... DynamicTypeSize.accessibility2)
            .preferredColorScheme(.light)
            .tint(Theme.deepSage)
    }

    @ViewBuilder
    private func sheetContent(_ sheet: ActiveSheet) -> some View {
        switch sheet {
        case .stockroom: StockroomView()
        case .upgrades: UpgradesView()
        case .decor: DecorView()
        case .journal: JournalView()
        case .goals: GoalsView()
        case .map: TownMapView()
        case .settings: SettingsView(purchases: store.purchases)
        }
    }
}
