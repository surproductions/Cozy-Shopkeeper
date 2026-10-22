import SwiftUI
import ShopCore

struct JournalView: View {
    @EnvironmentObject private var store: GameStore
    @State private var selected: CustomerDef?

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 12)]

    var body: some View {
        let discovered = store.state.customers.count
        VStack(spacing: 0) {
            SheetHeader(title: "Customer Journal", subtitle: "\(discovered) of \(store.content.customers.count) neighbors met") {
                store.activeSheet = nil
            }
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(store.content.customers) { customer in
                        let met = store.state.customers[customer.id] != nil
                        Button {
                            selected = customer
                        } label: {
                            VStack(spacing: 4) {
                                CustomerPortrait(customer: customer, mood: .happy, size: 64, silhouette: !met)
                                Text(met ? customer.name : "???")
                                    .font(Theme.caption.weight(.bold))
                                    .foregroundStyle(Theme.ink)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                if met {
                                    HeartsView(hearts: store.engine.hearts(for: customer.id), size: 9)
                                } else {
                                    SoftText(unlockHint(customer), font: .system(size: 10, design: .rounded))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, minHeight: 150)
                            .background(RoundedRectangle(cornerRadius: 16).fill(met ? Theme.card : Theme.card.opacity(0.55)))
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.cardEdge, lineWidth: 1.2))
                        }
                        .buttonStyle(.plain)
                        .disabled(!met)
                        .accessibilityLabel(met ? "\(customer.name), \(store.engine.hearts(for: customer.id)) hearts" : "Undiscovered customer. \(unlockHint(customer))")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
        .background(ParchmentBackground())
        .sheet(item: $selected) { customer in
            CustomerDetailView(customer: customer)
                .presentationDetents([.large])
        }
    }

    private func unlockHint(_ customer: CustomerDef) -> String {
        if let district = customer.district {
            return "Lives on \(store.content.district(district)?.name ?? "another street")"
        }
        if customer.minReputationLevel > store.engine.reputationLevel {
            return "Visits at reputation \(customer.minReputationLevel)"
        }
        return "Hasn't stopped by yet"
    }
}

struct CustomerDetailView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss
    let customer: CustomerDef

    var body: some View {
        let record = store.state.customers[customer.id] ?? CustomerRecord()
        let hearts = store.engine.hearts(for: customer.id)
        let config = store.engine.config
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.ink)
                            .frame(width: 44, height: 44).background(Circle().fill(Theme.parchment))
                    }
                    .accessibilityLabel("Close")
                }
                HStack(alignment: .bottom, spacing: 16) {
                    CustomerPortrait(customer: customer, mood: hearts >= 3 ? .delighted : .happy, size: 110)
                        .background(Circle().fill(Theme.parchment).frame(width: 130, height: 130).offset(y: 10))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(customer.name).font(Theme.title(24)).foregroundStyle(Theme.ink)
                        Text("\(customer.archetype.displayName) · \(customer.style.displayName)").font(Theme.callout).foregroundStyle(Theme.inkSoft)
                        HeartsView(hearts: hearts, maxHearts: config.maxHearts, size: 14)
                        if store.engine.isRegular(customer.id) {
                            Tag(text: "Regular — budget visible at the counter", color: Theme.rose)
                        }
                    }
                }
                Panel {
                    Text(customer.bio).font(Theme.body).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                }
                Panel {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Likes").font(Theme.headline).foregroundStyle(Theme.ink)
                        HStack { ForEach(customer.favorites, id: \.self) { Tag(text: $0.displayName, color: Theme.deepSage) } }
                        detailRow("Spending", customer.priceSensitivityLabel)
                        detailRow("Tips", customer.tipRate >= 0.15 ? "Generous" : customer.tipRate >= 0.08 ? "Friendly" : "Rare")
                        if customer.giftWrapChance > 0.3 { detailRow("Special", "Often asks for gift wrapping") }
                        if customer.prefersRare { detailRow("Special", "Drawn to uncommon and rare goods") }
                    }
                }
                Panel {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your history").font(Theme.headline).foregroundStyle(Theme.ink)
                        detailRow("First met", "Shop day \(record.discoveredOnShopDay)")
                        detailRow("Visits", "\(record.visits)")
                        detailRow("Purchases", "\(record.purchases)")
                        detailRow("Average happiness", record.purchases == 0 ? "—" : "\(record.averageSatisfaction)%")
                        let pointsToNext = hearts >= config.maxHearts ? 0 : (hearts + 1) * config.relationshipPointsPerHeart - record.relationshipPoints
                        if hearts < config.maxHearts {
                            SoftText("About \(max(1, (pointsToNext + 1) / 2))–\(pointsToNext) happy visits to the next heart. Delighting them counts double.", font: Theme.caption)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let gift = customer.heartGiftDecoration, let deco = store.content.decoration(gift) {
                            detailRow("Friendship gift", record.heartGiftClaimed ? "\(deco.name) — received!" : "\(deco.name) at \(config.maxHearts) hearts")
                        }
                    }
                }
            }
            .padding(18)
        }
        .background(ParchmentBackground())
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            SoftText(title, font: Theme.callout)
            Spacer()
            Text(value).font(Theme.callout.weight(.semibold)).foregroundStyle(Theme.ink).multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}
