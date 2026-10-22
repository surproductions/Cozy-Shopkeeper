import SwiftUI
import ShopCore

struct DecorView: View {
    @EnvironmentObject private var store: GameStore
    @State private var slot: DecorSlot = .wallpaper
    @State private var previewing: DecorationDef?

    var body: some View {
        let engine = store.engine
        let override: (slot: DecorSlot, decoration: DecorationDef?)? = previewing.map { (slot: $0.slot, decoration: Optional($0)) }
        VStack(spacing: 0) {
            SheetHeader(title: "Decor", subtitle: "Coziness \(engine.coziness) · cozy shops earn happier customers.") {
                store.activeSheet = nil
            }
            ShopSceneView(look: ShopLook.make(engine: engine, override: override)) { Color.clear }
                .aspectRatio(1.25, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color(hex: 0x8A6142), lineWidth: 3))
                .overlay(alignment: .topLeading) {
                    if let previewing {
                        Tag(text: "Previewing \(previewing.name)", color: Theme.deepTeal)
                            .background(Capsule().fill(Theme.card))
                            .padding(10)
                    }
                }
                .padding(.horizontal, 16)
                .frame(maxHeight: 230)
                .accessibilityLabel(previewing.map { "Preview of your shop with \($0.name)" } ?? "Your shop")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DecorSlot.allCases, id: \.self) { s in
                        Button {
                            slot = s
                            previewing = nil
                        } label: {
                            Text(s.displayName)
                                .font(Theme.callout.weight(.semibold))
                                .foregroundStyle(slot == s ? .white : Theme.ink)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 38)
                                .background(Capsule().fill(slot == s ? Theme.deepSage : Theme.card))
                                .overlay(Capsule().strokeBorder(Theme.cardEdge, lineWidth: slot == s ? 0 : 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(slot == s ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            ScrollView {
                VStack(spacing: 10) {
                    let items = store.content.decorations.filter { $0.slot == slot }
                    if !slot.isRequired, store.state.equippedDecorations[slot.rawValue] != nil {
                        Button("Clear this spot") {
                            store.clearSlot(slot)
                            previewing = nil
                        }
                        .buttonStyle(.cozy(.quiet, compact: true))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    ForEach(items) { deco in
                        DecorRow(decoration: deco, isPreviewing: previewing?.id == deco.id) {
                            previewing = previewing?.id == deco.id ? nil : deco
                        } onDone: {
                            previewing = nil
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
        .background(ParchmentBackground())
    }
}

struct DecorRow: View {
    @EnvironmentObject private var store: GameStore
    let decoration: DecorationDef
    let isPreviewing: Bool
    let onPreview: () -> Void
    let onDone: () -> Void

    var body: some View {
        let owned = store.state.ownedDecorations.contains(decoration.id)
        let equipped = store.state.equippedDecorations[decoration.slot.rawValue] == decoration.id
        Panel(padding: 12, fill: isPreviewing ? Color(hex: 0xEFF5E8) : Theme.card) {
            HStack(spacing: 12) {
                Swatch(decoration: decoration)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(decoration.name).font(Theme.headline).foregroundStyle(Theme.ink)
                        if decoration.coziness > 0 { Tag(text: "+\(decoration.coziness) cozy", color: Theme.terracotta) }
                    }
                    SoftText(decoration.flavor, font: Theme.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                VStack(spacing: 6) {
                    if equipped {
                        Tag(text: "In your shop", color: Theme.deepSage)
                    } else if owned {
                        Button("Use") {
                            store.equipDecoration(decoration.id)
                            onDone()
                        }
                        .buttonStyle(.cozy(.primary, compact: true))
                    } else if let price = decoration.price {
                        Button(isPreviewing ? "Hide" : "Preview", action: onPreview)
                            .buttonStyle(.cozy(.quiet, compact: true))
                        Button {
                            store.buyDecoration(decoration.id)
                            onDone()
                        } label: {
                            CoinAmount(amount: price, font: Theme.callout.weight(.bold), size: 14)
                        }
                        .buttonStyle(.cozy(store.state.coins >= price ? .secondary : .quiet, compact: true))
                        .disabled(store.state.coins < price)
                        .accessibilityLabel("Buy \(decoration.name) for \(price) coins")
                    } else {
                        Button(isPreviewing ? "Hide" : "Preview", action: onPreview)
                            .buttonStyle(.cozy(.quiet, compact: true))
                        Tag(text: "Gift only", color: Theme.gold)
                    }
                }
            }
        }
    }
}

/// Small color swatch / icon representing a decoration.
struct Swatch: View {
    let decoration: DecorationDef

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            context.fill(Path(roundedRect: rect, cornerRadius: 10), decoration.primary)
            switch decoration.slot {
            case .wallpaper, .floor, .rug:
                var x: CGFloat = 4
                while x < size.width {
                    context.fill(Path(CGRect(x: x, y: 0, width: 5, height: size.height)), decoration.secondary, 0.7)
                    x += 12
                }
            case .collectible:
                ShopArtist.drawKeepsake(decoration, rect: rect.insetBy(dx: 6, dy: 6), context: context)
            default:
                context.fill(Path(ellipseIn: rect.insetBy(dx: size.width * 0.28, dy: size.height * 0.28)), decoration.secondary)
            }
            context.stroke(Path(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: 10), 0x5A3E2B, 1.5, 0.4)
        }
        .frame(width: 52, height: 52)
        .accessibilityHidden(true)
    }
}
