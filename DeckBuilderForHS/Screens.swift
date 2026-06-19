import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct RootView: View {
    @State private var selectedTab: AppTab = DebugLaunch.initialTab
    @State private var morePath: [MoreRoute] = DebugLaunch.initialMorePath
    @State private var debugStandaloneScreen: DebugStandaloneScreen? = DebugLaunch.initialStandaloneScreen

    var body: some View {
        ZStack {
            if let debugStandaloneScreen {
                debugStandaloneView(debugStandaloneScreen)
            } else {
                mainTabs
            }
        }
        .appBackground()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if debugStandaloneScreen == nil {
                AppBottomBar(selectedTab: $selectedTab)
            }
        }
    }

    @ViewBuilder
    private var mainTabs: some View {
        ZStack {
            NavigationStack { CardLibraryView() }
                .accessibilityIdentifier("screen.library")
                .opacity(selectedTab == .library ? 1 : 0)
                .allowsHitTesting(selectedTab == .library)

            NavigationStack { SavedDecksView() }
                .accessibilityIdentifier("screen.saved")
                .opacity(selectedTab == .saved ? 1 : 0)
                .allowsHitTesting(selectedTab == .saved)

            NavigationStack(path: $morePath) {
                MoreView()
                    .navigationDestination(for: MoreRoute.self) { route in
                        switch route {
                        case .settings:
                            SettingsView()
                        case .cardData:
                            CardDataView()
                        }
                    }
            }
            .accessibilityIdentifier("screen.more")
            .opacity(selectedTab == .more ? 1 : 0)
            .allowsHitTesting(selectedTab == .more)
        }
    }

    @ViewBuilder
    private func debugStandaloneView(_ screen: DebugStandaloneScreen) -> some View {
        switch screen {
        case .libraryFilters:
            DebugFilterSheetRoute { debugStandaloneScreen = nil }
                .accessibilityIdentifier("screen.library.filters")
        case .cardDetail:
            DebugCardDetailRoute { debugStandaloneScreen = nil }
                .accessibilityIdentifier("screen.card-detail")
        case .savedNewDialog:
            NavigationStack { SavedDecksView(debugState: .newDeckDialog) }
                .accessibilityIdentifier("screen.saved.new-dialog")
        case .savedImport:
            NavigationStack { SavedDecksView(debugState: .importSheet) }
                .accessibilityIdentifier("screen.saved.import")
        case .savedRename:
            NavigationStack { SavedDecksView(debugState: .renameAlert) }
                .accessibilityIdentifier("screen.saved.rename")
        case .deckView:
            DebugDeckRoute { debugStandaloneScreen = nil }
                .accessibilityIdentifier("screen.deck-view")
        case .deckViewToast:
            DebugDeckRoute(showsToast: true) { debugStandaloneScreen = nil }
                .accessibilityIdentifier("screen.deck-view.toast")
        case .builder:
            DeckBuilderView(onClose: { debugStandaloneScreen = nil }) { _ in }
                .accessibilityIdentifier("screen.builder")
        case .builderEditorDeck:
            DeckBuilderView(debugState: .editorDeck, onClose: { debugStandaloneScreen = nil }) { _ in }
                .accessibilityIdentifier("screen.builder.editor-deck")
        case .builderEditorPool:
            DeckBuilderView(debugState: .editorPool, onClose: { debugStandaloneScreen = nil }) { _ in }
                .accessibilityIdentifier("screen.builder.editor-pool")
        case .builderEditorPoolFilled:
            DeckBuilderView(debugState: .editorPoolFilled, onClose: { debugStandaloneScreen = nil }) { _ in }
                .accessibilityIdentifier("screen.builder.editor-pool-filled")
        case .builderIncompleteDialog:
            DeckBuilderView(debugState: .incompleteDialog, onClose: { debugStandaloneScreen = nil }) { _ in }
                .accessibilityIdentifier("screen.builder.incomplete-dialog")
        case .settingsClearDialog:
            NavigationStack { SettingsView(debugShowsClearDialog: true) }
                .accessibilityIdentifier("screen.settings.clear-dialog")
        }
    }
}

private enum DebugLaunch {
    static var initialTab: AppTab {
        switch screen {
        case .saved:
            .saved
        case .more, .settings, .cardData:
            .more
        case .library, .libraryFilters, .cardDetail, .savedNewDialog, .savedImport, .savedRename, .deckView,
             .deckViewToast, .builder, .builderEditorDeck, .builderEditorPool, .builderEditorPoolFilled,
             .builderIncompleteDialog, .settingsClearDialog, nil:
            .library
        }
    }

    static var initialMorePath: [MoreRoute] {
        switch screen {
        case .settings:
            [.settings]
        case .cardData:
            [.cardData]
        default:
            []
        }
    }

    static var initialStandaloneScreen: DebugStandaloneScreen? {
        switch screen {
        case .libraryFilters:
            .libraryFilters
        case .cardDetail:
            .cardDetail
        case .savedNewDialog:
            .savedNewDialog
        case .savedImport:
            .savedImport
        case .savedRename:
            .savedRename
        case .deckView:
            .deckView
        case .deckViewToast:
            .deckViewToast
        case .builder:
            .builder
        case .builderEditorDeck:
            .builderEditorDeck
        case .builderEditorPool:
            .builderEditorPool
        case .builderEditorPoolFilled:
            .builderEditorPoolFilled
        case .builderIncompleteDialog:
            .builderIncompleteDialog
        case .settingsClearDialog:
            .settingsClearDialog
        default:
            nil
        }
    }

    private static var screen: DebugLaunchScreen? {
        #if DEBUG
        let args = CommandLine.arguments
        if let index = args.firstIndex(where: { $0 == "--debug-screen" || $0 == "-debug-screen" }),
           args.indices.contains(index + 1) {
            return DebugLaunchScreen(rawValue: args[index + 1])
        }
        if let value = ProcessInfo.processInfo.environment["DB_DEBUG_SCREEN"] {
            return DebugLaunchScreen(rawValue: value)
        }
        #endif
        return nil
    }
}

private enum DebugLaunchScreen: String {
    case library
    case libraryFilters = "library-filters"
    case cardDetail = "card-detail"
    case saved
    case savedNewDialog = "saved-new-dialog"
    case savedImport = "saved-import"
    case savedRename = "saved-rename"
    case deckView = "deck-view"
    case deckViewToast = "deck-view-toast"
    case more
    case settings
    case settingsClearDialog = "settings-clear-dialog"
    case cardData = "card-data"
    case builder
    case builderEditorDeck = "builder-editor-deck"
    case builderEditorPool = "builder-editor-pool"
    case builderEditorPoolFilled = "builder-editor-pool-filled"
    case builderIncompleteDialog = "builder-incomplete-dialog"
}

private enum DebugStandaloneScreen {
    case libraryFilters
    case cardDetail
    case savedNewDialog
    case savedImport
    case savedRename
    case deckView
    case deckViewToast
    case builder
    case builderEditorDeck
    case builderEditorPool
    case builderEditorPoolFilled
    case builderIncompleteDialog
    case settingsClearDialog
}

private enum MoreRoute: Hashable {
    case settings
    case cardData
}

private enum AppTab: CaseIterable {
    case library
    case saved
    case more

    var title: String {
        switch self {
        case .library: L10n.tr("Library")
        case .saved: L10n.tr("Saved")
        case .more: L10n.tr("More")
        }
    }

    var icon: String {
        switch self {
        case .library: "square.grid.2x2"
        case .saved: "bookmark"
        case .more: "ellipsis"
        }
    }
}

private struct AppBottomBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            if selectedTab == tab {
                                Capsule()
                                    .fill(AppColor.primarySoft)
                                    .frame(width: 64, height: 32)
                            }
                            Image(systemName: tab.icon)
                                .font(.system(size: 22, weight: .semibold))
                        }
                        .frame(height: 34)
                        Text(tab.title)
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(selectedTab == tab ? AppColor.primary : AppColor.onSurfaceDimmer)
                    .frame(maxWidth: .infinity, minHeight: 64)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tab.\(tab.accessibilityID)")
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .background(AppColor.surfaceContainer.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppColor.outlineSoft)
                .frame(height: 1)
        }
    }
}

private extension AppTab {
    var accessibilityID: String {
        switch self {
        case .library:
            "library"
        case .saved:
            "saved"
        case .more:
            "more"
        }
    }
}

private struct DebugFilterSheetRoute: View {
    let onClose: () -> Void

    @State private var filters = CardFilters(
        format: .standard,
        rarities: ["legendary"],
        types: ["minion"],
        manaCosts: [3, 7],
        collectibleOnly: false,
        textQuery: "dragon"
    )

    var body: some View {
        FilterSheet(filters: $filters, onApply: onClose)
            .appBackground()
    }
}

private struct DebugCardDetailRoute: View {
    let onClose: () -> Void

    @EnvironmentObject private var app: AppModel
    @State private var card: Card?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if let card {
                    CardDetailView(card: card, onClose: onClose)
                } else if let error {
                    EmptyStateView(title: L10n.tr("Error"), bodyText: error, icon: "exclamationmark.triangle")
                } else {
                    ProgressView(L10n.tr("Loading cards..."))
                        .tint(AppColor.primary)
                }
            }
            .appBackground()
        }
        .task { await loadCard() }
    }

    @MainActor
    private func loadCard() async {
        guard card == nil, error == nil else { return }
        await app.loadCardsIfNeeded()
        let preferred = ["EX1_116", "CS2_029", "CORE_EX1_116"]
        card = preferred.lazy.compactMap { app.card(idOrSlug: $0) }.first ??
            app.cards.first { $0.collectible && !$0.isHiddenFromLibrary }
        if card == nil {
            error = L10n.tr("No cards loaded yet.")
        }
    }
}

private struct DebugDeckRoute: View {
    var showsToast = false
    let onClose: () -> Void

    @EnvironmentObject private var app: AppModel
    @State private var deck: Deck?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if let deck {
                    DeckView(deck: deck, onClose: onClose, debugShowsToast: showsToast)
                } else if let error {
                    EmptyStateView(title: L10n.tr("Error"), bodyText: error, icon: "exclamationmark.triangle")
                } else {
                    ProgressView(L10n.tr("Loading cards..."))
                        .tint(AppColor.primary)
                }
            }
            .appBackground()
        }
        .task { await loadDeck() }
    }

    @MainActor
    private func loadDeck() async {
        guard deck == nil, error == nil else { return }
        await app.loadCardsIfNeeded()
        var filters = CardFilters()
        filters.classes = ["mage", "neutral"]
        filters.collectibleOnly = true
        filters.format = .all
        let page = await app.searchCards(filters: filters, page: 1, pageSize: 40)
        let ids = Array(page.items.filter { !$0.isHiddenFromLibrary && $0.cardType.slug != "hero" }.prefix(30).map(\.id))
        guard let heroCardId = DefaultHeroes.dbfId(for: "mage"), !ids.isEmpty else {
            error = L10n.tr("No cards loaded yet.")
            return
        }
        do {
            deck = try app.assembleDeck(ids: ids, heroCardId: heroCardId, format: .wild)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct CardLibraryView: View {
    @EnvironmentObject private var app: AppModel
    @State private var filters = CardFilters()
    @State private var visibleCards: [Card] = []
    @State private var page = 1
    @State private var pageCount = 1
    @State private var totalCount = 0
    @State private var isLoading = false
    @State private var selectedCard: Card?
    @State private var showFilters = false
    @State private var searchRevision = 0

    private let columns = [GridItem(.adaptive(minimum: 112), spacing: 10)]

    var body: some View {
        VStack(spacing: 0) {
            libraryHeader
            SearchField(text: $filters.textQuery, placeholder: L10n.tr("Search cards by name or text..."))
                .padding(.bottom, 4)
            ManaChips(selected: filters.manaCosts) { toggle($0, in: &filters.manaCosts) }
            ClassChips(selected: filters.classes) { toggle($0.normalizedClassSlug, in: &filters.classes) }

            ZStack {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(visibleCards) { card in
                            CardThumbnail(card: card) { selectedCard = card }
                                .task {
                                    if card.id == visibleCards.last?.id {
                                        await loadNextPage()
                                    }
                                }
                        }
                        if page < pageCount {
                            ProgressView()
                                .tint(AppColor.primary)
                                .gridCellColumns(columns.count)
                                .padding()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 110)
                }
                if isLoading && visibleCards.isEmpty {
                    ProgressView(L10n.tr("Loading cards..."))
                        .tint(AppColor.primary)
                } else if visibleCards.isEmpty && !isLoading {
                    EmptyStateView(
                        title: filters.hasFilters ? L10n.tr("No cards match these filters.") : L10n.tr("No cards loaded yet."),
                        bodyText: app.cardLoadError ?? app.rotationLoadError ?? L10n.tr("Try changing search or filters."),
                        icon: "square.grid.2x2"
                    )
                }
            }
        }
        .appBackground()
        .sheet(item: $selectedCard) { card in
            NavigationStack { CardDetailView(card: card) }
        }
        .sheet(isPresented: $showFilters) {
            FilterSheet(filters: $filters)
                .presentationDetents([.medium, .large])
        }
        .task {
            if visibleCards.isEmpty {
                await reload()
            }
        }
        .onChange(of: filters) { _, _ in Task { await reload() } }
    }

    private var libraryHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(L10n.tr("Library"))
                    .font(.system(size: 22, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                sortMenu
                filterButton
            }
            Text(L10n.cardsCount(totalCount))
                .font(.caption)
                .foregroundStyle(AppColor.onSurfaceDim)
                .padding(.top, 4)
        }
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var sortMenu: some View {
        Menu {
            Button(L10n.tr("Mana asc")) { filters.sort = CardSort(key: .manaCost, direction: .ascending) }
            Button(L10n.tr("Mana desc")) { filters.sort = CardSort(key: .manaCost, direction: .descending) }
            Button(L10n.tr("Name")) { filters.sort = CardSort(key: .name, direction: .ascending) }
            Button(L10n.tr("Newest")) { filters.sort = CardSort(key: .dateAdded, direction: .ascending) }
            Button(L10n.tr("Oldest")) { filters.sort = CardSort(key: .dateAdded, direction: .descending) }
            Button(L10n.tr("By class")) { filters.sort = CardSort(key: .groupByClass, direction: .ascending) }
        } label: {
            Text(currentSortLabel)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppColor.onSurface)
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(AppColor.surfaceContainer)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppColor.outlineSoft, lineWidth: 1))
        }
    }

    private var filterButton: some View {
        Button { showFilters = true } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(AppColor.onSurface)
                    .frame(width: 44, height: 44)
                if filters.activeFilterCount > 0 {
                    Text("\(filters.activeFilterCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppColor.onPrimary)
                        .frame(width: 16, height: 16)
                        .background(AppColor.primary)
                        .clipShape(Circle())
                        .offset(x: -3, y: 3)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var currentSortLabel: String {
        switch (filters.sort.key, filters.sort.direction) {
        case (.manaCost, .ascending): L10n.tr("Mana asc")
        case (.manaCost, .descending): L10n.tr("Mana desc")
        case (.name, _): L10n.tr("Name")
        case (.dateAdded, .ascending): L10n.tr("Newest")
        case (.dateAdded, .descending): L10n.tr("Oldest")
        case (.groupByClass, _): L10n.tr("By class")
        }
    }

    private func reload() async {
        searchRevision += 1
        let revision = searchRevision
        isLoading = true
        page = 1
        let result = await app.searchCards(filters: filters, page: 1)
        guard revision == searchRevision else { return }
        visibleCards = result.items
        pageCount = result.pageCount
        totalCount = result.totalCount
        isLoading = false
    }

    private func loadNextPage() async {
        guard !isLoading, page < pageCount else { return }
        let revision = searchRevision
        isLoading = true
        let result = await app.searchCards(filters: filters, page: page + 1)
        guard revision == searchRevision else { return }
        page = result.pageNumber
        pageCount = result.pageCount
        totalCount = result.totalCount
        visibleCards += result.items
        isLoading = false
    }

    private func toggle<T: Hashable>(_ value: T, in set: inout Set<T>) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }
}

struct FilterSheet: View {
    @Binding var filters: CardFilters
    var onApply: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(L10n.tr("Reset all")) { filters = CardFilters(textQuery: filters.textQuery) }
                    .buttonStyle(FilterHeaderButtonStyle())
                    .accessibilityIdentifier("filters.reset")
                Spacer()
                Button(L10n.tr("Apply")) { close() }
                    .buttonStyle(FilterHeaderButtonStyle(isProminent: true))
                    .accessibilityIdentifier("filters.apply")
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(L10n.tr("Filters"))
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(AppColor.onSurface)
                        .padding(.bottom, 6)

                    SettingsGroup(title: L10n.tr("Format")) {
                        HStack(spacing: 8) {
                            ForEach(CardFormatFilter.allCases) { format in
                                formatButton(format)
                            }
                        }
                        .padding(8)
                    }

                    FilterSection(title: L10n.tr("Mana cost")) {
                        HStack(spacing: 6) {
                            ForEach(0...7, id: \.self) { cost in
                                let isSelected = filters.manaCosts.contains(cost)
                                Button {
                                    toggle(cost, in: &filters.manaCosts)
                                } label: {
                                    Text(cost == 7 ? "7+" : "\(cost)")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(isSelected ? AppColor.primary : AppColor.onSurfaceDim)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 42)
                                        .background(isSelected ? AppColor.primarySoft : AppColor.surfaceContainerHigh)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(isSelected ? AppColor.primary : AppColor.outlineSoft, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    chipSection(title: L10n.tr("Rarity"), options: rarityOptions, selection: $filters.rarities) { option in
                        L10n.tr(option.label)
                    } leadingColor: { option in
                        AppColor.rarityColor(option.value)
                    }

                    chipSection(title: L10n.tr("Type"), options: typeOptions, selection: $filters.types) { option in
                        L10n.tr(option.label)
                    }

                    chipSection(title: L10n.tr("Minion type"), options: minionTypeOptions, selection: $filters.minionTypes) { option in
                        L10n.tr(option.label)
                    }

                    chipSection(title: L10n.tr("Spell school"), options: spellSchoolOptions, selection: $filters.spellSchools) { option in
                        L10n.tr(option.label)
                    }

                    chipSection(title: L10n.tr("Set (recent)"), options: setOptions, selection: $filters.sets) { option in
                        setLabel(option.value)
                    }

                    FilterSection(title: L10n.tr("Show non-collectible")) {
                        FilterChip(
                            label: filters.collectibleOnly ? L10n.tr("Collectible only") : L10n.tr("All cards"),
                            isSelected: !filters.collectibleOnly
                        ) {
                            filters.collectibleOnly.toggle()
                        }
                    }
                }
                .padding(20)
            }
            .appBackground()
        }
        .appBackground()
    }

    private func close() {
        if let onApply {
            onApply()
        } else {
            dismiss()
        }
    }

    private func formatButton(_ format: CardFormatFilter) -> some View {
        let isSelected = filters.format == format

        return Button {
            filters.format = format
        } label: {
            Text(format.label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? AppColor.onPrimary : AppColor.onSurfaceDim)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(isSelected ? AppColor.primary : AppColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func chipSection(
        title: String,
        options: [FilterOption],
        selection: Binding<Set<String>>,
        label: @escaping (FilterOption) -> String,
        leadingColor: @escaping (FilterOption) -> Color? = { _ in nil }
    ) -> some View {
        FilterSection(title: title) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(options) { option in
                    let isSelected = selection.wrappedValue.contains(option.value)
                    FilterChip(label: label(option), isSelected: isSelected, leadingColor: leadingColor(option)) {
                        var next = selection.wrappedValue
                        toggle(option.value, in: &next)
                        selection.wrappedValue = next
                    }
                }
            }
        }
    }

    private func toggle<T: Hashable>(_ value: T, in set: inout Set<T>) {
        if set.contains(value) {
            set.remove(value)
        } else {
            set.insert(value)
        }
    }

    private func setLabel(_ slug: String) -> String {
        let key = "set.\(slug)"
        let localized = L10n.tr(key)
        if localized != key { return localized }
        return slug
            .split { $0 == "-" || $0 == "_" }
            .map { word in word.prefix(1).uppercased() + word.dropFirst() }
            .joined(separator: " ")
    }

    private var rarityOptions: [FilterOption] {
        [
            FilterOption("Common", "common"),
            FilterOption("Rare", "rare"),
            FilterOption("Epic", "epic"),
            FilterOption("Legendary", "legendary")
        ]
    }

    private var typeOptions: [FilterOption] {
        [
            FilterOption("Minion", "minion"),
            FilterOption("Spell", "spell"),
            FilterOption("Weapon", "weapon"),
            FilterOption("Hero", "hero"),
            FilterOption("Location", "location")
        ]
    }

    private var minionTypeOptions: [FilterOption] {
        [
            FilterOption("Beast", "beast"),
            FilterOption("Demon", "demon"),
            FilterOption("Dragon", "dragon"),
            FilterOption("Elemental", "elemental"),
            FilterOption("Mech", "mech"),
            FilterOption("Murloc", "murloc"),
            FilterOption("Naga", "naga"),
            FilterOption("Pirate", "pirate"),
            FilterOption("Quilboar", "quilboar"),
            FilterOption("Totem", "totem"),
            FilterOption("Undead", "undead")
        ]
    }

    private var spellSchoolOptions: [FilterOption] {
        [
            FilterOption("Arcane", "arcane"),
            FilterOption("Fire", "fire"),
            FilterOption("Frost", "frost"),
            FilterOption("Holy", "holy"),
            FilterOption("Nature", "nature"),
            FilterOption("Shadow", "shadow"),
            FilterOption("Fel", "fel")
        ]
    }

    private var setOptions: [FilterOption] {
        [
            "core", "expert1", "naxx", "gvg", "brm", "tgt", "loe", "og", "kara", "gangs",
            "ungoro", "icecrown", "lootapalooza", "gilneas", "boomsday", "troll", "dalaran",
            "uldum", "dragons", "black-temple", "scholomance", "darkmoon-faire", "the-barrens",
            "stormwind", "alterac-valley", "the-sunken-city", "revendreth",
            "return-of-the-lich-king", "battle-of-the-bands", "titans", "wild-west",
            "whizbangs-workshop", "island-vacation", "space", "the-lost-city"
        ].map { FilterOption($0, $0) }
    }
}

private struct FilterOption: Identifiable {
    let label: String
    let value: String

    var id: String { value }

    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }
}

private struct FilterSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppColor.onSurface)
            content
        }
    }
}

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    var leadingColor: Color?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let leadingColor {
                    Circle()
                        .fill(leadingColor)
                        .frame(width: 8, height: 8)
                }
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .foregroundStyle(isSelected ? AppColor.primary : AppColor.onSurfaceDim)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(isSelected ? AppColor.primarySoft : AppColor.surfaceContainerHigh)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isSelected ? AppColor.primary : AppColor.outlineSoft, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct FilterHeaderButtonStyle: ButtonStyle {
    var isProminent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isProminent ? AppColor.onPrimary : AppColor.onSurface)
            .padding(.horizontal, 16)
            .frame(height: 42)
            .background(isProminent ? AppColor.primary : AppColor.surfaceContainerHigh)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppColor.outlineSoft, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct CardDetailView: View {
    let card: Card
    var onClose: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CardImagePanel(card: card)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(card.name)
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(AppColor.onSurface)
                        Spacer()
                        if let rarity = card.rarity {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(AppColor.rarityColor(rarity.slug))
                                    .frame(width: 10, height: 10)
                                Text(rarity.name)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppColor.rarityColor(rarity.slug))
                            }
                        }
                    }
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppColor.onSurfaceDim)
                    if let text = card.text?.strippedCardText(), !text.isEmpty {
                        Text(text)
                            .font(.body)
                            .foregroundStyle(AppColor.onSurface)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .compactCard()
                    }
                    if let flavor = card.flavorText, !flavor.isEmpty {
                        Text(flavor.strippedCardText())
                            .font(.callout.italic())
                            .foregroundStyle(AppColor.onSurfaceDim)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.tr("Close")) { close() }
                    .accessibilityIdentifier("card-detail.close")
            }
        }
        .appBackground()
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private var subtitle: String {
        let type = card.cardType.name.isEmpty ? "" : card.cardType.name
        let cls = card.classes.map { ClassLabels.label($0.slug) }.joined(separator: " / ")
        let set = card.cardSet?.name ?? ""
        let artist = card.artistName.map { "\(L10n.tr("By")) \($0)" } ?? ""
        return [cls, type, set, artist].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

struct CardImagePanel: View {
    let card: Card

    var body: some View {
        ZStack {
            AppColor.surfaceContainer
            AsyncImage(url: highResolutionURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                case .failure:
                    Text(L10n.tr("Image failed to load"))
                        .foregroundStyle(AppColor.onSurfaceDim)
                default:
                    ProgressView().tint(AppColor.primary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 430)
        .padding(.top, 8)
    }

    private var highResolutionURL: URL? {
        guard let raw = card.imageURL?.absoluteString else { return nil }
        return URL(string: raw.replacingOccurrences(of: "/256x/", with: "/512x/"))
    }
}

struct SavedDecksView: View {
    @EnvironmentObject private var app: AppModel
    @State private var showNewDeck = false
    @State private var showImport = false
    @State private var showBuilder = false
    @State private var selectedDeck: Deck?
    @State private var importCode = ""
    @State private var importError: String?
    @State private var actionError: String?
    @State private var renameDeck: DeckPreview?
    @State private var renameText = ""

    fileprivate init(debugState: SavedDecksDebugState? = nil) {
        _showNewDeck = State(initialValue: debugState == .newDeckDialog)
        _showImport = State(initialValue: debugState == .importSheet)
        _renameDeck = State(initialValue: debugState == .renameAlert ? DeckPreview.debugSample : nil)
        _renameText = State(initialValue: debugState == .renameAlert ? DeckPreview.debugSample.name : "")
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                HStack {
                    Text(L10n.tr("Saved decks"))
                        .font(.title2.weight(.bold))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 8)

                if app.savedDecks.isEmpty {
                    EmptyStateView(
                        title: L10n.tr("No saved decks yet."),
                        bodyText: L10n.tr("Tap the + button to start a new deck or paste a deck code."),
                        icon: "bookmark"
                    )
                } else {
                    List {
                        ForEach(app.savedDecks) { deck in
                            SavedDeckRow(deck: deck) {
                                Task {
                                    do {
                                        selectedDeck = try await app.decodeDeck(code: deck.code)
                                    } catch {
                                        actionError = error.localizedDescription
                                    }
                                }
                            } onCopy: {
                                Clipboard.copy(deck.code)
                            } onRename: {
                                renameDeck = deck
                                renameText = deck.name
                            } onDelete: {
                                do {
                                    try app.deleteDeck(code: deck.code)
                                } catch {
                                    actionError = error.localizedDescription
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(AppColor.surface)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }

            Button { showNewDeck = true } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppColor.onPrimary)
                    .frame(width: 58, height: 58)
                    .background(AppColor.primary)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 104)
        }
        .appBackground()
        .sheet(isPresented: $showImport) { importSheet }
        .sheet(item: $selectedDeck) { deck in NavigationStack { DeckView(deck: deck) } }
        .sheet(isPresented: $showBuilder) {
            DeckBuilderView(onClose: { showBuilder = false }) { deck in
                showBuilder = false
                selectedDeck = deck
            }
        }
        .overlay {
            if showNewDeck {
                NewDeckDialog(
                    onCreate: {
                        showNewDeck = false
                        showBuilder = true
                    },
                    onImport: {
                        showNewDeck = false
                        showImport = true
                    },
                    onCancel: { showNewDeck = false }
                )
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
            if renameDeck != nil {
                RenameDeckDialog(
                    text: $renameText,
                    onSave: saveRename,
                    onCancel: { renameDeck = nil }
                )
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
            if let actionError {
                DarkMessageDialog(
                    title: L10n.tr("Error"),
                    message: actionError,
                    buttonTitle: L10n.tr("OK")
                ) {
                    self.actionError = nil
                }
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.26, dampingFraction: 0.9), value: showNewDeck)
        .animation(.spring(response: 0.26, dampingFraction: 0.9), value: renameDeck != nil)
        .animation(.spring(response: 0.26, dampingFraction: 0.9), value: actionError)
    }

    private func saveRename() {
        do {
            if let deck = renameDeck {
                try app.renameDeck(code: deck.code, name: renameText)
            }
            renameDeck = nil
        } catch {
            actionError = error.localizedDescription
        }
    }

    private var importSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(L10n.tr("Import deck"))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppColor.onSurface)
                    Spacer()
                    Button(L10n.tr("Close")) { showImport = false }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.primary)
                }
                Text(L10n.tr("Paste a Hearthstone deck code. Tap Decode to view and save it."))
                    .font(.subheadline)
                    .foregroundStyle(AppColor.onSurfaceDim)
                TextEditor(text: $importCode)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(AppColor.onSurface)
                    .tint(AppColor.primary)
                    .frame(minHeight: 150)
                    .padding(10)
                    .background(AppColor.surfaceContainer)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppColor.outlineSoft, lineWidth: 1))
                if let importError {
                    Text(importError)
                        .foregroundStyle(AppColor.error)
                        .font(.footnote)
                }
                Button {
                    Task {
                        do {
                            selectedDeck = try await app.decodeDeck(code: importCode)
                            showImport = false
                            importCode = ""
                            importError = nil
                        } catch {
                            importError = error.localizedDescription
                        }
                    }
                } label: {
                    Text(L10n.tr("Decode"))
                }
                .buttonStyle(PrimaryButtonStyle())
                Spacer()
            }
            .padding(20)
            .appBackground()
        }
    }
}

private struct NewDeckDialog: View {
    let onCreate: () -> Void
    let onImport: () -> Void
    let onCancel: () -> Void

    var body: some View {
        DarkDialogBackdrop(onDismiss: onCancel) {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.tr("New deck"))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppColor.onSurface)
                DialogActionButton(title: L10n.tr("Create from scratch"), systemImage: "plus.square.on.square", action: onCreate)
                DialogActionButton(title: L10n.tr("Paste deck code"), systemImage: "doc.on.doc", action: onImport)
                Button(L10n.tr("Cancel"), action: onCancel)
                    .font(.headline)
                    .foregroundStyle(AppColor.onSurfaceDim)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .padding(18)
            .dialogCard()
            .padding(.horizontal, 24)
        }
    }
}

private struct RenameDeckDialog: View {
    @Binding var text: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        DarkDialogBackdrop(onDismiss: onCancel) {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.tr("Rename deck"))
                    .font(.title2.weight(.bold))
                TextField(L10n.tr("Deck name"), text: $text)
                    .textFieldStyle(.plain)
                    .foregroundStyle(AppColor.onSurface)
                    .tint(AppColor.primary)
                    .padding(12)
                    .background(AppColor.surfaceContainerHigh)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(AppColor.outlineSoft, lineWidth: 1))
                HStack(spacing: 10) {
                    Button(L10n.tr("Cancel"), action: onCancel)
                        .buttonStyle(SecondaryDialogButtonStyle())
                    Button(L10n.tr("Save"), action: onSave)
                        .buttonStyle(PrimaryDialogButtonStyle())
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(18)
            .dialogCard()
            .padding(.horizontal, 24)
        }
    }
}

private struct DarkMessageDialog: View {
    let title: String
    let message: String
    let buttonTitle: String
    let onDismiss: () -> Void

    var body: some View {
        DarkDialogBackdrop(onDismiss: onDismiss) {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.title2.weight(.bold))
                Text(message)
                    .font(.body)
                    .foregroundStyle(AppColor.onSurfaceDim)
                Button(buttonTitle, action: onDismiss)
                    .buttonStyle(PrimaryDialogButtonStyle())
            }
            .padding(18)
            .dialogCard()
            .padding(.horizontal, 24)
        }
    }
}

private struct DarkConfirmDialog: View {
    let title: String
    let message: String
    let confirmTitle: String
    let cancelTitle: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        DarkDialogBackdrop(onDismiss: onCancel) {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.title2.weight(.bold))
                Text(message)
                    .font(.body)
                    .foregroundStyle(AppColor.onSurfaceDim)
                HStack(spacing: 10) {
                    Button(cancelTitle, action: onCancel)
                        .buttonStyle(SecondaryDialogButtonStyle())
                    Button(confirmTitle, action: onConfirm)
                        .buttonStyle(PrimaryDialogButtonStyle())
                }
            }
            .padding(18)
            .dialogCard()
            .padding(.horizontal, 24)
        }
    }
}

private struct ToastBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppColor.onSurface)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(AppColor.surfaceContainerHighest)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppColor.outlineSoft, lineWidth: 1))
            .shadow(color: .black.opacity(0.28), radius: 16, y: 8)
            .padding(.horizontal, 20)
    }
}

private struct DialogActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(AppColor.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 52)
                .padding(.horizontal, 14)
                .background(AppColor.surfaceContainerHigh)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(AppColor.outlineSoft, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct DarkDialogBackdrop<Content: View>: View {
    let onDismiss: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            content
        }
    }
}

private struct PrimaryDialogButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(isEnabled ? AppColor.onPrimary : AppColor.onSurfaceDimmer)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(isEnabled ? AppColor.primary.opacity(configuration.isPressed ? 0.78 : 1) : AppColor.surfaceContainerHighest)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct SecondaryDialogButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(AppColor.onSurface)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(AppColor.surfaceContainerHigh.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(AppColor.outlineSoft, lineWidth: 1))
    }
}

private extension View {
    func dialogCard() -> some View {
        background(AppColor.surfaceContainer)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppColor.outlineSoft, lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
    }
}

private enum SavedDecksDebugState {
    case newDeckDialog
    case importSheet
    case renameAlert
}

private extension DeckPreview {
    static let debugSample = DeckPreview(
        code: "AAEBAf0EAA==",
        name: "Debug Mage deck",
        classSlug: "mage",
        className: ClassLabels.label("mage"),
        heroCardId: DefaultHeroes.dbfId(for: "mage") ?? 637,
        heroSlug: DefaultHeroes.cardId(for: "mage"),
        format: .wild,
        cardCount: 12,
        maxCardCount: 30,
        savedAt: Date(),
        cardIds: []
    )
}

struct SavedDeckRow: View {
    let deck: DeckPreview
    let onOpen: () -> Void
    let onCopy: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColor.classColor(deck.classSlug))
                        .frame(width: 3, height: 44)
                    HeroTile(cardId: deck.heroSlug ?? DefaultHeroes.cardId(for: deck.classSlug), classSlug: deck.classSlug)
                        .frame(width: 96, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(deck.name)
                            .font(.headline)
                            .foregroundStyle(AppColor.onSurface)
                            .lineLimit(1)
                        HStack(spacing: 8) {
                            FormatChip(text: deck.format.displayName)
                            Text("\(ClassLabels.label(deck.classSlug)) - \(deck.cardCount)/\(deck.maxCardCount)")
                                .font(.caption)
                                .foregroundStyle(AppColor.onSurfaceDim)
                        }
                    }
                    Spacer()
                    Menu {
                        Button(L10n.tr("Copy code"), systemImage: "doc.on.doc", action: onCopy)
                        Button(L10n.tr("Rename"), systemImage: "pencil", action: onRename)
                        Button(L10n.tr("Delete"), systemImage: "trash", role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(AppColor.onSurfaceDim)
                            .frame(width: 34, height: 34)
                    }
                }
                if deck.cardCount < deck.maxCardCount {
                    Text(L10n.deckWarningIncomplete(deck.cardCount, deck.maxCardCount))
                        .font(.caption)
                        .foregroundStyle(Color(hex: 0xE0A23F))
                        .padding(.leading, 39)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

struct DeckView: View {
    @Environment(\.dismiss) private var dismiss
    let deck: Deck
    var onClose: (() -> Void)?

    @State private var selectedCard: Card?
    @State private var toastMessage: String?

    init(deck: Deck, onClose: (() -> Void)? = nil, debugShowsToast: Bool = false) {
        self.deck = deck
        self.onClose = onClose
        _toastMessage = State(initialValue: debugShowsToast ? L10n.tr("Deck code copied") : nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ZStack(alignment: .bottomLeading) {
                        HeroTile(cardId: deck.hero?.slug ?? DefaultHeroes.cardId(for: deck.heroClass?.slug), classSlug: deck.heroClass?.slug)
                            .frame(height: 150)
                        LinearGradient(colors: [.clear, .black.opacity(0.88)], startPoint: .top, endPoint: .bottom)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(ClassLabels.label(deck.heroClass?.slug))
                                .font(.title.weight(.bold))
                                .foregroundStyle(.white)
                            HStack {
                                FormatChip(text: deck.format.displayName)
                                Text("\(deck.cardCount)/\(deck.maxCardCount)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.72))
                            }
                        }
                        .padding(18)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 0))

                    VStack(spacing: 6) {
                        ForEach(deck.cards) { entry in
                            DeckCardRow(entry: entry) { selectedCard = entry.card }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            HStack(spacing: 10) {
                Button {
                    Clipboard.copy(deck.code)
                    showToast(L10n.tr("Deck code copied"))
                } label: {
                    Label(L10n.tr("Copy code"), systemImage: "doc.on.doc")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(12)
            .background(AppColor.surfaceContainer)
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.tr("Close")) { close() }
                    .accessibilityIdentifier("deck.close")
            }
        }
        .sheet(item: $selectedCard) { card in NavigationStack { CardDetailView(card: card) } }
        .overlay {
            if let toastMessage {
                ToastBanner(message: toastMessage)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 84)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.26, dampingFraction: 0.9), value: toastMessage)
        .appBackground()
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(for: .seconds(1.7))
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }
}

private enum Clipboard {
    static func copy(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }
}

struct DeckBuilderView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    let onClose: (() -> Void)?
    let onSaved: (Deck) -> Void
    private let debugState: DeckBuilderDebugState?

    @State private var phaseClassPicker = true
    @State private var chosenClass: String?
    @State private var heroCardId: Int?
    @State private var format: GameFormat = .standard
    @State private var singleton = false
    @State private var deck: [Int: DeckCardEntry] = [:]
    @State private var poolFilters = CardFilters(sort: CardSort(key: .manaCost, direction: .ascending))
    @State private var poolCards: [Card] = []
    @State private var poolTotal = 0
    @State private var poolSearchRevision = 0
    @State private var showPoolFilters = false
    @State private var activeTab = 0
    @State private var selectedCard: Card?
    @State private var alertMessage: String?
    @State private var confirmIncompleteSave = false
    @State private var debugSeededDeck = false

    fileprivate init(
        debugState: DeckBuilderDebugState? = nil,
        onClose: (() -> Void)? = nil,
        onSaved: @escaping (Deck) -> Void
    ) {
        self.onClose = onClose
        self.onSaved = onSaved
        self.debugState = debugState
        let startsInEditor = debugState == .editorDeck || debugState == .editorPool || debugState == .editorPoolFilled || debugState == .incompleteDialog
        _phaseClassPicker = State(initialValue: !startsInEditor)
        _chosenClass = State(initialValue: startsInEditor ? "mage" : nil)
        _heroCardId = State(initialValue: startsInEditor ? DefaultHeroes.dbfId(for: "mage") : nil)
        _activeTab = State(initialValue: debugState == .editorPool || debugState == .editorPoolFilled ? 1 : 0)
        _confirmIncompleteSave = State(initialValue: debugState == .incompleteDialog)
    }

    var body: some View {
        NavigationStack {
            Group {
                if phaseClassPicker { classPicker } else { editor }
            }
            .task {
                if !phaseClassPicker, poolCards.isEmpty {
                    await reloadPool()
                }
                seedDebugDeckIfNeeded()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(phaseClassPicker ? L10n.tr("Close") : L10n.tr("Back")) {
                        if phaseClassPicker { close() } else { phaseClassPicker = true }
                    }
                    .accessibilityIdentifier(phaseClassPicker ? "builder.close" : "builder.back")
                }
            }
            .overlay {
                if let alertMessage {
                    DarkMessageDialog(
                        title: L10n.tr("Deck builder"),
                        message: alertMessage,
                        buttonTitle: L10n.tr("OK")
                    ) {
                        self.alertMessage = nil
                    }
                }
                if confirmIncompleteSave {
                    DarkConfirmDialog(
                        title: L10n.tr("Save incomplete deck?"),
                        message: L10n.incompleteSaveMessage(cardCount, maxDeckSize),
                        confirmTitle: L10n.tr("Save anyway"),
                        cancelTitle: L10n.tr("Cancel"),
                        onConfirm: {
                            confirmIncompleteSave = false
                            saveDeck()
                        },
                        onCancel: { confirmIncompleteSave = false }
                    )
                }
            }
            .sheet(item: $selectedCard) { card in NavigationStack { CardDetailView(card: card) } }
            .sheet(isPresented: $showPoolFilters) {
                FilterSheet(filters: $poolFilters)
                    .presentationDetents([.medium, .large])
            }
            .appBackground()
        }
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private var classPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("New deck"))
                .font(.title2.weight(.bold))
                .padding(.horizontal, 20)
            Text(L10n.tr("Pick a class to begin."))
                .font(.subheadline)
                .foregroundStyle(AppColor.onSurfaceDim)
                .padding(.horizontal, 20)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(ClassLabels.order, id: \.self) { slug in
                    Button {
                        chosenClass = slug
                        heroCardId = DefaultHeroes.dbfId(for: slug)
                        phaseClassPicker = false
                        Task { await reloadPool() }
                    } label: {
                        ZStack(alignment: .bottomLeading) {
                            HeroTile(cardId: DefaultHeroes.cardId(for: slug), classSlug: slug)
                            LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                            Text(ClassLabels.label(slug))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(8)
                        }
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            Spacer()
        }
        .padding(.top, 16)
    }

    private var editor: some View {
        VStack(spacing: 0) {
            builderHeader
            builderTabSelector
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            if activeTab == 0 { deckPane } else { poolPane }
            bottomActions
        }
    }

    private var builderTabSelector: some View {
        HStack(spacing: 6) {
            builderTabButton(title: L10n.tr("Deck"), tab: 0)
            builderTabButton(title: L10n.tr("Pool"), tab: 1)
        }
        .padding(6)
        .frame(height: 48)
        .background(AppColor.surfaceContainer)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppColor.outlineSoft, lineWidth: 1))
    }

    private func builderTabButton(title: String, tab: Int) -> some View {
        let isSelected = activeTab == tab

        return Button {
            activeTab = tab
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? AppColor.onPrimary : AppColor.onSurfaceDim)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(isSelected ? AppColor.primary : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var builderHeader: some View {
        HStack(spacing: 12) {
            HeroTile(cardId: DefaultHeroes.cardId(for: chosenClass), classSlug: chosenClass)
                .frame(width: 82, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(ClassLabels.label(chosenClass))
                    .font(.headline)
                Text("\(cardCount) / \(maxDeckSize)")
                    .font(.caption)
                    .foregroundStyle(AppColor.onSurfaceDim)
            }
            Spacer()
            Menu {
                ForEach(GameFormat.allCases.filter { $0 != .unknown }) { nextFormat in
                    Button(nextFormat.displayName) {
                        format = nextFormat
                        Task { await reloadPool() }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(format.displayName)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColor.primary)
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(AppColor.primarySoft)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            Button {
                singleton.toggle()
                if singleton {
                    deck = deck.mapValues { DeckCardEntry(card: $0.card, count: 1) }
                }
            } label: {
                Text("*1")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(singleton ? AppColor.rarityColor("legendary") : AppColor.onSurfaceDim)
                    .padding(.horizontal, 11)
                    .frame(height: 34)
                    .background(singleton ? AppColor.rarityColor("legendary").opacity(0.18) : AppColor.surfaceContainerHigh)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(singleton ? AppColor.rarityColor("legendary") : AppColor.outlineSoft, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    private var deckPane: some View {
        Group {
            if deckEntries.isEmpty {
                EmptyStateView(
                    title: L10n.tr("Empty deck."),
                    bodyText: L10n.tr("Switch to the Pool tab and tap cards to add them."),
                    icon: "rectangle.stack.badge.plus"
                )
            } else {
                List {
                    ForEach(deckEntries) { entry in
                        DeckCardRow(entry: entry) { remove(entry.card) }
                            .swipeActions { Button(L10n.tr("Remove"), role: .destructive) { remove(entry.card) } }
                            .listRowBackground(AppColor.surface)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var poolPane: some View {
        VStack(spacing: 0) {
            SearchField(text: $poolFilters.textQuery, placeholder: L10n.tr("Search pool"))
            builderPoolControls
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 10)], spacing: 10) {
                    ForEach(poolCards) { card in
                        let count = deck[card.id]?.count ?? 0
                        ZStack(alignment: .topTrailing) {
                            CardThumbnail(card: card) { add(card) }
                            if count > 0 {
                                Text("x\(count)")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(AppColor.onPrimary)
                                    .frame(width: 34, height: 30)
                                    .background(AppColor.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(AppColor.onPrimary.opacity(0.7), lineWidth: 1))
                                    .padding(7)
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(count > 0 ? AppColor.primary : Color.clear, lineWidth: 2)
                        )
                            .contextMenu {
                                Button(L10n.tr("Details")) { selectedCard = card }
                            }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 16)
            }
        }
        .onChange(of: poolFilters) { _, _ in Task { await reloadPool() } }
    }

    private var builderPoolControls: some View {
        HStack(spacing: 8) {
            Text(L10n.cardsCount(poolTotal))
                .font(.caption)
                .foregroundStyle(AppColor.onSurfaceDim)
                .frame(maxWidth: .infinity, alignment: .leading)
            Menu {
                Button(L10n.tr("Mana asc")) { poolFilters.sort = CardSort(key: .manaCost, direction: .ascending) }
                Button(L10n.tr("Mana desc")) { poolFilters.sort = CardSort(key: .manaCost, direction: .descending) }
                Button(L10n.tr("Name")) { poolFilters.sort = CardSort(key: .name, direction: .ascending) }
                Button(L10n.tr("Newest")) { poolFilters.sort = CardSort(key: .dateAdded, direction: .ascending) }
                Button(L10n.tr("Oldest")) { poolFilters.sort = CardSort(key: .dateAdded, direction: .descending) }
            } label: {
                Text(builderPoolSortLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppColor.onSurface)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(AppColor.surfaceContainer)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppColor.outlineSoft, lineWidth: 1))
            }
            Button { showPoolFilters = true } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 21, weight: .medium))
                        .foregroundStyle(AppColor.onSurface)
                        .frame(width: 42, height: 42)
                    if poolFilters.activeFilterCount > 0 {
                        Text("\(poolFilters.activeFilterCount)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(AppColor.onPrimary)
                            .frame(width: 16, height: 16)
                            .background(AppColor.primary)
                            .clipShape(Circle())
                            .offset(x: -3, y: 3)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var builderPoolSortLabel: String {
        switch (poolFilters.sort.key, poolFilters.sort.direction) {
        case (.manaCost, .ascending): L10n.tr("Mana asc")
        case (.manaCost, .descending): L10n.tr("Mana desc")
        case (.name, _): L10n.tr("Name")
        case (.dateAdded, .ascending): L10n.tr("Newest")
        case (.dateAdded, .descending): L10n.tr("Oldest")
        case (.groupByClass, _): L10n.tr("By class")
        }
    }

    private var bottomActions: some View {
        VStack(spacing: 6) {
            if let alertMessage {
                Text(alertMessage)
                    .font(.caption)
                    .foregroundStyle(AppColor.error)
            }
            Button {
                if cardCount < maxDeckSize { confirmIncompleteSave = true } else { saveDeck() }
            } label: {
                Text(L10n.tr("Save"))
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(cardCount == 0)
        }
        .padding(12)
        .background(AppColor.surfaceContainer)
    }

    private var deckEntries: [DeckCardEntry] {
        deck.values.sorted { $0.card.manaCost == $1.card.manaCost ? $0.card.name < $1.card.name : $0.card.manaCost < $1.card.manaCost }
    }

    private var cardCount: Int { deck.values.reduce(0) { $0 + $1.count } }
    private var maxDeckSize: Int { deck.values.contains(where: { $0.card.isPrinceRenathal }) ? 40 : 30 }

    private func reloadPool() async {
        guard let chosenClass else { return }
        poolSearchRevision += 1
        let revision = poolSearchRevision
        var filters = poolFilters
        filters.classes = [chosenClass, "neutral"]
        filters.collectibleOnly = true
        let result = await app.searchCards(filters: filters, page: 1, pageSize: 90)
        guard revision == poolSearchRevision else { return }
        poolCards = result.items.filter { !isDefaultHero($0) }
        poolTotal = result.totalCount
    }

    private func add(_ card: Card) {
        guard let chosenClass else { return }
        let cardClasses = Set(card.classes.map(\.slug))
        guard cardClasses.contains(chosenClass) || cardClasses.contains("neutral") || cardClasses.isEmpty else {
            alertMessage = L10n.wrongClass(ClassLabels.label(chosenClass))
            return
        }
        let current = deck[card.id]?.count ?? 0
        let cap = singleton || card.isLegendary ? 1 : 2
        guard current < cap else {
            alertMessage = card.isLegendary ? L10n.tr("Legendary limit (x1)") : L10n.tr("Card limit (x2)")
            return
        }
        guard cardCount < max(card.isPrinceRenathal ? 40 : maxDeckSize, maxDeckSize) else {
            alertMessage = L10n.tr("Deck is full")
            return
        }
        deck[card.id] = DeckCardEntry(card: card, count: current + 1)
    }

    private func remove(_ card: Card) {
        guard let entry = deck[card.id] else { return }
        if entry.count <= 1 { deck.removeValue(forKey: card.id) } else { deck[card.id] = DeckCardEntry(card: card, count: entry.count - 1) }
    }

    private func saveDeck() {
        guard let heroCardId else { return }
        do {
            let ids = deckEntries.flatMap { Array(repeating: $0.card.id, count: $0.count) }
            let built = try app.assembleDeck(ids: ids, heroCardId: heroCardId, format: format)
            try app.save(deck: built)
            onSaved(built)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func seedDebugDeckIfNeeded() {
        #if DEBUG
        guard debugState == .editorPoolFilled, !debugSeededDeck else { return }
        guard let card = poolCards.first(where: { $0.collectible && $0.cardType.slug != "hero" }) else { return }
        let count = card.isLegendary || singleton ? 1 : 2
        deck[card.id] = DeckCardEntry(card: card, count: count)
        debugSeededDeck = true
        #endif
    }

    private func isDefaultHero(_ card: Card) -> Bool {
        card.cardType.slug == "hero" && (card.text?.isEmpty ?? true) && card.slug.hasPrefix("HERO_")
    }
}

private enum DeckBuilderDebugState {
    case editorDeck
    case editorPool
    case editorPoolFilled
    case incompleteDialog
}

struct MoreView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.tr("More"))
                .font(.system(size: 22, weight: .semibold))
                .padding(.leading, 20)
                .padding(.trailing, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            VStack(spacing: 10) {
                NavigationLink(value: MoreRoute.settings) {
                    MoreHubRow(
                        icon: "gearshape",
                        title: L10n.tr("Settings"),
                        subtitle: L10n.tr("Theme, language, privacy")
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("more.settings")

                NavigationLink(value: MoreRoute.cardData) {
                    MoreHubRow(
                        icon: "curlybraces",
                        title: L10n.tr("Card data"),
                        subtitle: L10n.tr("Build, last update check")
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("more.card-data")
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .appBackground()
        .accessibilityIdentifier("screen.more.root")
    }
}

struct MoreHubRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(AppColor.onSurface)
                .frame(width: 36, height: 36)
                .background(AppColor.surfaceContainerHigh)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppColor.onSurface)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppColor.onSurfaceDim)
            }
            Spacer()
            Text("›")
                .font(.title2)
                .foregroundStyle(AppColor.onSurfaceDimmer)
        }
        .padding(14)
        .background(AppColor.surfaceContainer)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppColor.outlineSoft, lineWidth: 1))
    }
}

struct SettingsView: View {
    @EnvironmentObject private var app: AppModel
    @State private var confirmClearImageCache = false
    @State private var toastMessage: String?

    fileprivate init(debugShowsClearDialog: Bool = false) {
        _confirmClearImageCache = State(initialValue: debugShowsClearDialog)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsGroup(title: L10n.tr("Appearance")) {
                    SettingsRow(title: L10n.tr("Theme")) {
                        Picker(L10n.tr("Theme"), selection: Binding(get: { app.preferences.theme }, set: app.setTheme)) {
                            ForEach(ThemeMode.allCases) { theme in Text(theme.label).tag(theme) }
                        }
                        .labelsHidden()
                        .tint(AppColor.primary)
                    }
                }

                SettingsGroup(title: L10n.tr("Language")) {
                    SettingsRow(title: L10n.tr("Card language")) {
                        Picker(L10n.tr("Card language"), selection: Binding(get: { app.preferences.cardLocale }, set: app.setCardLocale)) {
                            ForEach(CardLocale.allCases) { locale in Text(locale.label).tag(locale.rawValue) }
                        }
                        .labelsHidden()
                        .tint(AppColor.primary)
                    }
                }

                SettingsGroup(title: L10n.tr("Privacy")) {
                    SettingsRow(title: L10n.tr("Send error reports")) {
                        Toggle("", isOn: Binding(get: { app.preferences.crashReportingEnabled }, set: app.setCrashReporting))
                            .labelsHidden()
                            .tint(AppColor.primary)
                    }
                }

                SettingsGroup(title: L10n.tr("Storage")) {
                    Button(role: .destructive) {
                        confirmClearImageCache = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "trash")
                            Text(L10n.tr("Clear image cache"))
                            Spacer()
                        }
                        .font(.body)
                        .foregroundStyle(AppColor.error)
                        .padding(14)
                    }
                }

                SettingsGroup(title: L10n.tr("About")) {
                    SettingsInfoRow(title: L10n.tr("Version"), value: "1.0")
                    SettingsDivider()
                    Link("iamajavagod@gmail.com", destination: URL(string: "mailto:iamajavagod@gmail.com")!)
                        .font(.body)
                        .foregroundStyle(AppColor.primary)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .navigationTitle(L10n.tr("Settings"))
        .appBackground()
        .accessibilityIdentifier("screen.settings")
        .overlay {
            if confirmClearImageCache {
                DarkConfirmDialog(
                    title: L10n.tr("Clear image cache?"),
                    message: L10n.tr("Cached card and hero images will be downloaded again when needed."),
                    confirmTitle: L10n.tr("Clear"),
                    cancelTitle: L10n.tr("Cancel"),
                    onConfirm: {
                        confirmClearImageCache = false
                        app.clearImageCache()
                        showToast(L10n.tr("Image cache cleared"))
                    },
                    onCancel: { confirmClearImageCache = false }
                )
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
            if let toastMessage {
                ToastBanner(message: toastMessage)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.26, dampingFraction: 0.9), value: confirmClearImageCache)
        .animation(.spring(response: 0.26, dampingFraction: 0.9), value: toastMessage)
    }

    private func showToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(for: .seconds(1.7))
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }
}

struct CardDataView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsGroup(title: L10n.tr("Card data")) {
                    SettingsInfoRow(title: L10n.tr("Cards loaded"), value: "\(app.cards.count)")
                    SettingsDivider()
                    SettingsInfoRow(title: L10n.tr("Locale"), value: app.preferences.cardLocale)
                    SettingsDivider()
                    SettingsInfoRow(title: L10n.tr("Build"), value: app.cardCacheInfo?.build ?? "-")
                    SettingsDivider()
                    SettingsInfoRow(title: L10n.tr("Downloaded"), value: formatted(app.cardCacheInfo?.fetchedAt))
                    SettingsDivider()
                    SettingsInfoRow(title: L10n.tr("Last update check"), value: formatted(app.cardCacheInfo?.lastCheckedAt))
                    SettingsDivider()
                    Button {
                        app.refreshCards()
                    } label: {
                        HStack(spacing: 12) {
                            if app.isLoadingCards {
                                ProgressView()
                                    .tint(AppColor.primary)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text(L10n.tr("Refresh card data"))
                            Spacer()
                        }
                        .font(.body.weight(.medium))
                        .foregroundStyle(AppColor.primary)
                        .padding(14)
                    }
                    .disabled(app.isLoadingCards)
                }

                if let error = app.cardLoadError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(AppColor.error)
                        .padding(.horizontal, 4)
                }
                if let error = app.rotationLoadError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(AppColor.error)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .navigationTitle(L10n.tr("Card data"))
        .appBackground()
        .accessibilityIdentifier("screen.card-data")
    }

    private func formatted(_ date: Date?) -> String {
        guard let date else { return "-" }
        return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppColor.onSurface)
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                content
            }
            .background(AppColor.surfaceContainer)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppColor.outlineSoft, lineWidth: 1))
        }
    }
}

private struct SettingsRow<Trailing: View>: View {
    let title: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.body)
                .foregroundStyle(AppColor.onSurface)
            Spacer()
            trailing
        }
        .padding(14)
        .frame(minHeight: 54)
    }
}

private struct SettingsInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.body)
                .foregroundStyle(AppColor.onSurface)
            Spacer()
            Text(value)
                .font(.body)
                .foregroundStyle(AppColor.onSurfaceDim)
                .multilineTextAlignment(.trailing)
        }
        .padding(14)
        .frame(minHeight: 54)
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppColor.outlineSoft)
            .frame(height: 1)
            .padding(.leading, 14)
    }
}
