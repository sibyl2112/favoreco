import SwiftData
import SwiftUI
import UIKit

struct GenreOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppStorageKeys.hasCompletedGenreOnboarding) private var hasCompletedGenreOnboarding = false
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
    @StateObject private var publicPlaceStore = PublicPlaceCatalogStore.shared
    @StateObject private var recurringEventStore = PublicRecurringEventCatalogStore.shared

    @State private var selectedTemplateKeys: Set<String> = []
    @State private var step: OnboardingStep = .genres
    @State private var preparationTask: Task<Void, Never>?
    @State private var saveErrorMessage = ""

    private var builtInCategories: [RecordCategory] {
        categories.filter {
            $0.isBuiltIn && CategoryPresetSeeder.isInitialReleaseTemplate($0.templateKey)
        }
    }

    private var hasSelection: Bool {
        !selectedTemplateKeys.isEmpty
    }

    private var selectedCategoryNames: [String] {
        builtInCategories
            .filter { selectedTemplateKeys.contains($0.templateKey) }
            .map(\.name)
    }

    var body: some View {
        VStack(spacing: 0) {
            onboardingHeader
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    content
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if step != .preparing {
                Divider()
                footer
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            if selectedTemplateKeys.isEmpty {
                selectedTemplateKeys = Set(builtInCategories.map(\.templateKey))
            }
        }
        .onChange(of: builtInCategories.map(\.templateKey)) { _, keys in
            if selectedTemplateKeys.isEmpty {
                selectedTemplateKeys = Set(keys)
            }
        }
        .onDisappear {
            preparationTask?.cancel()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .genres:
            genreSelectionContent
        case .preparing:
            preparationContent
        case .intro:
            OnboardingMessagePanel(
                symbol: "bookmark.fill",
                title: "観た・行った・体験したを、美しく一生残す。",
                message: "favorecoは、選んだジャンルの予定、チケット、写真と思い出をひとつにつなげて残します。",
                accentColor: Color(hex: "#9F2F4D")
            )
        case .records:
            VStack(alignment: .leading, spacing: 14) {
                Text("記録のしかた")
                    .font(FavorecoTypography.sectionTitle)
                Text("画面下の「追加」から、予定でも体験後でも登録できます。必要な情報だけを選んで残せます。")
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)

                OnboardingFeatureRow(color: Color(hex: "#9F2F4D"), title: "まず対象を選ぶ", message: "作品・公演 / 本 / 展示 / 施設")
                OnboardingFeatureRow(color: Color(hex: "#A9D4EA"), title: "体験を残す", message: "日付 / 場所 / 評価 / 写真 / メモ")
                OnboardingFeatureRow(color: Color(hex: "#D69B4F"), title: "先の予定も管理", message: "チケット / 座席 / 金額 / 通知")
            }
        case .crossGenre:
            VStack(alignment: .leading, spacing: 14) {
                Text("ジャンルをまたいで振り返る")
                    .font(FavorecoTypography.sectionTitle)
                Text("Homeでは直近の予定を、FAVOでは人物・作品・場所を軸に、ジャンルをまたいで振り返れます。")
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)

                OnboardingInfoCard(icon: "house", title: "Home", message: "次の予定、チケット、最近の記録をまとめて確認します。")
                OnboardingInfoCard(icon: "heart", title: "FAVO", message: "好きな人物・作品・場所から思い出をたどれます。")
                OnboardingInfoCard(icon: "chart.bar", title: "統計", message: "月・年・ジャンルごとの体験を自動で集計します。")
            }
        case .privacy:
            VStack(alignment: .leading, spacing: 14) {
                Text("必要な時だけ許可")
                    .font(FavorecoTypography.sectionTitle)
                Text("最初に権限をまとめて求めません。写真、通知、同期は、その機能を使う時に説明してから確認します。")
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)

                OnboardingInfoCard(icon: "photo", title: "写真", message: "位置情報などのメタデータを引き継がず保存します。")
                OnboardingInfoCard(icon: "icloud.slash", title: "同期", message: "まず端末内へ保存し、同期や自動バックアップは後から選べます。")
                OnboardingInfoCard(icon: "bell.badge", title: "通知", message: "予定やチケットで必要になった時だけ案内します。")
            }
        case .ready:
            VStack(alignment: .leading, spacing: 14) {
                OnboardingMessagePanel(
                    symbol: "checkmark.seal.fill",
                    title: "準備できました",
                    message: "最初の記録はあとからでも大丈夫です。Homeに入ってから画面下の「追加」で登録できます。",
                    accentColor: Color(hex: "#6F8F7A")
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("使うジャンル")
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(.secondary)
                    Text(selectedCategoryNames.joined(separator: " / "))
                        .font(FavorecoTypography.bodyStrong)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                OnboardingInfoCard(icon: "gearshape", title: "あとで変更可能", message: "設定 > ジャンル管理から、表示ジャンルをいつでも変更できます。")
            }
        }
    }

    private var genreSelectionContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("記録したいジャンルを選ぶ")
                .font(FavorecoTypography.sectionTitle)
            Text("使いたいものにチェックを入れてください。あとから変更できます。")
                .font(FavorecoTypography.body)
                .foregroundStyle(.secondary)

            if builtInCategories.isEmpty {
                OnboardingEmptyStateRow(
                    icon: "square.grid.2x2",
                    title: "ジャンルを準備中です",
                    message: "標準ジャンルの読み込みが終わると選択できます。"
                )
                .padding(14)
                .background(.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                genreGrid
            }

            if !saveErrorMessage.isEmpty {
                FavorecoIconLabel(saveErrorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.red)
            } else if !hasSelection {
                FavorecoIconLabel("最低ひとつ選んでください。", systemImage: "exclamationmark.circle")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var genreGrid: some View {
        let rows = stride(from: 0, to: builtInCategories.count, by: 3).map { start in
            Array(builtInCategories[start..<min(start + 3, builtInCategories.count)])
        }

        return VStack(spacing: 9) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 9) {
                    if row.count == 1 {
                        Color.clear.frame(maxWidth: .infinity)
                    }

                    ForEach(row) { category in
                        GenreVisualSelectionCard(
                            category: category,
                            isSelected: selectedTemplateKeys.contains(category.templateKey)
                        ) {
                            toggle(category)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    ForEach(0..<(3 - row.count), id: \.self) { _ in
                        if row.count != 1 {
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }

                    if row.count == 1 {
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private var preparationContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            ProgressView()
                .controlSize(.large)
                .tint(Color(hex: "#3296BD"))

            VStack(alignment: .leading, spacing: 8) {
                Text("選んだジャンルのDBを準備中")
                    .font(FavorecoTypography.jpSerif(28, weight: .bold, relativeTo: .title))
                Text(preparationMessage)
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                preparationStatusRow(title: "ジャンル設定", isReady: true)
                if needsPlaceCatalog {
                    preparationStatusRow(title: "会場・施設データ", isReady: !publicPlaceStore.entries.isEmpty)
                }
                if needsRecurringEventCatalog {
                    preparationStatusRow(title: "定期イベントデータ", isReady: !recurringEventStore.entries.isEmpty)
                }
            }
            .padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 28)
    }

    private func preparationStatusRow(title: String, isReady: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: isReady ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                .foregroundStyle(isReady ? Color(hex: "#3E8060") : Color(hex: "#3296BD"))
            Text(title)
                .font(FavorecoTypography.bodyStrong)
            Spacer()
            Text(isReady ? "準備済み" : "読込中")
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var preparationMessage: String {
        if needsPlaceCatalog && publicPlaceStore.entries.isEmpty {
            return "初回だけ、観劇やおでかけで使う全国の会場・施設データを読み込んでいます。"
        }
        if needsRecurringEventCatalog && recurringEventStore.entries.isEmpty {
            return "選んだジャンルで使えるイベント候補を読み込んでいます。"
        }
        return "端末内の準備が整いました。最新情報を確認しています。"
    }

    private var needsPlaceCatalog: Bool {
        // The catalog is shared across genres: cinemas, libraries, halls,
        // museums, parks and nature facilities all live in the same cache.
        hasSelection
    }

    private var needsRecurringEventCatalog: Bool {
        !selectedTemplateKeys.isDisjoint(with: ["theater", "live", "museum"])
    }

    private var onboardingHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("FAVORECO")
                    .font(FavorecoTypography.latinDisplay(25, weight: .semibold, relativeTo: .largeTitle))
                    .tracking(2.4)
                Text(step.headerSubtitle)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let progressText = step.progressText {
                Text(progressText)
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.background, in: Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                ForEach(OnboardingStep.guidedSteps) { item in
                    Circle()
                        .fill(item == step ? Color(hex: "#9F2F4D") : Color(.tertiaryLabel))
                        .frame(width: item == step ? 8 : 6, height: item == step ? 8 : 6)
                }
            }

            HStack(spacing: 12) {
                if step.allowsBackNavigation {
                    Button("戻る") {
                        step = step.previous
                    }
                    .buttonStyle(.bordered)
                }

                Button(primaryButtonTitle) {
                    advance()
                }
                .buttonStyle(.borderedProminent)
                .disabled(step == .genres && !hasSelection)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(20)
        .background(.regularMaterial)
    }

    private var primaryButtonTitle: String {
        switch step {
        case .genres: "このジャンルで準備する"
        case .ready: "favorecoを始める"
        default: "次へ"
        }
    }

    private func advance() {
        switch step {
        case .genres:
            startPreparation()
        case .ready:
            complete()
        default:
            step = step.next
        }
    }

    private func toggle(_ category: RecordCategory) {
        saveErrorMessage = ""
        if selectedTemplateKeys.contains(category.templateKey) {
            selectedTemplateKeys.remove(category.templateKey)
        } else {
            selectedTemplateKeys.insert(category.templateKey)
        }
    }

    private func startPreparation() {
        guard hasSelection else { return }
        do {
            try saveGenreSelection()
        } catch {
            saveErrorMessage = "ジャンルを保存できませんでした。もう一度お試しください。"
            return
        }

        step = .preparing
        preparationTask?.cancel()
        preparationTask = Task { @MainActor in
            await prepareSelectedCatalogs()
            guard !Task.isCancelled, step == .preparing else { return }
            step = .intro
        }
    }

    private func prepareSelectedCatalogs() async {
        await withTaskGroup(of: Void.self) { group in
            if needsPlaceCatalog {
                group.addTask {
                    await PublicPlaceCatalogStore.shared.prepare()
                }
            }
            if needsRecurringEventCatalog {
                group.addTask {
                    await PublicRecurringEventCatalogStore.shared.prepare()
                }
            }
        }

        if !needsPlaceCatalog && !needsRecurringEventCatalog {
            try? await Task.sleep(for: .milliseconds(450))
        }
    }

    private func saveGenreSelection() throws {
        let now = Date()
        for category in builtInCategories {
            category.isArchived = !selectedTemplateKeys.contains(category.templateKey)
            category.updatedAt = now
        }
        try CategoryPresetSeeder.ensureAtLeastOneActiveCategory(in: modelContext)
        try modelContext.save()
    }

    private func complete() {
        do {
            try saveGenreSelection()
            hasCompletedGenreOnboarding = true
        } catch {
            saveErrorMessage = "初期設定を保存できませんでした。もう一度お試しください。"
            step = .genres
        }
    }

    private enum OnboardingStep: Int, CaseIterable, Identifiable {
        case genres
        case preparing
        case intro
        case records
        case crossGenre
        case privacy
        case ready

        static let guidedSteps: [OnboardingStep] = [.genres, .intro, .records, .crossGenre, .privacy, .ready]

        var id: Int { rawValue }

        var headerSubtitle: String {
            switch self {
            case .genres: "ジャンル選択"
            case .preparing: "データ準備"
            default: "使い方"
            }
        }

        var progressText: String? {
            guard self != .preparing,
                  let index = Self.guidedSteps.firstIndex(of: self) else { return nil }
            return "\(index + 1)/\(Self.guidedSteps.count)"
        }

        var allowsBackNavigation: Bool {
            self != .genres && self != .preparing
        }

        var next: OnboardingStep {
            switch self {
            case .genres: .preparing
            case .preparing: .intro
            case .intro: .records
            case .records: .crossGenre
            case .crossGenre: .privacy
            case .privacy: .ready
            case .ready: .ready
            }
        }

        var previous: OnboardingStep {
            switch self {
            case .genres, .preparing: .genres
            case .intro: .genres
            case .records: .intro
            case .crossGenre: .records
            case .privacy: .crossGenre
            case .ready: .privacy
            }
        }
    }
}

private struct GenreVisualSelectionCard: View {
    let category: RecordCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                background
                    .overlay {
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.08), .black.opacity(0.78)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .overlay {
                        if !isSelected {
                            Color.black.opacity(0.18)
                        }
                    }

                Text(category.name)
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(9)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.9))
                    .background {
                        Circle()
                            .fill(isSelected ? Color(hex: category.colorHex) : Color.black.opacity(0.24))
                    }
                    .padding(7)
                    .shadow(color: .black.opacity(0.28), radius: 3, y: 2)
            }
            .frame(height: 124)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(isSelected ? Color(hex: category.colorHex) : Color.white.opacity(0.7), lineWidth: isSelected ? 3 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.name)
        .accessibilityValue(isSelected ? "選択中" : "未選択")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var background: some View {
        if let image = bundledHeroImage(named: Self.resourceName(for: category.templateKey)) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color(hex: category.colorHex).opacity(0.82)
                FavorecoIcon(
                    systemName: PhosphorIconGlyph.categorySystemName(
                        templateKey: category.templateKey,
                        storedSystemName: category.iconSymbol
                    ),
                    size: 30
                )
                .foregroundStyle(.white.opacity(0.86))
            }
        }
    }

    private static func resourceName(for templateKey: String) -> String {
        switch templateKey {
        case "theater": "theater-hero-venue-v2"
        case "movie": "movie-hero-default"
        case "live": "live-hero-default"
        case "book": "book-hero-default"
        case "museum": "museum-hero-default"
        case "theme_park": "theme_park-hero-default"
        case "nature_living": "nature_living-hero-zoo"
        default: ""
        }
    }

    private func bundledHeroImage(named resourceName: String) -> UIImage? {
        guard !resourceName.isEmpty else { return nil }
        if let image = UIImage(named: resourceName) { return image }
        guard let url = Bundle.main.url(
            forResource: resourceName,
            withExtension: "jpg",
            subdirectory: "CategoryHeroBackgrounds"
        ) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}

private struct OnboardingMessagePanel: View {
    let symbol: String
    let title: String
    let message: String
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FavorecoIcon(systemName: symbol, size: 42, fallbackWeight: .semibold)
                .foregroundStyle(accentColor)
                .frame(width: 74, height: 74)
                .background(accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(FavorecoTypography.jpSerif(30, weight: .bold, relativeTo: .largeTitle))
                    .fixedSize(horizontal: false, vertical: true)
                Text(message)
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct OnboardingFeatureRow: View {
    let color: Color
    let title: String
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(color).frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(FavorecoTypography.bodyStrong)
                Text(message).font(FavorecoTypography.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct OnboardingInfoCard: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            FavorecoIcon(systemName: icon, size: 17)
                .foregroundStyle(Color(hex: "#9F2F4D"))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(FavorecoTypography.bodyStrong)
                Text(message)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct OnboardingEmptyStateRow: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            FavorecoIcon(systemName: icon, size: 20)
                .foregroundStyle(.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(FavorecoTypography.bodyStrong)
                Text(message)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    GenreOnboardingView()
        .modelContainer(
            for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self, SocialAccount.self],
            inMemory: true
        )
}
