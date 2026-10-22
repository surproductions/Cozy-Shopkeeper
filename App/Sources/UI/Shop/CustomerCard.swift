import SwiftUI
import ShopCore

/// The request card: what the customer wants, your stock and price, and the sell action.
struct CustomerCard: View {
    @EnvironmentObject private var store: GameStore
    let visit: CustomerVisit

    var body: some View {
        let engine = store.engine
        if let customer = store.content.customer(visit.customerId), let product = store.content.product(visit.productId) {
            let price = engine.price(of: product.id)
            let stock = engine.stock(of: product.id)
            let hasStock = stock >= visit.quantity
            let budgetKnown = engine.isBudgetRevealed(for: visit)
            Panel(padding: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 12) {
                        ProductIcon(product: product, size: 58)
                            .background(Circle().fill(Theme.parchment).frame(width: 62, height: 62))
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(customer.name)
                                    .font(Theme.headline)
                                    .foregroundStyle(Theme.ink)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                if engine.isRegular(customer.id) { Tag(text: "Regular", color: Theme.rose) }
                                if visit.isFirstVisit { Tag(text: "New!", color: Theme.teal) }
                            }
                            Text(visit.quantity == 1 ? "Wants a \(product.name)" : "Wants \(visit.quantity) × \(product.name)")
                                .font(Theme.callout)
                                .foregroundStyle(Theme.ink)
                            HStack(spacing: 6) {
                                Tag(text: product.category.displayName, color: Theme.deepSage)
                                if visit.wantsGiftWrap {
                                    Tag(text: engine.hasGiftWrap ? "Gift wrap ✓" : "Hoping for gift wrap", color: Theme.rose)
                                }
                                Text("In stock: \(stock)")
                                    .font(Theme.caption.weight(.bold))
                                    .foregroundStyle(hasStock ? Theme.inkSoft : Theme.terracotta)
                            }
                        }
                        Spacer(minLength: 0)
                    }

                    if hasStock {
                        priceRow(product: product, price: price, budgetKnown: budgetKnown)
                        HStack(spacing: 10) {
                            Button("Not today") { store.turnAwayCurrentCustomer() }
                                .buttonStyle(.cozy(.quiet, compact: true))
                                .accessibilityIdentifier("turnAwayButton")
                                .disabled(visit.isTutorial)
                            Button {
                                store.serveCurrentCustomer()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "bag.fill")
                                    Text("Sell for \(short(price * visit.quantity))").lineLimit(1)
                                    CoinGlyph(size: 16)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.cozy(.primary))
                            .accessibilityLabel("Sell for \(price * visit.quantity) coins")
                            .accessibilityIdentifier("serveButton")
                        }
                    } else {
                        Text("You're out of \(product.name). Restock it now, or send them off kindly — turning someone away never costs reputation.")
                            .font(Theme.footnote)
                            .foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 10) {
                            Button("Sorry, sold out") { store.turnAwayCurrentCustomer() }
                                .buttonStyle(.cozy(.quiet, compact: true))
                                .accessibilityIdentifier("turnAwayButton")
                            Button {
                                store.activeSheet = .stockroom
                            } label: {
                                Label("Restock", systemImage: "shippingbox.fill").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.cozy(.secondary))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func priceRow(product: ProductDef, price: Int, budgetKnown: Bool) -> some View {
        let verdict = PriceVerdict(price: price, recommended: product.recommendedPrice)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Your price")
                    .font(Theme.callout.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 4)
                Button { store.adjustPrice(product.id, by: -1) } label: {
                    Image(systemName: "minus").frame(width: 34, height: 34)
                }
                .buttonStyle(.cozy(.quiet, compact: true))
                .accessibilityLabel("Lower price")
                .accessibilityIdentifier("priceDown")
                CoinAmount(amount: price, font: Theme.title(20), size: 18)
                    .frame(minWidth: 56)
                    .accessibilityLabel("Price \(price) coins each")
                Button { store.adjustPrice(product.id, by: 1) } label: {
                    Image(systemName: "plus").frame(width: 34, height: 34)
                }
                .buttonStyle(.cozy(.quiet, compact: true))
                .accessibilityLabel("Raise price")
                .accessibilityIdentifier("priceUp")
            }
            HStack(spacing: 6) {
                Tag(text: verdict.label, color: verdict.color)
                if budgetKnown {
                    SoftText("Will pay up to \(visit.maxUnitPrice) each", font: Theme.caption)
                } else {
                    SoftText("Fair price is about \(product.recommendedPrice)", font: Theme.caption)
                }
                Spacer(minLength: 0)
                if price != product.recommendedPrice {
                    Button("Use fair price") { store.setPrice(product.id, product.recommendedPrice) }
                        .font(Theme.caption.weight(.bold))
                        .foregroundStyle(Theme.deepTeal)
                }
            }
            if visit.attemptsUsed > 0 {
                Label("They hesitated at that price — one more try before they leave.", systemImage: "exclamationmark.bubble.fill")
                    .font(Theme.caption.weight(.semibold))
                    .foregroundStyle(Theme.terracotta)
            }
        }
    }
}

/// Plain-language read on a price compared with the fair price.
struct PriceVerdict {
    let label: String
    let color: Color

    init(price: Int, recommended: Int) {
        let ratio = Double(price) / Double(max(1, recommended))
        switch ratio {
        case ..<0.85:
            label = "Bargain — happy customers, thin profit"; color = Theme.deepSage
        case ..<1.12:
            label = "Fair price"; color = Theme.teal
        case ..<1.4:
            label = "Pricey — some will balk"; color = Theme.gold
        default:
            label = "Steep — most will refuse"; color = Theme.terracotta
        }
    }
}

/// Shown between customers.
struct WaitingCard: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        Panel(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    ProgressView().tint(Theme.deepSage)
                    Text(store.customersFlowing ? "Listening for the shop bell…" : "The shop is quiet for a moment.")
                        .font(Theme.headline)
                        .foregroundStyle(Theme.ink)
                }
                HStack(spacing: 6) {
                    Image(systemName: "target").foregroundStyle(Theme.gold)
                    SoftText("Next goal: \(store.engine.nextGoalHint)", font: Theme.callout)
                }
            }
        }
        .onAppear { store.resumeCustomers() }
    }
}

/// End-of-day summary with the optional, clearly-disclosed rewarded bonus.
struct DaySummaryCard: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        let summary = store.engine.currentDaySummary
        Panel(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "moon.stars.fill").foregroundStyle(Theme.gold)
                    Text("Day \(summary.dayNumber) complete!").font(Theme.title(20)).foregroundStyle(Theme.ink)
                }
                HStack(spacing: 14) {
                    stat("Served", "\(summary.customersServed)")
                    stat("Sales", short(summary.revenue))
                    stat("Tips", short(summary.tips))
                    stat("Restock", "−" + short(summary.restockSpend))
                }
                if store.canOfferRewardedBonus {
                    Button {
                        store.watchRewardedBonus()
                    } label: {
                        Label("Optional: watch a short video for +\(store.engine.rewardedDayBonusAmount) bonus coins", systemImage: "play.rectangle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.cozy(.quiet, compact: true))
                    .onAppear { store.noteRewardedOfferShown() }
                }
                Button {
                    store.openNextDay()
                } label: {
                    Label("Open the shop for Day \(summary.dayNumber + 1)", systemImage: "sun.max.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.cozy(.primary))
                .accessibilityIdentifier("nextDayButton")
            }
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(Theme.headline).foregroundStyle(Theme.ink).monospacedDigit().lineLimit(1)
            SoftText(title, font: Theme.caption)
        }
        .accessibilityElement(children: .combine)
    }
}
