import Foundation
import ShopCore

/// Abstraction over an ad network. The game never depends on ads to be playable.
@MainActor
protocol AdProviding: AnyObject {
    var networkName: String { get }
    var isRewardedReady: Bool { get }
    var isInterstitialReady: Bool { get }
    /// Must only return `.completed` when the network confirms the full view.
    func showRewarded(placement: AdPlacement) async -> AdResult
    func showInterstitial(placement: AdPlacement) async -> AdResult
}

/// Production default: no ad SDK is bundled, so no ads are ever offered or shown.
@MainActor
final class NoAdNetworkProvider: AdProviding {
    let networkName = "None configured"
    var isRewardedReady: Bool { false }
    var isInterstitialReady: Bool { false }
    func showRewarded(placement: AdPlacement) async -> AdResult { .unavailable }
    func showInterstitial(placement: AdPlacement) async -> AdResult { .unavailable }
}

#if DEBUG
/// Debug-only stand-in used to exercise the rewarded/interstitial flows from the diagnostics panel.
/// It is compiled out of Release builds.
@MainActor
final class DebugSimulatedAdProvider: AdProviding {
    enum Behavior: String, CaseIterable, Identifiable {
        case complete = "Complete", dismissEarly = "Dismiss early", fail = "Fail to load", off = "No fill"
        var id: String { rawValue }
    }

    let networkName = "Debug simulator"
    var behavior: Behavior = .off
    var isRewardedReady: Bool { behavior != .off }
    var isInterstitialReady: Bool { behavior != .off }

    func showRewarded(placement: AdPlacement) async -> AdResult { await simulate() }
    func showInterstitial(placement: AdPlacement) async -> AdResult { await simulate() }

    private func simulate() async -> AdResult {
        try? await Task.sleep(nanoseconds: 800_000_000)
        switch behavior {
        case .complete: return .completed
        case .dismissEarly: return .dismissedEarly
        case .fail: return .failed("simulated load error")
        case .off: return .unavailable
        }
    }
}
#endif
