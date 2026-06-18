import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var preferences: AppPreferences
    @Published private(set) var cards: [Card] = []
    @Published private(set) var isLoadingCards = false
    @Published private(set) var cardLoadError: String?
    @Published var savedDecks: [DeckPreview] = []

    private let hsJson = HsJsonService()
    private let preferencesStore = PreferencesStore()
    private let savedDeckStore = SavedDeckStore()
    private var cardIndexById: [Int: Card] = [:]
    private var cardIndexBySlug: [String: Card] = [:]
    private var lastLoadedLocale: String?

    init() {
        let prefs = preferencesStore.load()
        self.preferences = prefs
        self.savedDecks = savedDeckStore.load().sorted { $0.savedAt > $1.savedAt }
        Task { await loadCardsIfNeeded() }
    }

    func setTheme(_ theme: ThemeMode) {
        preferences.theme = theme
        preferencesStore.save(preferences)
    }

    func setCardLocale(_ locale: String) {
        guard preferences.cardLocale != locale else { return }
        preferences.cardLocale = locale
        preferencesStore.save(preferences)
        Task { await loadCardsIfNeeded(forceRefresh: false) }
    }

    func setCrashReporting(_ enabled: Bool) {
        preferences.crashReportingEnabled = enabled
        preferencesStore.save(preferences)
    }

    func loadCardsIfNeeded(forceRefresh: Bool = false) async {
        guard !isLoadingCards else { return }
        if !forceRefresh, !cards.isEmpty, lastLoadedLocale == preferences.cardLocale { return }
        isLoadingCards = true
        cardLoadError = nil
        do {
            let loaded = try await hsJson.loadCards(locale: preferences.cardLocale, forceRefresh: forceRefresh)
            installCards(loaded)
            lastLoadedLocale = preferences.cardLocale
        } catch {
            cardLoadError = error.localizedDescription
        }
        isLoadingCards = false
    }

    func refreshCards() {
        Task { await loadCardsIfNeeded(forceRefresh: true) }
    }

    func card(idOrSlug: String) -> Card? {
        if let id = Int(idOrSlug), let card = cardIndexById[id] { return card }
        let key = idOrSlug.lowercased()
        return cardIndexBySlug[key] ?? cards.first { $0.name.lowercased() == key }
    }

    func searchCards(filters: CardFilters, page: Int = 1, pageSize: Int = 60) async -> Page<Card> {
        await loadCardsIfNeeded()
        let matched = filteredCards(filters: filters)
        let total = matched.count
        let pageCount = max(1, Int(ceil(Double(total) / Double(pageSize))))
        let safePage = max(1, min(page, pageCount))
        let start = min((safePage - 1) * pageSize, total)
        let end = min(start + pageSize, total)
        return Page(items: Array(matched[start..<end]), pageNumber: safePage, pageCount: pageCount, totalCount: total)
    }

    func decodeDeck(code: String) async throws -> Deck {
        await loadCardsIfNeeded()
        let payload = try Deckstring.decode(code)
        return buildDeck(code: code.trimmingCharacters(in: .whitespacesAndNewlines), payload: payload)
    }

    func assembleDeck(ids: [Int], heroCardId: Int, format: GameFormat) throws -> Deck {
        let grouped = Dictionary(grouping: ids, by: { $0 }).map { DeckstringCard(dbfId: $0.key, count: $0.value.count) }
        let payload = DeckstringPayload(format: DeckstringFormat(format: format), heroes: [heroCardId], cards: grouped, sideboards: [])
        let code = try Deckstring.encode(payload)
        return buildDeck(code: code, payload: payload)
    }

    func save(deck: Deck, name: String? = nil) {
        let existing = savedDecks.first { $0.code == deck.code }
        let cardIds = deck.cards.flatMap { entry in Array(repeating: entry.card.id, count: entry.count) }
        let preview = DeckPreview(
            code: deck.code,
            name: name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? existing?.name ?? defaultDeckName(deck),
            classSlug: deck.heroClass?.slug,
            className: deck.heroClass?.name,
            heroCardId: deck.hero?.id ?? 0,
            heroSlug: deck.hero?.slug,
            format: deck.format,
            cardCount: deck.cardCount,
            maxCardCount: deck.maxCardCount,
            savedAt: Date(),
            cardIds: cardIds
        )
        savedDecks.removeAll { $0.code == deck.code }
        savedDecks.insert(preview, at: 0)
        persistSavedDecks()
    }

    func deleteDeck(code: String) {
        savedDecks.removeAll { $0.code == code }
        persistSavedDecks()
    }

    func renameDeck(code: String, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = savedDecks.firstIndex(where: { $0.code == code }) else { return }
        savedDecks[index].name = trimmed
        persistSavedDecks()
    }

    func clearImageCache() {
        URLCache.shared.removeAllCachedResponses()
    }

    private func installCards(_ loaded: [Card]) {
        cards = loaded
        cardIndexById = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
        cardIndexBySlug = Dictionary(uniqueKeysWithValues: loaded.map { ($0.slug.lowercased(), $0) })
    }

    private func buildDeck(code: String, payload: DeckstringPayload) -> Deck {
        let hero = payload.heroes.first.flatMap { cardIndexById[$0] }
        let invalid = (payload.heroes + payload.cards.map(\.dbfId)).filter { cardIndexById[$0] == nil }
        let entries = payload.cards.compactMap { payloadCard -> DeckCardEntry? in
            guard let card = cardIndexById[payloadCard.dbfId] else { return nil }
            return DeckCardEntry(card: card, count: payloadCard.count)
        }
        .sorted { lhs, rhs in
            lhs.card.manaCost == rhs.card.manaCost ? lhs.card.name < rhs.card.name : lhs.card.manaCost < rhs.card.manaCost
        }
        let heroClass = hero?.classes.first(where: { $0.slug != "neutral" }) ??
        entries.flatMap(\.card.classes).first(where: { $0.slug != "neutral" })
        return Deck(code: code, format: payload.format.gameFormat, hero: hero, heroClass: heroClass, cards: entries, invalidCardIds: invalid)
    }

    private func filteredCards(filters: CardFilters) -> [Card] {
        let q = filters.textQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let expandedMana = Set(filters.manaCosts.flatMap { $0 >= 7 ? Array(7...30) : [$0] })
        let rows = cards.filter { card in
            if filters.collectibleOnly && !card.collectible { return false }
            if !filters.classes.isEmpty {
                let cardClasses = Set(card.classes.map(\.slug))
                if cardClasses.isDisjoint(with: filters.classes.map(\.normalizedClassSlug)) { return false }
            }
            if !filters.sets.isEmpty, !(card.cardSet.map { filters.sets.contains($0.slug) } ?? false) { return false }
            if !filters.rarities.isEmpty, !(card.rarity.map { filters.rarities.contains($0.slug) } ?? false) { return false }
            if !filters.types.isEmpty, !filters.types.contains(card.cardType.slug) { return false }
            if !filters.minionTypes.isEmpty, !(card.minionType.map { filters.minionTypes.contains($0.slug) } ?? false) { return false }
            if !filters.spellSchools.isEmpty, !(card.spellSchool.map { filters.spellSchools.contains($0.slug) } ?? false) { return false }
            if !filters.keywords.isEmpty, Set(card.keywords.map(\.slug)).isDisjoint(with: filters.keywords) { return false }
            if !expandedMana.isEmpty, !expandedMana.contains(card.manaCost) { return false }
            if !q.isEmpty {
                let haystack = (card.name + " " + (card.text ?? "")).lowercased()
                if !haystack.contains(q) { return false }
            }
            if filters.format == .standard {
                let wildOnly = ["legacy", "vanilla", "expert1", "hall-of-fame", "naxx", "gvg", "brm", "tgt", "loe", "og", "kara", "gangs", "ungoro", "icecrown", "lootapalooza", "gilneas", "boomsday", "troll", "dalaraan", "uldum", "dragons"]
                if let set = card.cardSet?.slug, wildOnly.contains(set) { return false }
            }
            if filters.format == .wild {
                let standardish = ["core", "the-lost-city", "space", "island-vacation", "whizbangs-workshop", "wild-west", "titans", "festival-of-legends", "battle-of-the-bands"]
                if let set = card.cardSet?.slug, standardish.contains(set) { return false }
            }
            return true
        }
        return dedupeReprints(sort(rows, by: filters.sort))
    }

    private func sort(_ rows: [Card], by sort: CardSort) -> [Card] {
        let sorted: [Card]
        switch sort.key {
        case .manaCost:
            sorted = rows.sorted { $0.manaCost == $1.manaCost ? $0.name < $1.name : $0.manaCost < $1.manaCost }
        case .name:
            sorted = rows.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .dateAdded:
            sorted = rows.sorted { $0.id == $1.id ? $0.name < $1.name : $0.id > $1.id }
        case .groupByClass:
            sorted = rows.sorted {
                let l = $0.primaryClassSlug ?? ""
                let r = $1.primaryClassSlug ?? ""
                if l != r { return l < r }
                return $0.manaCost == $1.manaCost ? $0.name < $1.name : $0.manaCost < $1.manaCost
            }
        }
        return sort.direction == .ascending ? sorted : Array(sorted.reversed())
    }

    private func dedupeReprints(_ rows: [Card]) -> [Card] {
        var best: [String: Card] = [:]
        for card in rows where card.cardSet?.slug != "vanilla" {
            let key = [card.name.lowercased(), card.primaryClassSlug ?? "", "\(card.manaCost)", "\(card.attack ?? -1)", "\(card.health ?? -1)", card.cardType.slug, card.text?.lowercased() ?? ""].joined(separator: "|")
            guard let current = best[key] else {
                best[key] = card
                continue
            }
            let cardRank = card.cardSet?.slug == "core" ? 0 : 1
            let currentRank = current.cardSet?.slug == "core" ? 0 : 1
            if cardRank < currentRank || (cardRank == currentRank && card.id < current.id) {
                best[key] = card
            }
        }
        return rows.filter { card in best.values.contains(where: { $0.id == card.id }) }
    }

    private func defaultDeckName(_ deck: Deck) -> String {
        if let className = deck.heroClass?.name, !className.isEmpty {
            return L10n.classDeckName(className)
        }
        return L10n.tr("Untitled deck")
    }

    private func persistSavedDecks() {
        savedDecks.sort { $0.savedAt > $1.savedAt }
        try? savedDeckStore.save(savedDecks)
    }
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
