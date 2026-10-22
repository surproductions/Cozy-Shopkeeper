import SwiftUI
import ShopCore

/// A short, friendly first-session guide. Every step is skippable.
struct TutorialOverlay: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        switch store.state.tutorialStep {
        case .welcome:
            modal {
                VStack(spacing: 14) {
                    if let pip = store.content.customer(ContentIDs.tutorialCustomer) {
                        CustomerPortrait(customer: pip, mood: .delighted, size: 90)
                    }
                    Text("Welcome to Maple Corner!")
                        .font(Theme.title(24))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                    Text("Your little shop is ready: shelves of starter goods and \(store.state.coins) coins in the till. Let's flip the sign to Open and meet your first customer.")
                        .font(Theme.body)
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        store.acknowledgeTutorial(.welcome)
                    } label: {
                        Label("Open the shop", systemImage: "door.left.hand.open").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.cozy(.primary))
                    .accessibilityIdentifier("openShopButton")
                    skipButton
                }
            }
        case .firstSale:
            coach(symbol: "hand.tap.fill", text: store.state.currentVisit == nil
                  ? "Here comes someone now…"
                  : "Pip wants a honey bun. The fair price is already set — tap Sell to make your first sale!")
        case .restock:
            coach(symbol: "shippingbox.fill", text: "Lovely first sale! Shelves empty fast — tap Stock below and restock any item.")
        case .decorGift:
            modal {
                VStack(spacing: 12) {
                    Image(systemName: "gift.fill").font(.system(size: 40)).foregroundStyle(Theme.terracotta)
                    Text("A housewarming gift!")
                        .font(Theme.title(22)).foregroundStyle(Theme.ink)
                    Text("Your neighbors left a Potted Fern — it's already in the corner. Decorations make the shop cozier, and cozy customers are happier tippers. Find more under Decor.")
                        .font(Theme.body).foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Lovely!") { store.acknowledgeTutorial(.decorGift) }
                        .buttonStyle(.cozy(.primary))
                        .accessibilityIdentifier("tutorialContinue")
                }
            }
        case .goals:
            modal {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checklist").foregroundStyle(Theme.gold)
                        Text("Today's goals").font(Theme.title(22)).foregroundStyle(Theme.ink)
                    }
                    ForEach(store.state.daily.goals) { goal in
                        if let quest = store.content.quest(goal.questId) {
                            HStack {
                                Image(systemName: "circle").foregroundStyle(Theme.sage)
                                Text(quest.title).font(Theme.callout).foregroundStyle(Theme.ink)
                                Spacer()
                                CoinAmount(amount: quest.rewardCoins, font: Theme.callout, size: 14)
                            }
                        }
                    }
                    SoftText("New goals arrive every day. Finish shop days, serve regulars and save up for upgrades — and when you're ready, a second shop awaits on Flower Lane.", font: Theme.callout)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        store.acknowledgeTutorial(.goals)
                    } label: {
                        Text("Let's keep shop!").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.cozy(.primary))
                    .accessibilityIdentifier("tutorialContinue")
                }
            }
        case .done:
            EmptyView()
        }
    }

    private var skipButton: some View {
        Button("Skip the tour") { store.skipTutorial() }
            .font(Theme.callout)
            .foregroundStyle(Theme.inkSoft)
            .frame(minHeight: 44)
    }

    private func modal<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            Panel(padding: 22) {
                content()
            }
            .padding(.horizontal, 26)
        }
        .transition(.opacity)
        .accessibilityAddTraits(.isModal)
    }

    private func coach(symbol: String, text: String) -> some View {
        VStack {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.gold)
                Text(text)
                    .font(Theme.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button {
                    store.skipTutorial()
                } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white.opacity(0.8))
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("Skip tutorial")
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.deepTeal.opacity(0.95)))
            .padding(.horizontal, 18)
            .padding(.top, 62)
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
