import SwiftUI
import StoreKit
import ShopCore

struct SettingsView: View {
    @EnvironmentObject private var store: GameStore
    @ObservedObject var purchases: PurchaseService
    @State private var confirmReset = false
    @State private var page: Page?
    #if DEBUG
    @State private var showDiagnostics = false
    #endif

    enum Page: String, Identifiable {
        case privacy, credits
        var id: String { rawValue }
    }

    var body: some View {
        let settings = store.state.settings
        VStack(spacing: 0) {
            SheetHeader(title: "Settings", subtitle: "Make the shop just right for you.") {
                store.activeSheet = nil
            }
            ScrollView {
                VStack(spacing: 12) {
                    Panel {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionTitle("Sound", symbol: "speaker.wave.2.fill")
                            volumeRow("Music", value: settings.musicVolume) { v in store.updateSettings { $0.musicVolume = v } }
                            volumeRow("Sound effects", value: settings.sfxVolume) { v in store.updateSettings { $0.sfxVolume = v } }
                            Toggle("Haptics", isOn: Binding(get: { settings.hapticsEnabled }, set: { v in store.updateSettings { $0.hapticsEnabled = v } }))
                                .font(Theme.body).tint(Theme.deepSage)
                        }
                    }
                    Panel {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionTitle("Accessibility", symbol: "accessibility")
                            Toggle("Reduce motion", isOn: Binding(get: { settings.reducedMotion }, set: { v in store.updateSettings { $0.reducedMotion = v } }))
                            SoftText("Also follows your iPhone's Reduce Motion setting.", font: Theme.caption)
                            Toggle("Larger text", isOn: Binding(get: { settings.largerText }, set: { v in store.updateSettings { $0.largerText = v } }))
                            Toggle("High-contrast text", isOn: Binding(get: { settings.highContrast }, set: { v in store.updateSettings { $0.highContrast = v } }))
                        }
                        .font(Theme.body)
                        .tint(Theme.deepSage)
                    }
                    Panel {
                        VStack(alignment: .leading, spacing: 10) {
                            sectionTitle("Ads & purchases", symbol: "sparkles")
                            removeAdsSection
                            Button("Restore purchases") { store.restorePurchases() }
                                .buttonStyle(.cozy(.quiet, compact: true))
                            SoftText("No ad network is included in this version, so the game shows no ads. Remove Ads permanently disables interruptive ads in future versions; optional reward videos would stay optional.", font: Theme.caption)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Panel {
                        VStack(alignment: .leading, spacing: 10) {
                            sectionTitle("Your data", symbol: "externaldrive.fill")
                            SoftText(saveStatus, font: Theme.caption)
                            SoftText("Progress is saved on this device only — nothing is uploaded.", font: Theme.caption)
                            Button("Reset all progress…", role: .destructive) { confirmReset = true }
                                .buttonStyle(.cozy(.danger, compact: true))
                        }
                    }
                    Panel {
                        VStack(alignment: .leading, spacing: 10) {
                            sectionTitle("Help & about", symbol: "questionmark.circle.fill")
                            ShareLink(item: store.diagnosticReport, subject: Text("Cozy Shopkeeper issue"), message: Text("Here's what happened:")) {
                                Label("Report an issue", systemImage: "envelope.fill")
                            }
                            .buttonStyle(.cozy(.quiet, compact: true))
                            SoftText("Shares a short report (version, device model, shop progress — no personal data) via Mail, Messages or any app you choose.", font: Theme.caption)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack {
                                Button("Privacy") { page = .privacy }.buttonStyle(.cozy(.quiet, compact: true))
                                Button("Credits") { page = .credits }.buttonStyle(.cozy(.quiet, compact: true))
                            }
                            versionRow
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
        .background(ParchmentBackground())
        .confirmationDialog("Reset all progress?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Erase my shop and start over", role: .destructive) { store.resetProgress() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This erases your coins, stock, upgrades, decorations and customers on this device. Purchases are kept.")
        }
        .sheet(item: $page) { page in
            switch page {
            case .privacy: InfoPage(title: "Privacy", text: AppInfo.privacyText)
            case .credits: InfoPage(title: "Credits", text: AppInfo.creditsText)
            }
        }
        #if DEBUG
        .sheet(isPresented: $showDiagnostics) { DiagnosticsView() }
        #endif
    }

    @ViewBuilder
    private var removeAdsSection: some View {
        if purchases.ownsRemoveAds {
            Label("Remove Ads — owned. Thank you!", systemImage: "checkmark.seal.fill")
                .font(Theme.callout.weight(.semibold))
                .foregroundStyle(Theme.deepSage)
        } else {
            switch purchases.loadState {
            case .loaded:
                if let product = purchases.removeAdsProduct {
                    Button {
                        store.buyRemoveAds()
                    } label: {
                        HStack {
                            Text(purchases.isPurchasing ? "Purchasing…" : product.displayName)
                            Spacer()
                            Text(product.displayPrice)
                        }
                    }
                    .buttonStyle(.cozy(.secondary, compact: true))
                    .disabled(purchases.isPurchasing)
                }
            case .loading, .idle:
                HStack(spacing: 8) {
                    ProgressView()
                    SoftText("Checking the App Store…", font: Theme.caption)
                }
            case .unavailable(let message):
                SoftText(message, font: Theme.caption)
                Button("Try again") { Task { await purchases.loadProducts() } }
                    .buttonStyle(.cozy(.quiet, compact: true))
            }
        }
    }

    private var versionRow: some View {
        HStack {
            SoftText("Version \(store.appVersion) (\(store.buildNumber))", font: Theme.caption)
            Spacer()
        }
        #if DEBUG
        .contentShape(Rectangle())
        .onLongPressGesture { showDiagnostics = true }
        .accessibilityHint("Debug builds: long-press for diagnostics")
        #endif
    }

    private var saveStatus: String {
        if let error = store.lastSaveError { return "Last save failed: \(error)" }
        if let date = store.lastSaveAt {
            return "Saved automatically · \(date.formatted(date: .omitted, time: .shortened))"
        }
        return "Saved automatically after every action."
    }

    private func sectionTitle(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(Theme.headline)
            .foregroundStyle(Theme.ink)
    }

    private func volumeRow(_ title: String, value: Double, set: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).font(Theme.body).foregroundStyle(Theme.ink)
                Spacer()
                SoftText("\(Int((value * 100).rounded()))%", font: Theme.caption)
            }
            Slider(value: Binding(get: { value }, set: set), in: 0...1)
                .tint(Theme.deepSage)
                .accessibilityLabel("\(title) volume")
        }
    }
}

struct InfoPage: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let text: String

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: title, subtitle: "Cozy Shopkeeper") { dismiss() }
            ScrollView {
                Text(text)
                    .font(Theme.body)
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
            }
        }
        .background(ParchmentBackground())
    }
}

enum AppInfo {
    static let privacyText = """
    Cozy Shopkeeper is a single-player game that works entirely on your device.

    What we collect: nothing. The game has no accounts, no ads SDK, no analytics service and no server. Your shop is saved in the app's private storage on this iPhone and is deleted if you delete the app or choose "Reset all progress".

    Gameplay events (such as "sale complete") are kept in memory only so the developer diagnostics in test builds can show them. They are never sent anywhere.

    Purchases are handled entirely by Apple through the App Store. We never see your payment details or Apple ID.

    "Report an issue" only shares what you choose to send, through the app you pick.

    Questions about privacy can be sent through "Report an issue".
    """

    static let creditsText = """
    Design, code, art and music: made for Cozy Shopkeeper.

    All characters, products, illustrations, sound effects and the music loop are original and were created for this game. Product and character art is drawn procedurally in code; sounds and music were synthesized from scratch with a script included in the project (scripts/generate_audio.py).

    Interface icons are Apple SF Symbols, used under Apple's license for apps on Apple platforms. Text uses the system San Francisco Rounded font.

    No third-party assets or libraries are bundled.

    Thank you for keeping shop!
    """
}
