import SwiftUI
import ShopCore

struct TownMapView: View {
    @EnvironmentObject private var store: GameStore
    @State private var selectedId: String = ContentIDs.startingDistrict

    var body: some View {
        let districts = store.content.districts
        VStack(spacing: 0) {
            SheetHeader(title: "Town Map", subtitle: "Grow from one little shop to a whole town of them.") {
                store.activeSheet = nil
            }
            GeometryReader { geo in
                ZStack {
                    Canvas { context, size in
                        drawTown(context: context, size: size, districts: districts)
                    }
                    ForEach(districts) { district in
                        let unlocked = store.state.unlockedDistricts.contains(district.id)
                        let here = store.state.currentDistrict == district.id
                        Button {
                            selectedId = district.id
                        } label: {
                            VStack(spacing: 2) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: district.accent))
                                        .frame(width: here ? 46 : 38, height: here ? 46 : 38)
                                        .shadow(color: Theme.shadow, radius: 3, y: 2)
                                    Image(systemName: unlocked ? (here ? "house.fill" : "storefront.fill") : district.isPlayable ? "lock.fill" : "hammer.fill")
                                        .foregroundStyle(.white)
                                        .font(.system(size: 16, weight: .bold))
                                }
                                .overlay(Circle().strokeBorder(selectedId == district.id ? Theme.gold : .white, lineWidth: 3))
                                Text(district.name)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.ink)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Theme.card.opacity(0.9)))
                            }
                        }
                        .buttonStyle(.plain)
                        .position(x: geo.size.width * district.mapX, y: geo.size.height * district.mapY)
                        .accessibilityLabel("\(district.name), \(statusText(district))")
                    }
                }
            }
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.cardEdge, lineWidth: 2))
            .padding(.horizontal, 16)

            if let district = store.content.district(selectedId) {
                DistrictPanel(district: district)
                    .padding(16)
            }
            Spacer(minLength: 0)
        }
        .background(ParchmentBackground())
        .onAppear { selectedId = store.state.currentDistrict }
    }

    private func statusText(_ district: DistrictDef) -> String {
        if store.state.currentDistrict == district.id { return "you are here" }
        if store.state.unlockedDistricts.contains(district.id) { return "open" }
        return district.isPlayable ? "locked" : "coming in a future update"
    }

    private func drawTown(context ctx: GraphicsContext, size: CGSize, districts: [DistrictDef]) {
        let rect = CGRect(origin: .zero, size: size)
        ctx.fill(Path(rect), 0xDCE8C8)
        // River
        ctx.stroke(Path { p in
            p.move(to: P(size.width * 1.05, size.height * 0.05))
            p.addCurve(to: P(-10, size.height * 0.92), control1: P(size.width * 0.5, size.height * 0.2), control2: P(size.width * 0.55, size.height * 0.85))
        }, 0x9FD3D6, 22)
        // Sea in the corner
        ctx.fill(Path(ellipseIn: CGRect(x: size.width * 0.72, y: -size.height * 0.25, width: size.width * 0.6, height: size.height * 0.6)), 0x9FD3D6)
        // Trees
        var rng = SeededRandom(seed: 21)
        for _ in 0..<40 {
            let x = CGFloat(rng.unit()) * size.width
            let y = CGFloat(rng.unit()) * size.height
            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 12, height: 12)), 0x8FAE76, 0.8)
        }
        // Roads between districts
        let points = districts.map { P(size.width * $0.mapX, size.height * $0.mapY) }
        for (a, b) in zip(points, points.dropFirst()) {
            ctx.stroke(Path { p in p.move(to: a); p.addQuadCurve(to: b, control: P((a.x + b.x) / 2 + 20, (a.y + b.y) / 2)) },
                       with: .color(Color(hex: 0xE9D7AE)), style: StrokeStyle(lineWidth: 8, lineCap: .round, dash: [1, 0]))
            ctx.stroke(Path { p in p.move(to: a); p.addQuadCurve(to: b, control: P((a.x + b.x) / 2 + 20, (a.y + b.y) / 2)) },
                       with: .color(Color(hex: 0xC9A27A)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 6]))
        }
    }
}

struct DistrictPanel: View {
    @EnvironmentObject private var store: GameStore
    let district: DistrictDef

    var body: some View {
        let engine = store.engine
        let unlocked = store.state.unlockedDistricts.contains(district.id)
        let here = store.state.currentDistrict == district.id
        let repOK = engine.reputationLevel >= district.requiredReputationLevel
        let coinsOK = store.state.coins >= district.unlockCost
        let newProducts = store.content.products.filter { $0.district == district.id }
        let newCustomers = store.content.customers.filter { $0.district == district.id }
        Panel {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(district.name).font(Theme.title(20)).foregroundStyle(Theme.ink)
                    Spacer()
                    if here { Tag(text: "You are here", color: Theme.deepSage) }
                    else if unlocked { Tag(text: "Open", color: Theme.teal) }
                    else if !district.isPlayable { Tag(text: "Future update", color: Theme.inkSoft) }
                }
                SoftText(district.tagline, font: Theme.callout)
                if !newProducts.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(newProducts) { ProductIcon(product: $0, size: 30, faded: !unlocked) }
                        SoftText("+\(newProducts.count) goods, \(newCustomers.count) new neighbors", font: Theme.caption)
                    }
                }
                if !district.isPlayable {
                    SoftText("This district is being built and can't be entered in this version.", font: Theme.caption)
                } else if here {
                    SoftText("Your shop is open here.", font: Theme.caption)
                } else if unlocked {
                    Button {
                        store.travel(to: district.id)
                    } label: {
                        Label("Move shop here", systemImage: "figure.walk").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.cozy(.primary))
                    .disabled(store.state.currentVisit != nil)
                    if store.state.currentVisit != nil {
                        SoftText("Finish with your current customer first.", font: Theme.caption)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        requirement("Reputation level \(district.requiredReputationLevel)", met: repOK, detail: "you're level \(engine.reputationLevel)")
                        requirement("\(short(district.unlockCost)) coins", met: coinsOK, detail: "you have \(short(store.state.coins))")
                    }
                    Button {
                        store.unlockDistrict(district.id)
                    } label: {
                        Label("Open a shop on \(district.name)", systemImage: "key.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.cozy(repOK && coinsOK ? .secondary : .quiet))
                    .disabled(!(repOK && coinsOK))
                }
            }
        }
    }

    private func requirement(_ text: String, met: Bool, detail: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(met ? Theme.deepSage : Theme.cardEdge)
            Text(text).font(Theme.callout.weight(.semibold)).foregroundStyle(Theme.ink)
            SoftText("(\(detail))", font: Theme.caption)
        }
        .accessibilityElement(children: .combine)
    }
}
