import Foundation

/// A mid-game shop used only to capture App Store screenshots (Debug builds, launched
/// with `-ui-screenshots`). Built from the real rules so every value is reachable in play.
public enum ShowcaseState {
    public static func make(now: Date, timeZone: TimeZone) -> GameState {
        var engine = GameEngine.newGame(seed: 2026, now: now.addingTimeInterval(-20 * 86_400))
        engine.skipTutorial()
        var s = engine.state

        s.coins = 12_480
        s.reputation = 520
        s.upgradeLevels = [
            ContentIDs.Upgrade.shelves: 3, ContentIDs.Upgrade.stockroom: 2, ContentIDs.Upgrade.window: 2,
            ContentIDs.Upgrade.checkout: 2, ContentIDs.Upgrade.supplier: 1, ContentIDs.Upgrade.giftWrap: 1,
            ContentIDs.Upgrade.nook: 1,
        ]
        let stocked: [String: Int] = [
            "honey_bun": 14, "acorn_cookie": 11, "chamomile_tin": 8, "berry_cordial": 6, "daisy_posy": 9,
            "leaf_notebook": 7, "beeswax_candle": 12, "clay_mug": 5, "cinnamon_loaf": 6, "lavender_soap": 10,
            "quill_pen": 4, "pocket_almanac": 3, "sunflower_bundle": 0, "spiced_cider": 8, "fable_storybook": 2,
            "knit_scarf": 4, "tin_music_box": 3, "pressed_flower_card": 15, "pumpkin_tart": 7, "star_lantern": 2,
            "atlas_of_isles": 1, "porcelain_teapot": 2,
        ]
        s.inventory = stocked
        s.productsEverSold = Set(["honey_bun", "acorn_cookie", "cinnamon_loaf", "pumpkin_tart", "daisy_posy",
                                  "sunflower_bundle", "pocket_almanac", "fable_storybook", "beeswax_candle",
                                  "clay_mug", "tin_music_box", "lavender_soap"])

        let decor = ["terracotta_vines", "walnut_herringbone", "teal_counter", "whitewash_shelves", "monstera",
                     "fairy_lights", "sun_rug", "meadow_painting", "harvest_garland", "golden_teacup",
                     "potted_fern", "paper_lantern", "woven_rug", "hand_sign", "sage_stripes", "lucky_clover_jar"]
        for id in decor { s.ownedDecorations.insert(id) }
        for id in decor.prefix(10) {
            if let def = engine.content.decoration(id) { s.equippedDecorations[def.slot.rawValue] = id }
        }

        let relationships: [String: Int] = ["pip": 14, "mabel": 21, "ollie": 6, "bea": 12, "dottie": 10,
                                            "rowan": 9, "quillon": 5, "juniper": 4, "tilly": 3, "reginald": 20]
        for (id, points) in relationships {
            var record = CustomerRecord(discoveredOnShopDay: 1)
            record.relationshipPoints = points
            record.purchases = points
            record.visits = points + 2
            record.totalSatisfaction = points * 82
            record.heartGiftClaimed = id == "reginald"
            s.customers[id] = record
        }

        s.stats.totalSales = 168
        s.stats.itemsSold = 214
        s.stats.delightedSales = 61
        s.stats.daysCompleted = 20
        s.stats.upgradesBought = 12
        s.stats.decorationsBought = 14
        s.stats.lifetimeCoins = 18_900
        s.stats.unitsRestocked = 240
        s.claimedAchievements = ["first_sale", "first_day", "first_upgrade", "first_decoration", "first_regular",
                                 "sales_10", "days_7", "rep_3", "coins_1000", "delight_10"]
        s.claimedCollections = ["bakery_basket"]
        s.dailyReward.claimedCount = 4

        s.shopDay = ShopDayState()
        s.shopDay.dayNumber = 21
        s.shopDay.customersPlanned = 8
        s.shopDay.customersArrived = 5
        s.shopDay.customersServed = 4
        s.shopDay.revenue = 186
        s.shopDay.tips = 31
        s.visitCounter = 140
        s.currentVisit = CustomerVisit(id: 140, customerId: "dottie", productId: "tin_music_box", quantity: 1,
                                       maxUnitPrice: 58, wantsGiftWrap: true, attemptsUsed: 0,
                                       greeting: "It's my sister's birthday — could you wrap it with a bow?",
                                       isTutorial: false, isFirstVisit: false)

        var finished = GameEngine(state: s, content: engine.content, config: engine.config)
        finished.refreshCalendarDay(now: now, timeZone: timeZone)
        var goals = finished.state.daily.goals
        if goals.count >= 3 {
            let targets = goals.map { finished.content.quest($0.questId)?.target ?? 1 }
            goals[0].progress = targets[0]
            goals[0].claimed = true
            goals[1].progress = targets[1]
            goals[2].progress = max(0, targets[2] / 2)
        }
        var final = finished.state
        final.daily.goals = goals
        return SaveCodec.sanitize(final)
    }
}
