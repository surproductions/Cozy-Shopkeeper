import Foundation

/// The on-disk wrapper around a save. Versioned so future formats can migrate.
public struct SaveEnvelope: Codable, Sendable {
    public var formatVersion: Int
    public var savedAt: Date
    public var appVersion: String
    public var state: GameState

    public init(formatVersion: Int, savedAt: Date, appVersion: String, state: GameState) {
        self.formatVersion = formatVersion
        self.savedAt = savedAt
        self.appVersion = appVersion
        self.state = state
    }

    enum CodingKeys: String, CodingKey { case formatVersion, savedAt, appVersion, state }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = c.lenient(.formatVersion, SaveCodec.currentFormatVersion)
        savedAt = c.lenient(.savedAt, Date(timeIntervalSince1970: 0))
        appVersion = c.lenient(.appVersion, "unknown")
        state = try c.decode(GameState.self, forKey: .state)
    }
}

public enum SaveError: Error, Equatable, Sendable {
    case unreadable(String)
    case fromFutureVersion(Int)
}

public enum SaveCodec {
    public static let currentFormatVersion = 1

    /// Raw-JSON migrations keyed by the version they upgrade *from*.
    /// Each step must turn version N into version N + 1.
    static let migrations: [Int: ([String: Any]) -> [String: Any]] = [
        // Version 0: a bare GameState object with no envelope (e.g. a raw state export).
        0: { raw in
            var envelope: [String: Any] = [:]
            envelope["formatVersion"] = 1
            envelope["savedAt"] = raw["savedAt"] ?? 0
            envelope["appVersion"] = raw["appVersion"] ?? "0"
            envelope["state"] = raw
            return envelope
        }
    ]

    public static func encode(_ state: GameState, appVersion: String, now: Date) throws -> Data {
        let envelope = SaveEnvelope(formatVersion: currentFormatVersion, savedAt: now, appVersion: appVersion, state: state)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(envelope)
    }

    /// Decodes, migrates and sanitizes a save.
    public static func decode(_ data: Data, content: GameContent = .standard, config: EconomyConfig = .standard) throws -> GameState {
        guard let object = try? JSONSerialization.jsonObject(with: data), var raw = object as? [String: Any] else {
            throw SaveError.unreadable("not a JSON object")
        }
        var version = (raw["formatVersion"] as? Int) ?? 0
        if version > currentFormatVersion { throw SaveError.fromFutureVersion(version) }
        while version < currentFormatVersion {
            guard let step = migrations[version] else { throw SaveError.unreadable("no migration from \(version)") }
            raw = step(raw)
            version += 1
        }
        let migrated: Data
        do {
            migrated = try JSONSerialization.data(withJSONObject: raw)
        } catch {
            throw SaveError.unreadable("re-encode failed")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        do {
            let envelope = try decoder.decode(SaveEnvelope.self, from: migrated)
            return sanitize(envelope.state, content: content, config: config)
        } catch {
            throw SaveError.unreadable("decode failed: \(error)")
        }
    }

    /// Repairs any impossible values so a damaged or hand-edited save can't break the game.
    public static func sanitize(_ input: GameState, content: GameContent = .standard, config: EconomyConfig = .standard) -> GameState {
        var s = input
        s.schemaVersion = GameState.currentSchemaVersion
        s.coins = max(0, s.coins)
        s.reputation = max(0, s.reputation)

        // Upgrades first, because capacity depends on them.
        var levels: [String: Int] = [:]
        for def in content.upgrades {
            levels[def.id] = min(max(0, s.upgradeLevels[def.id] ?? 0), def.maxLevel)
        }
        s.upgradeLevels = levels.filter { $0.value > 0 }

        let engine = GameEngine(state: s, content: content, config: config)
        let capacity = engine.stockCapacity

        var inventory: [String: Int] = [:]
        for (id, qty) in s.inventory where content.product(id) != nil {
            inventory[id] = min(max(0, qty), capacity)
        }
        s.inventory = inventory

        var prices: [String: Int] = [:]
        for product in content.products {
            prices[product.id] = config.clampPrice(s.prices[product.id] ?? product.recommendedPrice, for: product)
        }
        s.prices = prices
        s.productsEverSold = s.productsEverSold.filter { content.product($0) != nil }

        var owned = s.ownedDecorations.filter { content.decoration($0) != nil }
        for def in content.decorations where def.isDefault { owned.insert(def.id) }
        s.ownedDecorations = owned
        var equipped: [String: String] = [:]
        for slot in DecorSlot.allCases {
            if let id = s.equippedDecorations[slot.rawValue], let def = content.decoration(id), def.slot == slot, owned.contains(id) {
                equipped[slot.rawValue] = id
            } else if slot.isRequired, let fallback = content.decorations.first(where: { $0.slot == slot && $0.isDefault }) {
                equipped[slot.rawValue] = fallback.id
            }
        }
        s.equippedDecorations = equipped

        s.customers = s.customers.filter { content.customer($0.key) != nil }

        var districts = s.unlockedDistricts.filter { content.district($0)?.isPlayable == true }
        districts.insert(ContentIDs.startingDistrict)
        s.unlockedDistricts = districts
        if !districts.contains(s.currentDistrict) { s.currentDistrict = ContentIDs.startingDistrict }

        if let visit = s.currentVisit {
            let valid = content.customer(visit.customerId) != nil && content.product(visit.productId) != nil
                && visit.quantity > 0 && visit.maxUnitPrice > 0
            if !valid { s.currentVisit = nil }
        }
        s.shopDay.dayNumber = max(1, s.shopDay.dayNumber)
        s.shopDay.customersPlanned = max(1, s.shopDay.customersPlanned)
        s.shopDay.customersArrived = min(max(0, s.shopDay.customersArrived), s.shopDay.customersPlanned)
        if s.currentVisit == nil && s.shopDay.customersArrived >= s.shopDay.customersPlanned {
            s.shopDay.isFinished = true
        }
        s.visitCounter = max(0, s.visitCounter)

        s.daily.goals = s.daily.goals.filter { content.quest($0.questId) != nil }
        for index in s.daily.goals.indices {
            let target = content.quest(s.daily.goals[index].questId)?.target ?? 0
            s.daily.goals[index].progress = min(max(0, s.daily.goals[index].progress), target)
        }
        s.dailyReward.claimedCount = max(0, s.dailyReward.claimedCount)
        s.claimedAchievements = s.claimedAchievements.filter { id in content.achievements.contains { $0.id == id } }
        s.claimedCollections = s.claimedCollections.filter { id in content.collections.contains { $0.id == id } }
        return s
    }
}

/// Where a load came from, for diagnostics.
public enum LoadSource: String, Sendable {
    case primary, backup, fresh
}

public struct LoadResult: Sendable {
    public let state: GameState?
    public let source: LoadSource
    public let problems: [String]

    public init(state: GameState?, source: LoadSource, problems: [String]) {
        self.state = state
        self.source = source
        self.problems = problems
    }
}

/// Stores saves as JSON in a directory with an automatic last-good backup.
/// Writes are atomic, so a crash mid-save can never leave a half-written file.
public final class FileSaveStore: @unchecked Sendable {
    public let directory: URL
    private let lock = NSLock()

    public var primaryURL: URL { directory.appendingPathComponent("cozy-shop-save.json") }
    public var backupURL: URL { directory.appendingPathComponent("cozy-shop-save.backup.json") }

    public init(directory: URL) {
        self.directory = directory
    }

    public func save(_ state: GameState, appVersion: String, now: Date = Date()) throws {
        let data = try SaveCodec.encode(state, appVersion: appVersion, now: now)
        lock.lock()
        defer { lock.unlock() }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fm = FileManager.default
        if fm.fileExists(atPath: primaryURL.path),
           let current = try? Data(contentsOf: primaryURL),
           (try? SaveCodec.decode(current)) != nil {
            // Keep the previous good save as a backup.
            try? current.write(to: backupURL, options: .atomic)
        }
        try data.write(to: primaryURL, options: .atomic)
    }

    public func load(content: GameContent = .standard, config: EconomyConfig = .standard) -> LoadResult {
        lock.lock()
        defer { lock.unlock() }
        var problems: [String] = []
        for (url, source) in [(primaryURL, LoadSource.primary), (backupURL, LoadSource.backup)] {
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            do {
                let data = try Data(contentsOf: url)
                let state = try SaveCodec.decode(data, content: content, config: config)
                return LoadResult(state: state, source: source, problems: problems)
            } catch {
                problems.append("\(source.rawValue): \(error)")
            }
        }
        return LoadResult(state: nil, source: .fresh, problems: problems)
    }

    /// Deletes both the save and its backup.
    public func eraseAll() throws {
        lock.lock()
        defer { lock.unlock() }
        for url in [primaryURL, backupURL] where FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    public var hasBackup: Bool { FileManager.default.fileExists(atPath: backupURL.path) }
}
