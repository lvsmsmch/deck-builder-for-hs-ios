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
    private let cacheCheckInterval: TimeInterval = 12 * 60 * 60

    init(session: URLSession = .shared) {
        self.session = session
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
    }

    func loadCards(locale: String, forceRefresh: Bool) async throws -> CardCacheSnapshot {
        let cached = try? loadCached(locale: locale)
        if !forceRefresh,
           let cached,
           !cached.cards.isEmpty,
           let lastCheckedAt = cached.info.lastCheckedAt,
           Date().timeIntervalSince(lastCheckedAt) < cacheCheckInterval {
            return cached
        }

        do {
            let latest = try await latestBuild()
            if !forceRefresh, let cached, !cached.cards.isEmpty, cached.info.build == latest {
                let updated = CardCacheSnapshot(
                    cards: cached.cards,
                    info: CardCacheInfo(
                        locale: locale,
                        build: latest,
                        fetchedAt: cached.info.fetchedAt,
                        lastCheckedAt: Date()
                    )
                )
                try cache(snapshot: updated)
                return updated
            }

            return try await fetchCards(locale: locale, build: latest)
        } catch {
            if !forceRefresh, let cached, !cached.cards.isEmpty {
                return cached
            }
            throw error
        }
    }

    private func latestBuild() async throws -> String {
        let url = URL(string: "https://api.hearthstonejson.com/v1/latest/")!
        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse).map({ 200..<300 ~= $0.statusCode }) == true else {
            throw URLError(.badServerResponse)
        }
        guard let html = String(data: data, encoding: .utf8),
              let regex = try? NSRegularExpression(pattern: #"href="/v1/(\d+)/?""#),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..<html.endIndex, in: html)),
              let range = Range(match.range(at: 1), in: html) else {
            throw URLError(.cannotParseResponse)
        }
        return String(html[range])
    }

    private func fetchCards(locale: String, build: String) async throws -> CardCacheSnapshot {
        let url = URL(string: "https://api.hearthstonejson.com/v1/\(build)/\(locale)/cards.json")!
        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse).map({ 200..<300 ~= $0.statusCode }) == true else {
            throw URLError(.badServerResponse)
        }
        let rows = try decoder.decode([HsJsonCardDTO].self, from: data)
        let cards = rows.compactMap { $0.toDomain(locale: locale) }
        let now = Date()
        let snapshot = CardCacheSnapshot(
            cards: cards,
            info: CardCacheInfo(locale: locale, build: build, fetchedAt: now, lastCheckedAt: now)
        )
        try cache(snapshot: snapshot)
        return snapshot
    }

    private func loadCached(locale: String) throws -> CardCacheSnapshot {
        let data = try Data(contentsOf: cacheURL(locale: locale))
        if let payload = try? decoder.decode(CardCachePayload.self, from: data) {
            return CardCacheSnapshot(cards: payload.cards, info: payload.info)
        }
        let cards = try decoder.decode([Card].self, from: data)
        return CardCacheSnapshot(
            cards: cards,
            info: CardCacheInfo(locale: locale, build: nil, fetchedAt: nil, lastCheckedAt: nil)
        )
    }

    private func cache(snapshot: CardCacheSnapshot) throws {
        let url = cacheURL(locale: snapshot.info.locale)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(CardCachePayload(cards: snapshot.cards, info: snapshot.info)).write(to: url, options: [.atomic])
    }

    private func cacheURL(locale: String) -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CardCache", isDirectory: true)
            .appendingPathComponent("cards-\(locale).json")
    }
}

struct CardCacheSnapshot {
    let cards: [Card]
    let info: CardCacheInfo
}

struct CardCacheInfo: Codable, Equatable {
    let locale: String
    let build: String?
    let fetchedAt: Date?
    let lastCheckedAt: Date?
}

private struct CardCachePayload: Codable {
    let cards: [Card]
    let info: CardCacheInfo
}

actor RotationService {
    private let sourceURL = URL(string: "https://raw.githubusercontent.com/HearthSim/python-hearthstone/master/hearthstone/utils/__init__.py")!
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(session: URLSession = .shared) {
        self.session = session
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
    }

    func standardSets(forceRefresh: Bool = false) async throws -> Set<String> {
        if !forceRefresh, let cached = try? loadCached(), !cached.standardSets.isEmpty {
            return Set(cached.standardSets)
        }

        let (data, response) = try await session.data(from: sourceURL)
        guard (response as? HTTPURLResponse).map({ 200..<300 ~= $0.statusCode }) == true else {
            throw RotationError.requestFailed
        }
        guard let source = String(data: data, encoding: .utf8) else {
            throw RotationError.invalidSource
        }
        let parsed = try parseStandardSets(source)
        try cache(StandardRotationCache(standardSets: Array(parsed).sorted(), fetchedAt: Date()))
        return parsed
    }

    private func parseStandardSets(_ source: String, now: Date = Date()) throws -> Set<String> {
        let standardByYear = try parseStandardSetsByYear(source)
        let year = parseCurrentZodiacYear(source, now: now) ?? standardByYear.keys.sorted().last
        guard let year, let sets = standardByYear[year], !sets.isEmpty else {
            throw RotationError.standardSetsMissing
        }
        return sets
    }

    private func parseStandardSetsByYear(_ source: String) throws -> [String: Set<String>] {
        let body = try dictionaryBody(named: "STANDARD_SETS", in: source)
        let regex = try NSRegularExpression(
            pattern: #"ZodiacYear\.([A-Z_]+)\s*:\s*\[([\s\S]*?)\]"#,
            options: []
        )
        let matches = regex.matches(in: body, range: NSRange(body.startIndex..<body.endIndex, in: body))
        var result: [String: Set<String>] = [:]

        for match in matches {
            guard let yearRange = Range(match.range(at: 1), in: body),
                  let setsRange = Range(match.range(at: 2), in: body) else { continue }
            let year = String(body[yearRange])
            let setTokens = try parseCardSetTokens(String(body[setsRange]))
            if !setTokens.isEmpty {
                result[year] = setTokens
            }
        }

        guard !result.isEmpty else { throw RotationError.standardSetsMissing }
        return result
    }

    private func parseCurrentZodiacYear(_ source: String, now: Date) -> String? {
        guard let body = try? dictionaryBody(named: "ZODIAC_ROTATION_DATES", in: source),
              let regex = try? NSRegularExpression(
                pattern: #"ZodiacYear\.([A-Z_]+)\s*:\s*(?:_EPOCH|datetime\((\d+),\s*(\d+),\s*(\d+)\))"#,
                options: []
              ) else {
            return nil
        }
        let matches = regex.matches(in: body, range: NSRange(body.startIndex..<body.endIndex, in: body))
        var current: (year: String, date: Date)?
        for match in matches {
            guard let yearRange = Range(match.range(at: 1), in: body) else { continue }
            let year = String(body[yearRange])
            let date: Date
            if match.range(at: 2).location == NSNotFound {
                date = Date(timeIntervalSince1970: 0)
            } else if let yRange = Range(match.range(at: 2), in: body),
                      let mRange = Range(match.range(at: 3), in: body),
                      let dRange = Range(match.range(at: 4), in: body),
                      let y = Int(body[yRange]),
                      let m = Int(body[mRange]),
                      let d = Int(body[dRange]) {
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
                date = calendar.date(from: DateComponents(year: y, month: m, day: d)) ?? .distantPast
            } else {
                continue
            }
            if date <= now, current == nil || date > current!.date {
                current = (year, date)
            }
        }
        return current?.year
    }

    private func parseCardSetTokens(_ body: String) throws -> Set<String> {
        let regex = try NSRegularExpression(pattern: #"CardSet\.([A-Z0-9_]+)"#)
        let matches = regex.matches(in: body, range: NSRange(body.startIndex..<body.endIndex, in: body))
        return Set(matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: body) else { return nil }
            return String(body[range])
        })
    }

    private func dictionaryBody(named name: String, in source: String) throws -> String {
        guard let startRange = source.range(of: "\(name) = {") else {
            throw RotationError.standardSetsMissing
        }
        var depth = 1
        let bodyStart = startRange.upperBound
        var index = startRange.upperBound
        while index < source.endIndex {
            let char = source[index]
            if char == "{" {
                depth += 1
            } else if char == "}" {
                depth -= 1
                if depth == 0 {
                    return String(source[bodyStart..<index])
                }
            }
            index = source.index(after: index)
        }
        throw RotationError.standardSetsMissing
    }

    private func loadCached() throws -> StandardRotationCache {
        let data = try Data(contentsOf: cacheURL)
        return try decoder.decode(StandardRotationCache.self, from: data)
    }

    private func cache(_ rotation: StandardRotationCache) throws {
        try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(rotation).write(to: cacheURL, options: [.atomic])
    }

    private var cacheURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Rotation", isDirectory: true)
            .appendingPathComponent("standard-sets.json")
    }
}

private struct StandardRotationCache: Codable {
    let standardSets: [String]
    let fetchedAt: Date
}

enum RotationError: LocalizedError {
    case requestFailed
    case invalidSource
    case standardSetsMissing

    var errorDescription: String? {
        switch self {
        case .requestFailed: L10n.tr("Rotation data failed to load.")
        case .invalidSource: L10n.tr("Rotation data is invalid.")
        case .standardSetsMissing: L10n.tr("Standard rotation sets were not found.")
        }
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
