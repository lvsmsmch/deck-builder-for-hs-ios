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
        switch selectedTab {
        case .library:
            NavigationStack { CardLibraryView() }
                .accessibilityIdentifier("screen.library")
        case .saved:
            NavigationStack { SavedDecksView() }
                .accessibilityIdentifier("screen.saved")
        case .more:
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
        }
    }

    @ViewBuilder
    private func debugStandaloneView(_ screen: DebugStandaloneScreen) -> some View {
        switch screen {
        case .builder:
            DeckBuilderView { _ in }
                .accessibilityIdentifier("screen.builder")
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
        case .library, .builder, nil:
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
        case .builder:
            .builder
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
    case saved
    case more
    case settings
    case cardData = "card-data"
    case builder
}

private enum DebugStandaloneScreen {
    case builder
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

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            libraryHeader
            SearchField(text: $filters.textQuery, placeholder: L10n.tr("Search cards by name or text..."))
                .padding(.bottom, 4)
            ManaChips(selected: filters.manaCosts) { toggle($0, in: &filters.manaCosts) }
            ClassChips(selected: filters.classes) { toggle($0.normalizedClassSlug, in: &filters.classes) }

            ZStack {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
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
                    .padding(.bottom, 16)
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
        .task { await reload() }
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
        isLoading = true
        page = 1
        let result = await app.searchCards(filters: filters, page: 1)
        visibleCards = result.items
        pageCount = result.pageCount
        totalCount = result.totalCount
        isLoading = false
    }

    private func loadNextPage() async {
        guard !isLoading, page < pageCount else { return }
        isLoading = true
        let result = await app.searchCards(filters: filters, page: page + 1)
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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.tr("Format")) {
                    Picker("", selection: $filters.format) {
                        ForEach(CardFormatFilter.allCases) { format in
                            Text(format.label).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section(L10n.tr("Rarity")) {
                    multiRow("Common", "common", selection: $filters.rarities)
                    multiRow("Rare", "rare", selection: $filters.rarities)
                    multiRow("Epic", "epic", selection: $filters.rarities)
                    multiRow("Legendary", "legendary", selection: $filters.rarities)
                }
                Section(L10n.tr("Type")) {
                    multiRow("Minion", "minion", selection: $filters.types)
                    multiRow("Spell", "spell", selection: $filters.types)
                    multiRow("Weapon", "weapon", selection: $filters.types)
                    multiRow("Hero", "hero", selection: $filters.types)
                    multiRow("Location", "location", selection: $filters.types)
                }
                Section {
                    Toggle(L10n.tr("Collectible only"), isOn: $filters.collectibleOnly)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColor.surface)
            .navigationTitle(L10n.tr("Filters"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("Reset all")) { filters = CardFilters(textQuery: filters.textQuery) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("Apply")) { dismiss() }
                }
            }
        }
    }

    private func multiRow(_ label: String, _ value: String, selection: Binding<Set<String>>) -> some View {
        Button {
            if selection.wrappedValue.contains(value) {
                selection.wrappedValue.remove(value)
            } else {
                selection.wrappedValue.insert(value)
            }
        } label: {
            HStack {
                Text(L10n.tr(label))
                Spacer()
                if selection.wrappedValue.contains(value) {
                    Image(systemName: "checkmark")
                }
            }
        }
        .foregroundStyle(AppColor.onSurface)
    }
}

struct CardDetailView: View {
    let card: Card
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
                    statsGrid
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L10n.tr("Close")) { dismiss() } } }
        .appBackground()
    }

    private var subtitle: String {
        let type = card.cardType.name.isEmpty ? "" : card.cardType.name
        let cls = card.classes.map { ClassLabels.label($0.slug) }.joined(separator: " / ")
        let set = card.cardSet?.name ?? ""
        return [cls, type, set].filter { !$0.isEmpty }.joined(separator: " - ")
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
            stat("Mana", card.manaCost)
            if let attack = card.attack { stat("Attack", attack) }
            if let health = card.health { stat("Health", health) }
            if let durability = card.durability { stat("Durability", durability) }
            if let armor = card.armor { stat("Armor", armor) }
        }
        .padding(.top, 4)
    }

    private func stat(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 3) {
            Text("\(value)")
                .font(.headline.weight(.bold))
            Text(L10n.tr(label))
                .font(.caption)
                .foregroundStyle(AppColor.onSurfaceDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .compactCard()
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
            .padding(20)
        }
        .appBackground()
        .confirmationDialog(L10n.tr("New deck"), isPresented: $showNewDeck) {
            Button(L10n.tr("Create from scratch")) { showBuilder = true }
            Button(L10n.tr("Paste deck code")) { showImport = true }
            Button(L10n.tr("Cancel"), role: .cancel) {}
        }
        .sheet(isPresented: $showImport) { importSheet }
        .sheet(item: $selectedDeck) { deck in NavigationStack { DeckView(deck: deck) } }
        .sheet(isPresented: $showBuilder) {
            DeckBuilderView { deck in
                showBuilder = false
                selectedDeck = deck
            }
        }
        .alert(L10n.tr("Rename deck"), isPresented: Binding(get: { renameDeck != nil }, set: { if !$0 { renameDeck = nil } })) {
            TextField(L10n.tr("Deck name"), text: $renameText)
            Button(L10n.tr("Save")) {
                do {
                    if let deck = renameDeck {
                        try app.renameDeck(code: deck.code, name: renameText)
                    }
                    renameDeck = nil
                } catch {
                    actionError = error.localizedDescription
                }
            }
            Button(L10n.tr("Cancel"), role: .cancel) { renameDeck = nil }
        }
        .alert(L10n.tr("Error"), isPresented: Binding(get: { actionError != nil }, set: { if !$0 { actionError = nil } })) {
            Button(L10n.tr("OK"), role: .cancel) { actionError = nil }
        } message: {
            Text(actionError ?? "")
        }
    }

    private var importSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.tr("Paste a Hearthstone deck code. Tap Decode to view and save it."))
                    .font(.subheadline)
                    .foregroundStyle(AppColor.onSurfaceDim)
                TextEditor(text: $importCode)
                    .frame(minHeight: 150)
                    .padding(8)
                    .compactCard()
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
            .navigationTitle(L10n.tr("Import deck"))
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L10n.tr("Close")) { showImport = false } } }
            .appBackground()
        }
    }
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
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    let deck: Deck
    @State private var selectedCard: Card?
    @State private var actionError: String?

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
                            HStack {
                                FormatChip(text: deck.format.displayName)
                                Text("\(deck.cardCount)/\(deck.maxCardCount)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppColor.onSurfaceDim)
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
                } label: {
                    Label(L10n.tr("Copy"), systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                ShareLink(item: deck.code) {
                    Label(L10n.tr("Share"), systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                Button {
                    do {
                        try app.save(deck: deck)
                    } catch {
                        actionError = error.localizedDescription
                    }
                } label: {
                    Text(L10n.tr("Save"))
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(12)
            .background(AppColor.surfaceContainer)
        }
        .navigationTitle("")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L10n.tr("Close")) { dismiss() } } }
        .sheet(item: $selectedCard) { card in NavigationStack { CardDetailView(card: card) } }
        .alert(L10n.tr("Error"), isPresented: Binding(get: { actionError != nil }, set: { if !$0 { actionError = nil } })) {
            Button(L10n.tr("OK"), role: .cancel) { actionError = nil }
        } message: {
            Text(actionError ?? "")
        }
        .appBackground()
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
    let onSaved: (Deck) -> Void

    @State private var phaseClassPicker = true
    @State private var chosenClass: String?
    @State private var heroCardId: Int?
    @State private var format: GameFormat = .standard
    @State private var singleton = false
    @State private var deck: [Int: DeckCardEntry] = [:]
    @State private var poolFilters = CardFilters(sort: CardSort(key: .manaCost, direction: .ascending))
    @State private var poolCards: [Card] = []
    @State private var poolTotal = 0
    @State private var activeTab = 0
    @State private var selectedCard: Card?
    @State private var alertMessage: String?
    @State private var confirmIncompleteSave = false

    var body: some View {
        NavigationStack {
            Group {
                if phaseClassPicker { classPicker } else { editor }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(phaseClassPicker ? L10n.tr("Close") : L10n.tr("Back")) {
                        if phaseClassPicker { dismiss() } else { phaseClassPicker = true }
                    }
                }
            }
            .alert(L10n.tr("Deck builder"), isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
                Button(L10n.tr("OK"), role: .cancel) { alertMessage = nil }
            } message: {
                Text(alertMessage ?? "")
            }
            .confirmationDialog(L10n.tr("Save incomplete deck?"), isPresented: $confirmIncompleteSave) {
                Button(L10n.tr("Save anyway")) { saveDeck() }
                Button(L10n.tr("Cancel"), role: .cancel) {}
            } message: {
                Text(L10n.incompleteSaveMessage(cardCount, maxDeckSize))
            }
            .sheet(item: $selectedCard) { card in NavigationStack { CardDetailView(card: card) } }
            .appBackground()
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
            Picker("", selection: $activeTab) {
                Text(L10n.tr("Deck")).tag(0)
                Text(L10n.tr("Pool")).tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            if activeTab == 0 { deckPane } else { poolPane }
            bottomActions
        }
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
            Menu(format.displayName) {
                Button(GameFormat.standard.displayName) { format = .standard; Task { await reloadPool() } }
                Button(GameFormat.wild.displayName) { format = .wild; Task { await reloadPool() } }
            }
            Toggle("x1", isOn: $singleton)
                .labelsHidden()
                .onChange(of: singleton) { _, enabled in
                    if enabled {
                        deck = deck.mapValues { DeckCardEntry(card: $0.card, count: 1) }
                    }
                }
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
            ManaChips(selected: poolFilters.manaCosts) { cost in
                if poolFilters.manaCosts.contains(cost) { poolFilters.manaCosts.remove(cost) } else { poolFilters.manaCosts.insert(cost) }
                Task { await reloadPool() }
            }
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 10)], spacing: 10) {
                    ForEach(poolCards) { card in
                        CardThumbnail(card: card) { add(card) }
                            .contextMenu {
                                Button(L10n.tr("Details")) { selectedCard = card }
                            }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 16)
            }
        }
        .onChange(of: poolFilters.textQuery) { _, _ in Task { await reloadPool() } }
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
            .opacity(cardCount == 0 ? 0.45 : 1)
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
        var filters = poolFilters
        filters.classes = [chosenClass, "neutral"]
        filters.collectibleOnly = true
        filters.format = format == .standard ? .standard : .all
        let result = await app.searchCards(filters: filters, page: 1, pageSize: 90)
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

    private func isDefaultHero(_ card: Card) -> Bool {
        card.cardType.slug == "hero" && (card.text?.isEmpty ?? true) && card.slug.hasPrefix("HERO_")
    }
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
                        app.clearImageCache()
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
