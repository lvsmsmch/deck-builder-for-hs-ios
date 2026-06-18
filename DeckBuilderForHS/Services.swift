import Foundation

struct HsJsonCardDTO: Codable {
    let id: String
    let dbfId: Int
    let name: String?
    let text: String?
    let flavor: String?
    let cost: Int?
    let attack: Int?
    let health: Int?
    let durability: Int?
    let armor: Int?
    let cardClass: String?
    let classes: [String]?
    let multiClassGroup: String?
    let set: String?
    let type: String?
    let rarity: String?
    let race: String?
    let races: [String]?
    let spellSchool: String?
    let mechanics: [String]?
    let referencedTags: [String]?
    let entourage: [String]?
    let collectible: Bool?
    let artist: String?
}

actor HsJsonService {
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(session: URLSession = .shared) {
        self.session = session
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func loadCards(locale: String, forceRefresh: Bool) async throws -> [Card] {
        if !forceRefresh, let cached = try? loadCached(locale: locale), !cached.isEmpty {
            return cached
        }
        let url = URL(string: "https://api.hearthstonejson.com/v1/latest/\(locale)/cards.json")!
        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse).map({ 200..<300 ~= $0.statusCode }) == true else {
            throw URLError(.badServerResponse)
        }
        let rows = try decoder.decode([HsJsonCardDTO].self, from: data)
        let cards = rows.compactMap { $0.toDomain(locale: locale) }
        try cache(cards: cards, locale: locale)
        return cards
    }

    private func loadCached(locale: String) throws -> [Card] {
        let data = try Data(contentsOf: cacheURL(locale: locale))
        return try decoder.decode([Card].self, from: data)
    }

    private func cache(cards: [Card], locale: String) throws {
        let url = cacheURL(locale: locale)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(cards).write(to: url, options: [.atomic])
    }

    private func cacheURL(locale: String) -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CardCache", isDirectory: true)
            .appendingPathComponent("cards-\(locale).json")
    }
}

extension HsJsonCardDTO {
    func toDomain(locale: String) -> Card? {
        guard let name, !name.isEmpty else { return nil }
        let classTokens = normalizedClassTokens()
        let classes = classTokens.map { token in
            ClassMeta(id: 0, slug: token.domainSlug.normalizedClassSlug, name: token.displayToken, heroCardId: nil)
        }
        let raceTokens = (races ?? race.map { [$0] } ?? [])
        let mechanics = ((mechanics ?? []) + (referencedTags ?? []))
            .filter { !["TRIGGER_VISUAL", "TAG_ONE_TURN_EFFECT"].contains($0) }
        let textValue = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let childRefs = ((entourage ?? []) + rewardNames(from: textValue)).filter { !$0.isEmpty }
        let cardSetSlug = set?.domainSlug
        let raritySlug = rarity?.domainSlug

        return Card(
            id: dbfId,
            slug: id,
            name: name,
            text: textValue?.isEmpty == true ? nil : textValue,
            flavorText: flavor?.isEmpty == true ? nil : flavor,
            imageURL: URL(string: "https://art.hearthstonejson.com/v1/render/latest/\(locale)/256x/\(id).png"),
            cropImageURL: URL(string: "https://art.hearthstonejson.com/v1/512x/\(id).webp"),
            artistName: artist?.isEmpty == true ? nil : artist,
            manaCost: cost ?? 0,
            attack: attack,
            health: health,
            durability: durability,
            armor: armor,
            classes: classes,
            cardSet: cardSetSlug.map { Expansion(id: 0, slug: $0, name: set?.displayToken ?? $0, type: nil) },
            rarity: raritySlug.map { Rarity(id: 0, slug: $0, name: rarity?.displayToken ?? $0, craftingCost: Self.craftingCost(for: $0)) },
            cardType: CardType(id: 0, slug: type?.domainSlug ?? "unknown", name: type?.displayToken ?? ""),
            minionType: raceTokens.first.map { MinionType(id: 0, slug: $0.domainSlug, name: $0.displayToken) },
            spellSchool: spellSchool.map { SpellSchool(id: 0, slug: $0.domainSlug, name: $0.displayToken) },
            keywords: Array(Set(mechanics)).sorted().map { Keyword(id: 0, slug: $0.domainSlug, name: $0.displayToken, refText: "") },
            collectible: collectible ?? false,
            childIds: Array(Set(childRefs))
        )
    }

    private func normalizedClassTokens() -> [String] {
        if let classes, !classes.isEmpty { return classes }
        if let cardClass { return [cardClass] }
        return ["NEUTRAL"]
    }

    private func rewardNames(from text: String?) -> [String] {
        guard let text else { return [] }
        let clean = text.strippedCardText()
        let patterns = ["(?i)\\bReward\\s*:\\s*([^\\.\\n]+)", "(?i)\\bНаграда\\s*:\\s*([^\\.\\n]+)"]
        return patterns.compactMap { pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
            let range = NSRange(clean.startIndex..<clean.endIndex, in: clean)
            guard let match = regex.firstMatch(in: clean, range: range), match.numberOfRanges > 1,
                  let swiftRange = Range(match.range(at: 1), in: clean) else { return nil }
            return String(clean[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func craftingCost(for slug: String) -> [Int] {
        switch slug {
        case "common": [40, 400]
        case "rare": [100, 800]
        case "epic": [400, 1600]
        case "legendary": [1600, 3200]
        default: []
        }
    }
}

struct DeckstringPayload: Equatable {
    let format: DeckstringFormat
    let heroes: [Int]
    let cards: [DeckstringCard]
    let sideboards: [DeckstringSideboardCard]
}

struct DeckstringCard: Equatable {
    let dbfId: Int
    let count: Int
}

struct DeckstringSideboardCard: Equatable {
    let dbfId: Int
    let count: Int
    let ownerDbfId: Int
}

enum DeckstringFormat: Int {
    case wild = 1
    case standard = 2
    case classic = 3
    case twist = 4

    var gameFormat: GameFormat {
        switch self {
        case .wild: .wild
        case .standard: .standard
        case .classic: .classic
        case .twist: .twist
        }
    }

    init(format: GameFormat) {
        switch format {
        case .standard: self = .standard
        case .wild, .unknown: self = .wild
        case .classic: self = .classic
        case .twist: self = .twist
        }
    }
}

enum Deckstring {
    static func decode(_ code: String) throws -> DeckstringPayload {
        let cleaned = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw DeckstringError.empty }
        guard let data = Data(base64Encoded: cleaned) else { throw DeckstringError.invalidBase64 }
        var reader = VarintReader(data: data)
        guard try reader.readByte() == 0 else { throw DeckstringError.badReservedByte }
        guard try reader.readVarInt() == 1 else { throw DeckstringError.unsupportedVersion }
        guard let format = DeckstringFormat(rawValue: try reader.readVarInt()) else { throw DeckstringError.unknownFormat }

        let heroes = try (0..<reader.readVarInt()).map { _ in try reader.readVarInt() }
        var cards: [DeckstringCard] = []
        try (0..<reader.readVarInt()).forEach { _ in cards.append(DeckstringCard(dbfId: try reader.readVarInt(), count: 1)) }
        try (0..<reader.readVarInt()).forEach { _ in cards.append(DeckstringCard(dbfId: try reader.readVarInt(), count: 2)) }
        try (0..<reader.readVarInt()).forEach { _ in
            cards.append(DeckstringCard(dbfId: try reader.readVarInt(), count: try reader.readVarInt()))
        }

        var sideboards: [DeckstringSideboardCard] = []
        if !reader.isAtEnd, try reader.readVarInt() == 1 {
            try (0..<reader.readVarInt()).forEach { _ in
                sideboards.append(DeckstringSideboardCard(dbfId: try reader.readVarInt(), count: 1, ownerDbfId: try reader.readVarInt()))
            }
            try (0..<reader.readVarInt()).forEach { _ in
                sideboards.append(DeckstringSideboardCard(dbfId: try reader.readVarInt(), count: 2, ownerDbfId: try reader.readVarInt()))
            }
            try (0..<reader.readVarInt()).forEach { _ in
                sideboards.append(DeckstringSideboardCard(dbfId: try reader.readVarInt(), count: try reader.readVarInt(), ownerDbfId: try reader.readVarInt()))
            }
        }
        return DeckstringPayload(format: format, heroes: heroes, cards: cards, sideboards: sideboards)
    }

    static func encode(_ payload: DeckstringPayload) throws -> String {
        guard !payload.heroes.isEmpty else { throw DeckstringError.emptyHero }
        var writer = VarintWriter()
        writer.writeByte(0)
        writer.writeVarInt(1)
        writer.writeVarInt(payload.format.rawValue)
        writer.writeVarInt(payload.heroes.count)
        payload.heroes.forEach { writer.writeVarInt($0) }

        let x1 = payload.cards.filter { $0.count == 1 }.sorted { $0.dbfId < $1.dbfId }
        let x2 = payload.cards.filter { $0.count == 2 }.sorted { $0.dbfId < $1.dbfId }
        let xn = payload.cards.filter { $0.count > 2 }.sorted { $0.dbfId < $1.dbfId }
        writeGroup1(x1, to: &writer)
        writeGroup1(x2, to: &writer)
        writeGroupN(xn, to: &writer)
        return writer.data.base64EncodedString()
    }

    private static func writeGroup1(_ group: [DeckstringCard], to writer: inout VarintWriter) {
        writer.writeVarInt(group.count)
        group.forEach { writer.writeVarInt($0.dbfId) }
    }

    private static func writeGroupN(_ group: [DeckstringCard], to writer: inout VarintWriter) {
        writer.writeVarInt(group.count)
        group.forEach {
            writer.writeVarInt($0.dbfId)
            writer.writeVarInt($0.count)
        }
    }
}

enum DeckstringError: LocalizedError {
    case empty
    case invalidBase64
    case badReservedByte
    case unsupportedVersion
    case unknownFormat
    case truncated
    case varintTooLong
    case emptyHero

    var errorDescription: String? {
        switch self {
        case .empty: L10n.tr("Deck code is empty.")
        case .invalidBase64: L10n.tr("Deck code is not valid base64.")
        case .badReservedByte: L10n.tr("Deck code header is invalid.")
        case .unsupportedVersion: L10n.tr("Unsupported deck code version.")
        case .unknownFormat: L10n.tr("Unknown deck format.")
        case .truncated: L10n.tr("Deck code is truncated.")
        case .varintTooLong: L10n.tr("Deck code contains an invalid number.")
        case .emptyHero: L10n.tr("Deck must have a hero.")
        }
    }
}

private struct VarintReader {
    let bytes: [UInt8]
    var index = 0

    init(data: Data) {
        self.bytes = Array(data)
    }

    var isAtEnd: Bool { index >= bytes.count }

    mutating func readByte() throws -> Int {
        guard index < bytes.count else { throw DeckstringError.truncated }
        let byte = bytes[index]
        index += 1
        return Int(byte)
    }

    mutating func readVarInt() throws -> Int {
        var result = 0
        var shift = 0
        while true {
            let byte = try readByte()
            result |= (byte & 0x7F) << shift
            if (byte & 0x80) == 0 { return result }
            shift += 7
            if shift > 35 { throw DeckstringError.varintTooLong }
        }
    }
}

private struct VarintWriter {
    var data = Data()

    mutating func writeByte(_ byte: UInt8) {
        data.append(byte)
    }

    mutating func writeVarInt(_ value: Int) {
        var v = value
        while true {
            let low7 = UInt8(v & 0x7F)
            v = v >> 7
            if v == 0 {
                data.append(low7)
                return
            }
            data.append(low7 | 0x80)
        }
    }
}

final class PreferencesStore {
    private let key = "app-preferences-v1"

    func load() -> AppPreferences {
        guard let data = UserDefaults.standard.data(forKey: key),
              let prefs = try? JSONDecoder().decode(AppPreferences.self, from: data) else {
            return AppPreferences()
        }
        return prefs
    }

    func save(_ preferences: AppPreferences) {
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

final class SavedDeckStore {
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
    }

    func load() -> [DeckPreview] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? decoder.decode([DeckPreview].self, from: data)) ?? []
    }

    func save(_ decks: [DeckPreview]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(decks).write(to: url, options: [.atomic])
    }

    private var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SavedDecks", isDirectory: true)
            .appendingPathComponent("decks.json")
    }
}
