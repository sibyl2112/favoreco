import SwiftData
import SwiftUI

struct BookShelfAssignmentView: View {
    let event: ExperienceEvent

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BookShelf.sortOrder) private var shelves: [BookShelf]
    @State private var isCreatingShelf = false
    @State private var newShelfName = ""
    @State private var errorMessage = ""

    private var sortedShelves: [BookShelf] {
        shelves.sorted {
            $0.sortOrder == $1.sortOrder
                ? $0.createdAt < $1.createdAt
                : $0.sortOrder < $1.sortOrder
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if sortedShelves.isEmpty {
                        ContentUnavailableView(
                            "本棚はまだありません",
                            systemImage: "books.vertical",
                            description: Text("本棚を作ると、同じ本を複数の本棚へ整理できます。")
                        )
                    } else {
                        ForEach(sortedShelves) { shelf in
                            Button {
                                toggleMembership(shelf)
                            } label: {
                                HStack(spacing: 12) {
                                    FavorecoIcon(systemName: "books.vertical", size: 18)
                                        .foregroundStyle(.secondary)
                                    Text(shelf.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if contains(event, in: shelf) {
                                        FavorecoIcon(systemName: "checkmark.circle.fill", size: 20)
                                            .foregroundStyle(Color.accentColor)
                                    } else {
                                        FavorecoIcon(systemName: "circle", size: 20)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } footer: {
                    Text("本棚は読書状態とは別の整理機能です。1冊を複数の本棚へ登録できます。")
                }

                Section {
                    Button {
                        newShelfName = ""
                        isCreatingShelf = true
                    } label: {
                        Label("新しい本棚を作る", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("本棚に追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
            .alert("新しい本棚", isPresented: $isCreatingShelf) {
                TextField("本棚名", text: $newShelfName)
                Button("作成") { createShelfAndAssign() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("作成後、この本を本棚へ追加します。")
            }
            .alert("保存できませんでした", isPresented: Binding(
                get: { !errorMessage.isEmpty },
                set: { if !$0 { errorMessage = "" } }
            )) {
                Button("OK", role: .cancel) { errorMessage = "" }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func contains(_ event: ExperienceEvent, in shelf: BookShelf) -> Bool {
        (shelf.books ?? []).contains { $0.id == event.id }
    }

    private func toggleMembership(_ shelf: BookShelf) {
        var books = shelf.books ?? []
        if let index = books.firstIndex(where: { $0.id == event.id }) {
            books.remove(at: index)
        } else {
            books.append(event)
        }
        shelf.books = books
        shelf.updatedAt = Date()
        save()
    }

    private func createShelfAndAssign() {
        let name = newShelfName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        guard !sortedShelves.contains(where: { normalizedShelfName($0.name) == normalizedShelfName(name) }) else {
            errorMessage = "同じ名前の本棚があります。"
            return
        }
        let shelf = BookShelf(
            name: name,
            sortOrder: (sortedShelves.map(\.sortOrder).max() ?? -1) + 1
        )
        shelf.books = [event]
        modelContext.insert(shelf)
        save()
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

struct BookShelfBrowserView: View {
    let categoryID: UUID
    let initialShelfID: UUID?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BookShelf.sortOrder) private var shelves: [BookShelf]
    @State private var selectedShelfID: UUID?
    @State private var isEditingShelves = false
    @State private var isCreatingShelf = false
    @State private var newShelfName = ""
    @State private var errorMessage = ""

    init(categoryID: UUID, initialShelfID: UUID? = nil) {
        self.categoryID = categoryID
        self.initialShelfID = initialShelfID
        _selectedShelfID = State(initialValue: initialShelfID)
    }

    private var sortedShelves: [BookShelf] {
        shelves.sorted {
            $0.sortOrder == $1.sortOrder
                ? $0.createdAt < $1.createdAt
                : $0.sortOrder < $1.sortOrder
        }
    }

    private var selectedShelf: BookShelf? {
        if let selectedShelfID,
           let selected = sortedShelves.first(where: { $0.id == selectedShelfID }) {
            return selected
        }
        return sortedShelves.first
    }

    var body: some View {
        NavigationStack {
            Group {
                if isEditingShelves {
                    shelfOrderingList
                } else {
                    shelfContents
                }
            }
            .navigationTitle("My Shelves")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        newShelfName = ""
                        isCreatingShelf = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("本棚を作る")
                    Button(isEditingShelves ? "完了" : "編集") {
                        withAnimation { isEditingShelves.toggle() }
                    }
                }
            }
            .onAppear {
                if selectedShelfID == nil {
                    selectedShelfID = sortedShelves.first?.id
                }
            }
            .onChange(of: sortedShelves.map(\.id)) { _, ids in
                if let selectedShelfID, !ids.contains(selectedShelfID) {
                    self.selectedShelfID = ids.first
                } else if selectedShelfID == nil {
                    selectedShelfID = ids.first
                }
            }
            .alert("新しい本棚", isPresented: $isCreatingShelf) {
                TextField("本棚名", text: $newShelfName)
                Button("作成") { createShelf() }
                Button("キャンセル", role: .cancel) {}
            }
            .alert("保存できませんでした", isPresented: Binding(
                get: { !errorMessage.isEmpty },
                set: { if !$0 { errorMessage = "" } }
            )) {
                Button("OK", role: .cancel) { errorMessage = "" }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var shelfContents: some View {
        VStack(alignment: .leading, spacing: 14) {
            if sortedShelves.isEmpty {
                ContentUnavailableView {
                    Label("本棚はまだありません", systemImage: "books.vertical")
                } description: {
                    Text("右上の＋から本棚を作成できます。")
                } actions: {
                    Button("本棚を作る") { isCreatingShelf = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(sortedShelves) { shelf in
                            Button {
                                selectedShelfID = shelf.id
                            } label: {
                                HStack(spacing: 5) {
                                    Text(shelf.name)
                                    Text("\(books(in: shelf).count)")
                                        .font(FavorecoTypography.caption)
                                        .foregroundStyle(
                                            selectedShelf?.id == shelf.id
                                                ? Color.white.opacity(0.82)
                                                : Color.secondary
                                        )
                                }
                                .font(FavorecoTypography.bodyStrong)
                                .foregroundStyle(
                                    selectedShelf?.id == shelf.id
                                        ? Color.white
                                        : Color.primary
                                )
                                .padding(.horizontal, 14)
                                .frame(minHeight: 38)
                                .background(
                                    selectedShelf?.id == shelf.id ? Color.accentColor : Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                if let selectedShelf {
                    let books = books(in: selectedShelf)
                    if books.isEmpty {
                        ContentUnavailableView(
                            "この本棚は空です",
                            systemImage: "books.vertical",
                            description: Text("本の詳細にあるメニューから追加できます。")
                        )
                    } else {
                        ScrollView {
                            LazyVGrid(
                                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                                spacing: 16
                            ) {
                                ForEach(books) { book in
                                    NavigationLink {
                                        EventDetailView(event: book)
                                    } label: {
                                        BookShelfCoverTile(book: book)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
        }
        .padding(.top, 12)
    }

    private var shelfOrderingList: some View {
        List {
            Section {
                ForEach(sortedShelves) { shelf in
                    HStack(spacing: 12) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.secondary)
                        Text(shelf.name)
                        Spacer()
                        Text("\(books(in: shelf).count)冊")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onMove(perform: moveShelves)
                .onDelete(perform: deleteShelves)
            } header: {
                Text("ドラッグして並べ替え")
            } footer: {
                Text("並び順の先頭3つが書籍トップに表示されます。本棚を削除しても本と読書記録は削除されません。")
            }
        }
        .environment(\.editMode, .constant(.active))
    }

    private func books(in shelf: BookShelf) -> [ExperienceEvent] {
        (shelf.books ?? [])
            .filter { $0.category?.id == categoryID && !$0.isArchived }
            .sorted {
                $0.updatedAt == $1.updatedAt
                    ? $0.title.localizedStandardCompare($1.title) == .orderedAscending
                    : $0.updatedAt > $1.updatedAt
            }
    }

    private func createShelf() {
        let name = newShelfName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        guard !sortedShelves.contains(where: { normalizedShelfName($0.name) == normalizedShelfName(name) }) else {
            errorMessage = "同じ名前の本棚があります。"
            return
        }
        let shelf = BookShelf(
            name: name,
            sortOrder: (sortedShelves.map(\.sortOrder).max() ?? -1) + 1
        )
        modelContext.insert(shelf)
        selectedShelfID = shelf.id
        save()
    }

    private func moveShelves(from source: IndexSet, to destination: Int) {
        var reordered = sortedShelves
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, shelf) in reordered.enumerated() {
            shelf.sortOrder = index
            shelf.updatedAt = Date()
        }
        save()
    }

    private func deleteShelves(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sortedShelves[index])
        }
        save()
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

struct BookShelfTopStrip: View {
    let categoryID: UUID
    let tint: Color
    let onOpen: (UUID?) -> Void

    @Query(sort: \BookShelf.sortOrder) private var shelves: [BookShelf]

    private var visibleShelves: [BookShelf] {
        Array(shelves.sorted {
            $0.sortOrder == $1.sortOrder
                ? $0.createdAt < $1.createdAt
                : $0.sortOrder < $1.sortOrder
        }.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                LayeredCategorySectionTitle(
                    englishTitle: "My Shelves",
                    japaneseTitle: "本棚",
                    foregroundColor: .primary
                )

                Text("\(shelves.count)")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 4)

                Button(visibleShelves.isEmpty ? "本棚を作る" : "すべて見る") {
                    onOpen(nil)
                }
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(tint)
                .buttonStyle(.plain)
            }

            if !visibleShelves.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(visibleShelves) { shelf in
                            Button {
                                onOpen(shelf.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                                        Text(shelf.name)
                                            .font(FavorecoTypography.bodyStrong)
                                            .lineLimit(1)
                                        Text("\(books(in: shelf).count)冊")
                                            .font(FavorecoTypography.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer(minLength: 2)
                                    }

                                    HStack(spacing: 8) {
                                        BookShelfCoverStack(
                                            books: Array(books(in: shelf).prefix(3)),
                                            tint: tint
                                        )
                                        Spacer(minLength: 0)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(tint.opacity(0.72))
                                    }
                                }
                                .foregroundStyle(.primary)
                                .padding(10)
                                .frame(width: 160, height: 100, alignment: .topLeading)
                                .background(tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(tint.opacity(0.34), lineWidth: 0.8)
                                }
                                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(shelf.name)、\(books(in: shelf).count)冊")
                            .accessibilityHint("本棚を開く")
                        }
                    }
                }
            }
        }
    }

    private func books(in shelf: BookShelf) -> [ExperienceEvent] {
        (shelf.books ?? [])
            .filter { $0.category?.id == categoryID && !$0.isArchived }
            .sorted {
                $0.updatedAt == $1.updatedAt
                    ? $0.title.localizedStandardCompare($1.title) == .orderedAscending
                    : $0.updatedAt > $1.updatedAt
            }
    }
}

private struct BookShelfCoverStack: View {
    let books: [ExperienceEvent]
    let tint: Color

    var body: some View {
        ZStack(alignment: .leading) {
            if books.isEmpty {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(tint.opacity(0.09))
                    .overlay {
                        FavorecoIcon(systemName: "books.vertical", size: 18)
                            .foregroundStyle(tint.opacity(0.62))
                    }
                    .frame(width: 34, height: 48)
            } else {
                ForEach(Array(books.enumerated()), id: \.element.id) { index, book in
                    BookCoverArtwork(event: book)
                        .frame(width: 34, height: 48)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                        .background {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Color(.systemBackground).opacity(0.92))
                                .offset(x: 2, y: 1.5)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .stroke(tint.opacity(0.4), lineWidth: 0.7)
                        }
                        .overlay(alignment: .leading) {
                            LinearGradient(
                                colors: [.white.opacity(0.26), .clear, .black.opacity(0.1)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: 5)
                            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                        }
                        .rotationEffect(.degrees(Double(index) * 1.8), anchor: .bottomLeading)
                        .shadow(
                            color: .black.opacity(index == 0 ? 0.22 : 0.14),
                            radius: index == 0 ? 2.6 : 1.8,
                            x: 1.2,
                            y: 2
                        )
                        .offset(x: CGFloat(index) * 11, y: CGFloat(index) * -2)
                        .zIndex(Double(books.count - index))
                }
            }
        }
        .frame(width: 60, height: 48, alignment: .leading)
        .accessibilityHidden(true)
    }
}

private struct BookShelfCoverTile: View {
    let book: ExperienceEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            BookCoverArtwork(event: book)
                .frame(maxWidth: .infinity)
                .overlay {
                    Rectangle().stroke(Color.accentColor.opacity(0.38), lineWidth: 0.7)
                }
            Text(book.title)
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private func normalizedShelfName(_ text: String) -> String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
        .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
        .filter { !$0.isWhitespace }
}
