import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

/// Small color math for shading procedural art.
enum Hex {
    static func mix(_ a: UInt32, _ b: UInt32, _ t: Double) -> UInt32 {
        let t = min(max(t, 0), 1)
        func channel(_ shift: UInt32) -> UInt32 {
            let ca = Double((a >> shift) & 0xFF)
            let cb = Double((b >> shift) & 0xFF)
            return UInt32((ca + (cb - ca) * t).rounded()) & 0xFF
        }
        return (channel(16) << 16) | (channel(8) << 8) | channel(0)
    }

    static func darker(_ c: UInt32, _ amount: Double = 0.2) -> UInt32 { mix(c, 0x2B1D14, amount) }
    static func lighter(_ c: UInt32, _ amount: Double = 0.2) -> UInt32 { mix(c, 0xFFFFFF, amount) }
}

/// Cozy Shopkeeper's visual identity.
enum Theme {
    static let cream = Color(hex: 0xFFF6E5)
    static let parchment = Color(hex: 0xF3E6C8)
    static let card = Color(hex: 0xFFFBF3)
    static let cardEdge = Color(hex: 0xE4D2AF)
    static let ink = Color(hex: 0x4A3426)
    static let inkSoft = Color(hex: 0x86684F)
    static let sage = Color(hex: 0x9CB38A)
    static let deepSage = Color(hex: 0x5F7D4F)
    static let teal = Color(hex: 0x5E9C9A)
    static let deepTeal = Color(hex: 0x3F7372)
    static let terracotta = Color(hex: 0xC96F4A)
    static let gold = Color(hex: 0xD4A84B)
    static let brown = Color(hex: 0x8A6142)
    static let rose = Color(hex: 0xD9898A)
    static let shadow = Color(hex: 0x5A3E2B, opacity: 0.18)

    static func title(_ size: CGFloat = 22) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    static let headline = Font.system(.headline, design: .rounded)
    static let body = Font.system(.body, design: .rounded)
    static let callout = Font.system(.callout, design: .rounded)
    static let caption = Font.system(.caption, design: .rounded)
    static let footnote = Font.system(.footnote, design: .rounded)
}

// MARK: - High-contrast support

private struct HighContrastKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var cozyHighContrast: Bool {
        get { self[HighContrastKey.self] }
        set { self[HighContrastKey.self] = newValue }
    }
}

/// Secondary text that becomes full-strength ink in high-contrast mode.
struct SoftText: View {
    @Environment(\.cozyHighContrast) private var highContrast
    let text: String
    var font: Font = Theme.footnote

    init(_ text: String, font: Font = Theme.footnote) {
        self.text = text
        self.font = font
    }

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(highContrast ? Theme.ink : Theme.inkSoft)
    }
}
