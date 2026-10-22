import Foundation

/// Deterministic SplitMix64 generator so customer behavior and daily goals can
/// be reproduced in tests and balanced offline.
public struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform double in [0, 1).
    public mutating func unit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    public mutating func chance(_ probability: Double) -> Bool {
        unit() < probability
    }

    /// Picks an element using non-negative weights. Returns nil for empty input or all-zero weights.
    public mutating func weightedPick<T>(_ items: [(T, Double)]) -> T? {
        let total = items.reduce(0) { $0 + max(0, $1.1) }
        guard total > 0 else { return nil }
        var roll = unit() * total
        for (item, weight) in items where weight > 0 {
            roll -= weight
            if roll < 0 { return item }
        }
        return items.last { $0.1 > 0 }?.0
    }

    /// Stable 64-bit hash of a string (FNV-1a), used to derive seeds from day keys.
    public static func hash(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }
}

/// Converts real-world time into calendar day keys ("yyyy-MM-dd") in a given time zone.
public enum DayClock {
    public static func dayKey(for date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
    }
}
