import SwiftUI
import ShopCore

// Shared helpers for the procedural, original illustrations. Most art is authored in a
// 100 × 100 unit box and scaled into place with `GraphicsContext.unit(_:)`.

extension GraphicsContext {
    func fill(_ path: Path, _ hex: UInt32, _ opacity: Double = 1) {
        fill(path, with: .color(Color(hex: hex, opacity: opacity)))
    }

    func stroke(_ path: Path, _ hex: UInt32, _ width: CGFloat, _ opacity: Double = 1) {
        stroke(path, with: .color(Color(hex: hex, opacity: opacity)),
               style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    /// Fills and outlines a shape in the game's soft ink style.
    func paint(_ path: Path, _ hex: UInt32, outline: UInt32? = nil, width: CGFloat = 1.6) {
        fill(path, hex)
        stroke(path, outline ?? Hex.darker(hex, 0.45), width, 0.85)
    }

    /// A copy of the context mapped so that (0,0)-(100,100) covers `rect`.
    func unit(_ rect: CGRect) -> GraphicsContext {
        var c = self
        c.translateBy(x: rect.minX, y: rect.minY)
        c.scaleBy(x: rect.width / 100, y: rect.height / 100)
        return c
    }
}

func R(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: x, y: y, width: w, height: h) }
func E(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path { Path(ellipseIn: R(x, y, w, h)) }
func RR(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> Path {
    Path(roundedRect: R(x, y, w, h), cornerRadius: r, style: .continuous)
}
func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

func polygon(_ points: [CGPoint]) -> Path {
    var path = Path()
    guard let first = points.first else { return path }
    path.move(to: first)
    for point in points.dropFirst() { path.addLine(to: point) }
    path.closeSubpath()
    return path
}

func line(_ a: CGPoint, _ b: CGPoint) -> Path {
    var path = Path()
    path.move(to: a)
    path.addLine(to: b)
    return path
}

/// Five-pointed star centered at `c`.
func star(_ c: CGPoint, _ outer: CGFloat, _ inner: CGFloat) -> Path {
    var points: [CGPoint] = []
    for i in 0..<10 {
        let r = i.isMultiple(of: 2) ? outer : inner
        let a = Double(i) * .pi / 5 - .pi / 2
        points.append(P(c.x + CGFloat(cos(a)) * r, c.y + CGFloat(sin(a)) * r))
    }
    return polygon(points)
}

/// Simple five-petal flower used by several illustrations.
func drawFlower(_ ctx: GraphicsContext, center c: CGPoint, radius r: CGFloat, petal: UInt32, middle: UInt32) {
    for i in 0..<5 {
        let a = Double(i) * 2 * .pi / 5
        let px = c.x + CGFloat(cos(a)) * r * 0.62
        let py = c.y + CGFloat(sin(a)) * r * 0.62
        ctx.fill(E(px - r * 0.5, py - r * 0.5, r, r), petal)
    }
    ctx.fill(E(c.x - r * 0.42, c.y - r * 0.42, r * 0.84, r * 0.84), middle)
}

// MARK: - Products

enum ProductArtist {
    static let kraft: UInt32 = 0xC9A27A

    static func draw(_ art: ProductArt, in rect: CGRect, context: GraphicsContext, faded: Bool = false) {
        var ctx = context.unit(rect)
        if faded { ctx.opacity = 0.35 }
        ctx.fill(E(18, 86, 64, 10), 0x5A3E2B, 0.14)
        let a = art.primary, b = art.secondary, c = art.accent
        switch art.shape {
        case .bun:
            ctx.paint(E(16, 40, 68, 48), a)
            ctx.fill(E(22, 40, 56, 26), b)
            ctx.stroke(line(P(34, 50), P(66, 50)), Hex.lighter(b, 0.5), 2.5)
            ctx.fill(E(30, 44, 12, 6), 0xFFFFFF, 0.5)
            ctx.stroke(Path { p in p.move(to: P(28, 60)); p.addQuadCurve(to: P(72, 60), control: P(50, 52)) }, c, 1.5, 0.4)
        case .cookie:
            ctx.paint(E(18, 30, 64, 58), a)
            ctx.paint(Path { p in
                p.move(to: P(20, 52)); p.addQuadCurve(to: P(80, 52), control: P(50, 18)); p.closeSubpath()
            }, b)
            for (x, y) in [(36.0, 64.0), (54, 70), (62, 60), (44, 76), (30, 72)] { ctx.fill(E(x, y, 6, 5), b) }
            ctx.fill(RR(47, 24, 6, 10, 2), b)
        case .loaf:
            ctx.paint(RR(12, 44, 76, 40, 14), a)
            ctx.paint(E(12, 32, 76, 34), Hex.lighter(a, 0.15))
            for x in [30.0, 46, 62] {
                ctx.stroke(Path { p in p.move(to: P(x, 38)); p.addQuadCurve(to: P(x + 8, 58), control: P(x + 10, 44)) }, b, 3)
            }
            ctx.fill(E(28, 36, 16, 6), c, 0.5)
        case .tart:
            ctx.paint(polygon([P(14, 56), P(86, 56), P(78, 84), P(22, 84)]), b)
            for x in stride(from: 20.0, through: 76, by: 8) { ctx.stroke(line(P(x + 2, 60), P(x, 82)), Hex.darker(b, 0.25), 1.2) }
            ctx.paint(E(14, 44, 72, 22), a)
            ctx.fill(E(40, 42, 20, 12), c)
            ctx.fill(E(46, 38, 10, 8), c)
        case .tin:
            ctx.paint(RR(26, 28, 48, 60, 6), a)
            ctx.paint(RR(23, 20, 54, 14, 4), Hex.darker(a, 0.2))
            ctx.paint(RR(31, 44, 38, 28, 5), b)
            ctx.fill(Path { p in p.move(to: P(50, 50)); p.addQuadCurve(to: P(50, 66), control: P(60, 58)); p.addQuadCurve(to: P(50, 50), control: P(40, 58)) }, c)
        case .bottle:
            ctx.paint(RR(29, 40, 42, 48, 12), a)
            ctx.paint(RR(42, 18, 16, 28, 4), Hex.lighter(a, 0.1))
            ctx.paint(RR(42, 10, 16, 10, 3), 0xB08A5B)
            ctx.paint(RR(33, 56, 34, 20, 4), b)
            ctx.fill(RR(33, 50, 34, 4, 2), c)
            ctx.fill(RR(34, 44, 6, 30, 3), 0xFFFFFF, 0.25)
        case .bouquet:
            for (x1, x2) in [(38.0, 30.0), (50, 50), (62, 70)] { ctx.stroke(line(P(50, 82), P(x2, 34 + abs(x1 - 50) * 0.3)), c, 3) }
            ctx.fill(E(24, 40, 18, 10), c)
            ctx.fill(E(60, 42, 18, 10), c)
            drawFlower(ctx, center: P(32, 34), radius: 14, petal: a, middle: b)
            drawFlower(ctx, center: P(68, 34), radius: 14, petal: a, middle: b)
            drawFlower(ctx, center: P(50, 24), radius: 16, petal: a, middle: b)
            ctx.paint(polygon([P(28, 50), P(72, 50), P(56, 92), P(44, 92)]), kraft)
            ctx.fill(RR(40, 62, 20, 6, 3), Hex.darker(b, 0.1))
        case .pottedPlant:
            ctx.stroke(line(P(50, 60), P(50, 28)), c, 3)
            ctx.fill(Path { p in p.move(to: P(50, 60)); p.addQuadCurve(to: P(28, 40), control: P(30, 58)); p.addQuadCurve(to: P(50, 60), control: P(44, 44)) }, c)
            ctx.fill(Path { p in p.move(to: P(50, 58)); p.addQuadCurve(to: P(74, 38), control: P(72, 56)); p.addQuadCurve(to: P(50, 58), control: P(56, 42)) }, c)
            ctx.paint(Path { p in p.move(to: P(40, 30)); p.addQuadCurve(to: P(60, 30), control: P(50, 6)); p.addQuadCurve(to: P(40, 30), control: P(50, 36)) }, a)
            ctx.fill(E(45, 20, 10, 8), Hex.lighter(a, 0.3))
            ctx.paint(polygon([P(28, 60), P(72, 60), P(66, 90), P(34, 90)]), b)
            ctx.paint(RR(25, 56, 50, 10, 3), Hex.darker(b, 0.12))
        case .seeds:
            ctx.paint(RR(26, 16, 48, 72, 4), a)
            ctx.paint(RR(32, 24, 36, 32, 4), 0xFFFFFF)
            drawFlower(ctx, center: P(42, 38), radius: 8, petal: b, middle: 0xF2D27C)
            drawFlower(ctx, center: P(58, 44), radius: 7, petal: Hex.lighter(b, 0.3), middle: 0xF2D27C)
            ctx.fill(RR(32, 62, 36, 4, 2), c)
            ctx.fill(RR(32, 70, 24, 4, 2), c, 0.6)
        case .notebook:
            ctx.paint(RR(24, 16, 54, 72, 5), a)
            ctx.fill(RR(72, 18, 5, 68, 2), b)
            ctx.fill(Path { p in p.move(to: P(50, 34)); p.addQuadCurve(to: P(50, 64), control: P(68, 48)); p.addQuadCurve(to: P(50, 34), control: P(32, 48)) }, Hex.lighter(a, 0.3))
            ctx.stroke(line(P(50, 36), P(50, 66)), Hex.darker(a, 0.2), 1.5)
            ctx.fill(RR(64, 16, 4, 72, 1), c)
        case .pen:
            ctx.paint(RR(20, 64, 26, 24, 6), 0x3B3550)
            ctx.fill(RR(24, 60, 18, 6, 2), Hex.lighter(0x3B3550, 0.2))
            ctx.paint(Path { p in
                p.move(to: P(36, 66))
                p.addQuadCurve(to: P(80, 10), control: P(44, 22))
                p.addQuadCurve(to: P(40, 66), control: P(82, 40))
                p.closeSubpath()
            }, a)
            ctx.stroke(Path { p in p.move(to: P(38, 64)); p.addQuadCurve(to: P(78, 14), control: P(56, 30)) }, Hex.darker(a, 0.3), 1.5)
            ctx.fill(polygon([P(34, 62), P(40, 66), P(36, 72)]), b)
        case .card:
            var tilted = ctx
            tilted.translateBy(x: 50, y: 52)
            tilted.rotate(by: .degrees(-6))
            tilted.translateBy(x: -50, y: -52)
            tilted.paint(RR(22, 18, 56, 68, 4), a)
            tilted.stroke(line(P(50, 74), P(50, 46)), c, 2)
            tilted.fill(E(42, 56, 10, 6), c)
            drawFlower(tilted, center: P(50, 40), radius: 12, petal: b, middle: 0xF2D27C)
        case .book:
            ctx.paint(RR(22, 14, 58, 74, 4), a)
            ctx.fill(RR(74, 18, 6, 66, 2), b)
            ctx.fill(RR(22, 14, 8, 74, 3), Hex.darker(a, 0.25))
            ctx.paint(RR(36, 28, 32, 12, 3), b)
            ctx.fill(star(P(52, 60), 10, 4.5), c)
        case .candle:
            ctx.paint(E(24, 78, 52, 12), c)
            ctx.paint(RR(36, 36, 28, 48, 4), a)
            ctx.fill(Path { p in p.move(to: P(36, 40)); p.addQuadCurve(to: P(44, 52), control: P(38, 52)); p.addQuadCurve(to: P(50, 40), control: P(48, 46)) }, Hex.lighter(a, 0.25))
            ctx.stroke(line(P(50, 36), P(50, 30)), 0x3B3550, 1.5)
            ctx.fill(Path { p in p.move(to: P(50, 10)); p.addQuadCurve(to: P(50, 31), control: P(62, 26)); p.addQuadCurve(to: P(50, 10), control: P(38, 26)) }, b)
            ctx.fill(E(46, 21, 8, 10), 0xFFF2C4)
        case .mug:
            ctx.stroke(E(62, 44, 22, 26), Hex.darker(a, 0.15), 6)
            ctx.paint(RR(24, 34, 44, 52, 10), a)
            ctx.fill(RR(24, 34, 44, 12, 6), b)
            ctx.fill(RR(30, 50, 6, 28, 3), 0xFFFFFF, 0.22)
            for x in [38.0, 50] {
                ctx.stroke(Path { p in p.move(to: P(x, 28)); p.addQuadCurve(to: P(x, 12), control: P(x + 6, 20)) }, 0xFFFFFF, 2.5, 0.8)
            }
        case .teapot:
            ctx.paint(Path { p in p.move(to: P(26, 56)); p.addQuadCurve(to: P(8, 38), control: P(12, 54)); p.addLine(to: P(14, 36)); p.addQuadCurve(to: P(30, 50), control: P(20, 48)) }, a)
            ctx.stroke(E(66, 44, 22, 26), Hex.darker(a, 0.25), 5)
            ctx.paint(E(20, 36, 60, 50), a)
            ctx.paint(E(34, 30, 32, 12), Hex.darker(a, 0.05))
            ctx.paint(E(45, 22, 10, 10), c)
            for (x, y) in [(34.0, 52.0), (50, 58), (64, 50), (42, 70), (58, 72)] { ctx.fill(E(x, y, 7, 7), b) }
            ctx.stroke(Path { p in p.move(to: P(26, 46)); p.addQuadCurve(to: P(74, 46), control: P(50, 40)) }, c, 2)
        case .soap:
            ctx.paint(RR(20, 42, 60, 36, 12), a)
            ctx.fill(RR(42, 42, 16, 36, 2), b)
            drawFlower(ctx, center: P(50, 60), radius: 7, petal: c, middle: 0xFFF6E5)
            ctx.fill(E(28, 46, 10, 5), 0xFFFFFF, 0.4)
        case .scarf:
            ctx.paint(RR(18, 30, 64, 26, 10), a)
            ctx.paint(RR(52, 44, 22, 42, 6), a)
            for y in [36.0, 46] { ctx.fill(RR(18, y, 64, 4, 2), b) }
            for y in [56.0, 66, 76] { ctx.fill(RR(52, y, 22, 4, 2), b) }
            for x in stride(from: 54.0, through: 72, by: 4) { ctx.stroke(line(P(x, 86), P(x, 92)), c, 1.6) }
        case .musicBox:
            ctx.paint(RR(20, 46, 60, 40, 6), a)
            ctx.paint(RR(18, 36, 64, 14, 5), Hex.darker(a, 0.15))
            ctx.fill(RR(44, 40, 12, 6, 2), b)
            ctx.stroke(Path { p in p.move(to: P(80, 66)); p.addLine(to: P(90, 66)); p.addLine(to: P(90, 58)) }, b, 3)
            for (x, y) in [(30.0, 22.0), (60, 14)] {
                ctx.fill(E(x, y + 10, 8, 6), c)
                ctx.stroke(line(P(x + 7.5, y + 12), P(x + 7.5, y)), c, 1.8)
            }
            drawFlower(ctx, center: P(50, 66), radius: 8, petal: Hex.lighter(a, 0.35), middle: b)
        case .lantern:
            ctx.stroke(E(40, 6, 20, 18), c, 2.5)
            ctx.paint(polygon([P(30, 30), P(70, 30), P(60, 18), P(40, 18)]), Hex.darker(a, 0.1))
            ctx.paint(RR(30, 30, 40, 50, 8), a)
            ctx.fill(RR(36, 36, 28, 38, 6), b)
            for (x, y, s) in [(44.0, 46.0, 4.0), (56, 52, 3), (48, 62, 3.5), (58, 66, 2.5)] { ctx.fill(star(P(x, y), s, s * 0.45), 0xFFFFFF) }
            ctx.paint(RR(28, 78, 44, 8, 3), Hex.darker(a, 0.1))
        }
    }
}

/// A product illustration as a SwiftUI view.
struct ProductIcon: View {
    let product: ProductDef
    var size: CGFloat = 44
    var faded = false

    var body: some View {
        Canvas { context, canvasSize in
            ProductArtist.draw(product.art, in: CGRect(origin: .zero, size: canvasSize), context: context, faded: faded)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(product.name)
    }
}
