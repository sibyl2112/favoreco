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
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
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
                Section {
                    ReleaseNoteContent(release: release)
                        .padding(.vertical, 4)
                } header: {
                    Text("Version \(release.version) ・ \(release.publishedAt)")
                }
            }

            Section {
                Link(destination: AppReleaseNotes.detailURL) {
                    Label("詳細な更新履歴を見る", systemImage: "arrow.up.right.square")
                }
            } footer: {
                Text("Favoreco公式サイトで、各アップデートの詳しい内容を確認できます。")
            }
        }
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
