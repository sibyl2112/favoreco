//
//  GenreOnboardingView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import SwiftUI
import SwiftData

struct GenreOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppStorageKeys.hasCompletedGenreOnboarding) private var hasCompletedGenreOnboarding = false
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
    @State private var selectedTemplateKeys: Set<String> = []
    @State private var step: OnboardingStep = .intro

    private var builtInCategories: [RecordCategory] {
        categories.filter(\.isBuiltIn)
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
            Divider()
            footer
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
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .intro:
            OnboardingMessagePanel(
                symbol: "bookmark.fill",
                title: "観た・行った・体験したを、美しく一生残す。",
                message: "favorecoは、映画も観劇も酒も御朱印も、あなたの体験をジャンル横断で記録するアプリです。",
                accentColor: Color(hex: "#9F2F4D")
            )
        case .records:
            VStack(alignment: .leading, spacing: 14) {
                Text("残せるもの")
                    .font(FavorecoTypography.sectionTitle)
                Text("1件の記録に、必要な情報だけをまとまった形で残します。")
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)

                OnboardingFeatureRow(color: Color(hex: "#9F2F4D"), title: "体験の基本", message: "タイトル / 日付 / 場所 / 評価")
                OnboardingFeatureRow(color: Color(hex: "#A9D4EA"), title: "写真と思い出", message: "写真 / メモ / OCR取込")
                OnboardingFeatureRow(color: Color(hex: "#D69B4F"), title: "予定とチケット", message: "状態 / 座席 / 金額")
                OnboardingFeatureRow(color: Color(hex: "#6F8F7A"), title: "人物・団体", message: "出演 / 作者 / ゲスト")
            }
        case .crossGenre:
            VStack(alignment: .leading, spacing: 14) {
                Text("ジャンルをまたげる")
                    .font(FavorecoTypography.sectionTitle)
                Text("映画も、観劇も、酒も、同じ場所に。あとから表示ジャンルは変更できます。")
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    OnboardingGenreBubble(name: "観劇", color: Color(hex: "#9F2F4D"), icon: "theatermasks.fill")
                    OnboardingGenreBubble(name: "映画", color: Color(hex: "#D69B4F"), icon: "film.fill")
                    OnboardingGenreBubble(name: "美術", color: Color(hex: "#A9D4EA"), icon: "paintpalette.fill")
                    OnboardingGenreBubble(name: "酒", color: Color(hex: "#6F8F7A"), icon: "wineglass.fill")
                }
            }
        case .privacy:
            VStack(alignment: .leading, spacing: 14) {
                Text("安心して残せる")
                    .font(FavorecoTypography.sectionTitle)
                Text("最初から権限をまとめて求めません。必要な機能を使う時だけ確認します。")
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)

                OnboardingInfoCard(icon: "photo", title: "写真メタデータ削除", message: "位置情報などは写真ファイルではなく記録データ側で管理します。")
                OnboardingInfoCard(icon: "icloud.slash", title: "同期はあとから選択", message: "まず端末内に保存。iCloud同期や自動バックアップは後で選べます。")
                OnboardingInfoCard(icon: "bell.badge", title: "通知も必要な時だけ", message: "予定やチケット作成時に、用途を説明してから案内します。")
            }
        case .genres:
            VStack(alignment: .leading, spacing: 14) {
                Text("ジャンルを選ぶ")
                    .font(FavorecoTypography.sectionTitle)
                Text("まず使うものだけで始めます。最低ひとつ選んでください。")
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)

                if builtInCategories.isEmpty {
                    OnboardingEmptyStateRow(
                        icon: "square.grid.2x2",
                        title: "ジャンルを準備中です",
                        message: "標準ジャンルの読み込みが終わると選択できます。"
                    )
                    .padding(14)
                    .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    VStack(spacing: 8) {
                        ForEach(builtInCategories) { category in
                            GenreSelectionRow(
                                category: category,
                                isSelected: selectedTemplateKeys.contains(category.templateKey)
                            ) {
                                toggle(category)
                            }
                            .padding(12)
                            .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }

                    if !hasSelection {
                        Label("何もありません。ひとつ選ぶと開始できます。", systemImage: "exclamationmark.circle")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        case .ready:
            VStack(alignment: .leading, spacing: 14) {
                OnboardingMessagePanel(
                    symbol: "checkmark.seal.fill",
                    title: "準備できました",
                    message: "最初の記録は、あとからでも大丈夫。Homeに入ってから中央の+で追加できます。",
                    accentColor: Color(hex: "#6F8F7A")
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("選択中")
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(.secondary)
                    Text(selectedCategoryNames.isEmpty ? "未選択" : selectedCategoryNames.joined(separator: " / "))
                        .font(FavorecoTypography.bodyStrong)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                OnboardingInfoCard(icon: "gearshape", title: "あとで変更可能", message: "設定 > ジャンル管理から、表示ジャンルや自作ジャンルを変更できます。")
            }
        }
    }

    private var onboardingHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("favoreco")
                    .font(FavorecoTypography.jpSerif(26, weight: .bold, relativeTo: .largeTitle))
                Text("初期設定")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(step.index + 1)/\(OnboardingStep.allCases.count)")
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.background, in: Capsule())
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                ForEach(OnboardingStep.allCases) { item in
                    Circle()
                        .fill(item == step ? Color(hex: "#9F2F4D") : Color(.tertiaryLabel))
                        .frame(width: item == step ? 8 : 6, height: item == step ? 8 : 6)
                }
            }

            HStack(spacing: 12) {
                if step != .intro {
                    Button("戻る") {
                        step = step.previous
                    }
                    .buttonStyle(.bordered)
                }

                Button(primaryButtonTitle) {
                    if step == .ready {
                        complete()
                    } else {
                        step = step.next
                    }
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
        case .genres:
            return "選んで次へ"
        case .ready:
            return "favorecoを始める"
        default:
            return "次へ"
        }
    }

    private enum OnboardingStep: Int, CaseIterable, Identifiable {
        case intro
        case records
        case crossGenre
        case privacy
        case genres
        case ready

        var id: Int { rawValue }
        var index: Int { rawValue }

        var next: OnboardingStep {
            OnboardingStep(rawValue: min(rawValue + 1, Self.allCases.count - 1)) ?? .ready
        }

        var previous: OnboardingStep {
            OnboardingStep(rawValue: max(rawValue - 1, 0)) ?? .intro
        }
    }

    private func toggle(_ category: RecordCategory) {
        if selectedTemplateKeys.contains(category.templateKey) {
            selectedTemplateKeys.remove(category.templateKey)
        } else {
            selectedTemplateKeys.insert(category.templateKey)
        }
    }

    private func complete() {
        let selectedKeys = selectedTemplateKeys.isEmpty
            ? Set(builtInCategories.prefix(1).map(\.templateKey))
            : selectedTemplateKeys
        let now = Date()

        for category in builtInCategories {
            category.isArchived = !selectedKeys.contains(category.templateKey)
            category.updatedAt = now
        }

        do {
            try CategoryPresetSeeder.ensureAtLeastOneActiveCategory(in: modelContext)
            try modelContext.save()
            hasCompletedGenreOnboarding = true
        } catch {
            assertionFailure("Failed to save genre onboarding: \(error)")
        }
    }
}

private struct GenreSelectionRow: View {
    let category: RecordCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: category.iconSymbol)
                    .foregroundStyle(Color(hex: category.colorHex))
                    .frame(width: 28)

                Text(category.name)
                    .font(FavorecoTypography.bodyStrong)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color(hex: category.colorHex) : .secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct OnboardingMessagePanel: View {
    let symbol: String
    let title: String
    let message: String
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: symbol)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(accentColor)
                .frame(width: 74, height: 74)
                .background(accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

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
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct OnboardingFeatureRow: View {
    let color: Color
    let title: String
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(FavorecoTypography.bodyStrong)
                Text(message)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct OnboardingGenreBubble: View {
    let name: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 54, height: 54)
                .background(color.opacity(0.13), in: Circle())
            Text(name)
                .font(FavorecoTypography.bodyStrong)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct OnboardingInfoCard: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color(hex: "#9F2F4D"))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(FavorecoTypography.bodyStrong)
                Text(message)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct OnboardingEmptyStateRow: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(FavorecoTypography.bodyStrong)
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
        .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self, SocialAccount.self], inMemory: true)
}
