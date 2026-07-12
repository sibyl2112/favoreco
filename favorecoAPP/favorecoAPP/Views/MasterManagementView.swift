import CoreLocation
import SwiftData
import SwiftUI

struct PersonMasterManagementView: View {
    @Query(sort: \PersonMaster.displayName) private var people: [PersonMaster]

    private var activePeople: [PersonMaster] { people.filter { !$0.isArchived } }

    var body: some View {
        List {
            if activePeople.isEmpty {
                ContentUnavailableView("人物・団体はまだありません", systemImage: "person.2")
            } else {
                ForEach(activePeople) { person in
                    NavigationLink {
                        PersonMasterMergeView(person: person)
                    } label: {
                        MasterListRow(
                            title: person.displayName,
                            subtitle: person.reading,
                            countLabel: "\(person.eventLinks?.count ?? 0)件の紐付け",
                            systemImage: "person.crop.circle"
                        )
                    }
                }
            }
        }
        .navigationTitle("人物・団体マスター")
    }
}

struct PlaceMasterManagementView: View {
    @Query(sort: \PlaceMaster.name) private var places: [PlaceMaster]

    private var activePlaces: [PlaceMaster] { places.filter { !$0.isArchived } }

    var body: some View {
        List {
            if activePlaces.isEmpty {
                ContentUnavailableView("場所はまだありません", systemImage: "mappin.and.ellipse")
            } else {
                ForEach(activePlaces) { place in
                    NavigationLink {
                        PlaceMasterMergeView(place: place)
                    } label: {
                        MasterListRow(
                            title: place.name,
                            subtitle: place.address,
                            countLabel: "\((place.visits?.count ?? 0) + (place.plans?.count ?? 0))件の利用",
                            systemImage: "mappin.circle"
                        )
                    }
                }
            }
        }
        .navigationTitle("場所マスター")
    }
}

private struct PersonMasterMergeView: View {
    let person: PersonMaster
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PersonMaster.displayName) private var people: [PersonMaster]
    @State private var selectedDestination: PersonMaster?
    @State private var errorMessage = ""

    private var candidates: [PersonMaster] {
        people.filter { !$0.isArchived && $0.id != person.id && isSimilarPerson($0, person) }
    }

    var body: some View {
        Form {
            Section("現在のマスター") {
                LabeledContent("表示名", value: person.displayName)
                if !person.reading.isEmpty { LabeledContent("よみ", value: person.reading) }
                LabeledContent("紐付け", value: "\(person.eventLinks?.count ?? 0)件")
            }

            Section("似た人物・団体") {
                if candidates.isEmpty {
                    Text("統合候補はありません。名称・よみ・別名が近い候補をここに表示します。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(candidates) { candidate in
                        Button {
                            selectedDestination = candidate
                        } label: {
                            MasterCandidateRow(
                                title: candidate.displayName,
                                subtitle: candidate.reading,
                                countLabel: "\(candidate.eventLinks?.count ?? 0)件の紐付け"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !errorMessage.isEmpty {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
        }
        .navigationTitle(person.displayName)
        .confirmationDialog(
            "人物・団体を統合しますか？",
            isPresented: Binding(get: { selectedDestination != nil }, set: { if !$0 { selectedDestination = nil } }),
            titleVisibility: .visible
        ) {
            if let destination = selectedDestination {
                Button("「\(destination.displayName)」へ統合", role: .destructive) {
                    merge(into: destination)
                }
            }
            Button("キャンセル", role: .cancel) { selectedDestination = nil }
        } message: {
            Text("すべての人物リンクを統合先へ付け替え、現在のマスターをアーカイブします。過去の表示名スナップショットは変更しません。")
        }
    }

    private func merge(into destination: PersonMaster) {
        do {
            try MasterMergeService.merge(person: person, into: destination, in: modelContext)
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = "統合できませんでした: \(error.localizedDescription)"
        }
    }
}

private struct PlaceMasterMergeView: View {
    let place: PlaceMaster
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlaceMaster.name) private var places: [PlaceMaster]
    @State private var selectedDestination: PlaceMaster?
    @State private var errorMessage = ""

    private var candidates: [PlaceMaster] {
        places.filter { !$0.isArchived && $0.id != place.id && isSimilarPlace($0, place) }
    }

    var body: some View {
        Form {
            Section("現在のマスター") {
                LabeledContent("名称", value: place.name)
                if !place.address.isEmpty { LabeledContent("住所", value: place.address) }
                LabeledContent("利用", value: "\((place.visits?.count ?? 0) + (place.plans?.count ?? 0))件")
            }

            Section("同じ場所の可能性") {
                if candidates.isEmpty {
                    Text("統合候補はありません。名称、住所、座標が近い候補をここに表示します。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(candidates) { candidate in
                        Button {
                            selectedDestination = candidate
                        } label: {
                            MasterCandidateRow(
                                title: candidate.name,
                                subtitle: candidate.address,
                                countLabel: "\((candidate.visits?.count ?? 0) + (candidate.plans?.count ?? 0))件の利用"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !errorMessage.isEmpty {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
        }
        .navigationTitle(place.name)
        .confirmationDialog(
            "場所を統合しますか？",
            isPresented: Binding(get: { selectedDestination != nil }, set: { if !$0 { selectedDestination = nil } }),
            titleVisibility: .visible
        ) {
            if let destination = selectedDestination {
                Button("「\(destination.name)」へ統合", role: .destructive) {
                    merge(into: destination)
                }
            }
            Button("キャンセル", role: .cancel) { selectedDestination = nil }
        } message: {
            Text("記録と予定の場所参照を統合先へ付け替え、現在のマスターをアーカイブします。記録に保存した施設名・住所・座標は変更しません。")
        }
    }

    private func merge(into destination: PlaceMaster) {
        do {
            try MasterMergeService.merge(place: place, into: destination, in: modelContext)
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = "統合できませんでした: \(error.localizedDescription)"
        }
    }
}

private struct MasterListRow: View {
    let title: String
    let subtitle: String
    let countLabel: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage).foregroundStyle(.secondary).frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(FavorecoTypography.bodyStrong)
                if !subtitle.isEmpty { Text(subtitle).font(FavorecoTypography.caption).foregroundStyle(.secondary) }
                Text(countLabel).font(FavorecoTypography.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct MasterCandidateRow: View {
    let title: String
    let subtitle: String
    let countLabel: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(FavorecoTypography.bodyStrong)
                if !subtitle.isEmpty { Text(subtitle).font(FavorecoTypography.caption).foregroundStyle(.secondary) }
                Text(countLabel).font(FavorecoTypography.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "arrow.triangle.merge").foregroundStyle(Color.accentColor)
        }
        .contentShape(Rectangle())
    }
}

private func isSimilarPerson(_ lhs: PersonMaster, _ rhs: PersonMaster) -> Bool {
    let leftName = normalizedMasterText(lhs.displayName)
    let rightName = normalizedMasterText(rhs.displayName)
    if !leftName.isEmpty, leftName == rightName { return true }
    if min(leftName.count, rightName.count) >= 2, leftName.contains(rightName) || rightName.contains(leftName) { return true }
    let leftReading = normalizedMasterText(lhs.reading)
    let rightReading = normalizedMasterText(rhs.reading)
    if !leftReading.isEmpty, leftReading == rightReading { return true }
    let leftAliases = normalizedMasterTerms(lhs.aliasesRaw)
    let rightAliases = normalizedMasterTerms(rhs.aliasesRaw)
    return leftAliases.contains(rightName) || rightAliases.contains(leftName) || !leftAliases.isDisjoint(with: rightAliases)
}

private func isSimilarPlace(_ lhs: PlaceMaster, _ rhs: PlaceMaster) -> Bool {
    let leftName = normalizedMasterText(lhs.name)
    let rightName = normalizedMasterText(rhs.name)
    let sameName = !leftName.isEmpty && leftName == rightName
    let leftAddress = normalizedMasterText(lhs.address)
    let rightAddress = normalizedMasterText(rhs.address)
    let sameAddress = !leftAddress.isEmpty && leftAddress == rightAddress
    let nearby: Bool
    if lhs.latitude != 0, lhs.longitude != 0, rhs.latitude != 0, rhs.longitude != 0 {
        nearby = CLLocation(latitude: lhs.latitude, longitude: lhs.longitude)
            .distance(from: CLLocation(latitude: rhs.latitude, longitude: rhs.longitude)) <= 150
    } else {
        nearby = false
    }
    return sameAddress || nearby || (sameName && (leftAddress.isEmpty || rightAddress.isEmpty))
}

private func normalizedMasterTerms(_ value: String) -> Set<String> {
    Set(value.components(separatedBy: CharacterSet(charactersIn: ",、\n")).map(normalizedMasterText).filter { !$0.isEmpty })
}

private func normalizedMasterText(_ value: String) -> String {
    value.folding(options: [.caseInsensitive, .widthInsensitive, .diacriticInsensitive], locale: .current)
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "　", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}
