import Foundation
import SwiftUI

struct Card: Identifiable, Codable, Hashable {
    let id: Int
    let slug: String
    let name: String
    let text: String?
    let flavorText: String?
    let imageURL: URL?
    let cropImageURL: URL?
    let artistName: String?
    let manaCost: Int
    let attack: Int?
    let health: Int?
    let durability: Int?
    let armor: Int?
    let classes: [ClassMeta]
    let cardSet: Expansion?
    let rarity: Rarity?
    let cardType: CardType
    let minionType: MinionType?
    let spellSchool: SpellSchool?
    let keywords: [Keyword]
    let collectible: Bool
    let childIds: [String]

    var isLegendary: Bool { rarity?.slug == "legendary" }
    var isPrinceRenathal: Bool { slug.caseInsensitiveCompare("REV_018") == .orderedSame || slug.caseInsensitiveCompare("CORE_REV_018") == .orderedSame }
    var primaryClassSlug: String? { classes.first(where: { $0.slug != "neutral" })?.slug ?? classes.first?.slug }
    var isHiddenFromLibrary: Bool {
        if cardSet?.slug == "hero-skins" { return true }
        guard cardType.slug == "hero", text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true else {
            return false
        }
        return slug.range(of: #"^HERO_\d+[A-Za-z]*$"#, options: .regularExpression) != nil
    }
}

struct ClassMeta: Codable, Hashable {
    let id: Int
    let slug: String
    let name: String
    let heroCardId: Int?
}

struct Expansion: Codable, Hashable {
    let id: Int
    let slug: String
    let name: String
    let type: String?
}

struct Rarity: Codable, Hashable {
    let id: Int
    let slug: String
    let name: String
    let craftingCost: [Int]
}

struct CardType: Codable, Hashable {
    let id: Int
    let slug: String
    let name: String
}

struct MinionType: Codable, Hashable {
    let id: Int
    let slug: String
    let name: String
}

struct SpellSchool: Codable, Hashable {
    let id: Int
    let slug: String
    let name: String
}

struct Keyword: Codable, Hashable {
    let id: Int
    let slug: String
    let name: String
    let refText: String
}

enum GameFormat: String, Codable, CaseIterable, Identifiable {
    case standard
    case wild
    case classic
    case twist
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: L10n.tr("Standard")
        case .wild: L10n.tr("Wild")
        case .classic: L10n.tr("Classic")
        case .twist: L10n.tr("Twist")
        case .unknown: "-"
        }
    }
}

struct Deck: Codable, Hashable {
    let code: String
    let format: GameFormat
    let hero: Card?
    let heroClass: ClassMeta?
    let cards: [DeckCardEntry]
    let invalidCardIds: [Int]

    var cardCount: Int { cards.reduce(0) { $0 + $1.count } }
    var maxCardCount: Int { cards.contains(where: { $0.card.isPrinceRenathal }) ? 40 : 30 }
}

extension Deck: Identifiable {
    var id: String { code }
}

struct DeckCardEntry: Identifiable, Codable, Hashable {
    let card: Card
    var count: Int
    var id: Int { card.id }
}

struct DeckPreview: Identifiable, Codable, Hashable {
    let code: String
    var name: String
    let classSlug: String?
    let className: String?
    let heroCardId: Int
    let heroSlug: String?
    let format: GameFormat
    let cardCount: Int
    let maxCardCount: Int
    let savedAt: Date
    let cardIds: [Int]

    var id: String { code }
}

struct CardFilters: Equatable {
    var classes: Set<String> = []
    var sets: Set<String> = []
    var format: CardFormatFilter = .all
    var rarities: Set<String> = []
    var types: Set<String> = []
    var minionTypes: Set<String> = []
    var keywords: Set<String> = []
    var spellSchools: Set<String> = []
    var manaCosts: Set<Int> = []
    var collectibleOnly = true
    var textQuery = ""
    var sort = CardSort()

    var hasFilters: Bool {
        !classes.isEmpty || !sets.isEmpty || format != .all || !rarities.isEmpty || !types.isEmpty ||
        !minionTypes.isEmpty || !keywords.isEmpty || !spellSchools.isEmpty || !manaCosts.isEmpty ||
        !collectibleOnly || !textQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var activeFilterCount: Int {
        [
            !classes.isEmpty, !sets.isEmpty, format != .all, !rarities.isEmpty, !types.isEmpty,
            !minionTypes.isEmpty, !keywords.isEmpty, !spellSchools.isEmpty, !manaCosts.isEmpty,
            !collectibleOnly, !textQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ].filter { $0 }.count
    }
}

enum CardFormatFilter: String, CaseIterable, Identifiable {
    case all
    case standard
    case wild

    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: L10n.tr("All")
        case .standard: L10n.tr("Standard")
        case .wild: L10n.tr("Wild")
        }
    }
}

struct CardSort: Equatable {
    var key: SortKey = .manaCost
    var direction: SortDirection = .ascending
}

enum SortKey: String, CaseIterable {
    case manaCost
    case name
    case dateAdded
    case groupByClass
}

enum SortDirection {
    case ascending
    case descending
}

struct Page<T> {
    let items: [T]
    let pageNumber: Int
    let pageCount: Int
    let totalCount: Int
}

enum ThemeMode: String, Codable, CaseIterable, Identifiable {
    case system
    case dark
    case light

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .dark: .dark
        case .light: .light
        }
    }

    var label: String {
        switch self {
        case .system: L10n.tr("System default")
        case .dark: L10n.tr("Always dark")
        case .light: L10n.tr("Always light")
        }
    }
}

struct AppPreferences: Codable, Equatable {
    var theme: ThemeMode = .system
    var cardLocale = "enUS"
    var crashReportingEnabled = true
}

enum CardLocale: String, CaseIterable, Identifiable {
    case enUS
    case ruRU
    case deDE
    case esES
    case frFR

    var id: String { rawValue }
    var label: String {
        switch self {
        case .enUS: L10n.tr("English")
        case .ruRU: L10n.tr("Russian")
        case .deDE: L10n.tr("German")
        case .esES: L10n.tr("Spanish")
        case .frFR: L10n.tr("French")
        }
    }
}

enum ClassLabels {
    static let order = ["druid", "hunter", "mage", "paladin", "priest", "rogue", "shaman", "warlock", "warrior", "demonhunter", "deathknight"]

    static func label(_ slug: String?) -> String {
        switch slug?.normalizedClassSlug {
        case "druid": L10n.tr("Druid")
        case "hunter": L10n.tr("Hunter")
        case "mage": L10n.tr("Mage")
        case "paladin": L10n.tr("Paladin")
        case "priest": L10n.tr("Priest")
        case "rogue": L10n.tr("Rogue")
        case "shaman": L10n.tr("Shaman")
        case "warlock": L10n.tr("Warlock")
        case "warrior": L10n.tr("Warrior")
        case "demonhunter": L10n.tr("Demon Hunter")
        case "deathknight": L10n.tr("Death Knight")
        default: L10n.tr("Neutral")
        }
    }

    static func short(_ slug: String?) -> String {
        switch slug?.normalizedClassSlug {
        case "demonhunter": L10n.tr("Demon H.")
        case "deathknight": L10n.tr("Death K.")
        default: label(slug)
        }
    }
}

enum DefaultHeroes {
    static let cardIdByClass = [
        "warrior": "HERO_01", "shaman": "HERO_02", "rogue": "HERO_03", "paladin": "HERO_04",
        "hunter": "HERO_05", "druid": "HERO_06", "warlock": "HERO_07", "mage": "HERO_08",
        "priest": "HERO_09", "demonhunter": "HERO_10", "deathknight": "HERO_11"
    ]

    static let dbfIdByClass = [
        "warrior": 7, "shaman": 31, "rogue": 930, "paladin": 671, "hunter": 31127,
        "druid": 274, "warlock": 893, "mage": 637, "priest": 813, "demonhunter": 56550,
        "deathknight": 78065
    ]

    static func cardId(for slug: String?) -> String? {
        guard let key = slug?.normalizedClassSlug else { return nil }
        return cardIdByClass[key]
    }

    static func dbfId(for slug: String?) -> Int? {
        guard let key = slug?.normalizedClassSlug else { return nil }
        return dbfIdByClass[key]
    }

    static func imageName(cardId: String?, classSlug: String?) -> String? {
        if let classSlug, let name = imageName(for: classSlug) {
            return name
        }
        guard let cardId else { return nil }
        guard let match = cardIdByClass.first(where: { $0.value == cardId }) else { return nil }
        return imageName(for: match.key)
    }

    static func imageName(for slug: String?) -> String? {
        guard let key = slug?.normalizedClassSlug, cardIdByClass[key] != nil else { return nil }
        return "hero_\(key)"
    }
}

enum L10n {
    static func tr(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String.localizedStringWithFormat(tr(key), arguments)
    }

    static func cardsCount(_ count: Int) -> String {
        format("library.count.format", count)
    }

    static func deckWarningIncomplete(_ current: Int, _ max: Int) -> String {
        format("deck.warning.incomplete", current, max)
    }

    static func incompleteSaveMessage(_ current: Int, _ max: Int) -> String {
        format("builder.incomplete.save.message", current, max)
    }

    static func wrongClass(_ className: String) -> String {
        format("builder.wrongClass", className)
    }

    static func classDeckName(_ className: String) -> String {
        format("default.classDeckName", className)
    }
}

extension String {
    var domainSlug: String { lowercased().replacingOccurrences(of: "_", with: "-") }

    var normalizedClassSlug: String {
        lowercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
    }

    var displayToken: String {
        split { $0 == "_" || $0 == "-" }
            .map { part in
                let lower = part.lowercased()
                return lower.prefix(1).uppercased() + lower.dropFirst()
            }
            .joined(separator: " ")
    }

    func strippedCardText() -> String {
        replacingOccurrences(of: "[x]", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "\\s*(\\r?\\n|<\\s*br\\s*/?\\s*>)\\s*", with: " ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"<(?!\s*/?\s*[bi]\s*>)[^>]*>"#, with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"<\s*/?\s*[bi]\s*>"#, with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
