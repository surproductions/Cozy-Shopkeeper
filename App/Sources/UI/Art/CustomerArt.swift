import SwiftUI
import ShopCore

enum CustomerMood {
    case neutral, happy, delighted, hesitant, sad
}

/// Draws the original customer characters from their `CustomerLook` description.
/// Authored in a 100 × 120 box (scaled to fit).
enum CustomerArtist {
    static func draw(_ look: CustomerLook, mood: CustomerMood, in rect: CGRect, context: GraphicsContext) {
        // Map 100 × 120 design units into the rect, preserving aspect.
        let scale = min(rect.width / 100, rect.height / 120)
        var ctx = context
        ctx.translateBy(x: rect.midX - 50 * scale, y: rect.maxY - 120 * scale)
        ctx.scaleBy(x: scale, y: scale)

        let skin = look.skin
        let skinShade = Hex.darker(skin, 0.18)
        let hair = look.hair

        // Long hair & braids sit behind the head.
        switch look.hairStyle {
        case .long:
            ctx.paint(RR(22, 30, 56, 58, 22), hair)
        case .braid:
            ctx.paint(RR(26, 30, 48, 34, 18), hair)
            for i in 0..<4 { ctx.paint(E(66, 58 + CGFloat(i) * 9, 12, 11), hair) }
        default:
            break
        }

        // Body and outfit
        ctx.paint(Path { p in
            p.move(to: P(14, 120))
            p.addLine(to: P(16, 98))
            p.addQuadCurve(to: P(36, 78), control: P(18, 80))
            p.addLine(to: P(64, 78))
            p.addQuadCurve(to: P(84, 98), control: P(82, 80))
            p.addLine(to: P(86, 120))
            p.closeSubpath()
        }, look.outfit)
        // Neck and collar
        ctx.fill(RR(43, 64, 14, 18, 5), skinShade)
        ctx.paint(polygon([P(38, 78), P(50, 92), P(62, 78), P(56, 76), P(50, 84), P(44, 76)]), look.outfitTrim)

        switch look.accessory {
        case .apron:
            ctx.paint(RR(34, 92, 32, 30, 6), look.outfitTrim)
            ctx.fill(RR(42, 100, 16, 8, 3), Hex.darker(look.outfitTrim, 0.1))
        case .satchel:
            ctx.stroke(line(P(36, 79), P(72, 112)), 0x6B4A31, 4)
            ctx.paint(RR(64, 102, 18, 16, 4), 0x8A6142)
        case .scarf:
            ctx.paint(RR(34, 72, 32, 12, 6), look.outfitTrim)
            ctx.paint(RR(54, 78, 10, 22, 4), look.outfitTrim)
        case .bowtie:
            ctx.paint(polygon([P(50, 84), P(40, 78), P(40, 90)]), 0xC0392B)
            ctx.paint(polygon([P(50, 84), P(60, 78), P(60, 90)]), 0xC0392B)
        default:
            break
        }

        // Ears and head
        ctx.paint(E(23, 44, 10, 14), skin)
        ctx.paint(E(67, 44, 10, 14), skin)
        ctx.paint(E(26, 22, 48, 50), skin)

        // Front hair
        switch look.hairStyle {
        case .short:
            ctx.paint(Path { p in
                p.move(to: P(26, 44)); p.addQuadCurve(to: P(74, 44), control: P(50, 6))
                p.addQuadCurve(to: P(50, 32), control: P(62, 30)); p.addQuadCurve(to: P(26, 44), control: P(34, 30))
            }, hair)
        case .bun:
            ctx.paint(E(38, 6, 24, 20), hair)
            ctx.paint(Path { p in
                p.move(to: P(26, 46)); p.addQuadCurve(to: P(74, 46), control: P(50, 4))
                p.addQuadCurve(to: P(26, 46), control: P(50, 28))
            }, hair)
        case .curly:
            for (x, y) in [(22.0, 32.0), (30, 20), (42, 14), (56, 14), (66, 20), (72, 32), (24, 44), (70, 44)] {
                ctx.paint(E(x - 4, y - 4, 16, 16), hair)
            }
        case .spiky:
            ctx.paint(polygon([P(26, 44), P(28, 26), P(34, 30), P(38, 14), P(46, 24), P(52, 10), P(58, 24), P(66, 14), P(68, 30), P(74, 28), P(74, 44), P(50, 32)]), hair)
        case .long:
            ctx.paint(Path { p in
                p.move(to: P(26, 50)); p.addQuadCurve(to: P(74, 50), control: P(50, 2))
                p.addQuadCurve(to: P(50, 30), control: P(66, 30)); p.addQuadCurve(to: P(26, 50), control: P(34, 30))
            }, hair)
        case .braid:
            ctx.paint(Path { p in
                p.move(to: P(26, 46)); p.addQuadCurve(to: P(74, 46), control: P(50, 4))
                p.addQuadCurve(to: P(26, 46), control: P(44, 28))
            }, hair)
        case .bald:
            ctx.paint(E(24, 38, 10, 14), hair)
            ctx.paint(E(66, 38, 10, 14), hair)
        }

        // Face
        let eyeColor: UInt32 = 0x3B2A20
        switch mood {
        case .delighted:
            for x in [38.0, 58] {
                ctx.stroke(Path { p in p.move(to: P(x - 4, 50)); p.addQuadCurve(to: P(x + 4, 50), control: P(x, 44)) }, eyeColor, 2.2)
            }
        case .sad:
            for x in [38.0, 58] { ctx.fill(E(x - 2.5, 48, 5, 5.5), eyeColor) }
            ctx.stroke(line(P(33, 43), P(41, 41)), eyeColor, 1.6)
            ctx.stroke(line(P(59, 41), P(67, 43)), eyeColor, 1.6)
        default:
            for x in [38.0, 58] {
                ctx.fill(E(x - 2.8, 46, 5.6, 6.5), eyeColor)
                ctx.fill(E(x - 1, 47, 2, 2), 0xFFFFFF)
            }
        }
        ctx.fill(E(30, 54, 9, 5), 0xE58A8A, mood == .sad ? 0.25 : 0.55)
        ctx.fill(E(61, 54, 9, 5), 0xE58A8A, mood == .sad ? 0.25 : 0.55)
        switch mood {
        case .delighted:
            ctx.paint(Path { p in p.move(to: P(42, 58)); p.addQuadCurve(to: P(58, 58), control: P(50, 70)); p.closeSubpath() }, 0x8A3B3B, outline: 0x5A2A20, width: 1.2)
        case .happy, .neutral:
            ctx.stroke(Path { p in p.move(to: P(43, 59)); p.addQuadCurve(to: P(57, 59), control: P(50, mood == .happy ? 66 : 63)) }, 0x5A2A20, 2)
        case .hesitant:
            ctx.stroke(Path { p in p.move(to: P(44, 61)); p.addQuadCurve(to: P(56, 60), control: P(50, 59)) }, 0x5A2A20, 2)
        case .sad:
            ctx.stroke(Path { p in p.move(to: P(44, 63)); p.addQuadCurve(to: P(56, 63), control: P(50, 57)) }, 0x5A2A20, 2)
        }

        // Face accessories
        switch look.accessory {
        case .glasses:
            ctx.stroke(E(31, 42, 14, 12), 0x3B3550, 1.8)
            ctx.stroke(E(51, 42, 14, 12), 0x3B3550, 1.8)
            ctx.stroke(line(P(45, 47), P(51, 47)), 0x3B3550, 1.8)
        case .monocle:
            ctx.stroke(E(51, 41, 15, 14), 0xD4A84B, 2)
            ctx.stroke(Path { p in p.move(to: P(64, 54)); p.addQuadCurve(to: P(70, 80), control: P(74, 64)) }, 0xD4A84B, 1)
        case .earrings:
            ctx.fill(E(25, 57, 5, 5), 0xD4A84B)
            ctx.fill(E(70, 57, 5, 5), 0xD4A84B)
        default:
            break
        }

        // Hats
        let hat = look.hatColor
        switch look.hat {
        case .none:
            break
        case .beret:
            ctx.paint(E(24, 14, 50, 20), hat)
            ctx.paint(E(47, 9, 6, 6), Hex.darker(hat, 0.2))
        case .topHat:
            ctx.paint(E(20, 24, 60, 10), hat)
            ctx.paint(RR(32, 0, 36, 28, 3), hat)
            ctx.fill(RR(32, 18, 36, 6, 1), 0xC0392B)
        case .sunHat:
            ctx.paint(E(10, 22, 80, 16), hat)
            ctx.paint(E(30, 10, 40, 24), hat)
            ctx.fill(RR(31, 24, 38, 5, 2), 0xD9898A)
        case .captain:
            ctx.paint(RR(28, 12, 44, 20, 8), 0xFFFFFF)
            ctx.paint(RR(26, 24, 48, 9, 3), hat)
            ctx.paint(E(30, 29, 32, 8), 0x2B2420)
            ctx.fill(E(46, 15, 8, 7), 0xD4A84B)
        case .flowerCrown:
            for i in 0..<5 {
                let x = 28 + CGFloat(i) * 11
                drawFlower(ctx, center: P(x, 24 - (i == 2 ? 2 : 0)), radius: 6, petal: i.isMultiple(of: 2) ? 0xE8A0BF : 0xFFFFFF, middle: hat)
            }
        case .beanie:
            ctx.paint(Path { p in p.move(to: P(25, 34)); p.addQuadCurve(to: P(75, 34), control: P(50, 0)); p.closeSubpath() }, hat)
            ctx.paint(RR(24, 28, 52, 9, 4), Hex.darker(hat, 0.15))
            ctx.paint(E(44, 4, 12, 10), Hex.lighter(hat, 0.3))
        case .scholarCap:
            ctx.paint(RR(32, 16, 36, 14, 4), hat)
            ctx.paint(polygon([P(18, 16), P(50, 6), P(82, 16), P(50, 24)]), hat)
            ctx.stroke(Path { p in p.move(to: P(50, 14)); p.addLine(to: P(76, 18)); p.addLine(to: P(76, 30)) }, 0xD4A84B, 1.6)
        }
    }
}

struct CustomerPortrait: View {
    let customer: CustomerDef
    var mood: CustomerMood = .neutral
    var size: CGFloat = 80
    var silhouette = false

    var body: some View {
        Canvas { context, canvasSize in
            var look = customer.look
            if silhouette {
                look = CustomerLook(skin: 0xC9B79C, hair: 0xB9A68A, hairStyle: look.hairStyle, outfit: 0xB9A68A, outfitTrim: 0xC9B79C,
                                    hat: look.hat, hatColor: 0xB9A68A, accessory: .none)
            }
            CustomerArtist.draw(look, mood: silhouette ? .neutral : mood, in: CGRect(origin: .zero, size: canvasSize), context: context)
        }
        .frame(width: size, height: size * 1.2)
        .accessibilityLabel(silhouette ? "Undiscovered customer" : customer.name)
    }
}
