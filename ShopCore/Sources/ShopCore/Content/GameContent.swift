import Foundation

/// All authored game content. Every name, character and description here is original.
public struct GameContent: Sendable {
    public let products: [ProductDef]
    public let customers: [CustomerDef]
    public let upgrades: [UpgradeDef]
    public let decorations: [DecorationDef]
    public let districts: [DistrictDef]
    public let quests: [QuestDef]
    public let achievements: [AchievementDef]
    public let collections: [CollectionDef]
    public let dailyRewards: [DailyRewardDef]

    private let productIndex: [String: ProductDef]
    private let customerIndex: [String: CustomerDef]
    private let upgradeIndex: [String: UpgradeDef]
    private let decorationIndex: [String: DecorationDef]
    private let districtIndex: [String: DistrictDef]
    private let questIndex: [String: QuestDef]

    public init(products: [ProductDef], customers: [CustomerDef], upgrades: [UpgradeDef],
                decorations: [DecorationDef], districts: [DistrictDef], quests: [QuestDef],
                achievements: [AchievementDef], collections: [CollectionDef], dailyRewards: [DailyRewardDef]) {
        self.products = products
        self.customers = customers
        self.upgrades = upgrades
        self.decorations = decorations
        self.districts = districts
        self.quests = quests
        self.achievements = achievements
        self.collections = collections
        self.dailyRewards = dailyRewards
        productIndex = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        customerIndex = Dictionary(uniqueKeysWithValues: customers.map { ($0.id, $0) })
        upgradeIndex = Dictionary(uniqueKeysWithValues: upgrades.map { ($0.id, $0) })
        decorationIndex = Dictionary(uniqueKeysWithValues: decorations.map { ($0.id, $0) })
        districtIndex = Dictionary(uniqueKeysWithValues: districts.map { ($0.id, $0) })
        questIndex = Dictionary(uniqueKeysWithValues: quests.map { ($0.id, $0) })
    }

    public func product(_ id: String) -> ProductDef? { productIndex[id] }
    public func customer(_ id: String) -> CustomerDef? { customerIndex[id] }
    public func upgrade(_ id: String) -> UpgradeDef? { upgradeIndex[id] }
    public func decoration(_ id: String) -> DecorationDef? { decorationIndex[id] }
    public func district(_ id: String) -> DistrictDef? { districtIndex[id] }
    public func quest(_ id: String) -> QuestDef? { questIndex[id] }
}

// MARK: - IDs used by game rules

public enum ContentIDs {
    public static let startingDistrict = "maple_corner"
    public static let secondDistrict = "flower_lane"
    public static let tutorialCustomer = "pip"
    public static let tutorialProduct = "honey_bun"
    public static let tutorialGiftDecoration = "potted_fern"

    public enum Upgrade {
        public static let shelves = "shelves"
        public static let stockroom = "stockroom"
        public static let checkout = "checkout"
        public static let supplier = "supplier"
        public static let window = "window"
        public static let giftWrap = "gift_wrap"
        public static let nook = "reading_nook"
    }
}

fileprivate enum Palette {
    static let cream: UInt32 = 0xFFF6E5
    static let parchment: UInt32 = 0xF3E6C8
    static let sage: UInt32 = 0x9CB38A
    static let deepSage: UInt32 = 0x6F8C5E
    static let teal: UInt32 = 0x5E9C9A
    static let deepTeal: UInt32 = 0x3F7372
    static let terracotta: UInt32 = 0xC96F4A
    static let gold: UInt32 = 0xD4A84B
    static let brown: UInt32 = 0x8A6142
    static let deepBrown: UInt32 = 0x5A3E2B
    static let rose: UInt32 = 0xD9898A
    static let plum: UInt32 = 0x8C5C7A
    static let sky: UInt32 = 0xA9CFE0
    static let butter: UInt32 = 0xF2D27C
    static let ink: UInt32 = 0x3B3550
}

public extension GameContent {
    static let standard: GameContent = GameContent(
        products: StandardContent.products,
        customers: StandardContent.customers,
        upgrades: StandardContent.upgrades,
        decorations: StandardContent.decorations,
        districts: StandardContent.districts,
        quests: StandardContent.quests,
        achievements: StandardContent.achievements,
        collections: StandardContent.collections,
        dailyRewards: StandardContent.dailyRewards
    )
}

enum StandardContent {
    fileprivate typealias P = Palette

    // MARK: Products (24)
    static let products: [ProductDef] = [
        // Tier 1 — starter shelves
        ProductDef(id: "honey_bun", name: "Honey Bun", blurb: "Soft, sticky and still warm from the oven.", category: .food, rarity: .common, tier: 1, unitCost: 4, recommendedPrice: 9, district: nil, art: ProductArt(.bun, 0xE3A857, 0xF6D58E, P.deepBrown)),
        ProductDef(id: "acorn_cookie", name: "Acorn Cookie", blurb: "A crunchy cookie shaped like an acorn cap.", category: .food, rarity: .common, tier: 1, unitCost: 3, recommendedPrice: 7, district: nil, art: ProductArt(.cookie, 0xC98E52, 0x7A4E2D, P.cream)),
        ProductDef(id: "chamomile_tin", name: "Chamomile Tea Tin", blurb: "Loose-leaf chamomile for sleepy evenings.", category: .beverage, rarity: .common, tier: 1, unitCost: 6, recommendedPrice: 13, district: nil, art: ProductArt(.tin, P.sage, P.butter, P.deepSage)),
        ProductDef(id: "berry_cordial", name: "Berry Cordial", blurb: "Bramble berries pressed into a bright syrup.", category: .beverage, rarity: .common, tier: 1, unitCost: 7, recommendedPrice: 15, district: nil, art: ProductArt(.bottle, 0xB04A6A, P.cream, P.gold)),
        ProductDef(id: "daisy_posy", name: "Daisy Posy", blurb: "A handful of daisies tied with twine.", category: .flowers, rarity: .common, tier: 1, unitCost: 5, recommendedPrice: 11, district: nil, art: ProductArt(.bouquet, 0xFFFFFF, P.butter, P.sage)),
        ProductDef(id: "leaf_notebook", name: "Leaf Notebook", blurb: "Pressed-leaf cover, creamy pages inside.", category: .stationery, rarity: .common, tier: 1, unitCost: 6, recommendedPrice: 12, district: nil, art: ProductArt(.notebook, P.deepSage, P.cream, P.gold)),
        ProductDef(id: "beeswax_candle", name: "Beeswax Candle", blurb: "Hand-dipped and faintly honey-scented.", category: .crafts, rarity: .common, tier: 1, unitCost: 8, recommendedPrice: 17, district: nil, art: ProductArt(.candle, P.butter, 0xFFB347, P.brown)),
        ProductDef(id: "clay_mug", name: "Clay Mug", blurb: "Thrown on a wheel, glazed in sea-glass teal.", category: .crafts, rarity: .common, tier: 1, unitCost: 9, recommendedPrice: 19, district: nil, art: ProductArt(.mug, P.teal, P.cream, P.deepTeal)),
        // Tier 2
        ProductDef(id: "cinnamon_loaf", name: "Cinnamon Loaf", blurb: "Swirled with cinnamon sugar and patience.", category: .food, rarity: .common, tier: 2, unitCost: 8, recommendedPrice: 17, district: nil, art: ProductArt(.loaf, 0xC58B4E, 0x8A5530, P.cream)),
        ProductDef(id: "lavender_soap", name: "Lavender Soap", blurb: "A creamy bar wrapped in pressed paper.", category: .gifts, rarity: .common, tier: 2, unitCost: 7, recommendedPrice: 15, district: nil, art: ProductArt(.soap, 0xB7A3D6, P.cream, P.plum)),
        ProductDef(id: "quill_pen", name: "Quill Pen", blurb: "A goose-feather quill with a brass nib.", category: .stationery, rarity: .common, tier: 2, unitCost: 10, recommendedPrice: 22, district: nil, art: ProductArt(.pen, P.cream, P.gold, P.ink)),
        ProductDef(id: "pocket_almanac", name: "Pocket Almanac", blurb: "Moon phases, planting days and old proverbs.", category: .books, rarity: .common, tier: 2, unitCost: 11, recommendedPrice: 23, district: nil, art: ProductArt(.book, P.terracotta, P.cream, P.gold)),
        ProductDef(id: "sunflower_bundle", name: "Sunflower Bundle", blurb: "Three tall sunflowers that follow you around the room.", category: .flowers, rarity: .common, tier: 2, unitCost: 9, recommendedPrice: 19, district: nil, art: ProductArt(.bouquet, 0xF5C542, 0x7A4E2D, P.sage)),
        ProductDef(id: "spiced_cider", name: "Spiced Cider", blurb: "Orchard cider with clove and orange peel.", category: .beverage, rarity: .common, tier: 2, unitCost: 8, recommendedPrice: 17, district: nil, art: ProductArt(.bottle, 0xD98B3A, P.parchment, P.deepBrown)),
        // Tier 3
        ProductDef(id: "fable_storybook", name: "Fable Storybook", blurb: "Twelve bedtime fables with painted plates.", category: .books, rarity: .uncommon, tier: 3, unitCost: 15, recommendedPrice: 32, district: nil, art: ProductArt(.book, P.deepTeal, P.cream, P.gold)),
        ProductDef(id: "knit_scarf", name: "Knit Scarf", blurb: "Chunky wool in autumn stripes.", category: .crafts, rarity: .uncommon, tier: 3, unitCost: 16, recommendedPrice: 34, district: nil, art: ProductArt(.scarf, P.terracotta, P.butter, P.deepSage)),
        ProductDef(id: "tin_music_box", name: "Tin Music Box", blurb: "Wind it up for a tiny waltz.", category: .gifts, rarity: .uncommon, tier: 3, unitCost: 20, recommendedPrice: 42, district: nil, art: ProductArt(.musicBox, P.rose, P.gold, P.deepBrown)),
        ProductDef(id: "pressed_flower_card", name: "Pressed Flower Card", blurb: "A greeting card with a real pressed violet.", category: .stationery, rarity: .common, tier: 3, unitCost: 6, recommendedPrice: 14, district: nil, art: ProductArt(.card, P.parchment, 0x9B7BC2, P.sage)),
        // Tier 4
        ProductDef(id: "pumpkin_tart", name: "Pumpkin Tart", blurb: "Spiced pumpkin custard in a fluted crust.", category: .seasonal, rarity: .common, tier: 4, unitCost: 10, recommendedPrice: 22, district: nil, art: ProductArt(.tart, 0xE08A3C, 0xD9A86B, P.cream)),
        ProductDef(id: "star_lantern", name: "Star Lantern", blurb: "Pierced tin that scatters stars across the ceiling.", category: .seasonal, rarity: .uncommon, tier: 4, unitCost: 18, recommendedPrice: 38, district: nil, art: ProductArt(.lantern, P.gold, 0xFFE9A8, P.deepBrown)),
        ProductDef(id: "atlas_of_isles", name: "Atlas of Isles", blurb: "Hand-drawn maps of islands that may not exist.", category: .books, rarity: .rare, tier: 4, unitCost: 25, recommendedPrice: 55, district: nil, art: ProductArt(.book, P.ink, P.parchment, P.gold)),
        ProductDef(id: "porcelain_teapot", name: "Porcelain Teapot", blurb: "Blue-and-cream porcelain, thin as an eggshell.", category: .gifts, rarity: .rare, tier: 4, unitCost: 24, recommendedPrice: 52, district: nil, art: ProductArt(.teapot, 0xF7F3EA, 0x4F78A8, P.gold)),
        // Flower Lane district
        ProductDef(id: "rose_bouquet", name: "Rose Bouquet", blurb: "Garden roses wrapped in brown paper.", category: .flowers, rarity: .common, tier: 1, unitCost: 12, recommendedPrice: 26, district: "flower_lane", art: ProductArt(.bouquet, 0xD9536A, 0xF2A7B0, P.deepSage)),
        ProductDef(id: "tulip_pot", name: "Tulip Pot", blurb: "Striped tulips in a little clay pot.", category: .flowers, rarity: .common, tier: 1, unitCost: 10, recommendedPrice: 21, district: "flower_lane", art: ProductArt(.pottedPlant, 0xE86A5A, P.terracotta, P.sage)),
        ProductDef(id: "moon_orchid", name: "Moon Orchid", blurb: "Pale petals that seem to glow at dusk.", category: .flowers, rarity: .rare, tier: 1, unitCost: 22, recommendedPrice: 48, district: "flower_lane", art: ProductArt(.pottedPlant, 0xE9E1F5, P.cream, P.deepTeal)),
        ProductDef(id: "wildflower_seeds", name: "Wildflower Seeds", blurb: "A meadow's worth of seeds in a paper packet.", category: .flowers, rarity: .common, tier: 1, unitCost: 4, recommendedPrice: 9, district: "flower_lane", art: ProductArt(.seeds, P.parchment, 0xE8A0BF, P.deepSage)),
    ]

    // MARK: Customers (13)
    static let customers: [CustomerDef] = [
        CustomerDef(id: "pip", name: "Pip Bramble", archetype: .shopper,
                    bio: "A cheerful hedge-gardener who pops in on the way to work, usually with soil on one boot.",
                    favorites: [.food, .beverage], priceTolerance: 1.3, tipRate: 0.12, bulkChance: 0.15, giftWrapChance: 0,
                    prefersRare: false, style: .chatty, minReputationLevel: 0, district: nil, spawnWeight: 10,
                    look: CustomerLook(skin: 0xF1C7A3, hair: 0xB5652E, hairStyle: .spiky, outfit: 0x6F8C5E, outfitTrim: 0xF3E6C8, hat: .none, hatColor: 0, accessory: .satchel),
                    heartGiftDecoration: nil,
                    greetings: ["Morning! Smells wonderful in here.", "Quick one before the hedges call!", "Hello hello! What's fresh?"]),
        CustomerDef(id: "mabel", name: "Mabel Thistlewick", archetype: .regular,
                    bio: "Bakes for the whole street, and still insists your buns are better than hers.",
                    favorites: [.food, .beverage, .crafts], priceTolerance: 1.3, tipRate: 0.16, bulkChance: 0.3, giftWrapChance: 0.1,
                    prefersRare: false, style: .warm, minReputationLevel: 0, district: nil, spawnWeight: 9,
                    look: CustomerLook(skin: 0xE8B996, hair: 0xD8D4CF, hairStyle: .bun, outfit: 0xC96F4A, outfitTrim: 0xFFF6E5, hat: .none, hatColor: 0, accessory: .apron),
                    heartGiftDecoration: nil,
                    greetings: ["There's my favorite shopkeeper.", "Have you eaten today, dear?", "Just a little something for tea."]),
        CustomerDef(id: "ollie", name: "Ollie Fennick", archetype: .bargainHunter,
                    bio: "Keeps a ledger of every price in town. Will tell you about it, too.",
                    favorites: [.stationery, .food], priceTolerance: 1.02, tipRate: 0.03, bulkChance: 0.35, giftWrapChance: 0,
                    prefersRare: false, style: .brisk, minReputationLevel: 0, district: nil, spawnWeight: 8,
                    look: CustomerLook(skin: 0xC68E68, hair: 0x2F2A28, hairStyle: .short, outfit: 0x5E9C9A, outfitTrim: 0xD4A84B, hat: .beanie, hatColor: 0xD4A84B, accessory: .glasses),
                    heartGiftDecoration: nil,
                    greetings: ["I've checked three shops already.", "Let's see if your prices are honest.", "Is that the real price?"]),
        CustomerDef(id: "bea", name: "Bea Honeycomb", archetype: .regular,
                    bio: "Keeps bees on the rooftop and always smells faintly of clover.",
                    favorites: [.beverage, .food, .crafts], priceTolerance: 1.2, tipRate: 0.12, bulkChance: 0.2, giftWrapChance: 0,
                    prefersRare: false, style: .warm, minReputationLevel: 0, district: nil, spawnWeight: 8,
                    look: CustomerLook(skin: 0x8D5A3C, hair: 0x1F1A17, hairStyle: .curly, outfit: 0xF2D27C, outfitTrim: 0x5A3E2B, hat: .sunHat, hatColor: 0xF3E6C8, accessory: .earrings),
                    heartGiftDecoration: nil,
                    greetings: ["The bees say hello.", "Busy day in the hive!", "Something sweet, please."]),
        CustomerDef(id: "dottie", name: "Dottie Wren", archetype: .giftBuyer,
                    bio: "Remembers every birthday in the neighborhood and celebrates all of them.",
                    favorites: [.gifts, .flowers, .crafts], priceTolerance: 1.35, tipRate: 0.14, bulkChance: 0.1, giftWrapChance: 0.75,
                    prefersRare: false, style: .chatty, minReputationLevel: 1, district: nil, spawnWeight: 7,
                    look: CustomerLook(skin: 0xF3D2B8, hair: 0x8C3B2E, hairStyle: .braid, outfit: 0xD9898A, outfitTrim: 0xFFF6E5, hat: .beret, hatColor: 0x8C5C7A, accessory: .scarf),
                    heartGiftDecoration: nil,
                    greetings: ["It's someone's birthday somewhere!", "I need a present, quickly!", "Could you make it look special?"]),
        CustomerDef(id: "rowan", name: "Rowan Ferngully", archetype: .shopper,
                    bio: "Paints watercolors by the canal and buys flowers to paint, then to keep.",
                    favorites: [.flowers, .crafts, .stationery], priceTolerance: 1.2, tipRate: 0.1, bulkChance: 0.15, giftWrapChance: 0.1,
                    prefersRare: false, style: .shy, minReputationLevel: 1, district: nil, spawnWeight: 7,
                    look: CustomerLook(skin: 0xDDA77F, hair: 0x4A6B3A, hairStyle: .long, outfit: 0x9CB38A, outfitTrim: 0xC96F4A, hat: .none, hatColor: 0, accessory: .scarf),
                    heartGiftDecoration: nil,
                    greetings: ["Oh — hello. Sorry, the light in here is lovely.", "Just browsing… mostly.", "Hi."]),
        CustomerDef(id: "quillon", name: "Prof. Quillon Ashby", archetype: .scholar,
                    bio: "Retired lecturer of Very Old Maps. Reads standing up so he can leave mid-chapter.",
                    favorites: [.books, .stationery], priceTolerance: 1.35, tipRate: 0.1, bulkChance: 0.1, giftWrapChance: 0,
                    prefersRare: true, style: .grand, minReputationLevel: 1, district: nil, spawnWeight: 6,
                    look: CustomerLook(skin: 0xE2B48F, hair: 0xEDEDED, hairStyle: .bald, outfit: 0x3B3550, outfitTrim: 0xD4A84B, hat: .scholarCap, hatColor: 0x3B3550, accessory: .monocle),
                    heartGiftDecoration: nil,
                    greetings: ["Fascinating little establishment.", "Do you stock anything with footnotes?", "Ah. Books. Splendid."]),
        CustomerDef(id: "juniper", name: "Juniper Moss", archetype: .collector,
                    bio: "Collects rare things in labeled jars. Nobody has seen the whole collection.",
                    favorites: [.crafts, .gifts, .seasonal], priceTolerance: 1.5, tipRate: 0.12, bulkChance: 0.05, giftWrapChance: 0.1,
                    prefersRare: true, style: .shy, minReputationLevel: 2, district: nil, spawnWeight: 5,
                    look: CustomerLook(skin: 0xF0D0B4, hair: 0x2F4B4A, hairStyle: .bun, outfit: 0x5E9C9A, outfitTrim: 0xF2D27C, hat: .beret, hatColor: 0x6F8C5E, accessory: .glasses),
                    heartGiftDecoration: nil,
                    greetings: ["Anything… unusual today?", "I'm looking for something special.", "Hm. Promising."]),
        CustomerDef(id: "tilly", name: "Tilly Pockets", archetype: .traveler,
                    bio: "A wandering tinker whose coat has twenty-three pockets, each with a purpose.",
                    favorites: [.crafts, .stationery, .seasonal], priceTolerance: 1.25, tipRate: 0.09, bulkChance: 0.3, giftWrapChance: 0,
                    prefersRare: false, style: .chatty, minReputationLevel: 2, district: nil, spawnWeight: 6,
                    look: CustomerLook(skin: 0xB8825E, hair: 0xE07B39, hairStyle: .curly, outfit: 0x8A6142, outfitTrim: 0x9CB38A, hat: .topHat, hatColor: 0x5A3E2B, accessory: .satchel),
                    heartGiftDecoration: nil,
                    greetings: ["Just passing through — again!", "Got room in pocket nineteen.", "What've you got that travels well?"]),
        CustomerDef(id: "marlowe", name: "Captain Marlowe Brine", archetype: .traveler,
                    bio: "Retired ferry captain with a laugh you can hear from the harbor.",
                    favorites: [.beverage, .food, .books], priceTolerance: 1.4, tipRate: 0.15, bulkChance: 0.45, giftWrapChance: 0,
                    prefersRare: false, style: .grand, minReputationLevel: 3, district: nil, spawnWeight: 5,
                    look: CustomerLook(skin: 0xD49A73, hair: 0xF2F2F2, hairStyle: .short, outfit: 0x2E4A6B, outfitTrim: 0xF3E6C8, hat: .captain, hatColor: 0x2E4A6B, accessory: .none),
                    heartGiftDecoration: "brass_compass",
                    greetings: ["Ahoy, shopkeep!", "Provisions for the crew — that's me.", "Fair winds and fresh bread!"]),
        CustomerDef(id: "reginald", name: "Sir Reginald Plumtart", archetype: .vip,
                    bio: "Owns the big house on the hill and a waistcoat for every day of the year.",
                    favorites: [.gifts, .books, .seasonal], priceTolerance: 1.8, tipRate: 0.25, bulkChance: 0.2, giftWrapChance: 0.5,
                    prefersRare: true, style: .grand, minReputationLevel: 4, district: nil, spawnWeight: 3,
                    look: CustomerLook(skin: 0xF2C9A8, hair: 0x7A5230, hairStyle: .short, outfit: 0x8C5C7A, outfitTrim: 0xD4A84B, hat: .topHat, hatColor: 0x2B2420, accessory: .bowtie),
                    heartGiftDecoration: "golden_teacup",
                    greetings: ["I hear this is the place to be.", "Only your finest, if you please.", "Splendid. Simply splendid."]),
        CustomerDef(id: "fern", name: "Fern Petalworth", archetype: .giftBuyer,
                    bio: "Runs the Flower Lane post office and sends a bouquet with every parcel.",
                    favorites: [.flowers, .stationery], priceTolerance: 1.3, tipRate: 0.12, bulkChance: 0.25, giftWrapChance: 0.5,
                    prefersRare: false, style: .warm, minReputationLevel: 0, district: "flower_lane", spawnWeight: 8,
                    look: CustomerLook(skin: 0xC99272, hair: 0x5A2F25, hairStyle: .long, outfit: 0xE8A0BF, outfitTrim: 0x6F8C5E, hat: .flowerCrown, hatColor: 0xF2D27C, accessory: .none),
                    heartGiftDecoration: nil,
                    greetings: ["Special delivery — of me!", "Something to tuck into a parcel?", "Flowers make everything better."]),
        CustomerDef(id: "wisteria", name: "Wisteria Vale", archetype: .collector,
                    bio: "A botanist who swears she once grew an orchid that hummed.",
                    favorites: [.flowers, .gifts], priceTolerance: 1.6, tipRate: 0.18, bulkChance: 0.1, giftWrapChance: 0.2,
                    prefersRare: true, style: .shy, minReputationLevel: 0, district: "flower_lane", spawnWeight: 6,
                    look: CustomerLook(skin: 0xF4D9C6, hair: 0x9E86C9, hairStyle: .braid, outfit: 0x6F8C5E, outfitTrim: 0xE9E1F5, hat: .sunHat, hatColor: 0xE9E1F5, accessory: .earrings),
                    heartGiftDecoration: nil,
                    greetings: ["Do you have anything rare in bloom?", "The petals here look happy.", "Oh, how lovely."]),
    ]

    // MARK: Upgrades (7)
    static let upgrades: [UpgradeDef] = [
        UpgradeDef(id: ContentIDs.Upgrade.shelves, name: "More Shelves", summary: "Add shelving to stock new kinds of goods.", symbol: "books.vertical.fill",
                   effect: .productTier, values: [1, 2, 3, 4], costs: [120, 400, 900]),
        UpgradeDef(id: ContentIDs.Upgrade.stockroom, name: "Bigger Stockroom", summary: "Hold more of every product.", symbol: "shippingbox.fill",
                   effect: .stockCapacity, values: [10, 15, 20, 30, 40], costs: [90, 220, 450, 800]),
        UpgradeDef(id: ContentIDs.Upgrade.window, name: "Window Display", summary: "A prettier window draws more customers each day.", symbol: "storefront.fill",
                   effect: .customersPerDay, values: [6, 7, 8, 10, 12], costs: [80, 200, 420, 760]),
        UpgradeDef(id: ContentIDs.Upgrade.checkout, name: "Brass Register", summary: "A friendlier checkout earns bigger tips.", symbol: "bell.fill",
                   effect: .tipBonus, values: [0, 0.1, 0.2, 0.35], costs: [150, 380, 750]),
        UpgradeDef(id: ContentIDs.Upgrade.supplier, name: "Supplier Friendship", summary: "Better terms from the wholesaler.", symbol: "cart.fill",
                   effect: .restockDiscount, values: [0, 0.05, 0.1, 0.15], costs: [100, 300, 650]),
        UpgradeDef(id: ContentIDs.Upgrade.giftWrap, name: "Ribbon & Wrap Station", summary: "Gift buyers love a bow on top.", symbol: "gift.fill",
                   effect: .giftWrap, values: [0, 1], costs: [140]),
        UpgradeDef(id: ContentIDs.Upgrade.nook, name: "Cozy Reading Nook", summary: "Customers linger and spread the word.", symbol: "sofa.fill",
                   effect: .reputationBonus, values: [0, 0.15, 0.3], costs: [180, 500]),
    ]

    // MARK: Decorations (30)
    static let decorations: [DecorationDef] = [
        // Walls
        DecorationDef(id: "cream_plaster", name: "Cream Plaster", slot: .wallpaper, price: 0, coziness: 0, pattern: .plain, primary: 0xF6E8CC, secondary: 0xEBD9B5, isDefault: true, flavor: "Freshly whitewashed and ready for anything."),
        DecorationDef(id: "sage_stripes", name: "Sage Stripes", slot: .wallpaper, price: 120, coziness: 2, pattern: .stripes, primary: 0xDDE6CF, secondary: 0xBFD0AC, isDefault: false, flavor: "Calm stripes the color of new leaves."),
        DecorationDef(id: "terracotta_vines", name: "Terracotta Vines", slot: .wallpaper, price: 260, coziness: 3, pattern: .vines, primary: 0xF0D2BE, secondary: 0xC96F4A, isDefault: false, flavor: "Painted vines climb toward the ceiling."),
        DecorationDef(id: "midnight_stars", name: "Midnight Stars", slot: .wallpaper, price: 400, coziness: 4, pattern: .stars, primary: 0x3B4A6B, secondary: 0xF2D27C, isDefault: false, flavor: "Gold stars on deep blue, for dreamers."),
        // Floors
        DecorationDef(id: "oak_boards", name: "Oak Boards", slot: .floor, price: 0, coziness: 0, pattern: .boards, primary: 0xC9965F, secondary: 0xA97A48, isDefault: true, flavor: "Creaky in all the right places."),
        DecorationDef(id: "checker_tiles", name: "Checker Tiles", slot: .floor, price: 150, coziness: 2, pattern: .checker, primary: 0xF3E6C8, secondary: 0x5E9C9A, isDefault: false, flavor: "Teal and cream, cool underfoot."),
        DecorationDef(id: "walnut_herringbone", name: "Walnut Herringbone", slot: .floor, price: 320, coziness: 3, pattern: .herringbone, primary: 0x8A6142, secondary: 0x6B4A31, isDefault: false, flavor: "Rich, dark and very fancy."),
        // Counters
        DecorationDef(id: "simple_counter", name: "Pine Counter", slot: .counter, price: 0, coziness: 0, pattern: .solid, primary: 0xB88552, secondary: 0x8A6142, isDefault: true, flavor: "Sturdy and honest."),
        DecorationDef(id: "teal_counter", name: "Painted Teal Counter", slot: .counter, price: 180, coziness: 2, pattern: .solid, primary: 0x5E9C9A, secondary: 0x3F7372, isDefault: false, flavor: "A cheerful coat of sea-glass paint."),
        DecorationDef(id: "carved_counter", name: "Carved Walnut Counter", slot: .counter, price: 380, coziness: 3, pattern: .carved, primary: 0x7A5233, secondary: 0xD4A84B, isDefault: false, flavor: "Hand-carved acorns along the edge."),
        // Shelves
        DecorationDef(id: "pine_shelves", name: "Pine Shelves", slot: .shelves, price: 0, coziness: 0, pattern: .solid, primary: 0xC08D58, secondary: 0x8A6142, isDefault: true, flavor: "They hold things. Admirably."),
        DecorationDef(id: "whitewash_shelves", name: "Whitewashed Shelves", slot: .shelves, price: 160, coziness: 2, pattern: .solid, primary: 0xEFE7DA, secondary: 0xBFAF98, isDefault: false, flavor: "Soft and bright, like a seaside cottage."),
        DecorationDef(id: "glass_cabinet", name: "Glass Cabinet", slot: .shelves, price: 420, coziness: 4, pattern: .glass, primary: 0x6B4A31, secondary: 0xCFE6E8, isDefault: false, flavor: "Makes every item look precious."),
        // Plants
        DecorationDef(id: "potted_fern", name: "Potted Fern", slot: .plant, price: 60, coziness: 2, pattern: .fern, primary: 0x6F8C5E, secondary: 0xC96F4A, isDefault: false, flavor: "A housewarming gift from the neighborhood."),
        DecorationDef(id: "monstera", name: "Big Monstera", slot: .plant, price: 140, coziness: 3, pattern: .monstera, primary: 0x4E7A4A, secondary: 0xF3E6C8, isDefault: false, flavor: "Leaves the size of umbrellas."),
        DecorationDef(id: "hanging_ivy", name: "Hanging Ivy", slot: .plant, price: 200, coziness: 3, pattern: .ivy, primary: 0x5F8F55, secondary: 0x8A6142, isDefault: false, flavor: "Trails down from a macramé hanger."),
        // Lighting
        DecorationDef(id: "paper_lantern", name: "Paper Lantern", slot: .lighting, price: 110, coziness: 2, pattern: .lantern, primary: 0xF7E3B5, secondary: 0xD4A84B, isDefault: false, flavor: "A soft glow, like a sleepy moon."),
        DecorationDef(id: "brass_lamp", name: "Brass Reading Lamp", slot: .lighting, price: 240, coziness: 3, pattern: .lamp, primary: 0xD4A84B, secondary: 0x9CB38A, isDefault: false, flavor: "Warm light for long afternoons."),
        DecorationDef(id: "fairy_lights", name: "Fairy Lights", slot: .lighting, price: 300, coziness: 4, pattern: .fairyLights, primary: 0xFFE9A8, secondary: 0x6F8C5E, isDefault: false, flavor: "Strung across the ceiling like fireflies."),
        // Rugs
        DecorationDef(id: "woven_rug", name: "Woven Rug", slot: .rug, price: 90, coziness: 2, pattern: .wovenRug, primary: 0xC96F4A, secondary: 0xF3E6C8, isDefault: false, flavor: "Braided from old aprons."),
        DecorationDef(id: "sun_rug", name: "Sunburst Rug", slot: .rug, price: 180, coziness: 3, pattern: .sunRug, primary: 0xF2D27C, secondary: 0xC96F4A, isDefault: false, flavor: "Like standing in a patch of sunlight."),
        // Wall art
        DecorationDef(id: "hand_sign", name: "Hand-painted Sign", slot: .wallArt, price: 70, coziness: 1, pattern: .sign, primary: 0x8A6142, secondary: 0xFFF6E5, isDefault: false, flavor: "\"Come in, we're cozy.\""),
        DecorationDef(id: "meadow_painting", name: "Meadow Painting", slot: .wallArt, price: 210, coziness: 3, pattern: .painting, primary: 0x9CB38A, secondary: 0xD4A84B, isDefault: false, flavor: "Painted by a shy local artist."),
        DecorationDef(id: "moonmoth_tapestry", name: "Moonmoth Tapestry", slot: .wallArt, price: 330, coziness: 3, pattern: .tapestry, primary: 0x3F7372, secondary: 0xE9E1F5, isDefault: false, flavor: "Embroidered moths circling a silver moon."),
        // Seasonal
        DecorationDef(id: "harvest_garland", name: "Harvest Garland", slot: .seasonal, price: 150, coziness: 2, pattern: .garland, primary: 0xD98B3A, secondary: 0x8A3B2E, isDefault: false, flavor: "Dried leaves and tiny gourds."),
        DecorationDef(id: "snowy_wreath", name: "Snowy Wreath", slot: .seasonal, price: 150, coziness: 2, pattern: .wreath, primary: 0x4E7A4A, secondary: 0xFFFFFF, isDefault: false, flavor: "Pine, berries and a dusting of white."),
        // Keepsakes (reward-only)
        DecorationDef(id: "lucky_clover_jar", name: "Lucky Clover Jar", slot: .collectible, price: nil, coziness: 2, pattern: .cloverJar, primary: 0x6F8C5E, secondary: 0xCFE6E8, isDefault: false, flavor: "A daily-visit gift. Four leaves, every one."),
        DecorationDef(id: "brass_compass", name: "Captain's Compass", slot: .collectible, price: nil, coziness: 2, pattern: .compass, primary: 0xD4A84B, secondary: 0xF3E6C8, isDefault: false, flavor: "Captain Brine insists it points to good company."),
        DecorationDef(id: "golden_teacup", name: "Golden Teacup", slot: .collectible, price: nil, coziness: 3, pattern: .teacup, primary: 0xE9C46A, secondary: 0xFFF6E5, isDefault: false, flavor: "Sir Reginald's thank-you, far too fancy to drink from."),
        DecorationDef(id: "bloom_frame", name: "Pressed Bloom Frame", slot: .collectible, price: nil, coziness: 2, pattern: .painting, primary: 0xE8A0BF, secondary: 0xF3E6C8, isDefault: false, flavor: "Reward for completing the Garden Blooms collection."),
    ]

    // MARK: Districts (5)
    static let districts: [DistrictDef] = [
        DistrictDef(id: "maple_corner", name: "Maple Corner", tagline: "Where your little shop began.", isPlayable: true, requiredReputationLevel: 0, unlockCost: 0,
                    skyTop: 0xA9CFE0, skyBottom: 0xF6E3C3, accent: 0xC96F4A, mapX: 0.28, mapY: 0.68),
        DistrictDef(id: "flower_lane", name: "Flower Lane", tagline: "A lane of greenhouses, florists and bees.", isPlayable: true, requiredReputationLevel: 3, unlockCost: 1200,
                    skyTop: 0xF4C7D3, skyBottom: 0xFBEBD6, accent: 0xD9536A, mapX: 0.62, mapY: 0.52),
        DistrictDef(id: "book_quarter", name: "Book Quarter", tagline: "Crooked bookshops and ink-stained cafés.", isPlayable: false, requiredReputationLevel: 5, unlockCost: 3000,
                    skyTop: 0xC2B6D9, skyBottom: 0xF1E4D0, accent: 0x3B3550, mapX: 0.36, mapY: 0.34),
        DistrictDef(id: "seaside_promenade", name: "Seaside Promenade", tagline: "Salt air, shell stalls and harbor lights.", isPlayable: false, requiredReputationLevel: 6, unlockCost: 5000,
                    skyTop: 0x9FD3D6, skyBottom: 0xF7EBD0, accent: 0x3F7372, mapX: 0.78, mapY: 0.24),
        DistrictDef(id: "winter_village", name: "Winter Village", tagline: "Snowy rooftops and mulled-cider markets.", isPlayable: false, requiredReputationLevel: 8, unlockCost: 8000,
                    skyTop: 0xC9DCEB, skyBottom: 0xF5F2EC, accent: 0x5E7FA3, mapX: 0.2, mapY: 0.14),
    ]

    // MARK: Quests (20)
    static let quests: [QuestDef] = [
        QuestDef(id: "sell_5", title: "Sell 5 items", kind: .sellItems, target: 5, rewardCoins: 40, group: .selling),
        QuestDef(id: "sell_12", title: "Sell 12 items", kind: .sellItems, target: 12, rewardCoins: 90, group: .selling),
        QuestDef(id: "sell_food", title: "Sell 4 baked goods", kind: .sellCategory(.food), target: 4, rewardCoins: 45, group: .selling),
        QuestDef(id: "sell_beverage", title: "Sell 3 drinks", kind: .sellCategory(.beverage), target: 3, rewardCoins: 45, group: .selling),
        QuestDef(id: "sell_flowers", title: "Sell 3 flower items", kind: .sellCategory(.flowers), target: 3, rewardCoins: 50, group: .selling),
        QuestDef(id: "sell_stationery", title: "Sell 3 stationery items", kind: .sellCategory(.stationery), target: 3, rewardCoins: 50, group: .selling),
        QuestDef(id: "sell_crafts", title: "Sell 3 crafts", kind: .sellCategory(.crafts), target: 3, rewardCoins: 50, group: .selling),
        QuestDef(id: "sell_books", title: "Sell 2 books", kind: .sellCategory(.books), target: 2, rewardCoins: 60, group: .selling),
        QuestDef(id: "sell_gifts", title: "Sell 2 gifts", kind: .sellCategory(.gifts), target: 2, rewardCoins: 60, group: .selling),
        QuestDef(id: "sell_seasonal", title: "Sell 2 seasonal treats", kind: .sellCategory(.seasonal), target: 2, rewardCoins: 70, group: .selling),
        QuestDef(id: "earn_150", title: "Earn 150 coins from sales", kind: .earnCoins, target: 150, rewardCoins: 50, group: .earning),
        QuestDef(id: "earn_400", title: "Earn 400 coins from sales", kind: .earnCoins, target: 400, rewardCoins: 110, group: .earning),
        QuestDef(id: "tips_25", title: "Collect 25 coins in tips", kind: .receiveTips, target: 25, rewardCoins: 45, group: .earning),
        QuestDef(id: "delight_4", title: "Delight 4 customers", kind: .delightCustomers, target: 4, rewardCoins: 55, group: .earning),
        QuestDef(id: "regular_2", title: "Serve 2 regulars", kind: .serveRegulars, target: 2, rewardCoins: 60, group: .shopkeeping),
        QuestDef(id: "restock_10", title: "Restock 10 units", kind: .restockUnits, target: 10, rewardCoins: 35, group: .shopkeeping),
        QuestDef(id: "day_1", title: "Finish a shop day", kind: .completeShopDays, target: 1, rewardCoins: 40, group: .shopkeeping),
        QuestDef(id: "upgrade_1", title: "Buy a shop upgrade", kind: .buyUpgrades, target: 1, rewardCoins: 60, group: .shopkeeping),
        QuestDef(id: "decor_1", title: "Decorate a corner", kind: .buyDecorations, target: 1, rewardCoins: 50, group: .shopkeeping),
        QuestDef(id: "discover_1", title: "Meet a new customer", kind: .discoverCustomers, target: 1, rewardCoins: 50, group: .shopkeeping),
    ]

    // MARK: Achievements (16)
    static let achievements: [AchievementDef] = [
        AchievementDef(id: "first_sale", title: "Open for Business", detail: "Make your very first sale.", condition: .totalSales(1), rewardCoins: 25, isMilestone: true),
        AchievementDef(id: "first_day", title: "Lights Out", detail: "Finish your first shop day.", condition: .daysCompleted(1), rewardCoins: 40, isMilestone: true),
        AchievementDef(id: "first_upgrade", title: "Handy with a Hammer", detail: "Buy your first upgrade.", condition: .upgradesBought(1), rewardCoins: 50, isMilestone: true),
        AchievementDef(id: "first_decoration", title: "Feels Like Home", detail: "Buy your first decoration.", condition: .decorationsBought(1), rewardCoins: 40, isMilestone: true),
        AchievementDef(id: "first_regular", title: "The Usual?", detail: "Turn a customer into a regular.", condition: .regulars(1), rewardCoins: 60, isMilestone: true),
        AchievementDef(id: "first_collection", title: "Curator", detail: "Complete any collection.", condition: .collectionsCompleted(1), rewardCoins: 150, isMilestone: true),
        AchievementDef(id: "flower_lane", title: "Branching Out", detail: "Open your shop on Flower Lane.", condition: .districtUnlocked("flower_lane"), rewardCoins: 200, isMilestone: true),
        AchievementDef(id: "sales_10", title: "Busy Hands", detail: "Make 10 sales.", condition: .totalSales(10), rewardCoins: 50, isMilestone: false),
        AchievementDef(id: "sales_100", title: "Neighborhood Fixture", detail: "Make 100 sales.", condition: .totalSales(100), rewardCoins: 300, isMilestone: false),
        AchievementDef(id: "days_7", title: "A Week of Mornings", detail: "Finish 7 shop days.", condition: .daysCompleted(7), rewardCoins: 150, isMilestone: false),
        AchievementDef(id: "rep_3", title: "Word Gets Around", detail: "Reach reputation level 3.", condition: .reputationLevel(3), rewardCoins: 100, isMilestone: false),
        AchievementDef(id: "rep_5", title: "Talk of the Town", detail: "Reach reputation level 5.", condition: .reputationLevel(5), rewardCoins: 250, isMilestone: false),
        AchievementDef(id: "coins_1000", title: "Jar of Coins", detail: "Earn 1,000 coins in total.", condition: .lifetimeCoins(1000), rewardCoins: 100, isMilestone: false),
        AchievementDef(id: "coins_10000", title: "Treasure Chest", detail: "Earn 10,000 coins in total.", condition: .lifetimeCoins(10000), rewardCoins: 500, isMilestone: false),
        AchievementDef(id: "delight_10", title: "Pure Delight", detail: "Delight 10 customers.", condition: .delightedSales(10), rewardCoins: 120, isMilestone: false),
        AchievementDef(id: "all_customers", title: "Everybody Knows Your Name", detail: "Meet all 13 customers.", condition: .customersDiscovered(13), rewardCoins: 500, isMilestone: false),
    ]

    // MARK: Collections (5)
    static let collections: [CollectionDef] = [
        CollectionDef(id: "bakery_basket", title: "Bakery Basket", detail: "Sell every baked good and seasonal tart.",
                      requirement: .sellProducts(["honey_bun", "acorn_cookie", "cinnamon_loaf", "pumpkin_tart"]), rewardCoins: 200, rewardDecoration: nil),
        CollectionDef(id: "library_shelf", title: "Library Shelf", detail: "Sell every kind of book.",
                      requirement: .sellProducts(["pocket_almanac", "fable_storybook", "atlas_of_isles"]), rewardCoins: 250, rewardDecoration: nil),
        CollectionDef(id: "garden_blooms", title: "Garden Blooms", detail: "Sell every flower, from daisies to moon orchids.",
                      requirement: .sellProducts(["daisy_posy", "sunflower_bundle", "rose_bouquet", "tulip_pot", "moon_orchid", "wildflower_seeds"]), rewardCoins: 300, rewardDecoration: "bloom_frame"),
        CollectionDef(id: "cozy_corner", title: "Cozy Corner", detail: "Own the fern, lantern, woven rug and painted sign.",
                      requirement: .ownDecorations(["potted_fern", "paper_lantern", "woven_rug", "hand_sign"]), rewardCoins: 150, rewardDecoration: nil),
        CollectionDef(id: "familiar_faces", title: "Familiar Faces", detail: "Meet 8 different customers.",
                      requirement: .discoverCustomers(8), rewardCoins: 200, rewardDecoration: nil),
    ]

    // MARK: Daily rewards (7-day cycle)
    static let dailyRewards: [DailyRewardDef] = [
        DailyRewardDef(day: 1, kind: .coins(60)),
        DailyRewardDef(day: 2, kind: .coins(80)),
        DailyRewardDef(day: 3, kind: .decoration("lucky_clover_jar", fallbackCoins: 120)),
        DailyRewardDef(day: 4, kind: .coins(100)),
        DailyRewardDef(day: 5, kind: .reputation(15)),
        DailyRewardDef(day: 6, kind: .coins(150)),
        DailyRewardDef(day: 7, kind: .coins(250)),
    ]
}
