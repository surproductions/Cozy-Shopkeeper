import SwiftUI
import ShopCore

/// A soft parchment card used throughout the game.
struct Panel<Content: View>: View {
    @Environment(\.cozyHighContrast) private var highContrast
    var padding: CGFloat = 14
    var fill: Color = Theme.card
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(fill)
                    .shadow(color: Theme.shadow, radius: 6, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(highContrast ? Theme.ink : Theme.cardEdge, lineWidth: highContrast ? 2 : 1.5)
            )
    }
}

enum CozyButtonStyleKind {
    case primary, secondary, quiet, danger

    var fill: Color {
        switch self {
        case .primary: return Theme.deepSage
        case .secondary: return Theme.terracotta
        case .quiet: return Theme.parchment
        case .danger: return Color(hex: 0xB2533E)
        }
    }

    var text: Color {
        switch self {
        case .quiet: return Theme.ink
        default: return .white
        }
    }
}

/// Chunky, tactile button with a pressed state.
struct CozyButtonStyle: ButtonStyle {
    var kind: CozyButtonStyleKind = .primary
    var compact = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(compact ? Theme.callout.weight(.semibold) : Theme.headline)
            .foregroundStyle(kind.text.opacity(isEnabled ? 1 : 0.7))
            .padding(.vertical, compact ? 8 : 12)
            .padding(.horizontal, compact ? 12 : 18)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isEnabled ? kind.fill : Color(hex: 0xBFB3A0))
                    .shadow(color: Theme.shadow, radius: configuration.isPressed ? 1 : 3, x: 0, y: configuration.isPressed ? 1 : 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == CozyButtonStyle {
    static var cozy: CozyButtonStyle { CozyButtonStyle() }
    static func cozy(_ kind: CozyButtonStyleKind, compact: Bool = false) -> CozyButtonStyle {
        CozyButtonStyle(kind: kind, compact: compact)
    }
}

/// A gold coin glyph drawn in code.
struct CoinGlyph: View {
    var size: CGFloat = 18

    var body: some View {
        ZStack {
            Circle().fill(Color(hex: 0xE9B949))
            Circle().strokeBorder(Color(hex: 0xB9862C), lineWidth: size * 0.1)
            Circle().fill(Color(hex: 0xF7D77C)).frame(width: size * 0.45, height: size * 0.45).offset(x: -size * 0.08, y: -size * 0.08)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct CoinAmount: View {
    let amount: Int
    var font: Font = Theme.headline
    var size: CGFloat = 18

    var body: some View {
        HStack(spacing: 4) {
            CoinGlyph(size: size)
            Text("\(amount)")
                .font(font)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(amount) coins")
    }
}

struct HeartsView: View {
    let hearts: Int
    var maxHearts = 5
    var size: CGFloat = 12

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<maxHearts, id: \.self) { index in
                Image(systemName: index < hearts ? "heart.fill" : "heart")
                    .font(.system(size: size))
                    .foregroundStyle(index < hearts ? Theme.rose : Theme.cardEdge)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(hearts) of \(maxHearts) hearts")
    }
}

struct CozyProgressBar: View {
    let value: Double
    var tint: Color = Theme.deepSage
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.parchment)
                Capsule().fill(tint)
                    .frame(width: max(height, geo.size.width * min(max(value, 0), 1)))
            }
        }
        .frame(height: height)
        .overlay(Capsule().strokeBorder(Color.black.opacity(0.06)))
        .accessibilityElement()
        .accessibilityValue("\(Int((min(max(value, 0), 1) * 100).rounded())) percent")
    }
}

/// Header shared by every sheet.
struct SheetHeader: View {
    let title: String
    let subtitle: String
    var onClose: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.title(26)).foregroundStyle(Theme.ink)
                SoftText(subtitle, font: Theme.callout)
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.parchment))
            }
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }
}

/// Little pill label (rarity, category, status).
struct Tag: View {
    let text: String
    var color: Color = Theme.teal

    var body: some View {
        Text(text)
            .font(.system(.caption2, design: .rounded).weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.14)))
    }
}

extension Rarity {
    var color: Color {
        switch self {
        case .common: return Theme.deepSage
        case .uncommon: return Theme.teal
        case .rare: return Color(hex: 0xA0702A)
        }
    }
}

/// Parchment background used behind sheets.
struct ParchmentBackground: View {
    var body: some View {
        LinearGradient(colors: [Theme.cream, Theme.parchment], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

/// Friendly empty-state view.
struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 34))
                .foregroundStyle(Theme.sage)
            Text(title).font(Theme.headline).foregroundStyle(Theme.ink)
            SoftText(message, font: Theme.callout)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
    }
}
