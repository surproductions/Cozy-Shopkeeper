import SwiftUI
import ShopCore

struct StockroomView: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        let engine = store.engine
        let available = engine.availableProducts
        let locked = store.content.products.filter { !engine.isProductAvailable($0) }
        VStack(spacing: 0) {
            SheetHeader(title: "Stockroom", subtitle: "Restock goods and set your prices. Capacity \(engine.stockCapacity) each.") {
                store.activeSheet = nil
            }
            HStack {
                CoinAmount(amount: store.state.coins)
                Spacer()
                if engine.restockDiscount > 0 {
                    Tag(text: "\(Int(engine.restockDiscount * 100))% supplier discount", color: Theme.deepSage)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 8)
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(ProductCategory.allCases, id: \.self) { category in
                        let items = available.filter { $0.category == category }
                        if !items.isEmpty {
                            Text(category.displayName)
                                .font(Theme.headline)
                                .foregroundStyle(Theme.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 6)
                            ForEach(items) { product in
                                StockRow(product: product)
                            }
                        }
                    }
                    if !locked.isEmpty {
                        Text("Coming soon to your shelves")
                            .font(Theme.headline)
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 10)
                        ForEach(locked) { product in
                            LockedProductRow(product: product)
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

struct StockRow: View {
    @EnvironmentObject private var store: GameStore
    let product: ProductDef

    var body: some View {
        let engine = store.engine
        let stock = engine.stock(of: product.id)
        let capacity = engine.stockCapacity
        let price = engine.price(of: product.id)
        let unitCost = engine.restockCost(productId: product.id, quantity: 1)
        let maxBuy = engine.maxRestockable(productId: product.id)
        let room = capacity - stock
        Panel(padding: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    ProductIcon(product: product, size: 54, faded: stock == 0)
                        .background(Circle().fill(Theme.parchment).frame(width: 58, height: 58))
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(product.name).font(Theme.headline).foregroundStyle(Theme.ink)
                            Tag(text: product.rarity.displayName, color: product.rarity.color)
                        }
                        SoftText(product.blurb, font: Theme.caption)
                            .lineLimit(2)
                        HStack(spacing: 8) {
                            CozyProgressBar(value: Double(stock) / Double(max(1, capacity)), tint: stock == 0 ? Theme.terracotta : Theme.deepSage, height: 8)
                                .frame(width: 80)
                            Text(stock == 0 ? "Sold out" : "\(stock)/\(capacity)")
                                .font(Theme.caption.weight(.bold))
                                .foregroundStyle(stock == 0 ? Theme.terracotta : Theme.inkSoft)
                        }
                    }
                }
                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        SoftText("Cost \(unitCost) · Fair \(product.recommendedPrice)", font: Theme.caption)
                        Text("Profit \(price - unitCost) each")
                            .font(Theme.caption.weight(.bold))
                            .foregroundStyle(price - unitCost > 0 ? Theme.deepSage : Theme.terracotta)
                    }
                    Spacer(minLength: 4)
                    Button { store.adjustPrice(product.id, by: -1) } label: { Image(systemName: "minus").frame(width: 28, height: 28) }
                        .buttonStyle(.cozy(.quiet, compact: true))
                        .accessibilityLabel("Lower \(product.name) price")
                    CoinAmount(amount: price, font: Theme.headline, size: 15)
                        .frame(minWidth: 46)
                        .accessibilityLabel("\(product.name) price \(price) coins")
                    Button { store.adjustPrice(product.id, by: 1) } label: { Image(systemName: "plus").frame(width: 28, height: 28) }
                        .buttonStyle(.cozy(.quiet, compact: true))
                        .accessibilityLabel("Raise \(product.name) price")
                }
                HStack(spacing: 8) {
                    restockButton(label: "+1", quantity: 1, enabled: maxBuy >= 1)
                    restockButton(label: "+5", quantity: 5, enabled: maxBuy >= 5)
                    restockButton(label: room == 0 ? "Full" : "Fill (\(maxBuy))", quantity: maxBuy, enabled: maxBuy >= 1, prominent: true)
                }
                if room > 0 && maxBuy == 0 {
                    Label("Need \(unitCost) coins for one more", systemImage: "exclamationmark.circle")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.terracotta)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func restockButton(label: String, quantity: Int, enabled: Bool, prominent: Bool = false) -> some View {
        let cost = store.engine.restockCost(productId: product.id, quantity: max(quantity, 0))
        return Button {
            store.restock(product.id, quantity: quantity)
        } label: {
            VStack(spacing: 1) {
                Text(label).font(Theme.callout.weight(.bold))
                if enabled {
                    HStack(spacing: 2) {
                        CoinGlyph(size: 10)
                        Text(short(cost)).font(.system(size: 11, weight: .semibold, design: .rounded)).monospacedDigit()
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.cozy(prominent ? .secondary : .quiet, compact: true))
        .disabled(!enabled)
        .accessibilityLabel(enabled ? "Restock \(quantity) for \(cost) coins" : "\(label), unavailable")
    }
}

struct LockedProductRow: View {
    @EnvironmentObject private var store: GameStore
    let product: ProductDef

    var body: some View {
        HStack(spacing: 12) {
            ProductIcon(product: product, size: 40, faded: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name).font(Theme.callout.weight(.semibold)).foregroundStyle(Theme.inkSoft)
                SoftText(requirement, font: Theme.caption)
            }
            Spacer()
            Image(systemName: "lock.fill").foregroundStyle(Theme.cardEdge)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card.opacity(0.6)))
        .accessibilityElement(children: .combine)
    }

    private var requirement: String {
        if let district = product.district, !store.state.unlockedDistricts.contains(district) {
            return "Sold once you open \(store.content.district(district)?.name ?? "a new district")"
        }
        return "Unlocks with More Shelves level \(product.tier - 1)"
    }
}
