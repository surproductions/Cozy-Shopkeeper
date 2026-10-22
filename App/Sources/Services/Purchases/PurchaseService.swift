import Foundation
import StoreKit
import ShopCore

/// StoreKit 2 integration for the non-consumable "Remove Interruptive Ads" purchase.
/// Prices always come from the App Store; entitlements only from verified transactions.
@MainActor
final class PurchaseService: ObservableObject {
    enum LoadState: Equatable {
        case idle, loading, loaded, unavailable(String)
    }

    @Published private(set) var removeAdsProduct: Product?
    @Published private(set) var loadState: LoadState = .idle
    @Published private(set) var isPurchasing = false
    @Published private(set) var ownsRemoveAds = false

    /// Called whenever the verified entitlement is (re)computed.
    var onEntitlementChange: ((Bool) -> Void)?
    var onEvent: ((AnalyticsEvent) -> Void)?
    private var updatesTask: Task<Void, Never>?

    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self?.refreshEntitlements()
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    func loadProducts() async {
        loadState = .loading
        do {
            let products = try await Product.products(for: StoreProductID.all)
            removeAdsProduct = products.first { $0.id == StoreProductID.removeAds }
            loadState = removeAdsProduct == nil ? .unavailable("This purchase isn't available right now.") : .loaded
        } catch {
            loadState = .unavailable("Couldn't reach the App Store. Check your connection and try again.")
        }
    }

    func purchaseRemoveAds() async -> PurchaseOutcome {
        guard let product = removeAdsProduct else { return .productUnavailable }
        guard !isPurchasing else { return .pending }
        isPurchasing = true
        defer { isPurchasing = false }
        onEvent?(AnalyticsEvent(.purchase_started, ["product_id": product.id]))
        let outcome: PurchaseOutcome
        do {
            switch try await product.purchase() {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    outcome = .verified(productId: transaction.productID)
                case .unverified(let transaction, let error):
                    outcome = .unverified(productId: transaction.productID, reason: error.localizedDescription)
                }
            case .userCancelled:
                outcome = .userCancelled
            case .pending:
                outcome = .pending
            @unknown default:
                outcome = .failed("Unknown purchase result")
            }
        } catch {
            outcome = .failed(error.localizedDescription)
        }
        if case .verified(let id) = outcome {
            onEvent?(AnalyticsEvent(.purchase_completed, ["product_id": id]))
        }
        await refreshEntitlements()
        return outcome
    }

    /// Syncs with the App Store, then rebuilds entitlements from verified transactions.
    func restorePurchases() async -> String {
        do {
            try await AppStore.sync()
        } catch {
            await refreshEntitlements()
            return "Couldn't reach the App Store to restore purchases. Please try again later."
        }
        await refreshEntitlements()
        onEvent?(AnalyticsEvent(.purchase_restored, ["owns_remove_ads": ownsRemoveAds ? "true" : "false"]))
        return ownsRemoveAds ? "Purchases restored. Interruptive ads are removed." : "No previous purchases were found for this Apple ID."
    }

    func refreshEntitlements() async {
        var verified = Set<String>()
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.revocationDate == nil {
                verified.insert(transaction.productID)
            }
        }
        ownsRemoveAds = EntitlementLedger.removeAdsOwned(verifiedProductIds: verified)
        onEntitlementChange?(ownsRemoveAds)
    }
}
