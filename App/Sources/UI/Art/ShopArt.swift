import SwiftUI
import ShopCore

/// Everything needed to paint the shop interior. Built from game state, optionally with
/// decoration overrides so the Decor screen can preview items before buying.
struct ShopLook {
    var decor: [DecorSlot: DecorationDef]
    var district: DistrictDef
    var shelfProducts: [ProductDef]
    var dayProgress: Double

    @MainActor
    static func make(engine: GameEngine, override: (slot: DecorSlot, decoration: DecorationDef?)? = nil) -> ShopLook {
        var decor: [DecorSlot: DecorationDef] = [:]
        for slot in DecorSlot.allCases {
            if let id = engine.state.equippedDecorations[slot.rawValue], let def = engine.content.decoration(id) {
                decor[slot] = def
            }
        }
        if let override {
            decor[override.slot] = override.decoration
        }
        let stocked = engine.availableProducts.filter { engine.stock(of: $0.id) > 0 }
        let district = engine.content.district(engine.state.currentDistrict) ?? engine.content.districts[0]
        let day = engine.state.shopDay
        let progress = day.customersPlanned == 0 ? 0 : Double(day.customersArrived) / Double(day.customersPlanned)
        return ShopLook(decor: decor, district: district, shelfProducts: Array(stocked.prefix(12)), dayProgress: progress)
    }
}

enum ShopArtist {
    // MARK: Background: walls, window, shelves, wall decor, floor, rug, plant

    static func drawBackdrop(_ look: ShopLook, size: CGSize, context ctx: GraphicsContext) {
        let w = size.width, h = size.height
        let wallBottom = h * 0.66

        // Walls
        let wall = look.decor[.wallpaper]
        let wallA = wall?.primary ?? 0xF6E8CC
        let wallB = wall?.secondary ?? 0xEBD9B5
        ctx.fill(Path(R(0, 0, w, wallBottom)), wallA)
        switch wall?.pattern ?? .plain {
        case .stripes:
            let stripe = w / 14
            var x: CGFloat = 0
            while x < w {
                ctx.fill(Path(R(x, 0, stripe * 0.5, wallBottom)), wallB, 0.55)
                x += stripe
            }
        case .vines:
            for i in 0..<6 {
                let x = w * (0.08 + CGFloat(i) * 0.17)
                ctx.stroke(Path { p in
                    p.move(to: P(x, wallBottom))
                    var y = wallBottom
                    var flip: CGFloat = 1
                    while y > 0 {
                        p.addQuadCurve(to: P(x, y - 28), control: P(x + 10 * flip, y - 14))
                        y -= 28
                        flip *= -1
                    }
                }, wallB, 1.6, 0.55)
                var y = wallBottom - 14
                var side: CGFloat = 1
                while y > 10 {
                    ctx.fill(E(x + side * 3 - 4, y - 3, 8, 5), 0x6F8C5E, 0.6)
                    y -= 22
                    side *= -1
                }
            }
        case .stars:
            var rng = SeededRandom(seed: 7)
            for _ in 0..<38 {
                let x = CGFloat(rng.unit()) * w
                let y = CGFloat(rng.unit()) * wallBottom
                let s = CGFloat(2 + rng.unit() * 3)
                ctx.fill(star(P(x, y), s, s * 0.45), wallB, 0.85)
            }
        default:
            // Plaster speckles
            var rng = SeededRandom(seed: 3)
            for _ in 0..<24 {
                ctx.fill(E(CGFloat(rng.unit()) * w, CGFloat(rng.unit()) * wallBottom, 3, 2), wallB, 0.6)
            }
        }
        // Wainscot and ceiling beam
        ctx.fill(Path(R(0, wallBottom - h * 0.08, w, h * 0.08)), Hex.darker(wallA, 0.12), 0.8)
        ctx.fill(Path(R(0, wallBottom - h * 0.085, w, 3)), Hex.darker(wallA, 0.3), 0.6)
        ctx.fill(Path(R(0, 0, w, h * 0.035)), 0x8A6142)
        ctx.fill(Path(R(0, h * 0.035, w, 2)), 0x5A3E2B, 0.5)

        drawWindow(look, rect: R(w * 0.33, h * 0.07, w * 0.34, h * 0.27), context: ctx)
        drawShelves(look, size: size, context: ctx)

        // Wall art above the left shelf
        if let art = look.decor[.wallArt] {
            drawWallArt(art, rect: R(w * 0.07, h * 0.055, w * 0.2, h * 0.1), context: ctx)
        }
        // Seasonal decor above the right shelf / along the beam
        if let seasonal = look.decor[.seasonal] {
            drawSeasonal(seasonal, size: size, context: ctx)
        }

        // Floor
        let floor = look.decor[.floor]
        let floorA = floor?.primary ?? 0xC9965F
        let floorB = floor?.secondary ?? 0xA97A48
        ctx.fill(Path(R(0, wallBottom, w, h - wallBottom)), floorA)
        switch floor?.pattern ?? .boards {
        case .checker:
            let tile = w / 10
            var row = 0
            var y = wallBottom
            while y < h {
                var col = 0
                var x: CGFloat = 0
                while x < w {
                    if (row + col).isMultiple(of: 2) { ctx.fill(Path(R(x, y, tile, tile * 0.6)), floorB) }
                    x += tile
                    col += 1
                }
                y += tile * 0.6
                row += 1
            }
        case .herringbone:
            let step: CGFloat = 18
            var y = wallBottom
            var row = 0
            while y < h {
                var x: CGFloat = row.isMultiple(of: 2) ? 0 : -step / 2
                while x < w {
                    ctx.stroke(line(P(x, y + 12), P(x + step / 2, y)), floorB, 2)
                    ctx.stroke(line(P(x + step / 2, y), P(x + step, y + 12)), floorB, 2)
                    x += step
                }
                y += 12
                row += 1
            }
        default:
            var y = wallBottom
            var row = 0
            while y < h {
                ctx.fill(Path(R(0, y, w, 1.5)), floorB)
                let offset: CGFloat = row.isMultiple(of: 2) ? 0 : w * 0.12
                var x = offset
                while x < w {
                    ctx.fill(Path(R(x, y, 1.5, h * 0.06)), floorB, 0.8)
                    x += w * 0.24
                }
                y += h * 0.06
                row += 1
            }
        }
        ctx.fill(Path(R(0, wallBottom, w, 4)), 0x5A3E2B, 0.25)

        if let rug = look.decor[.rug] {
            drawRug(rug, rect: R(w * 0.16, h * 0.86, w * 0.68, h * 0.12), context: ctx)
        }
        if let plant = look.decor[.plant] {
            drawPlant(plant, size: size, context: ctx)
        }
        if let light = look.decor[.lighting] {
            drawLighting(light, size: size, context: ctx)
        }
    }

    static func drawWindow(_ look: ShopLook, rect: CGRect, context ctx: GraphicsContext) {
        let frame = Path(roundedRect: rect, cornerRadius: 8)
        let dusk: UInt32 = 0xF2A65A
        let t = look.dayProgress * 0.55
        let top = Hex.mix(look.district.skyTop, 0x8C6FA8, t)
        let bottom = Hex.mix(look.district.skyBottom, dusk, t)
        ctx.fill(frame, with: .linearGradient(Gradient(colors: [Color(hex: top), Color(hex: bottom)]),
                                               startPoint: CGPoint(x: rect.midX, y: rect.minY),
                                               endPoint: CGPoint(x: rect.midX, y: rect.maxY)))
        // Sun sinking through the day
        let sunY = rect.minY + rect.height * (0.22 + 0.5 * look.dayProgress)
        ctx.fill(E(rect.minX + rect.width * 0.7, sunY, rect.width * 0.16, rect.width * 0.16), Hex.mix(0xFFE8A3, 0xF28C4A, look.dayProgress), 0.9)
        // Clouds
        for (cx, cy) in [(0.25, 0.25), (0.55, 0.15)] {
            let x = rect.minX + rect.width * cx, y = rect.minY + rect.height * cy
            ctx.fill(E(x, y, rect.width * 0.2, rect.height * 0.1), 0xFFFFFF, 0.8)
            ctx.fill(E(x + rect.width * 0.06, y - rect.height * 0.05, rect.width * 0.14, rect.height * 0.12), 0xFFFFFF, 0.8)
        }
        // Rooftops across the street
        let accent = look.district.accent
        let baseY = rect.maxY
        var roofs = Path()
        roofs.move(to: P(rect.minX, baseY))
        let peaks: [(CGFloat, CGFloat)] = [(0.0, 0.62), (0.12, 0.5), (0.26, 0.62), (0.26, 0.7), (0.42, 0.7), (0.5, 0.56), (0.62, 0.7), (0.78, 0.6), (0.9, 0.48), (1.0, 0.6)]
        for (px, py) in peaks { roofs.addLine(to: P(rect.minX + rect.width * px, rect.minY + rect.height * py)) }
        roofs.addLine(to: P(rect.maxX, baseY))
        roofs.closeSubpath()
        var clipped = ctx
        clipped.clip(to: frame)
        clipped.fill(roofs, Hex.mix(accent, 0xFFFFFF, 0.35), 0.75)
        for i in 0..<4 {
            let x = rect.minX + rect.width * (0.08 + CGFloat(i) * 0.24)
            clipped.fill(Path(R(x, rect.minY + rect.height * 0.76, rect.width * 0.05, rect.height * 0.07)), 0xFFE9A8, 0.4 + look.dayProgress * 0.5)
        }
        // Frame, mullions, sill
        ctx.stroke(frame, 0x8A6142, 6)
        ctx.fill(Path(R(rect.midX - 2, rect.minY, 4, rect.height)), 0x8A6142)
        ctx.fill(Path(R(rect.minX, rect.midY - 2, rect.width, 4)), 0x8A6142)
        ctx.fill(RR(rect.minX - 8, rect.maxY - 2, rect.width + 16, 9, 3), 0x6B4A31)
        if look.district.id == ContentIDs.secondDistrict {
            // Flower box on the sill for Flower Lane
            ctx.fill(RR(rect.minX + 6, rect.maxY - 10, rect.width - 12, 9, 2), 0xC96F4A)
            for i in 0..<6 {
                let x = rect.minX + 12 + CGFloat(i) * (rect.width - 24) / 5
                drawFlower(ctx, center: P(x, rect.maxY - 12), radius: 5, petal: i.isMultiple(of: 2) ? 0xE86A5A : 0xF4C7D3, middle: 0xF2D27C)
            }
        }
    }

    static func drawShelves(_ look: ShopLook, size: CGSize, context ctx: GraphicsContext) {
        let w = size.width, h = size.height
        let style = look.decor[.shelves]
        let wood = style?.primary ?? 0xC08D58
        let edge = style?.secondary ?? 0x8A6142
        let units = [R(w * 0.03, h * 0.16, w * 0.27, h * 0.44), R(w * 0.70, h * 0.16, w * 0.27, h * 0.44)]
        let boardYs: [CGFloat] = [0.31, 0.62, 0.93]
        var productIndex = 0
        for unit in units {
            if style?.pattern == .glass {
                ctx.fill(RR(unit.minX - 4, unit.minY - 6, unit.width + 8, unit.height + 10, 6), wood)
                ctx.fill(Path(R(unit.minX, unit.minY, unit.width, unit.height)), 0x3B2A20, 0.35)
            } else {
                ctx.fill(Path(R(unit.minX, unit.minY, unit.width, unit.height)), Hex.darker(wood, 0.35), 0.18)
                ctx.fill(Path(R(unit.minX - 3, unit.minY, 5, unit.height + 4)), wood)
                ctx.fill(Path(R(unit.maxX - 2, unit.minY, 5, unit.height + 4)), wood)
            }
            for boardY in boardYs {
                let y = unit.minY + unit.height * boardY
                let itemSize = min(unit.width * 0.45, unit.height * 0.27)
                for slot in 0..<2 {
                    guard productIndex < look.shelfProducts.count else { break }
                    let product = look.shelfProducts[productIndex]
                    let x = unit.minX + unit.width * (slot == 0 ? 0.27 : 0.73) - itemSize / 2
                    ProductArtist.draw(product.art, in: R(x, y - itemSize * 0.92, itemSize, itemSize), context: ctx)
                    productIndex += 1
                }
                ctx.fill(RR(unit.minX - 6, y, unit.width + 12, max(5, h * 0.018), 2), wood)
                ctx.fill(Path(R(unit.minX - 6, y + max(5, h * 0.018) - 2, unit.width + 12, 2)), edge, 0.8)
            }
            if style?.pattern == .glass {
                ctx.fill(Path(R(unit.minX, unit.minY, unit.width, unit.height)), style?.secondary ?? 0xCFE6E8, 0.18)
                ctx.stroke(line(P(unit.minX + unit.width * 0.15, unit.minY + 6), P(unit.minX + unit.width * 0.35, unit.minY + unit.height * 0.4)), 0xFFFFFF, 2, 0.5)
            }
        }
    }

    static func drawWallArt(_ art: DecorationDef, rect: CGRect, context ctx: GraphicsContext) {
        switch art.pattern {
        case .sign:
            ctx.stroke(line(P(rect.minX + 8, rect.minY - 4), P(rect.midX, rect.minY - 12)), 0x5A3E2B, 1.2)
            ctx.stroke(line(P(rect.maxX - 8, rect.minY - 4), P(rect.midX, rect.minY - 12)), 0x5A3E2B, 1.2)
            ctx.paint(RR(rect.minX, rect.minY, rect.width, rect.height, 5), art.primary)
            ctx.fill(RR(rect.minX + 4, rect.minY + 4, rect.width - 8, rect.height - 8, 3), art.secondary, 0.2)
            let text = Text("Come in!").font(.system(size: max(8, rect.height * 0.38), weight: .bold, design: .rounded)).foregroundColor(Color(hex: art.secondary))
            ctx.draw(text, at: P(rect.midX, rect.midY))
        case .painting:
            ctx.paint(RR(rect.minX + rect.width * 0.12, rect.minY - 4, rect.width * 0.76, rect.height + 8, 2), 0xD4A84B)
            let inner = R(rect.minX + rect.width * 0.17, rect.minY, rect.width * 0.66, rect.height)
            ctx.fill(Path(inner), 0xBFE0EA)
            ctx.fill(Path { p in p.move(to: P(inner.minX, inner.maxY)); p.addQuadCurve(to: P(inner.maxX, inner.maxY - inner.height * 0.3), control: P(inner.midX, inner.minY + inner.height * 0.2)); p.addLine(to: P(inner.maxX, inner.maxY)); p.closeSubpath() }, art.primary)
            ctx.fill(E(inner.minX + inner.width * 0.65, inner.minY + 3, 7, 7), art.secondary)
        case .tapestry:
            ctx.stroke(line(P(rect.minX + rect.width * 0.15, rect.minY - 2), P(rect.maxX - rect.width * 0.15, rect.minY - 2)), 0x8A6142, 3)
            ctx.paint(Path { p in
                p.move(to: P(rect.minX + rect.width * 0.18, rect.minY))
                p.addLine(to: P(rect.maxX - rect.width * 0.18, rect.minY))
                p.addLine(to: P(rect.maxX - rect.width * 0.18, rect.maxY + 6))
                p.addLine(to: P(rect.midX, rect.maxY))
                p.addLine(to: P(rect.minX + rect.width * 0.18, rect.maxY + 6))
                p.closeSubpath()
            }, art.primary)
            ctx.fill(E(rect.midX - 7, rect.minY + 6, 14, 14), art.secondary)
            ctx.fill(E(rect.midX - 14, rect.minY + 20, 10, 6), art.secondary, 0.7)
            ctx.fill(E(rect.midX + 4, rect.minY + 20, 10, 6), art.secondary, 0.7)
        default:
            break
        }
    }

    static func drawSeasonal(_ deco: DecorationDef, size: CGSize, context ctx: GraphicsContext) {
        let w = size.width, h = size.height
        switch deco.pattern {
        case .garland:
            var rope = Path()
            rope.move(to: P(0, h * 0.045))
            let swags = 5
            for i in 0..<swags {
                let x0 = w * CGFloat(i) / CGFloat(swags)
                let x1 = w * CGFloat(i + 1) / CGFloat(swags)
                rope.addQuadCurve(to: P(x1, h * 0.045), control: P((x0 + x1) / 2, h * 0.11))
            }
            ctx.stroke(rope, 0x6B4A31, 1.5)
            for i in 0..<14 {
                let t = CGFloat(i) / 13
                let x = w * t
                let swagT = (t * CGFloat(swags)).truncatingRemainder(dividingBy: 1)
                let y = h * 0.045 + (h * 0.065) * 4 * swagT * (1 - swagT) * 0.5
                ctx.fill(E(x - 4, y, 8, 9), i.isMultiple(of: 3) ? deco.secondary : deco.primary)
            }
        case .wreath:
            let c = P(w * 0.835, h * 0.1)
            let r = min(w, h) * 0.055
            ctx.stroke(Path(ellipseIn: R(c.x - r, c.y - r, r * 2, r * 2)), deco.primary, r * 0.55)
            for i in 0..<10 {
                let a = Double(i) * .pi / 5
                ctx.fill(E(c.x + CGFloat(cos(a)) * r - 2, c.y + CGFloat(sin(a)) * r - 2, 4, 4), i.isMultiple(of: 2) ? deco.secondary : 0xC0392B)
            }
            ctx.fill(polygon([P(c.x, c.y + r), P(c.x - 6, c.y + r + 9), P(c.x + 6, c.y + r + 9)]), 0xC0392B)
        default:
            break
        }
    }

    static func drawRug(_ rug: DecorationDef, rect: CGRect, context ctx: GraphicsContext) {
        switch rug.pattern {
        case .sunRug:
            ctx.fill(Path(ellipseIn: rect), rug.secondary)
            ctx.fill(Path(ellipseIn: rect.insetBy(dx: rect.width * 0.06, dy: rect.height * 0.12)), rug.primary)
            ctx.fill(Path(ellipseIn: rect.insetBy(dx: rect.width * 0.3, dy: rect.height * 0.3)), Hex.lighter(rug.primary, 0.3))
        default:
            for i in 0..<4 {
                let inset = CGFloat(i)
                ctx.fill(Path(ellipseIn: rect.insetBy(dx: inset * rect.width * 0.07, dy: inset * rect.height * 0.14)),
                         i.isMultiple(of: 2) ? rug.primary : rug.secondary)
            }
        }
    }

    static func drawPlant(_ plant: DecorationDef, size: CGSize, context ctx: GraphicsContext) {
        let w = size.width, h = size.height
        switch plant.pattern {
        case .ivy:
            let anchor = P(w * 0.06, h * 0.035)
            ctx.stroke(line(anchor, P(w * 0.06, h * 0.12)), 0xC9A27A, 1.2)
            ctx.paint(RR(w * 0.02, h * 0.12, w * 0.09, h * 0.06, 4), plant.secondary)
            for strand in 0..<3 {
                let x = w * (0.03 + CGFloat(strand) * 0.03)
                for j in 0..<6 {
                    let y = h * 0.18 + CGFloat(j) * h * 0.045
                    ctx.fill(E(x + (j.isMultiple(of: 2) ? -3 : 2), y, 7, 6), Hex.mix(plant.primary, 0x9CB38A, Double(j) * 0.08))
                }
            }
        case .monstera:
            let base = P(w * 0.09, h * 0.97)
            for (dx, dy, s) in [(-0.05, -0.27, 1.0), (0.04, -0.3, 0.9), (0.0, -0.18, 1.1), (-0.07, -0.14, 0.8)] {
                let leaf = R(base.x + w * CGFloat(dx) - 14 * CGFloat(s), base.y + h * CGFloat(dy) - 10, 28 * CGFloat(s), 22 * CGFloat(s))
                ctx.stroke(line(P(base.x, base.y - h * 0.06), P(leaf.midX, leaf.midY)), Hex.darker(plant.primary, 0.2), 2)
                ctx.paint(Path(ellipseIn: leaf), plant.primary)
                ctx.stroke(line(P(leaf.minX + 4, leaf.midY), P(leaf.maxX - 4, leaf.midY)), Hex.lighter(plant.primary, 0.3), 1)
            }
            ctx.paint(polygon([P(base.x - w * 0.06, base.y - h * 0.09), P(base.x + w * 0.06, base.y - h * 0.09), P(base.x + w * 0.045, base.y), P(base.x - w * 0.045, base.y)]), plant.secondary)
        default:
            let base = P(w * 0.085, h * 0.97)
            for i in 0..<7 {
                let a = -Double.pi / 2 + (Double(i) - 3) * 0.32
                let len = h * (0.14 + (i == 3 ? 0.04 : 0))
                let tip = P(base.x + CGFloat(cos(a)) * len * 0.9, base.y - h * 0.08 + CGFloat(sin(a)) * len)
                ctx.stroke(Path { p in p.move(to: P(base.x, base.y - h * 0.08)); p.addQuadCurve(to: tip, control: P((base.x + tip.x) / 2 + 6, (base.y + tip.y) / 2 - 10)) }, plant.primary, 5)
            }
            ctx.paint(polygon([P(base.x - w * 0.05, base.y - h * 0.09), P(base.x + w * 0.05, base.y - h * 0.09), P(base.x + w * 0.04, base.y), P(base.x - w * 0.04, base.y)]), plant.secondary)
        }
    }

    static func drawLighting(_ light: DecorationDef, size: CGSize, context ctx: GraphicsContext) {
        let w = size.width, h = size.height
        switch light.pattern {
        case .lantern:
            let c = P(w * 0.76, h * 0.12)
            ctx.fill(Path(ellipseIn: R(c.x - 60, c.y - 40, 120, 110)), with: .radialGradient(Gradient(colors: [Color(hex: 0xFFE9A8, opacity: 0.45), .clear]), center: c, startRadius: 0, endRadius: 60))
            ctx.stroke(line(P(c.x, h * 0.035), P(c.x, c.y - 12)), 0x5A3E2B, 1.2)
            ctx.paint(E(c.x - 13, c.y - 12, 26, 26), light.primary)
            ctx.stroke(line(P(c.x - 12, c.y), P(c.x + 12, c.y)), light.secondary, 1)
        case .lamp:
            let base = P(w * 0.93, h * 0.97)
            ctx.fill(Path(ellipseIn: R(base.x - 70, h * 0.3, 120, 140)), with: .radialGradient(Gradient(colors: [Color(hex: 0xFFE3A3, opacity: 0.4), .clear]), center: P(base.x - 10, h * 0.42), startRadius: 0, endRadius: 70))
            ctx.stroke(line(P(base.x, base.y), P(base.x, h * 0.46)), light.primary, 3)
            ctx.paint(E(base.x - 12, base.y - 5, 24, 8), light.primary)
            ctx.paint(polygon([P(base.x - 16, h * 0.46), P(base.x + 16, h * 0.46), P(base.x + 10, h * 0.37), P(base.x - 10, h * 0.37)]), light.secondary)
        case .fairyLights:
            var wire = Path()
            wire.move(to: P(0, h * 0.06))
            for i in 0..<4 {
                let x0 = w * CGFloat(i) / 4, x1 = w * CGFloat(i + 1) / 4
                wire.addQuadCurve(to: P(x1, h * 0.06), control: P((x0 + x1) / 2, h * 0.16))
            }
            ctx.stroke(wire, light.secondary, 1)
            for i in 0..<20 {
                let t = CGFloat(i) / 19
                let local = (t * 4).truncatingRemainder(dividingBy: 1)
                let y = h * 0.06 + h * 0.05 * 4 * local * (1 - local) * 0.5
                let p = P(w * t, y + 2)
                ctx.fill(Path(ellipseIn: R(p.x - 7, p.y - 7, 14, 14)), with: .radialGradient(Gradient(colors: [Color(hex: light.primary, opacity: 0.6), .clear]), center: p, startRadius: 0, endRadius: 7))
                ctx.fill(E(p.x - 2, p.y - 2, 4, 5), light.primary)
            }
        default:
            break
        }
    }

    // MARK: Foreground: counter, register, keepsake

    static func drawCounter(_ look: ShopLook, size: CGSize, context ctx: GraphicsContext) {
        let w = size.width, h = size.height
        let style = look.decor[.counter]
        let wood = style?.primary ?? 0xB88552
        let trim = style?.secondary ?? 0x8A6142
        let top = R(w * 0.14, h * 0.72, w * 0.72, h * 0.045)
        let body = R(w * 0.17, top.maxY, w * 0.66, h * 0.2)
        ctx.fill(E(body.minX, body.maxY - 6, body.width, 14), 0x3B2A20, 0.18)
        ctx.paint(Path(body), Hex.darker(wood, 0.08))
        for i in 0..<3 {
            let panel = R(body.minX + body.width * (0.05 + CGFloat(i) * 0.315), body.minY + body.height * 0.18, body.width * 0.27, body.height * 0.64)
            ctx.stroke(RR(panel.minX, panel.minY, panel.width, panel.height, 4), Hex.darker(wood, 0.3), 1.5, 0.7)
            if style?.pattern == .carved {
                ctx.fill(E(panel.midX - 5, panel.midY - 6, 10, 12), trim)
                ctx.fill(RR(panel.midX - 6, panel.midY - 9, 12, 5, 2), Hex.darker(trim, 0.3))
            }
        }
        ctx.paint(RR(top.minX, top.minY, top.width, top.height, 4), wood)
        ctx.fill(Path(R(top.minX + 4, top.minY + 2, top.width - 8, 2)), 0xFFFFFF, 0.25)

        // Register
        let reg = R(w * 0.2, h * 0.63, w * 0.14, h * 0.09)
        ctx.paint(RR(reg.minX, reg.minY + reg.height * 0.35, reg.width, reg.height * 0.65, 4), 0xB08A3E)
        ctx.paint(polygon([P(reg.minX + reg.width * 0.1, reg.minY + reg.height * 0.38), P(reg.maxX - reg.width * 0.1, reg.minY + reg.height * 0.38), P(reg.maxX - reg.width * 0.2, reg.minY), P(reg.minX + reg.width * 0.2, reg.minY)]), 0xD4A84B)
        ctx.fill(RR(reg.minX + reg.width * 0.3, reg.minY + reg.height * 0.08, reg.width * 0.4, reg.height * 0.18, 2), 0x3B3550)
        // Little bell
        ctx.paint(Path { p in
            let b = P(w * 0.4, h * 0.705)
            p.move(to: P(b.x - 8, b.y)); p.addQuadCurve(to: P(b.x + 8, b.y), control: P(b.x, b.y - 18)); p.closeSubpath()
        }, 0xD4A84B)

        // Keepsake on the counter
        if let keepsake = look.decor[.collectible] {
            drawKeepsake(keepsake, rect: R(w * 0.68, h * 0.64, w * 0.1, h * 0.085), context: ctx)
        }
    }

    static func drawKeepsake(_ deco: DecorationDef, rect: CGRect, context: GraphicsContext) {
        let ctx = context.unit(rect)
        switch deco.pattern {
        case .cloverJar:
            ctx.paint(RR(22, 20, 56, 76, 14), deco.secondary)
            ctx.paint(RR(26, 10, 48, 12, 3), 0x8A6142)
            for (x, y) in [(40.0, 50.0), (58, 60), (46, 72)] {
                for i in 0..<4 {
                    let a = Double(i) * .pi / 2
                    ctx.fill(E(x + CGFloat(cos(a)) * 5 - 5, y + CGFloat(sin(a)) * 5 - 5, 10, 10), deco.primary)
                }
            }
        case .compass:
            ctx.paint(E(10, 20, 80, 76), deco.primary)
            ctx.paint(E(20, 30, 60, 56), deco.secondary)
            ctx.fill(polygon([P(50, 34), P(56, 58), P(50, 82), P(44, 58)]), 0xC0392B)
            ctx.fill(E(46, 54, 8, 8), deco.primary)
        case .teacup:
            ctx.paint(E(10, 80, 80, 14), deco.primary)
            ctx.stroke(E(70, 46, 22, 24), deco.primary, 6)
            ctx.paint(Path { p in p.move(to: P(18, 40)); p.addLine(to: P(82, 40)); p.addQuadCurve(to: P(18, 40), control: P(50, 112)) }, deco.primary)
            ctx.fill(E(30, 40, 40, 8), deco.secondary)
        case .painting:
            ctx.paint(RR(10, 10, 80, 86, 4), 0xD4A84B)
            ctx.fill(Path(R(20, 20, 60, 66)), deco.secondary)
            drawFlower(ctx, center: P(50, 50), radius: 16, petal: deco.primary, middle: 0xF2D27C)
        default:
            ctx.paint(E(20, 20, 60, 70), deco.primary)
        }
    }
}

/// The illustrated shop interior with an optional customer standing behind the counter.
struct ShopSceneView<Customer: View>: View {
    let look: ShopLook
    @ViewBuilder var customer: Customer

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    ShopArtist.drawBackdrop(look, size: size, context: context)
                }
                customer
                    .frame(width: geo.size.width * 0.36, height: geo.size.height * 0.5)
                    .position(x: geo.size.width * 0.5, y: geo.size.height * 0.56)
                Canvas { context, size in
                    ShopArtist.drawCounter(look, size: size, context: context)
                }
                .allowsHitTesting(false)
            }
        }
    }
}
