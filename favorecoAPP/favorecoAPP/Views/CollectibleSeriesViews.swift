import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct CollectibleCategoryHero: View {
    let events: [ExperienceEvent]
    let snapshot: CategoryTopSnapshot
    let tint: Color
    let onAdd: () -> Void

    var body: some View {
        let summaries = events.map { CollectibleSeriesSummary.make(series: $0) }
        let collected = summaries.reduce(0) { $0 + $1.collectedCount }
        let target = summaries.reduce(0) { $0 + $1.targetCount }
        let duplicates = summaries.reduce(0) { $0 + $1.duplicateQuantity }

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                FavorecoIcon(systemName: "shippingbox.fill", size: 27)
                    .foregroundStyle(tint)
                    .frame(width: 48, height: 48)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Goods")
                        .font(FavorecoTypography.jpSerif(25, weight: .bold, relativeTo: .title2))
                    Text(
                        snapshot.events.isEmpty
                            ? "シリーズを登録して、何種類・何個集まったか残せます。"
                            : "全 \(snapshot.eventCount) シリーズ・\(collected)/\(target) 種類・ダブり \(duplicates) 個"
                    )
                        .font(FavorecoTypography.body)
                        .foregroundStyle(.secondary)
                }
            }
            Button(action: onAdd) {
                FavorecoIconLabel("シリーズを追加", systemImage: "plus.circle.fill", iconSize: 17)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(tint)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct AddCollectibleSeriesView: View {
    private let category: RecordCategory?
    private let editingSeries: ExperienceEvent?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title: String
    @State private var kind: CollectibleKind
    @State private var maker: String
    @State private var releaseText: String
    @State private var lineupCount: Int
    @State private var officialURL: String
    @State private var memo: String
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var imageData: Data?
    @State private var errorMessage: String? = nil

    init(category: RecordCategory) {
        self.category = category
        editingSeries = nil
        _title = State(initialValue: "")
        _kind = State(initialValue: .capsuleToy)
        _maker = State(initialValue: "")
        _releaseText = State(initialValue: "")
        _lineupCount = State(initialValue: 1)
        _officialURL = State(initialValue: "")
        _memo = State(initialValue: "")
        _imageData = State(initialValue: nil)
    }

    init(series: ExperienceEvent) {
        category = series.category
        editingSeries = series
        _title = State(initialValue: series.title)
        _kind = State(initialValue: CollectibleKind.resolved(from: series.subTypeKey))
        _maker = State(initialValue: series.organizerNameSnapshot)
        _releaseText = State(initialValue: series.seriesName)
        _lineupCount = State(initialValue: max(1, (series.collectibleItems ?? []).count))
        _officialURL = State(initialValue: series.officialURL)
        _memo = State(initialValue: series.memo)
        _imageData = State(initialValue: series.eyecatchData)
    }

    var body: some View {
        NavigationStack {
            Form {
                FavorecoRegistrationSection("シリーズ") {
                    TextField("シリーズ名", text: $title)
                    Picker("グッズの種類", selection: $kind) {
                        ForEach(CollectibleKind.allCases) { value in
                            Text(value.displayName).tag(value)
                        }
                    }
                    TextField("メーカー・発売元（任意）", text: $maker)
                    TextField("発売時期（任意）", text: $releaseText)
                    if editingSeries == nil {
                        Stepper("全 \(lineupCount) 種類", value: $lineupCount, in: 1...100)
                    }
                }

                FavorecoRegistrationSection("画像") {
                    let photoActionTitle = imageData == nil ? "シリーズ画像を選ぶ" : "シリーズ画像を変更"
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        FavorecoIconLabel(photoActionTitle, systemImage: "photo")
                    }
                    if let imageData, let image = UIImage(data: imageData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }

                FavorecoRegistrationSection("補足") {
                    TextField("公式URL（任意）", text: $officialURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    TextField("メモ（任意）", text: $memo, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .favorecoRegistrationFormCanvas()
            .navigationTitle(editingSeries == nil ? "シリーズを追加" : "シリーズを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                Task { imageData = await CollectibleImageLoader.load(item) }
            }
            .alert("保存できませんでした", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func save() {
        let now = Date()
        if let editingSeries {
            editingSeries.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            editingSeries.seriesName = releaseText.trimmingCharacters(in: .whitespacesAndNewlines)
            editingSeries.subTypeKey = kind.rawValue
            editingSeries.organizerNameSnapshot = maker.trimmingCharacters(in: .whitespacesAndNewlines)
            editingSeries.officialURL = officialURL.trimmingCharacters(in: .whitespacesAndNewlines)
            editingSeries.memo = memo.trimmingCharacters(in: .whitespacesAndNewlines)
            editingSeries.eyecatchData = imageData
            editingSeries.updatedAt = now
            saveContext(errorMessage: "シリーズを更新できませんでした。もう一度お試しください。")
            return
        }

        guard let category else {
            errorMessage = "保存先のグッズジャンルを確認できませんでした。"
            return
        }
        let event = ExperienceEvent(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            seriesName: releaseText.trimmingCharacters(in: .whitespacesAndNewlines),
            subTypeKey: kind.rawValue,
            organizerNameSnapshot: maker.trimmingCharacters(in: .whitespacesAndNewlines),
            officialURL: officialURL.trimmingCharacters(in: .whitespacesAndNewlines),
            memo: memo.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: now,
            updatedAt: now,
            eyecatchData: imageData,
            category: category
        )
        modelContext.insert(event)
        for index in 0..<lineupCount {
            modelContext.insert(CollectibleItem(sortOrder: index, series: event))
        }
        category.isArchived = false
        category.updatedAt = now
        saveContext(errorMessage: "シリーズを保存できませんでした。もう一度お試しください。")
    }

    private func saveContext(errorMessage: String) {
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            self.errorMessage = errorMessage
        }
    }
}

struct CollectibleCategorySeriesGrid: View {
    let events: [ExperienceEvent]
    let tint: Color
    let onAdd: () -> Void
    let onOpenSeries: (UUID) -> Void
    @State private var selectedKind: CollectibleKind?

    private let columns = [
        GridItem(.flexible(minimum: 0), spacing: 12, alignment: .top),
        GridItem(.flexible(minimum: 0), spacing: 12, alignment: .top)
    ]

    private var activeEvents: [ExperienceEvent] {
        events
            .filter { !$0.isArchived }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var filteredEvents: [ExperienceEvent] {
        guard let selectedKind else { return activeEvents }
        return activeEvents.filter {
            CollectibleKind.resolved(from: $0.subTypeKey) == selectedKind
        }
    }

    init(
        events: [ExperienceEvent],
        tint: Color,
        onAdd: @escaping () -> Void,
        onOpenSeries: @escaping (UUID) -> Void,
        selectedKind: CollectibleKind? = nil
    ) {
        self.events = events
        self.tint = tint
        self.onAdd = onAdd
        self.onOpenSeries = onOpenSeries
        _selectedKind = State(initialValue: selectedKind)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    LayeredCategorySectionTitle(
                        englishTitle: "Series",
                        japaneseTitle: "シリーズ",
                        foregroundColor: .primary
                    )
                    Text("集めた種類とダブりをシリーズごとに確認できます")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onAdd) { FavorecoIcon(systemName: "plus.circle.fill", size: 22) }
                    .tint(tint)
            }

            if activeEvents.isEmpty {
                ContentUnavailableView {
                    FavorecoIconLabel("シリーズはまだありません", systemImage: "shippingbox", iconSize: 20)
                } description: {
                    Text("よく集めるグッズをシリーズとして登録し、種類別の収集状況を残しましょう。")
                } actions: {
                    Button("最初のシリーズを追加", action: onAdd)
                        .buttonStyle(.borderedProminent)
                        .tint(tint)
                }
            } else {
                CollectibleKindFilterBar(selection: $selectedKind, tint: tint)

                if filteredEvents.isEmpty {
                    ContentUnavailableView {
                        FavorecoIconLabel("該当するシリーズはありません", systemImage: "shippingbox", iconSize: 20)
                    } description: {
                        Text("別の種別を選ぶか、新しいシリーズを追加してください。")
                    } actions: {
                        Button("シリーズを追加", action: onAdd)
                            .buttonStyle(.borderedProminent)
                            .tint(tint)
                    }
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(filteredEvents) { event in
                            Button {
                                onOpenSeries(event.id)
                            } label: {
                                CollectibleSeriesCard(event: event, tint: tint)
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

private struct CollectibleKindFilterBar: View {
    @Binding var selection: CollectibleKind?
    let tint: Color

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                filterButton(title: "すべて", kind: nil)
                ForEach(CollectibleKind.allCases) { kind in
                    filterButton(title: kind.shortDisplayName, kind: kind)
                }
            }
        }
        .scrollIndicators(.hidden)
        .background { GenreSwipeExclusionZone() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("グッズ種別")
    }

    private func filterButton(title: String, kind: CollectibleKind?) -> some View {
        let isSelected = selection == kind
        return Button {
            selection = kind
        } label: {
            Text(title)
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(isSelected ? Color.white : tint)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(
                    isSelected ? tint : tint.opacity(0.10),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct CollectibleSeriesCard: View {
    let event: ExperienceEvent
    let tint: Color

    var body: some View {
        let summary = CollectibleSeriesSummary.make(series: event)
        VStack(alignment: .leading, spacing: 9) {
            GeometryReader { proxy in
                let side = max(proxy.size.width, 1)
                ThumbnailImage(
                    reference: .event(event.id),
                    displaySize: CGSize(width: side, height: side),
                    contentMode: .fill
                ) {
                    CategoryDefaultArtworkImage(
                        templateKey: event.category?.templateKey ?? "random_goods",
                        displaySize: CGSize(width: side, height: side)
                    )
                }
                .frame(width: side, height: side)
                .clipped()
            }
            .aspectRatio(1, contentMode: .fit)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(event.title)
                .font(.subheadline.bold())
                .lineLimit(2, reservesSpace: true)
            Text(CollectibleKind.resolved(from: event.subTypeKey).displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            ProgressView(value: summary.progress).tint(tint)
            HStack {
                Text("\(summary.collectedCount)/\(summary.targetCount)種類")
                Spacer()
                if summary.duplicateQuantity > 0 { Text("ダブり \(summary.duplicateQuantity)") }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct CollectibleSeriesDashboard: View {
    let series: ExperienceEvent
    let accentColor: Color

    @State private var filter = CollectibleItemFilter.all
    @State private var isShowingItemEditor = false
    @State private var isShowingTransactionEditor = false

    private let columns = [GridItem(.adaptive(minimum: 132), spacing: 12)]

    var body: some View {
        let summary = CollectibleSeriesSummary.make(series: series)
        let items = filteredItems
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(summary.isComplete ? "コンプリート" : "収集中")
                        .font(.title3.bold())
                        .foregroundStyle(accentColor)
                    Spacer()
                    Text("\(summary.collectedCount) / \(summary.targetCount) 種類")
                        .font(.headline.monospacedDigit())
                }
                ProgressView(value: summary.progress).tint(accentColor)
                HStack(spacing: 0) {
                    CollectibleMetric(value: "\(summary.ownedQuantity)", label: "所持")
                    CollectibleMetric(value: "\(summary.duplicateQuantity)", label: "ダブり")
                    CollectibleMetric(value: "\(summary.missingCount)", label: "未入手")
                    CollectibleMetric(value: summary.spentAmount.formatted(.currency(code: "JPY").precision(.fractionLength(0))), label: "関連支出")
                }
            }
            .padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack(spacing: 10) {
                Button { isShowingTransactionEditor = true } label: {
                    FavorecoIconLabel("入手・手放し", systemImage: "plusminus.circle.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(accentColor)
                Button { isShowingItemEditor = true } label: {
                    FavorecoIconLabel("種類を追加", systemImage: "square.grid.2x2.fill")
                }
                .buttonStyle(.bordered).tint(accentColor)
            }

            Picker("表示", selection: $filter) {
                ForEach(CollectibleItemFilter.allCases) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)

            if items.isEmpty {
                FavorecoContentUnavailableView("該当する種類はありません", systemImage: "checkmark.circle")
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(items) { item in
                        NavigationLink {
                            CollectibleItemDetailView(item: item, accentColor: accentColor)
                        } label: {
                            CollectibleItemCard(item: item, accentColor: accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingItemEditor) {
            CollectibleItemEditorView(series: series)
        }
        .sheet(isPresented: $isShowingTransactionEditor) {
            CollectibleTransactionEditorView(series: series)
        }
    }

    private var filteredItems: [CollectibleItem] {
        let items = (series.collectibleItems ?? []).filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
        switch filter {
        case .all: return items
        case .missing: return items.filter { $0.currentQuantity == 0 }
        case .duplicates: return items.filter { $0.currentQuantity > 1 }
        }
    }
}

private enum CollectibleItemFilter: String, CaseIterable, Identifiable {
    case all, missing, duplicates
    var id: String { rawValue }
    var displayName: String {
        switch self { case .all: "すべて"; case .missing: "未入手"; case .duplicates: "ダブり" }
    }
}

private struct CollectibleMetric: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 3) {
            Text(value).font(.subheadline.bold()).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
    }
}

private struct CollectibleItemCard: View {
    let item: CollectibleItem
    let accentColor: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                ThumbnailImage(
                    reference: .collectibleItem(item.id),
                    displaySize: CGSize(width: 180, height: 180),
                    contentMode: .fill
                ) {
                    ZStack {
                        accentColor.opacity(0.1)
                        FavorecoIcon(
                            systemName: item.currentQuantity > 0 ? "checkmark.seal.fill" : "photo",
                            size: 28
                        )
                        .foregroundStyle(item.currentQuantity > 0 ? accentColor : .secondary)
                    }
                }
                .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit).clipped()
                if item.currentQuantity > 0 {
                    Text("×\(item.currentQuantity)").font(.caption.bold()).foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 4).background(.black.opacity(0.7), in: Capsule()).padding(7)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(item.displayName).font(.subheadline.bold()).lineLimit(2)
            if !item.variantName.isEmpty { Text(item.variantName).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
        }
        .padding(9).background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct CollectibleItemEditorView: View {
    let series: ExperienceEvent
    var item: CollectibleItem?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name: String
    @State private var variantName: String
    @State private var memo: String
    @State private var isCompletionTarget: Bool
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var errorMessage: String?

    init(series: ExperienceEvent, item: CollectibleItem? = nil) {
        self.series = series
        self.item = item
        _name = State(initialValue: item?.name ?? "")
        _variantName = State(initialValue: item?.variantName ?? "")
        _memo = State(initialValue: item?.memo ?? "")
        _isCompletionTarget = State(initialValue: item?.isCompletionTarget ?? true)
        _imageData = State(initialValue: item?.imageData)
    }

    var body: some View {
        NavigationStack {
            Form {
                FavorecoRegistrationSection("種類") {
                    TextField("名前（例：赤・キャラクター名）", text: $name)
                    TextField("バリエーション・レア度（任意）", text: $variantName)
                    Toggle("コンプリート対象に含める", isOn: $isCompletionTarget)
                }
                FavorecoRegistrationSection("メモ") {
                    TextField("このGoodsについて残したいこと（任意）", text: $memo, axis: .vertical)
                        .lineLimit(3...5)
                }
                FavorecoRegistrationSection("画像") {
                    let photoActionTitle = imageData == nil ? "画像を選ぶ" : "画像を変更"
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        FavorecoIconLabel(photoActionTitle, systemImage: "photo")
                    }
                    if let imageData, let image = UIImage(data: imageData) {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 240)
                    }
                }
            }
            .favorecoRegistrationFormCanvas()
            .navigationTitle(item == nil ? "種類を追加" : "種類を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { save() } }
            }
            .onChange(of: selectedPhoto) { _, item in Task { imageData = await CollectibleImageLoader.load(item) } }
            .alert("保存できませんでした", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(errorMessage ?? "") }
        }
    }

    private func save() {
        let target = item ?? CollectibleItem(
            sortOrder: ((series.collectibleItems ?? []).map(\.sortOrder).max() ?? -1) + 1,
            series: series
        )
        if item == nil { modelContext.insert(target) }
        target.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        target.variantName = variantName.trimmingCharacters(in: .whitespacesAndNewlines)
        target.memo = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        target.isCompletionTarget = isCompletionTarget
        target.imageData = imageData
        target.updatedAt = Date()
        series.updatedAt = Date()
        do {
            try modelContext.save()
            ThumbnailLoader.purge(reference: .collectibleItem(target.id))
            dismiss()
        }
        catch { modelContext.rollback(); errorMessage = "種類を保存できませんでした。" }
    }
}

struct CollectibleTransactionEditorView: View {
    let series: ExperienceEvent
    var initialItem: CollectibleItem?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedItemID: UUID?
    @State private var kind = CollectibleTransactionKind.purchase
    @State private var quantity = 1
    @State private var occurredAt = Date()
    @State private var amountText = ""
    @State private var place = ""
    @State private var memo = ""
    @State private var errorMessage: String?

    init(series: ExperienceEvent, initialItem: CollectibleItem? = nil) {
        self.series = series
        self.initialItem = initialItem
        _selectedItemID = State(initialValue: initialItem?.id)
    }

    private var items: [CollectibleItem] {
        (series.collectibleItems ?? []).filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var selectedItem: CollectibleItem? {
        guard let selectedItemID else { return nil }
        return items.first { $0.id == selectedItemID }
    }

    private var exceedsOwnedQuantity: Bool {
        kind.signedDirection < 0 && quantity > (selectedItem?.currentQuantity ?? 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                FavorecoRegistrationSection("対象") {
                    Picker("種類", selection: $selectedItemID) {
                        Text("選択してください").tag(UUID?.none)
                        ForEach(items) { Text($0.displayName).tag(Optional($0.id)) }
                    }
                    Picker("記録", selection: $kind) {
                        ForEach(CollectibleTransactionKind.allCases) { Text($0.displayName).tag($0) }
                    }
                    Stepper("数量 \(quantity) 個", value: $quantity, in: 1...99)
                    DatePicker("日付", selection: $occurredAt, displayedComponents: .date)
                    if exceedsOwnedQuantity {
                        Text("現在の所持数を超えて手放すことはできません。")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                FavorecoRegistrationSection("詳細（任意）") {
                    TextField("合計金額", text: $amountText).keyboardType(.numberPad)
                    TextField("場所・店舗", text: $place)
                    TextField("メモ", text: $memo, axis: .vertical).lineLimit(2...5)
                }
                if items.isEmpty {
                    Text("先にラインナップの種類を追加してください。").foregroundStyle(.secondary)
                }
            }
            .favorecoRegistrationFormCanvas()
            .navigationTitle("入手・手放しを記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(selectedItemID == nil || exceedsOwnedQuantity)
                }
            }
            .onAppear { if selectedItemID == nil { selectedItemID = items.first?.id } }
            .alert("保存できませんでした", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(errorMessage ?? "") }
        }
    }

    private func save() {
        guard let item = selectedItem, !exceedsOwnedQuantity else { return }
        let amount = Decimal(string: amountText.replacingOccurrences(of: ",", with: "")) ?? 0
        modelContext.insert(CollectibleTransaction(
            kindKey: kind.rawValue,
            quantity: quantity,
            occurredAt: occurredAt,
            amount: amount,
            placeNameSnapshot: place.trimmingCharacters(in: .whitespacesAndNewlines),
            memo: memo.trimmingCharacters(in: .whitespacesAndNewlines),
            item: item
        ))
        item.updatedAt = Date()
        series.updatedAt = Date()
        do { try modelContext.save(); dismiss() }
        catch { modelContext.rollback(); errorMessage = "履歴を保存できませんでした。" }
    }
}

private struct CollectibleItemDetailView: View {
    let item: CollectibleItem
    let accentColor: Color
    @Environment(\.modelContext) private var modelContext
    @State private var isShowingEditor = false
    @State private var isShowingTransaction = false

    var body: some View {
        List {
            Section {
                if let data = item.imageData, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: .infinity)
                }
                HStack {
                    CollectibleMetric(value: "\(item.currentQuantity)", label: "現在の所持数")
                    CollectibleMetric(value: "\(item.duplicateQuantity)", label: "ダブり")
                }
                Button { isShowingTransaction = true } label: {
                    FavorecoIconLabel("入手・手放しを記録", systemImage: "plusminus.circle.fill")
                }.tint(accentColor)
            }
            if !item.memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                FavorecoRegistrationSection("メモ") {
                    Text(item.memo)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            FavorecoRegistrationSection("履歴") {
                let transactions = (item.transactions ?? []).sorted { $0.occurredAt > $1.occurredAt }
                if transactions.isEmpty { Text("履歴はまだありません").foregroundStyle(.secondary) }
                ForEach(transactions) { transaction in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(transaction.kind.displayName)
                            Text(transaction.occurredAt, style: .date).font(.caption).foregroundStyle(.secondary)
                            if !transaction.placeNameSnapshot.isEmpty { Text(transaction.placeNameSnapshot).font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        Text("\(transaction.signedQuantity > 0 ? "+" : "")\(transaction.signedQuantity)")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(transaction.signedQuantity > 0 ? accentColor : .secondary)
                    }
                    .swipeActions {
                        Button("削除", role: .destructive) { modelContext.delete(transaction); try? modelContext.save() }
                    }
                }
            }
        }
        .navigationTitle(item.displayName)
        .toolbar { Button("編集") { isShowingEditor = true } }
        .sheet(isPresented: $isShowingEditor) {
            if let series = item.series { CollectibleItemEditorView(series: series, item: item) }
        }
        .sheet(isPresented: $isShowingTransaction) {
            if let series = item.series { CollectibleTransactionEditorView(series: series, initialItem: item) }
        }
    }
}

private enum CollectibleImageLoader {
    static func load(_ item: PhotosPickerItem?) async -> Data? {
        guard let data = try? await item?.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return nil }
        return image.jpegData(compressionQuality: 0.82)
    }
}
