import Foundation

/// Product-analytics event schema. No personal data is ever attached.
public enum AnalyticsEventName: String, CaseIterable, Sendable {
    case first_open, tutorial_step, tutorial_complete, first_core_action, first_sale
    case session_start, session_end, shop_day_start, shop_day_complete
    case customer_arrive, customer_request, sale_complete, sale_failed
    case product_restock, price_changed, upgrade_purchased, decoration_purchased
    case customer_discovered, quest_started, quest_completed, daily_reward_claimed
    case collection_progress, district_unlocked
    case ad_offer_shown, ad_offer_accepted, ad_impression, ad_completed
    case purchase_started, purchase_completed, purchase_restored
    case app_error
}

public struct AnalyticsEvent: Equatable, Sendable {
    public let name: AnalyticsEventName
    public let parameters: [String: String]

    public init(_ name: AnalyticsEventName, _ parameters: [String: String] = [:]) {
        self.name = name
        self.parameters = parameters
    }
}
