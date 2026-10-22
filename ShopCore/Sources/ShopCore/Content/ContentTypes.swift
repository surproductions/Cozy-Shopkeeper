import Foundation

// MARK: - Products

public enum ProductCategory: String, Codable, CaseIterable, Sendable {
    case food, beverage, flowers, stationery, books, crafts, gifts, seasonal

    public var displayName: String {
        switch self {
        case .food: return "Baked Goods"
        case .beverage: return "Drinks"
        case .flowers: return "Flowers"
        case .stationery: return "Stationery"
        case .books: return "Books"
        case .crafts: return "Crafts"
        case .gifts: return "Gifts"
        case .seasonal: return "Seasonal"
        }
    }
}

public enum Rarity: String, Codable, CaseIterable, Sendable {
    case common, uncommon, rare

    public var displayName: String { rawValue.capitalized }
}

/// Shape family used by the procedural product illustrations in the app.
public enum ProductShape: String, Codable, CaseIterable, Sendable {
    case bun, cookie, loaf, tart, tin, bottle, bouquet, pottedPlant, seeds
    case notebook, pen, card, book, candle, mug, teapot, soap, scarf, musicBox, lantern
}

/// Colors are stored as 0xRRGGBB so the core stays UI-framework free.
public struct ProductArt: Codable, Equatable, Sendable {
    public let shape: ProductShape
    public let primary: UInt32
    public let secondary: UInt32
    public let accent: UInt32

    public init(_ shape: ProductShape, _ primary: UInt32, _ secondary: UInt32, _ accent: UInt32) {
        self.shape = shape
        self.primary = primary
        self.secondary = secondary
        self.accent = accent
    }
}

public struct ProductDef: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let blurb: String
    public let category: ProductCategory
    public let rarity: Rarity
    /// Shelf tier required (1 = starter shelves, raised by the shelves upgrade).
    public let tier: Int
    /// Wholesale cost of one unit before discounts.
    public let unitCost: Int
    /// The fair price customers expect.
    public let recommendedPrice: Int
    /// District that must be unlocked to stock this product (nil = available everywhere).
    public let district: String?
    public let art: ProductArt
}

// MARK: - Customers

public enum CustomerArchetype: String, Codable, CaseIterable, Sendable {
    case shopper, regular, collector, bargainHunter, giftBuyer, vip, scholar, traveler

    public var displayName: String {
        switch self {
        case .shopper: return "Shopper"
        case .regular: return "Neighbor"
        case .collector: return "Collector"
        case .bargainHunter: return "Bargain Hunter"
        case .giftBuyer: return "Gift Buyer"
        case .vip: return "VIP Visitor"
        case .scholar: return "Scholar"
        case .traveler: return "Traveler"
        }
    }
}

public enum InteractionStyle: String, Codable, Sendable {
    case chatty, shy, brisk, warm, grand

    public var displayName: String { rawValue.capitalized }
}

public enum HairStyle: String, Codable, Sendable { case bun, short, long, curly, braid, bald, spiky }
public enum HatStyle: String, Codable, Sendable { case none, beret, topHat, sunHat, captain, flowerCrown, beanie, scholarCap }
public enum Accessory: String, Codable, Sendable { case none, glasses, monocle, scarf, apron, satchel, bowtie, earrings }

public struct CustomerLook: Codable, Equatable, Sendable {
    public let skin: UInt32
    public let hair: UInt32
    public let hairStyle: HairStyle
    public let outfit: UInt32
    public let outfitTrim: UInt32
    public let hat: HatStyle
    public let hatColor: UInt32
    public let accessory: Accessory

    public init(skin: UInt32, hair: UInt32, hairStyle: HairStyle, outfit: UInt32, outfitTrim: UInt32,
                hat: HatStyle, hatColor: UInt32, accessory: Accessory) {
        self.skin = skin
        self.hair = hair
        self.hairStyle = hairStyle
        self.outfit = outfit
        self.outfitTrim = outfitTrim
        self.hat = hat
        self.hatColor = hatColor
        self.accessory = accessory
    }
}

public struct CustomerDef: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let archetype: CustomerArchetype
    public let bio: String
    public let favorites: [ProductCategory]
    /// Multiplier on the recommended price that this customer will still pay.
    public let priceTolerance: Double
    /// Fraction of the sale they tip when delighted.
    public let tipRate: Double
    /// Chance (0...1) they ask for more than one unit.
    public let bulkChance: Double
    /// Chance (0...1) they ask for gift wrapping.
    public let giftWrapChance: Double
    /// Collectors prefer uncommon / rare goods.
    public let prefersRare: Bool
    public let style: InteractionStyle
    public let minReputationLevel: Int
    /// District this customer lives in (nil = visits any shop).
    public let district: String?
    public let spawnWeight: Double
    public let look: CustomerLook
    /// Decoration gifted when the relationship is maxed out (optional).
    public let heartGiftDecoration: String?
    public let greetings: [String]

    public var priceSensitivityLabel: String {
        switch priceTolerance {
        case ..<1.1: return "Watches every coin"
        case ..<1.3: return "Likes a fair price"
        case ..<1.55: return "Happy to pay for quality"
        default: return "Money is no object"
        }
    }
}

// MARK: - Upgrades

public enum UpgradeEffect: String, Codable, Sendable {
    case productTier        // value = highest product tier unlocked
    case stockCapacity      // value = max units per product
    case tipBonus           // value = extra tip fraction
    case restockDiscount    // value = discount fraction
    case customersPerDay    // value = customers per shop day
    case giftWrap           // value = 1 when available
    case reputationBonus    // value = extra reputation fraction
}

public struct UpgradeDef: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let summary: String
    public let symbol: String
    public let effect: UpgradeEffect
    /// Effect value at each level; index 0 is the un-upgraded value.
    public let values: [Double]
    /// Cost to go from level i to level i+1.
    public let costs: [Int]

    public var maxLevel: Int { costs.count }

    public func value(at level: Int) -> Double {
        values[max(0, min(level, values.count - 1))]
    }

    public func describe(level: Int) -> String {
        let v = value(at: level)
        switch effect {
        case .productTier: return "Product tier \(Int(v)) of 4"
        case .stockCapacity: return "\(Int(v)) units per product"
        case .tipBonus: return v == 0 ? "Standard tips" : "+\(Int((v * 100).rounded()))% tips"
        case .restockDiscount: return v == 0 ? "Standard wholesale prices" : "\(Int((v * 100).rounded()))% off restocking"
        case .customersPerDay: return "\(Int(v)) customers each day"
        case .giftWrap: return v == 0 ? "No gift wrapping" : "Gift wrapping for delighted gift buyers"
        case .reputationBonus: return v == 0 ? "Standard reputation" : "+\(Int((v * 100).rounded()))% reputation"
        }
    }
}

// MARK: - Decorations

public enum DecorSlot: String, Codable, CaseIterable, Sendable {
    case wallpaper, floor, counter, shelves, plant, lighting, rug, wallArt, seasonal, collectible

    public var displayName: String {
        switch self {
        case .wallpaper: return "Walls"
        case .floor: return "Floor"
        case .counter: return "Counter"
        case .shelves: return "Shelves"
        case .plant: return "Plants"
        case .lighting: return "Lighting"
        case .rug: return "Rugs"
        case .wallArt: return "Wall Art"
        case .seasonal: return "Seasonal"
        case .collectible: return "Keepsakes"
        }
    }

    /// Slots that always have something equipped.
    public var isRequired: Bool {
        switch self {
        case .wallpaper, .floor, .counter, .shelves: return true
        default: return false
        }
    }
}

public enum DecorPattern: String, Codable, Sendable {
    case plain, stripes, vines, stars, boards, checker, herringbone, solid, carved, glass
    case fern, monstera, ivy, lantern, lamp, fairyLights, wovenRug, sunRug
    case sign, painting, tapestry, garland, wreath, cloverJar, compass, teacup
}

public struct DecorationDef: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let slot: DecorSlot
    /// Coin price; nil = cannot be bought (reward-only).
    public let price: Int?
    public let coziness: Int
    public let pattern: DecorPattern
    public let primary: UInt32
    public let secondary: UInt32
    public let isDefault: Bool
    public let flavor: String
}

// MARK: - Districts

public struct DistrictDef: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let tagline: String
    /// Whether this district can actually be entered in this build.
    public let isPlayable: Bool
    public let requiredReputationLevel: Int
    public let unlockCost: Int
    public let skyTop: UInt32
    public let skyBottom: UInt32
    public let accent: UInt32
    public let mapX: Double
    public let mapY: Double
}

// MARK: - Quests, achievements, collections, daily rewards

public enum QuestKind: Codable, Equatable, Sendable {
    case sellItems
    case sellCategory(ProductCategory)
    case earnCoins
    case receiveTips
    case serveRegulars
    case restockUnits
    case completeShopDays
    case delightCustomers
    case buyUpgrades
    case buyDecorations
    case discoverCustomers
}

public enum QuestGroup: String, Codable, Sendable { case selling, earning, shopkeeping }

public struct QuestDef: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let kind: QuestKind
    public let target: Int
    public let rewardCoins: Int
    public let group: QuestGroup
}

public enum AchievementCondition: Equatable, Sendable {
    case totalSales(Int)
    case daysCompleted(Int)
    case upgradesBought(Int)
    case decorationsBought(Int)
    case regulars(Int)
    case reputationLevel(Int)
    case lifetimeCoins(Int)
    case collectionsCompleted(Int)
    case districtUnlocked(String)
    case customersDiscovered(Int)
    case delightedSales(Int)
}

public struct AchievementDef: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let condition: AchievementCondition
    public let rewardCoins: Int
    public let isMilestone: Bool
}

public enum CollectionRequirement: Equatable, Sendable {
    case sellProducts([String])
    case ownDecorations([String])
    case discoverCustomers(Int)
}

public struct CollectionDef: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let requirement: CollectionRequirement
    public let rewardCoins: Int
    public let rewardDecoration: String?
}

public enum DailyRewardKind: Equatable, Sendable {
    case coins(Int)
    case decoration(String, fallbackCoins: Int)
    case reputation(Int)
}

public struct DailyRewardDef: Equatable, Sendable {
    public let day: Int
    public let kind: DailyRewardKind
}
