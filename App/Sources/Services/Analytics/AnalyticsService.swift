import Foundation
import os
import ShopCore

/// Destination for analytics events. Swap in a real SDK by conforming to this protocol.
@MainActor
protocol AnalyticsSink: AnyObject {
    var destinationName: String { get }
    func record(_ event: AnalyticsEvent, context: [String: String])
}

struct RecordedEvent: Identifiable {
    let id = UUID()
    let date: Date
    let name: String
    let parameters: [String: String]
}

/// Keeps a short in-memory log for the developer diagnostics panel.
/// Nothing is uploaded anywhere: no analytics service is configured in this build.
@MainActor
final class LocalAnalytics: AnalyticsSink, ObservableObject {
    let destinationName = "Local only (not uploaded)"
    @Published private(set) var recent: [RecordedEvent] = []
    private let logger = Logger(subsystem: "com.surproductions.cozyshopkeeper", category: "analytics")
    private let limit = 200

    func record(_ event: AnalyticsEvent, context: [String: String]) {
        let merged = event.parameters.merging(context) { current, _ in current }
        recent.insert(RecordedEvent(date: Date(), name: event.name.rawValue, parameters: merged), at: 0)
        if recent.count > limit { recent.removeLast(recent.count - limit) }
        #if DEBUG
        logger.debug("\(event.name.rawValue, privacy: .public) \(merged.description, privacy: .public)")
        #endif
    }
}
