import SwiftData
import SwiftUI

struct FavoAnniversaryManagementView: View {
    let profile: FavoriteProfile

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @State private var isAdding = false
    @State private var isShowingPlans = false
    @State private var selectedAnniversary: FavoAnniversary?
    @State private var anniversaryPendingDeletion: FavoAnniversary?
    @State private var message = ""

    private var anniversaries: [FavoAnniversary] {
        (profile.anniversaries ?? []).sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.createdAt < rhs.createdAt
        }
    }

    private var canAddAnniversary: Bool {
        FavoAnniversaryAccess.canAdd(
            plan: purchaseManager.currentPlan,
            existingCount: anniversaries.count
        )
    }

    private var canEditExistingAnniversaries: Bool {
        FavoAnniversaryAccess.canEditExisting(
            plan: purchaseManager.currentPlan,
            existingCount: anniversaries.count
        )
    }

    var body: some View {
        List {
            Section {
                Button {
                    if canAddAnniversary {
                        isAdding = true
                    } else {
                        isShowingPlans = true
                    }
                } label: {
                    Label(
                        canAddAnniversary ? "記念日を追加" : "複数の記念日はPro以上",
                        systemImage: canAddAnniversary ? "calendar.badge.plus" : "lock.fill"
                    )
                }
            } footer: {
                Text("無料版はカスタム記念日1件まで、Pro以上は複数登録できます。毎年、同じ月日に記念日として表示します。")
            }

            Section("登録済み \(anniversaries.count)件") {
                if anniversaries.isEmpty {
                    Text("記念日はまだありません。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(anniversaries) { anniversary in
                        if canEditExistingAnniversaries {
                            Button {
                                selectedAnniversary = anniversary
                            } label: {
                                FavoAnniversaryManagementRow(anniversary: anniversary)
                            }
                            .buttonStyle(.plain)
                            .swipeActions {
                                Button("削除", role: .destructive) {
                                    anniversaryPendingDeletion = anniversary
                                }
                            }
                        } else {
                            FavoAnniversaryManagementRow(
                                anniversary: anniversary,
                                showsDisclosureIndicator: false
                            )
                                .opacity(0.82)
                        }
                    }
                    .onMove { source, destination in
                        guard purchaseManager.currentPlan.includesLocalFullFeatures else { return }
                        moveAnniversaries(from: source, to: destination)
                    }
                    .moveDisabled(!purchaseManager.currentPlan.includesLocalFullFeatures)
                }
            }

            if !canEditExistingAnniversaries {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("保存済みの記念日はそのままです", systemImage: "lock.fill")
                            .font(FavorecoTypography.bodyStrong)
                        Text("無料版へ戻っても削除されません。複数の記念日の編集・並べ替えを再開するにはPro以上が必要です。")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                        Button("プランを見る") { isShowingPlans = true }
                    }
                }
            }

            if !message.isEmpty {
                Section {
                    Text(message)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("FAVO記念日")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if purchaseManager.currentPlan.includesLocalFullFeatures && anniversaries.count > 1 {
                EditButton()
            }
        }
        .sheet(isPresented: $isAdding) {
            NavigationStack {
                FavoAnniversaryEditorView(
                    profile: profile,
                    anniversary: nil,
                    nextSortOrder: anniversaries.map(\.sortOrder).max().map { $0 + 1 } ?? 0
                )
            }
        }
        .sheet(item: $selectedAnniversary) { anniversary in
            NavigationStack {
                FavoAnniversaryEditorView(
                    profile: profile,
                    anniversary: anniversary,
                    nextSortOrder: anniversary.sortOrder
                )
            }
        }
        .sheet(isPresented: $isShowingPlans) {
            NavigationStack {
                BillingPlanSettingsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("閉じる") { isShowingPlans = false }
                        }
                    }
            }
        }
        .confirmationDialog(
            "この記念日を削除しますか？",
            isPresented: Binding(
                get: { anniversaryPendingDeletion != nil },
                set: { if !$0 { anniversaryPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("記念日を削除", role: .destructive, action: deletePendingAnniversary)
            Button("キャンセル", role: .cancel) { anniversaryPendingDeletion = nil }
        }
    }

    private func moveAnniversaries(from source: IndexSet, to destination: Int) {
        guard purchaseManager.currentPlan.includesLocalFullFeatures else { return }
        var reordered = anniversaries
        reordered.move(fromOffsets: source, toOffset: destination)
        let now = Date()
        for (index, anniversary) in reordered.enumerated() {
            anniversary.sortOrder = index
            anniversary.updatedAt = now
        }
        saveChanges(successMessage: "並び順を更新しました。")
    }

    private func deletePendingAnniversary() {
        guard canEditExistingAnniversaries else { return }
        guard let anniversary = anniversaryPendingDeletion else { return }
        let removedID = anniversary.id
        anniversaryPendingDeletion = nil
        modelContext.delete(anniversary)
        let now = Date()
        for (index, item) in anniversaries.filter({ $0.id != removedID }).enumerated() {
            item.sortOrder = index
            item.updatedAt = now
        }
        saveChanges(successMessage: "記念日を削除しました。")
    }

    private func saveChanges(successMessage: String) {
        do {
            try modelContext.save()
            message = successMessage
        } catch {
            modelContext.rollback()
            message = "保存できませんでした: \(error.localizedDescription)"
        }
    }
}

private struct FavoAnniversaryManagementRow: View {
    let anniversary: FavoAnniversary
    var showsDisclosureIndicator = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 38, height: 38)
                .background(Color(.secondarySystemGroupedBackground), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(anniversary.title)
                    .font(FavorecoTypography.bodyStrong)
                Text(FavorecoDateText.fullDate(anniversary.date))
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if showsDisclosureIndicator {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }
}

private struct FavoAnniversaryEditorView: View {
    let profile: FavoriteProfile
    let anniversary: FavoAnniversary?
    let nextSortOrder: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @State private var title: String
    @State private var date: Date
    @State private var errorMessage = ""

    init(profile: FavoriteProfile, anniversary: FavoAnniversary?, nextSortOrder: Int) {
        self.profile = profile
        self.anniversary = anniversary
        self.nextSortOrder = nextSortOrder
        _title = State(initialValue: anniversary?.title ?? "")
        _date = State(initialValue: anniversary?.date ?? Date())
    }

    var body: some View {
        Form {
            Section("記念日") {
                TextField("名称（例：初めて会った日）", text: $title)
                DatePicker("日付", selection: $date, displayedComponents: .date)
            }
            Section {
                Text("登録した月日を毎年の記念日として扱い、起点日からの周年を表示します。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
            if !errorMessage.isEmpty {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
        }
        .navigationTitle(anniversary == nil ? "記念日を追加" : "記念日を編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存", action: save)
                    .disabled(trimmedTitle.isEmpty)
            }
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        if anniversary == nil,
           !FavoAnniversaryAccess.canAdd(
               plan: purchaseManager.currentPlan,
               existingCount: (profile.anniversaries ?? []).count
           ) {
            errorMessage = "複数の記念日を追加するにはPro以上が必要です。"
            return
        }
        let now = Date()
        let model = anniversary ?? FavoAnniversary(
            sortOrder: nextSortOrder,
            createdAt: now,
            updatedAt: now,
            profile: profile
        )
        if anniversary == nil { modelContext.insert(model) }
        model.title = trimmedTitle
        model.date = date
        model.updatedAt = now
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = "保存できませんでした: \(error.localizedDescription)"
        }
    }
}

enum FavoAnniversaryAccess {
    nonisolated static let freeCustomAnniversaryLimit = 1

    nonisolated static func canAdd(plan: FavorecoPlan, existingCount: Int) -> Bool {
        plan.includesLocalFullFeatures || existingCount < freeCustomAnniversaryLimit
    }

    nonisolated static func canEditExisting(plan: FavorecoPlan, existingCount: Int) -> Bool {
        plan.includesLocalFullFeatures || existingCount <= freeCustomAnniversaryLimit
    }
}

struct FavoAnniversarySection: View {
    let profile: FavoriteProfile
    let colorHex: String

    private var anniversaries: [FavoAnniversary] {
        (profile.anniversaries ?? []).sorted { lhs, rhs in
            let lhsDate = FavoAnniversaryDate.nextOccurrence(for: lhs.date) ?? .distantFuture
            let rhsDate = FavoAnniversaryDate.nextOccurrence(for: rhs.date) ?? .distantFuture
            if lhsDate != rhsDate { return lhsDate < rhsDate }
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                FavoSectionTitle(title: "記念日", subtitle: anniversaries.isEmpty ? nil : "\(anniversaries.count)件")
                Spacer()
                NavigationLink {
                    FavoAnniversaryManagementView(profile: profile)
                } label: {
                    Text(anniversaries.isEmpty ? "追加" : "管理")
                        .font(FavorecoTypography.captionStrong)
                }
            }

            if anniversaries.isEmpty {
                NavigationLink {
                    FavoAnniversaryManagementView(profile: profile)
                } label: {
                    Label("大切な日を登録する", systemImage: "calendar.badge.plus")
                        .font(FavorecoTypography.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                        .padding(.horizontal, 14)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 8) {
                    ForEach(anniversaries.prefix(3)) { anniversary in
                        FavoAnniversaryCard(anniversary: anniversary, colorHex: colorHex)
                    }
                    if anniversaries.count > 3 {
                        Text("ほか\(anniversaries.count - 3)件は「管理」から確認できます。")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
        }
    }
}

private struct FavoAnniversaryCard: View {
    let anniversary: FavoAnniversary
    let colorHex: String

    private var nextOccurrence: Date? {
        FavoAnniversaryDate.nextOccurrence(for: anniversary.date)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(hex: colorHex))
                .frame(width: 42, height: 42)
                .background(Color(hex: colorHex).opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(anniversary.title)
                    .font(FavorecoTypography.bodyStrong)
                Text(FavorecoDateText.fullDate(anniversary.date, includesWeekday: false))
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 3) {
                if let nextOccurrence {
                    Text(FavoAnniversaryDate.countdownText(to: nextOccurrence))
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(Color(hex: colorHex))
                    Text("次回 \(FavorecoDateText.compactDate(nextOccurrence))")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
                let years = FavoAnniversaryDate.completedYears(since: anniversary.date)
                if years > 0 {
                    Text("\(years)周年")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

enum FavoAnniversaryDate {
    nonisolated static func nextOccurrence(for sourceDate: Date, from referenceDate: Date = Date()) -> Date? {
        let calendar = calendar
        let source = calendar.startOfDay(for: sourceDate)
        let today = calendar.startOfDay(for: referenceDate)
        let minimumDate = max(source, today)
        let sourceComponents = calendar.dateComponents([.month, .day], from: source)
        let minimumYear = calendar.component(.year, from: minimumDate)

        for year in minimumYear...(minimumYear + 12) {
            guard let candidate = calendar.date(from: DateComponents(
                calendar: calendar,
                timeZone: calendar.timeZone,
                year: year,
                month: sourceComponents.month,
                day: sourceComponents.day
            )), candidate >= minimumDate else { continue }
            let candidateComponents = calendar.dateComponents([.month, .day], from: candidate)
            guard candidateComponents.month == sourceComponents.month,
                  candidateComponents.day == sourceComponents.day else { continue }
            return candidate
        }
        return nil
    }

    nonisolated static func completedYears(since sourceDate: Date, asOf referenceDate: Date = Date()) -> Int {
        let calendar = calendar
        let source = calendar.startOfDay(for: sourceDate)
        let reference = calendar.startOfDay(for: referenceDate)
        guard reference >= source else { return 0 }
        return max(calendar.dateComponents([.year], from: source, to: reference).year ?? 0, 0)
    }

    nonisolated static func countdownText(to date: Date, from referenceDate: Date = Date()) -> String {
        let calendar = calendar
        let today = calendar.startOfDay(for: referenceDate)
        let target = calendar.startOfDay(for: date)
        let days = max(calendar.dateComponents([.day], from: today, to: target).day ?? 0, 0)
        if days == 0 { return "今日" }
        return "あと\(days)日"
    }

    nonisolated private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }
}
