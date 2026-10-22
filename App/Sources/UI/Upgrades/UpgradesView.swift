import SwiftUI
import ShopCore

struct UpgradesView: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Upgrades", subtitle: "Invest your earnings in a better shop.") {
                store.activeSheet = nil
            }
            HStack {
                CoinAmount(amount: store.state.coins)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 8)
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(store.content.upgrades) { upgrade in
                        UpgradeRow(upgrade: upgrade)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
        .background(ParchmentBackground())
    }
}

struct UpgradeRow: View {
    @EnvironmentObject private var store: GameStore
    let upgrade: UpgradeDef

    var body: some View {
        let level = store.engine.upgradeLevel(upgrade.id)
        let maxed = level >= upgrade.maxLevel
        let cost = maxed ? 0 : upgrade.costs[level]
        let affordable = store.state.coins >= cost
        Panel {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: upgrade.symbol)
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.brown))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(upgrade.name).font(Theme.headline).foregroundStyle(Theme.ink)
                        SoftText(upgrade.summary, font: Theme.caption)
                        HStack(spacing: 3) {
                            ForEach(0..<upgrade.maxLevel, id: \.self) { i in
                                Capsule()
                                    .fill(i < level ? Theme.gold : Theme.parchment)
                                    .frame(width: 18, height: 6)
                            }
                            Text(maxed ? "Max level" : "Level \(level) of \(upgrade.maxLevel)")
                                .font(Theme.caption.weight(.bold))
                                .foregroundStyle(Theme.inkSoft)
                                .padding(.leading, 4)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Label("Now: \(upgrade.describe(level: level))", systemImage: "checkmark.circle")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.ink)
                    if !maxed {
                        Label("Next: \(upgrade.describe(level: level + 1))", systemImage: "arrow.up.circle.fill")
                            .font(Theme.caption.weight(.semibold))
                            .foregroundStyle(Theme.deepSage)
                    }
                }
                if !maxed {
                    Button {
                        store.buyUpgrade(upgrade.id)
                    } label: {
                        HStack {
                            Text(affordable ? "Upgrade" : "Need \(short(cost - store.state.coins)) more")
                            Spacer()
                            CoinAmount(amount: cost, font: Theme.headline, size: 16)
                        }
                    }
                    .buttonStyle(.cozy(affordable ? .primary : .quiet, compact: true))
                    .disabled(!affordable)
                    .accessibilityLabel(affordable ? "Upgrade \(upgrade.name) for \(cost) coins" : "Need \(cost - store.state.coins) more coins")
                }
            }
        }
    }
}
