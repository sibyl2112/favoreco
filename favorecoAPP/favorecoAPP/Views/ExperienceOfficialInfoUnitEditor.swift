import SwiftUI

struct ExperienceOfficialInfoUnitEditor: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Binding var officialURL: String
    @Binding var title: String
    @Binding var seriesName: String
    @Binding var visitedAt: Date
    @Binding var venueName: String
    @Binding var venueAddress: String
    @Binding var pendingPeople: [PendingPersonLink]
    @Binding var advancedEntries: [AdvancedFieldEntry]

    @AppStorage(AppStorageKeys.usesURLImportAssist) private var usesURLImportAssist = true
    @State private var candidate: URLMetadataCandidate?
    @State private var isLoading = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("公式URL（任意）", text: $officialURL)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)

            if usesURLImportAssist {
                Button {
                    Task { await fetchMetadata() }
                } label: {
                    if isLoading {
                        Label("候補を取得中", systemImage: "hourglass")
                    } else {
                        Label("URLから候補を取得", systemImage: "link.badge.plus")
                    }
                }
                .disabled(isLoading || officialURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let candidate {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("取得したタイトル")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                        Text(candidate.title)
                            .font(FavorecoTypography.bodyStrong)
                            .textSelection(.enabled)
                        HStack {
                            Button("タイトルに反映") {
                                title = candidate.title
                            }
                            .buttonStyle(.bordered)
                            Button("シリーズ名に反映") {
                                seriesName = candidate.title
                            }
                            .buttonStyle(.bordered)
                        }

                        if purchaseManager.currentPlan.includesLocalFullFeatures {
                            structuredCandidates(candidate)
                        } else {
                            Label("日時・会場・人物候補はPro以上", systemImage: "lock.fill")
                                .font(FavorecoTypography.captionStrong)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onChange(of: officialURL) { _, _ in
            candidate = nil
            errorMessage = ""
        }
        .onChange(of: usesURLImportAssist) { _, isEnabled in
            if !isEnabled {
                candidate = nil
                errorMessage = ""
            }
        }
    }

    @ViewBuilder
    private func structuredCandidates(_ candidate: URLMetadataCandidate) -> some View {
        if candidate.eventDate != nil || !candidate.venueName.isEmpty || !candidate.venueAddress.isEmpty || !candidate.contributors.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(structuredCandidateTitle(candidate.structuredType))
                    .font(FavorecoTypography.captionStrong)

                if let date = candidate.eventDate {
                    Button {
                        applyStructuredDate(date, candidate: candidate)
                    } label: {
                        Label(
                            "\(candidate.structuredDateLabel): \(formattedStructuredDate(date, type: candidate.structuredType))",
                            systemImage: "calendar"
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                }

                if !candidate.venueName.isEmpty || !candidate.venueAddress.isEmpty {
                    Button {
                        if !candidate.venueName.isEmpty { venueName = candidate.venueName }
                        if !candidate.venueAddress.isEmpty { venueAddress = candidate.venueAddress }
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Label(candidate.venueName.isEmpty ? "住所を反映" : candidate.venueName, systemImage: "mappin.and.ellipse")
                            if !candidate.venueAddress.isEmpty {
                                Text(candidate.venueAddress)
                                    .font(FavorecoTypography.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                }

                ForEach(candidate.contributors) { contributor in
                    Button {
                        appendContributor(contributor)
                    } label: {
                        Label("\(contributor.roleName): \(contributor.name)", systemImage: "person.badge.plus")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .disabled(hasContributor(contributor))
                }
            }
        } else {
            Text("このページには利用できる構造化データがありません。")
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func structuredCandidateTitle(_ type: String) -> String {
        switch type {
        case "Book": return "書籍の構造化候補"
        case "Movie": return "映画の構造化候補"
        default: return "イベントの構造化候補"
        }
    }

    private func formattedStructuredDate(_ date: Date, type: String) -> String {
        type == "Event"
            ? date.formatted(date: .long, time: .shortened)
            : date.formatted(date: .long, time: .omitted)
    }

    private func applyStructuredDate(_ date: Date, candidate: URLMetadataCandidate) {
        if candidate.structuredType == "Event" {
            visitedAt = date
            return
        }
        let label = candidate.structuredDateLabel
        let value = date.formatted(date: .long, time: .omitted)
        if let index = advancedEntries.firstIndex(where: { $0.trimmedLabel == label }) {
            advancedEntries[index].value = value
        } else {
            advancedEntries.append(AdvancedFieldEntry(label: label, value: value))
        }
    }

    private func hasContributor(_ contributor: URLContributorCandidate) -> Bool {
        pendingPeople.contains {
            normalizedPersonName($0.name) == normalizedPersonName(contributor.name) && $0.role.key == contributor.roleKey
        }
    }

    private func appendContributor(_ contributor: URLContributorCandidate) {
        guard !hasContributor(contributor) else { return }
        pendingPeople.append(
            PendingPersonLink(name: contributor.name, role: PersonRoleOption.option(for: contributor.roleKey))
        )
    }

    @MainActor
    private func fetchMetadata() async {
        isLoading = true
        candidate = nil
        errorMessage = ""
        defer { isLoading = false }
        do {
            let result = try await URLMetadataService.fetch(
                from: officialURL,
                includesStructuredData: purchaseManager.currentPlan.includesLocalFullFeatures
            )
            candidate = result
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "候補を取得できませんでした。"
        }
    }
}

struct ExperienceOfficialInfoReferenceView: View {
    var body: some View {
        Text("公式URLや参考リンクは対象詳細で編集します。")
            .font(FavorecoTypography.caption)
            .foregroundStyle(.secondary)
    }
}
