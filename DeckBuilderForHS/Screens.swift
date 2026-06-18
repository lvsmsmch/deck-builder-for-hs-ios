import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { CardLibraryView() }
                .tabItem { Label(L10n.t("Library", "Карты"), systemImage: "square.grid.2x2") }
            NavigationStack { SavedDecksView() }
                .tabItem { Label(L10n.t("Saved", "Колоды"), systemImage: "bookmark") }
            NavigationStack { MoreView() }
                .tabItem { Label(L10n.t("More", "Еще"), systemImage: "ellipsis") }
        }
        .appBackground()
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

    private let columns = [GridItem(.adaptive(minimum: 112), spacing: 10)]

    var body: some View {
        VStack(spacing: 0) {
            libraryHeader
            SearchField(text: $filters.textQuery, placeholder: L10n.t("Search cards by name or text...", "Поиск по имени или тексту..."))
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
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                    .padding(.bottom, 16)
                }
                if isLoading && visibleCards.isEmpty {
                    ProgressView(L10n.t("Loading cards...", "Загружаем карты..."))
                        .tint(AppColor.primary)
                } else if visibleCards.isEmpty && !isLoading {
                    EmptyStateView(
                        title: filters.hasFilters ? L10n.t("No cards match these filters.", "Под эти фильтры ничего не найдено.") : L10n.t("No cards loaded yet.", "Карты еще не загружены."),
                        bodyText: app.cardLoadError ?? L10n.t("Try changing search or filters.", "Попробуй изменить поиск или фильтры."),
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
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("Library", "Карты"))
                    .font(.title2.weight(.bold))
                Text(L10n.t("\(totalCount) cards", "карт: \(totalCount)"))
                    .font(.caption)
                    .foregroundStyle(AppColor.onSurfaceDim)
            }
            Spacer()
            Menu {
                Button(L10n.t("Mana asc", "Мана вверх")) { filters.sort = CardSort(key: .manaCost, direction: .ascending) }
                Button(L10n.t("Mana desc", "Мана вниз")) { filters.sort = CardSort(key: .manaCost, direction: .descending) }
                Button(L10n.t("Name", "Имя")) { filters.sort = CardSort(key: .name, direction: .ascending) }
                Button(L10n.t("Newest", "Сначала новые")) { filters.sort = CardSort(key: .dateAdded, direction: .ascending) }
                Button(L10n.t("By class", "По классу")) { filters.sort = CardSort(key: .groupByClass, direction: .ascending) }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .frame(width: 40, height: 40)
                    .background(AppColor.surfaceContainer)
                    .clipShape(Circle())
            }
            Button { showFilters = true } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .frame(width: 40, height: 40)
                        .background(AppColor.surfaceContainer)
                        .clipShape(Circle())
                    if filters.activeFilterCount > 0 {
                        Text("\(filters.activeFilterCount)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppColor.onPrimary)
                            .frame(width: 17, height: 17)
                            .background(AppColor.primary)
                            .clipShape(Circle())
                    }
                }
            }
            Button { app.refreshCards() } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 40, height: 40)
                    .background(AppColor.surfaceContainer)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
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
                Section(L10n.t("Format", "Формат")) {
                    Picker("", selection: $filters.format) {
                        ForEach(CardFormatFilter.allCases) { format in
                            Text(format.label).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section(L10n.t("Rarity", "Редкость")) {
                    multiRow("Common", "common", selection: $filters.rarities)
                    multiRow("Rare", "rare", selection: $filters.rarities)
                    multiRow("Epic", "epic", selection: $filters.rarities)
                    multiRow("Legendary", "legendary", selection: $filters.rarities)
                }
                Section(L10n.t("Type", "Тип")) {
                    multiRow("Minion", "minion", selection: $filters.types)
                    multiRow("Spell", "spell", selection: $filters.types)
                    multiRow("Weapon", "weapon", selection: $filters.types)
                    multiRow("Hero", "hero", selection: $filters.types)
                    multiRow("Location", "location", selection: $filters.types)
                }
                Section {
                    Toggle(L10n.t("Collectible only", "Только доступные"), isOn: $filters.collectibleOnly)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColor.surface)
            .navigationTitle(L10n.t("Filters", "Фильтры"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("Reset all", "Сбросить")) { filters = CardFilters(textQuery: filters.textQuery) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("Apply", "Применить")) { dismiss() }
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
                Text(label)
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
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L10n.t("Close", "Закрыть")) { dismiss() } } }
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
            Text(label)
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
                    Text(L10n.t("Image failed to load", "Изображение не загрузилось"))
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
    @State private var renameDeck: DeckPreview?
    @State private var renameText = ""

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                HStack {
                    Text(L10n.t("Saved decks", "Сохраненные колоды"))
                        .font(.title2.weight(.bold))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 8)

                if app.savedDecks.isEmpty {
                    EmptyStateView(
                        title: L10n.t("No saved decks yet.", "Колоды еще не сохранены."),
                        bodyText: L10n.t("Tap the + button to start a new deck or paste a deck code.", "Жми +, чтобы создать новую колоду или вставить код."),
                        icon: "bookmark"
                    )
                } else {
                    List {
                        ForEach(app.savedDecks) { deck in
                            SavedDeckRow(deck: deck) {
                                Task { selectedDeck = try? await app.decodeDeck(code: deck.code) }
                            } onCopy: {
                                Clipboard.copy(deck.code)
                            } onRename: {
                                renameDeck = deck
                                renameText = deck.name
                            } onDelete: {
                                app.deleteDeck(code: deck.code)
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
        .confirmationDialog(L10n.t("New deck", "Новая колода"), isPresented: $showNewDeck) {
            Button(L10n.t("Create from scratch", "Создать с нуля")) { showBuilder = true }
            Button(L10n.t("Paste deck code", "Вставить код")) { showImport = true }
            Button(L10n.t("Cancel", "Отмена"), role: .cancel) {}
        }
        .sheet(isPresented: $showImport) { importSheet }
        .sheet(item: $selectedDeck) { deck in NavigationStack { DeckView(deck: deck) } }
        .sheet(isPresented: $showBuilder) {
            DeckBuilderView { deck in
                showBuilder = false
                selectedDeck = deck
            }
        }
        .alert(L10n.t("Rename deck", "Переименовать колоду"), isPresented: Binding(get: { renameDeck != nil }, set: { if !$0 { renameDeck = nil } })) {
            TextField(L10n.t("Deck name", "Имя колоды"), text: $renameText)
            Button(L10n.t("Save", "Сохранить")) {
                if let deck = renameDeck { app.renameDeck(code: deck.code, name: renameText) }
                renameDeck = nil
            }
            Button(L10n.t("Cancel", "Отмена"), role: .cancel) { renameDeck = nil }
        }
    }

    private var importSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.t("Paste a Hearthstone deck code. Tap Decode to view and save it.", "Вставь код колоды Hearthstone. Нажми Декодировать, чтобы увидеть и сохранить."))
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
                    Text(L10n.t("Decode", "Декодировать"))
                }
                .buttonStyle(PrimaryButtonStyle())
                Spacer()
            }
            .padding(20)
            .navigationTitle(L10n.t("Import deck", "Импорт колоды"))
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L10n.t("Close", "Закрыть")) { showImport = false } } }
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
                        Button(L10n.t("Copy code", "Копировать код"), systemImage: "doc.on.doc", action: onCopy)
                        Button(L10n.t("Rename", "Переименовать"), systemImage: "pencil", action: onRename)
                        Button(L10n.t("Delete", "Удалить"), systemImage: "trash", role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(AppColor.onSurfaceDim)
                            .frame(width: 34, height: 34)
                    }
                }
                if deck.cardCount < deck.maxCardCount {
                    Text(L10n.t("Deck has only \(deck.cardCount)/\(deck.maxCardCount) cards.", "В колоде только \(deck.cardCount)/\(deck.maxCardCount) карт."))
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
                    Label(L10n.t("Copy", "Копировать"), systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                ShareLink(item: deck.code) {
                    Label(L10n.t("Share", "Поделиться"), systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                Button {
                    app.save(deck: deck)
                } label: {
                    Text(L10n.t("Save", "Сохранить"))
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(12)
            .background(AppColor.surfaceContainer)
        }
        .navigationTitle("")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L10n.t("Close", "Закрыть")) { dismiss() } } }
        .sheet(item: $selectedCard) { card in NavigationStack { CardDetailView(card: card) } }
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
                    Button(phaseClassPicker ? L10n.t("Close", "Закрыть") : L10n.t("Back", "Назад")) {
                        if phaseClassPicker { dismiss() } else { phaseClassPicker = true }
                    }
                }
            }
            .alert(L10n.t("Deck builder", "Создание колоды"), isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
                Button("OK", role: .cancel) { alertMessage = nil }
            } message: {
                Text(alertMessage ?? "")
            }
            .confirmationDialog(L10n.t("Save incomplete deck?", "Сохранить неполную колоду?"), isPresented: $confirmIncompleteSave) {
                Button(L10n.t("Save anyway", "Сохранить")) { saveDeck() }
                Button(L10n.t("Cancel", "Отмена"), role: .cancel) {}
            } message: {
                Text(L10n.t("This deck has only \(cardCount)/\(maxDeckSize) cards. Save it anyway?", "В колоде только \(cardCount)/\(maxDeckSize) карт. Все равно сохранить?"))
            }
            .sheet(item: $selectedCard) { card in NavigationStack { CardDetailView(card: card) } }
            .appBackground()
        }
    }

    private var classPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("New deck", "Новая колода"))
                .font(.title2.weight(.bold))
                .padding(.horizontal, 20)
            Text(L10n.t("Pick a class to begin.", "Выбери класс, чтобы начать."))
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
                Text(L10n.t("Deck", "Колода")).tag(0)
                Text(L10n.t("Pool", "Пул")).tag(1)
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
                    title: L10n.t("Empty deck.", "Колода пуста."),
                    bodyText: L10n.t("Switch to the Pool tab and tap cards to add them.", "Перейди во вкладку Пул и тапай по картам, чтобы добавить."),
                    icon: "rectangle.stack.badge.plus"
                )
            } else {
                List {
                    ForEach(deckEntries) { entry in
                        DeckCardRow(entry: entry) { remove(entry.card) }
                            .swipeActions { Button(L10n.t("Remove", "Убрать"), role: .destructive) { remove(entry.card) } }
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
            SearchField(text: $poolFilters.textQuery, placeholder: L10n.t("Search pool", "Поиск в пуле"))
            ManaChips(selected: poolFilters.manaCosts) { cost in
                if poolFilters.manaCosts.contains(cost) { poolFilters.manaCosts.remove(cost) } else { poolFilters.manaCosts.insert(cost) }
                Task { await reloadPool() }
            }
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 10)], spacing: 10) {
                    ForEach(poolCards) { card in
                        CardThumbnail(card: card) { add(card) }
                            .contextMenu {
                                Button(L10n.t("Details", "Детали")) { selectedCard = card }
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
                Text(L10n.t("Save", "Сохранить"))
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
            alertMessage = L10n.t("Not a \(ClassLabels.label(chosenClass)) or Neutral card", "Это карта другого класса")
            return
        }
        let current = deck[card.id]?.count ?? 0
        let cap = singleton || card.isLegendary ? 1 : 2
        guard current < cap else {
            alertMessage = card.isLegendary ? L10n.t("Legendary limit (x1)", "Лимит легендарок (x1)") : L10n.t("Card limit (x2)", "Лимит карт (x2)")
            return
        }
        guard cardCount < max(card.isPrinceRenathal ? 40 : maxDeckSize, maxDeckSize) else {
            alertMessage = L10n.t("Deck is full", "Колода заполнена")
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
            app.save(deck: built)
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
        List {
            Section {
                NavigationLink {
                    SettingsView()
                } label: {
                    Label {
                        VStack(alignment: .leading) {
                            Text(L10n.t("Settings", "Настройки"))
                            Text(L10n.t("Theme, language, privacy", "Тема, язык, приватность"))
                                .font(.caption)
                                .foregroundStyle(AppColor.onSurfaceDim)
                        }
                    } icon: {
                        Image(systemName: "gearshape")
                    }
                }
                NavigationLink {
                    CardDataView()
                } label: {
                    Label {
                        VStack(alignment: .leading) {
                            Text(L10n.t("Card data", "Данные карт"))
                            Text(L10n.t("Build, last update check", "Билд, последняя проверка"))
                                .font(.caption)
                                .foregroundStyle(AppColor.onSurfaceDim)
                        }
                    } icon: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                }
            }
            .listRowBackground(AppColor.surfaceContainer)
        }
        .navigationTitle(L10n.t("More", "Еще"))
        .scrollContentBackground(.hidden)
        .appBackground()
    }
}

struct SettingsView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        Form {
            Section(L10n.t("Appearance", "Внешний вид")) {
                Picker(L10n.t("Theme", "Тема"), selection: Binding(get: { app.preferences.theme }, set: app.setTheme)) {
                    ForEach(ThemeMode.allCases) { theme in Text(theme.label).tag(theme) }
                }
            }
            Section(L10n.t("Language", "Язык")) {
                Picker(L10n.t("Card language", "Язык карт"), selection: Binding(get: { app.preferences.cardLocale }, set: app.setCardLocale)) {
                    ForEach(CardLocale.allCases) { locale in Text(locale.label).tag(locale.rawValue) }
                }
            }
            Section(L10n.t("Privacy", "Конфиденциальность")) {
                Toggle(L10n.t("Send error reports", "Отправлять отчеты об ошибках"), isOn: Binding(get: { app.preferences.crashReportingEnabled }, set: app.setCrashReporting))
            }
            Section(L10n.t("Storage", "Хранилище")) {
                Button(role: .destructive) {
                    app.clearImageCache()
                } label: {
                    Label(L10n.t("Clear image cache", "Очистить кеш изображений"), systemImage: "trash")
                }
            }
            Section(L10n.t("About", "О приложении")) {
                LabeledContent(L10n.t("Version", "Версия"), value: "1.0")
                Link("iamajavagod@gmail.com", destination: URL(string: "mailto:iamajavagod@gmail.com")!)
            }
        }
        .navigationTitle(L10n.t("Settings", "Настройки"))
        .scrollContentBackground(.hidden)
        .appBackground()
    }
}

struct CardDataView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        List {
            Section(L10n.t("Card data", "Данные карт")) {
                LabeledContent(L10n.t("Cards loaded", "Карт загружено"), value: "\(app.cards.count)")
                LabeledContent(L10n.t("Locale", "Локаль"), value: app.preferences.cardLocale)
                if let error = app.cardLoadError {
                    Text(error).foregroundStyle(AppColor.error)
                }
                Button {
                    app.refreshCards()
                } label: {
                    if app.isLoadingCards {
                        ProgressView()
                    } else {
                        Label(L10n.t("Refresh card data", "Обновить данные карт"), systemImage: "arrow.clockwise")
                    }
                }
            }
        }
        .navigationTitle(L10n.t("Card data", "Данные карт"))
        .scrollContentBackground(.hidden)
        .appBackground()
    }
}
