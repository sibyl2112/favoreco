//
//  ExperiencePeopleUnitEditor.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/15.
//

import Foundation
import SwiftUI

struct PendingPersonLink: Identifiable {
    let id = UUID()
    var name: String
    var role: PersonRoleOption

    func makeEventPersonLink(
        person: PersonMaster,
        event: ExperienceEvent?,
        visit: Visit?,
        sortOrder: Int
    ) -> EventPersonLink {
        EventPersonLink(
            roleKey: role.key,
            displayRole: role.name,
            sortOrder: sortOrder,
            nameSnapshot: name.trimmingCharacters(in: .whitespacesAndNewlines),
            person: person,
            event: event,
            visit: visit
        )
    }
}

struct PersonRoleOption: Identifiable, Hashable {
    let key: String
    let name: String

    var id: String { key }

    static let all: [PersonRoleOption] = [
        PersonRoleOption(key: "artist", name: "アーティスト"),
        PersonRoleOption(key: "cast", name: "出演"),
        PersonRoleOption(key: "lead", name: "主演"),
        PersonRoleOption(key: "writer", name: "作家"),
        PersonRoleOption(key: "author", name: "作者"),
        PersonRoleOption(key: "director", name: "監督"),
        PersonRoleOption(key: "screenplay", name: "脚本"),
        PersonRoleOption(key: "stage_director", name: "演出"),
        PersonRoleOption(key: "original_work", name: "原作"),
        PersonRoleOption(key: "music", name: "音楽"),
        PersonRoleOption(key: "performer", name: "演奏"),
        PersonRoleOption(key: "translator", name: "翻訳"),
        PersonRoleOption(key: "curator", name: "キュレーター"),
        PersonRoleOption(key: "organizer", name: "主催"),
        PersonRoleOption(key: "production", name: "制作"),
        PersonRoleOption(key: "publisher", name: "出版社"),
        PersonRoleOption(key: "guest", name: "ゲスト"),
        PersonRoleOption(key: "other", name: "その他"),
    ]

    static let defaultOption = PersonRoleOption(key: "cast", name: "出演")

    static func option(for key: String) -> PersonRoleOption {
        all.first(where: { $0.key == key }) ?? defaultOption
    }
}

func normalizedPersonName(_ name: String) -> String {
    name
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .folding(options: [.caseInsensitive, .widthInsensitive, .diacriticInsensitive], locale: .current)
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "　", with: "")
}

struct PeopleUnitEditor: View {
    let existingLinks: [EventPersonLink]
    @Binding var deletedLinkIDs: Set<UUID>
    @Binding var pendingLinks: [PendingPersonLink]
    let personMasters: [PersonMaster]

    @AppStorage(AppStorageKeys.usesInputSuggestionDictionary) private var usesInputSuggestionDictionary = true

    @State private var name = ""
    @State private var selectedRole = PersonRoleOption.defaultOption

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var suggestions: [PersonMaster] {
        guard usesInputSuggestionDictionary, !trimmedName.isEmpty else { return [] }
        let normalizedInput = normalizedPersonName(trimmedName)
        return personMasters
            .filter { !$0.isArchived }
            .filter { person in
                normalizedPersonName(person.displayName).contains(normalizedInput)
                    || person.normalizedName.contains(normalizedInput)
            }
            .prefix(4)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if existingLinks.isEmpty && pendingLinks.isEmpty {
                Text("出演者、作家、作者、主催、制作などを役割つきで追加できます。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                peopleList
            }

            VStack(alignment: .leading, spacing: 10) {
                TextField("人物・団体名", text: $name)
                Picker("役割", selection: $selectedRole) {
                    ForEach(PersonRoleOption.all) { role in
                        Text(role.name).tag(role)
                    }
                }

                if !suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("似た人物・団体")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                        ForEach(suggestions) { person in
                            Button {
                                name = person.displayName
                            } label: {
                                HStack {
                                    Text(person.displayName)
                                    Spacer()
                                    Image(systemName: "arrow.up.left")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button {
                    appendPerson()
                } label: {
                    Label("人物・団体を追加", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(trimmedName.isEmpty)
            }
        }
    }

    private var peopleList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(existingLinks) { link in
                PeopleLinkRow(
                    name: link.nameSnapshot.isEmpty ? link.person?.displayName ?? "人物・団体" : link.nameSnapshot,
                    role: link.displayRole.isEmpty ? PersonRoleOption.option(for: link.roleKey).name : link.displayRole,
                    sourceLabel: "保存済み",
                    onDelete: {
                        deletedLinkIDs.insert(link.id)
                    }
                )
            }

            ForEach(pendingLinks) { link in
                PeopleLinkRow(
                    name: link.name,
                    role: link.role.name,
                    sourceLabel: "追加予定",
                    onDelete: {
                        pendingLinks.removeAll { $0.id == link.id }
                    }
                )
            }
        }
    }

    private func appendPerson() {
        pendingLinks.append(PendingPersonLink(name: trimmedName, role: selectedRole))
        name = ""
        selectedRole = .defaultOption
    }
}

private struct PeopleLinkRow: View {
    let name: String
    let role: String
    let sourceLabel: String
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.crop.circle")
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(FavorecoTypography.bodyStrong)
                Text("\(role) ・ \(sourceLabel)")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(name)を削除")
        }
        .padding(.vertical, 4)
    }
}
