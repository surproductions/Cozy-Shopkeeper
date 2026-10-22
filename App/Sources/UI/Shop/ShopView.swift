import SwiftUI
import ShopCore

struct ShopView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private var reduceMotion: Bool { systemReduceMotion || store.state.settings.reducedMotion }

    var body: some View {
        ZStack {
            ParchmentBackground()
            VStack(spacing: 10) {
                ShopHUD()
                sceneCard
                    .layoutPriority(0)
                bottomPanel
                    .layoutPriority(1)
                ShopToolbar()
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .padding(.bottom, 6)

            if let burst = store.coinBurst {
                CoinBurstView(burst: burst, reduceMotion: reduceMotion)
                    .id(burst.id)
                    .allowsHitTesting(false)
            }
            TutorialOverlay()
            ToastOverlay()
        }
    }

    private var sceneCard: some View {
        let look = ShopLook.make(engine: store.engine)
        return ShopSceneView(look: look) {
            CustomerLayer(reduceMotion: reduceMotion)
        }
        .aspectRatio(0.92, contentMode: .fit)
        .frame(minHeight: 200, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color(hex: 0x8A6142), lineWidth: 4)
        )
        .shadow(color: Theme.shadow, radius: 8, x: 0, y: 4)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Your shop in \(look.district.name)")
    }

    @ViewBuilder
    private var bottomPanel: some View {
        if let visit = store.state.currentVisit {
            CustomerCard(visit: visit)
                .id(visit.id)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        } else if store.isDayFinished {
            DaySummaryCard()
                .transition(.opacity)
        } else {
            WaitingCard()
                .transition(.opacity)
        }
    }
}

// MARK: - HUD

struct ShopHUD: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        let engine = store.engine
        let day = store.state.shopDay
        HStack(spacing: 10) {
            CoinAmount(amount: store.state.coins, font: Theme.title(22), size: 24)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Theme.card))
                .overlay(Capsule().strokeBorder(Theme.cardEdge, lineWidth: 1.5))
                .layoutPriority(2)
                .accessibilityIdentifier("coinsLabel")
                .animation(.spring(response: 0.4), value: store.state.coins)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill").foregroundStyle(Theme.gold).font(.system(size: 12))
                    Text("Reputation \(engine.reputationLevel)").font(Theme.caption.weight(.bold)).foregroundStyle(Theme.ink)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                CozyProgressBar(value: engine.config.reputationProgress(for: store.state.reputation), tint: Theme.gold, height: 7)
                    .frame(minWidth: 50, maxWidth: 92)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Reputation level \(engine.reputationLevel)")

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 1) {
                Text("Day \(short(day.dayNumber))").font(Theme.headline).foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                SoftText("\(min(day.customersArrived, day.customersPlanned))/\(day.customersPlanned) customers", font: Theme.caption)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .accessibilityElement(children: .combine)

            Button {
                store.activeSheet = .settings
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.brown)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.card))
                    .overlay(Circle().strokeBorder(Theme.cardEdge, lineWidth: 1.5))
            }
            .accessibilityLabel("Settings")
        }
    }
}

// MARK: - Customer in the scene

struct CustomerLayer: View {
    @EnvironmentObject private var store: GameStore
    let reduceMotion: Bool
    @State private var bob = false

    var body: some View {
        ZStack(alignment: .top) {
            if let visit = store.state.currentVisit, let customer = store.content.customer(visit.customerId) {
                CustomerPortrait(customer: customer, mood: mood(for: visit), size: 150)
                    .scaleEffect(0.98)
                    .offset(y: bob && !reduceMotion ? -3 : 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .id(visit.id)
                    .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .leading).combined(with: .opacity),
                                                                      removal: .move(edge: .trailing).combined(with: .opacity)))
                    .onAppear {
                        guard !reduceMotion else { return }
                        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { bob = true }
                    }
                SpeechBubble(text: store.reaction?.text ?? visit.greeting)
                    .offset(y: -30)
                    .id("bubble-\(visit.id)-\(store.reaction?.id.uuidString ?? "greet")")
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            } else if let reaction = store.reaction {
                SpeechBubble(text: reaction.text)
                    .offset(y: -30)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.55, dampingFraction: 0.85), value: store.state.currentVisit?.id)
        .animation(.easeInOut(duration: 0.2), value: store.reaction?.id)
    }

    private func mood(for visit: CustomerVisit) -> CustomerMood {
        if let reaction = store.reaction {
            switch reaction.mood {
            case .delighted: return .delighted
            case .happy: return .happy
            case .hesitant: return .hesitant
            case .sad: return .sad
            }
        }
        return visit.attemptsUsed > 0 ? .hesitant : .happy
    }
}

struct SpeechBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.callout.weight(.semibold))
            .foregroundStyle(Theme.ink)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Theme.shadow, radius: 3, x: 0, y: 2)
            )
            .overlay(alignment: .bottom) {
                Triangle()
                    .fill(Color.white)
                    .frame(width: 14, height: 8)
                    .offset(y: 7)
            }
            .frame(width: 200)
            .accessibilityLabel("Customer says: \(text)")
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        polygon([P(rect.minX, rect.minY), P(rect.maxX, rect.minY), P(rect.midX, rect.maxY)])
    }
}

// MARK: - Toolbar

struct ShopToolbar: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        let engine = store.engine
        let lowStock = engine.availableProducts.contains { engine.stock(of: $0.id) == 0 }
        let goalsBadge = engine.claimableCount + (engine.isDailyRewardAvailable(now: Date(), timeZone: .current) ? 1 : 0)
        HStack(spacing: 6) {
            ToolbarButton(title: "Stock", symbol: "shippingbox.fill", tint: Theme.terracotta, badge: lowStock ? "!" : nil,
                          highlight: store.state.tutorialStep == .restock, identifier: "stockButton") { store.activeSheet = .stockroom }
            ToolbarButton(title: "Upgrades", symbol: "hammer.fill", tint: Theme.brown, badge: nil, highlight: false, identifier: "upgradesButton") { store.activeSheet = .upgrades }
            ToolbarButton(title: "Decor", symbol: "paintbrush.pointed.fill", tint: Theme.deepSage, badge: nil, highlight: false, identifier: "decorButton") { store.activeSheet = .decor }
            ToolbarButton(title: "Journal", symbol: "book.closed.fill", tint: Theme.teal, badge: nil, highlight: false, identifier: "journalButton") { store.activeSheet = .journal }
            ToolbarButton(title: "Goals", symbol: "checklist", tint: Theme.gold, badge: goalsBadge > 0 ? "\(goalsBadge)" : nil, highlight: false, identifier: "goalsButton") { store.activeSheet = .goals }
            ToolbarButton(title: "Map", symbol: "map.fill", tint: Theme.deepTeal, badge: nil, highlight: false, identifier: "mapButton") { store.activeSheet = .map }
        }
    }
}

struct ToolbarButton: View {
    let title: String
    let symbol: String
    let tint: Color
    let badge: String?
    let highlight: Bool
    let identifier: String
    let action: () -> Void
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(height: 22)
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.card)
                    .shadow(color: Theme.shadow, radius: 3, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(highlight ? Theme.gold : Theme.cardEdge, lineWidth: highlight ? 3 : 1.2)
            )
            .scaleEffect(highlight && pulse ? 1.06 : 1)
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Capsule().fill(Theme.terracotta))
                        .offset(x: 4, y: -5)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(badge == nil ? title : "\(title), \(badge == "!" ? "needs attention" : "\(badge!) ready")")
        .accessibilityIdentifier(identifier)
        .onAppear { startPulse() }
        .onChange(of: highlight) { _, _ in startPulse() }
    }

    private func startPulse() {
        guard highlight, !reduceMotion else { pulse = false; return }
        withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { pulse = true }
    }
}

// MARK: - Effects and toasts

struct CoinBurstView: View {
    let burst: CoinBurst
    let reduceMotion: Bool
    @State private var launched = false

    var body: some View {
        GeometryReader { geo in
            let origin = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.42)
            ZStack {
                if !reduceMotion {
                    ForEach(0..<8, id: \.self) { i in
                        CoinGlyph(size: 20)
                            .position(launched ? CGPoint(x: 70 + CGFloat(i % 3) * 6, y: 30) : CGPoint(x: origin.x + CGFloat(i - 4) * 14, y: origin.y + CGFloat(i % 2) * 12))
                            .opacity(launched ? 0 : 1)
                            .animation(.easeIn(duration: 0.7).delay(Double(i) * 0.04), value: launched)
                    }
                    if burst.delighted {
                        ForEach(0..<6, id: \.self) { i in
                            Image(systemName: "sparkle")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Theme.gold)
                                .position(x: origin.x + CGFloat(cos(Double(i))) * (launched ? 90 : 20),
                                          y: origin.y - 40 + CGFloat(sin(Double(i))) * (launched ? 60 : 10))
                                .opacity(launched ? 0 : 1)
                                .animation(.easeOut(duration: 0.9), value: launched)
                        }
                    }
                }
                VStack(spacing: 2) {
                    Text("+\(short(burst.amount))")
                        .font(Theme.title(30))
                        .foregroundStyle(Color(hex: 0xA0702A))
                    if burst.tip > 0 {
                        Text("+\(short(burst.tip)) tip")
                            .font(Theme.headline)
                            .foregroundStyle(Theme.deepSage)
                    }
                }
                .shadow(color: .white, radius: 2)
                .position(x: origin.x, y: origin.y - (launched ? 70 : 0))
                .opacity(launched ? 0 : 1)
                .animation(.easeOut(duration: 1.4).delay(0.3), value: launched)
            }
        }
        .onAppear { launched = true }
        .accessibilityHidden(true)
    }
}

struct ToastOverlay: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        VStack {
            if let toast = store.toast {
                HStack(spacing: 8) {
                    Image(systemName: icon(toast.kind))
                        .foregroundStyle(color(toast.kind))
                    Text(toast.text)
                        .font(Theme.callout.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Capsule().fill(Theme.card).shadow(color: Theme.shadow, radius: 8, x: 0, y: 4))
                .overlay(Capsule().strokeBorder(color(toast.kind).opacity(0.5), lineWidth: 1.5))
                .padding(.horizontal, 20)
                .padding(.top, 54)
                .transition(.move(edge: .top).combined(with: .opacity))
                .id(toast.id)
                .accessibilityAddTraits(.isStaticText)
                .onTapGesture { store.toast = nil }
            }
            Spacer()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: store.toast)
    }

    private func icon(_ kind: Toast.Kind) -> String {
        switch kind {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.seal.fill"
        case .warning: return "exclamationmark.circle.fill"
        }
    }

    private func color(_ kind: Toast.Kind) -> Color {
        switch kind {
        case .info: return Theme.teal
        case .success: return Theme.deepSage
        case .warning: return Theme.terracotta
        }
    }
}
