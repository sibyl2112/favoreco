//
//  ReleaseNotesView.swift
//  favorecoAPP
//

import SwiftUI

struct ReleaseUpdateSheet: View {
    let release: AppReleaseNote
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.title)
                            .foregroundStyle(Color.accentColor)

                        Text("Favorecoが更新されました")
                            .font(FavorecoTypography.heroLead)

                        Text("Version \(release.version)")
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(.secondary)
                    }

                    ReleaseNoteContent(release: release)

                    Link(destination: AppReleaseNotes.detailURL) {
                        Label("詳細な更新履歴を見る", systemImage: "arrow.up.right.square")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    TheaterLifecycleFlatStyle.fieldBackground,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.secondary.opacity(0.20), lineWidth: 1)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .background(TheaterLifecycleFlatStyle.canvasBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ReleaseHistoryView: View {
    var body: some View {
        List {
            ForEach(AppReleaseNotes.entries) { release in
                FavorecoSettingsSection("Version \(release.version) ・ \(release.publishedAt)") {
                    ReleaseNoteContent(release: release)
                        .padding(.vertical, 4)
                }
            }

            FavorecoSettingsSectionWithFooter("関連リンク") {
                Link(destination: AppReleaseNotes.detailURL) {
                    Label("詳細な更新履歴を見る", systemImage: "arrow.up.right.square")
                }
            } footer: {
                Text("Favoreco公式サイトで、各アップデートの詳しい内容を確認できます。")
            }
        }
        .favorecoSettingsListLayout()
        .navigationTitle("更新履歴")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ReleaseNoteContent: View {
    let release: AppReleaseNote

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(release.title)
                .font(FavorecoTypography.sectionTitle)

            Text(release.summary)
                .font(FavorecoTypography.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !release.highlights.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(release.highlights, id: \.self) { highlight in
                        Label {
                            Text(highlight)
                                .font(FavorecoTypography.body)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
        }
    }
}
