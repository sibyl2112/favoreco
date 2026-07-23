import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct AddCollectibleSeriesView: View {
    let category: RecordCategory

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var kind = CollectibleKind.capsuleToy
    @State private var maker = ""
    @State private var releaseText = ""
    @State private var lineupCount = 1
    @State private var officialURL = ""
    @State private var memo = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("シリーズ") {
                    TextField("シリーズ名", text: $title)
                    Picker("グッズの種類", selection: $kind) {
                        ForEach(CollectibleKind.allCases) { value in
                            Text(value.displayName).tag(value)
                        }
                    }
                    TextField("メーカー・発売元（任意）", text: $maker)
                    TextField("発売時期（任意）", text: $releaseText)
                    Stepper("全 \(lineupCount) 種類", value: $lineupCount, in: 1...100)
                }

                Section("画像") {
                    let photoActionTitle = imageData == nil ? "シリーズ画像を選ぶ" : "シリーズ画像を変更"
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(photoActionTitle, systemImage: "photo")
                    }
                    if let imageData, let image = UIImage(data: imageData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }

                Section("補足") {
                    TextField("公式URL（任意）", text: $officialURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    TextField("メモ（任意）", text: $memo, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("シリーズを追加")
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
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = "シリーズを保存できませんでした。もう一度お試しください。"
        }
    }
}

struct CollectibleCategorySeriesGrid: View {
    let events: [ExperienceEvent]
    let tint: Color
    let onAdd: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("シリーズ")
                        .font(.title3.bold())
                    Text("集めた種類とダブりをシリーズごとに確認できます")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onAdd) { Image(systemName: "plus.circle.fill").font(.title2) }
                    .tint(tint)
            }

            if events.isEmpty {
                ContentUnavailableView {
                    Label("シリーズはまだありません", systemImage: "shippingbox")
                } description: {
                    Text("カプセルトイやランダムグッズの全種類を登録して、収集状況を残しましょう。")
                } actions: {
                    Button("最初のシリーズを追加", action: onAdd)
                        .buttonStyle(.borderedProminent)
                        .tint(tint)
                }
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(events.filter { !$0.isArchived }.sorted { $0.updatedAt > $1.updatedAt }) { event in
                        NavigationLink {
                            EventDetailView(event: event)
                        } label: {
                            CollectibleSeriesCard(event: event, tint: tint)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct CollectibleSeriesCard: View {
    let event: ExperienceEvent
    let tint: Color

    var body: some View {
        let summary = CollectibleSeriesSummary.make(series: event)
        VStack(alignment: .leading, spacing: 9) {
            Group {
                if let data = event.eyecatchData, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    ZStack {
                        tint.opacity(0.12)
                        Image(systemName: "shippingbox.fill").font(.largeTitle).foregroundStyle(tint)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(event.title).font(.subheadline.bold()).lineLimit(2)
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
                    Label("入手・手放し", systemImage: "plusminus.circle.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(accentColor)
                Button { isShowingItemEditor = true } label: {
                    Label("種類を追加", systemImage: "square.grid.2x2.fill")
                }
                .buttonStyle(.bordered).tint(accentColor)
            }

            Picker("表示", selection: $filter) {
                ForEach(CollectibleItemFilter.allCases) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)

            if items.isEmpty {
                ContentUnavailableView("該当する種類はありません", systemImage: "checkmark.circle")
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
                Group {
                    if let data = item.imageData, let image = UIImage(data: data) {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        ZStack {
                            accentColor.opacity(0.1)
                            Image(systemName: item.currentQuantity > 0 ? "checkmark.seal.fill" : "photo")
                                .font(.title).foregroundStyle(item.currentQuantity > 0 ? accentColor : .secondary)
                        }
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
    @State private var isCompletionTarget: Bool
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var errorMessage: String?

    init(series: ExperienceEvent, item: CollectibleItem? = nil) {
        self.series = series
        self.item = item
        _name = State(initialValue: item?.name ?? "")
        _variantName = State(initialValue: item?.variantName ?? "")
        _isCompletionTarget = State(initialValue: item?.isCompletionTarget ?? true)
        _imageData = State(initialValue: item?.imageData)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("種類") {
                    TextField("名前（例：赤・キャラクター名）", text: $name)
                    TextField("バリエーション・レア度（任意）", text: $variantName)
                    Toggle("コンプリート対象に含める", isOn: $isCompletionTarget)
                }
                Section("画像") {
                    let photoActionTitle = imageData == nil ? "画像を選ぶ" : "画像を変更"
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(photoActionTitle, systemImage: "photo")
                    }
                    if let imageData, let image = UIImage(data: imageData) {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 240)
                    }
                }
            }
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
        target.isCompletionTarget = isCompletionTarget
        target.imageData = imageData
        target.updatedAt = Date()
        series.updatedAt = Date()
        do { try modelContext.save(); dismiss() }
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
                Section("対象") {
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
                Section("詳細（任意）") {
                    TextField("合計金額", text: $amountText).keyboardType(.numberPad)
                    TextField("場所・店舗", text: $place)
                    TextField("メモ", text: $memo, axis: .vertical).lineLimit(2...5)
                }
                if items.isEmpty {
                    Text("先にラインナップの種類を追加してください。").foregroundStyle(.secondary)
                }
            }
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
                    Label("入手・手放しを記録", systemImage: "plusminus.circle.fill")
                }.tint(accentColor)
            }
            Section("履歴") {
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
