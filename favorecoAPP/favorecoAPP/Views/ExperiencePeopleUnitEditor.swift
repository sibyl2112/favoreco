//
//  ExperiencePeopleUnitEditor.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/15.
//

import Foundation
import SwiftData
import SwiftUI

struct PendingPersonLink: Identifiable {
    let id = UUID()
    var name: String
    var role: PersonRoleOption
    var entityKind: PersonEntityKind = .person
    var parentOrganizationID: UUID?
    var relationshipTagKeys: [String] = []

    func makeEventPersonLink(
        person: PersonMaster,
        event: ExperienceEvent?,
        visit: Visit?,
        sortOrder: Int
    ) -> EventPersonLink {
        let link = EventPersonLink(
            roleKey: role.key,
            displayRole: role.name,
            sortOrder: sortOrder,
            nameSnapshot: name.trimmingCharacters(in: .whitespacesAndNewlines),
            person: person,
            event: event,
            visit: visit
        )
        if role.key == PersonRoleOption.theaterFocus.key {
            link.memo = TheaterFocusLinkMetadata(reactionKeys: relationshipTagKeys).encodedMemo
        }
        return link
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
        PersonRoleOption(key: "choreography", name: "振付"),
        PersonRoleOption(key: "conductor", name: "指揮"),
        PersonRoleOption(key: "performer", name: "演奏"),
        PersonRoleOption(key: "replacement", name: "代役"),
        PersonRoleOption(key: "daily_guest", name: "日替わりゲスト"),
        PersonRoleOption(key: "theater_focus", name: "お目当て・注目"),
        PersonRoleOption(key: "stage_design", name: "美術"),
        PersonRoleOption(key: "lighting", name: "照明"),
        PersonRoleOption(key: "sound", name: "音響"),
        PersonRoleOption(key: "costume", name: "衣裳"),
        PersonRoleOption(key: "hair_makeup", name: "ヘアメイク"),
        PersonRoleOption(key: "stage_manager", name: "舞台監督"),
        PersonRoleOption(key: "translator", name: "翻訳"),
        PersonRoleOption(key: "curator", name: "キュレーター"),
        PersonRoleOption(key: "performing_organization", name: "上演団体"),
        PersonRoleOption(key: "organizer", name: "主催"),
        PersonRoleOption(key: "production", name: "制作"),
        PersonRoleOption(key: "planning", name: "企画"),
        PersonRoleOption(key: "presenter", name: "招聘・提供"),
        PersonRoleOption(key: "publisher", name: "出版社"),
        PersonRoleOption(key: "guest", name: "ゲスト"),
        PersonRoleOption(key: "other", name: "その他"),
    ]

    static let defaultOption = PersonRoleOption(key: "cast", name: "出演")

    static let theaterVisitCast: [PersonRoleOption] = [
        option(for: "cast"),
        option(for: "lead"),
        option(for: "guest"),
        option(for: "replacement"),
        option(for: "daily_guest"),
        option(for: "performer"),
    ]

    static let theaterFocus = option(for: "theater_focus")

    static let theaterOrganizations: [PersonRoleOption] = [
        option(for: "performing_organization"),
        option(for: "organizer"),
        option(for: "production"),
        option(for: "planning"),
        option(for: "presenter"),
    ]

    static let theaterEvent: [PersonRoleOption] = [
        option(for: "cast"),
        option(for: "lead"),
        option(for: "guest"),
        option(for: "stage_director"),
        option(for: "screenplay"),
        option(for: "original_work"),
        option(for: "choreography"),
        option(for: "music"),
        option(for: "conductor"),
        option(for: "performer"),
        option(for: "stage_design"),
        option(for: "lighting"),
        option(for: "sound"),
        option(for: "costume"),
        option(for: "hair_makeup"),
        option(for: "stage_manager"),
        option(for: "performing_organization"),
        option(for: "organizer"),
        option(for: "production"),
        option(for: "planning"),
        option(for: "presenter"),
        option(for: "other"),
    ]

    var defaultsToOrganization: Bool {
        ["performing_organization", "organizer", "production", "planning", "presenter", "publisher"].contains(key)
    }

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
    var roleOptions: [PersonRoleOption] = PersonRoleOption.all
    var emptyDescription = "出演者、作家、作者、主催、制作などを役割つきで追加できます。"
    var showsRolePicker = true
    var allowsOrganizations = true
    var namePlaceholder = "人物・団体名"
    var addButtonTitle = "人物・団体を追加"
    var relationshipTagOptions: [TheaterFocusReaction] = []
    var existingRelationshipTagKeys: Binding<[UUID: Set<String>]> = .constant([:])

    @State private var name = ""
    @State private var selectedRole = PersonRoleOption.defaultOption
    @State private var entityKind = PersonEntityKind.person
    @State private var parentOrganizationID: UUID?
    @State private var selectedRelationshipTagKeys: Set<String> = []

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var suggestions: [PersonMaster] {
        PersonMasterSuggestion.matching(
            personMasters,
            query: trimmedName,
            allowsOrganizations: allowsOrganizations
        )
    }

    private var organizationMasters: [PersonMaster] {
        personMasters
            .filter { !$0.isArchived && $0.isOrganization }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if existingLinks.isEmpty && pendingLinks.isEmpty {
                Text(emptyDescription)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                peopleList
            }

            VStack(alignment: .leading, spacing: 10) {
                TextField(namePlaceholder, text: $name)
                if showsRolePicker {
                    Picker("役割", selection: $selectedRole) {
                        ForEach(roleOptions) { role in
                            Text(role.name).tag(role)
                        }
                    }
                    .onChange(of: selectedRole) { _, role in
                        if role.defaultsToOrganization {
                            entityKind = .organization
                        }
                    }
                }

                if allowsOrganizations {
                    Picker("区分", selection: $entityKind) {
                        ForEach(PersonEntityKind.allCases) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if allowsOrganizations && entityKind == .organization {
                    Picker("所属する上位団体", selection: $parentOrganizationID) {
                        Text("なし").tag(UUID?.none)
                        ForEach(organizationMasters) { organization in
                            Text(organization.displayName).tag(Optional(organization.id))
                        }
                    }
                    Text("例：先に宝塚歌劇団を登録し、星組の上位団体として選びます。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }

                if !relationshipTagOptions.isEmpty {
                    relationshipTagPicker(selection: $selectedRelationshipTagKeys)
                }

                if !suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("似た人物・団体")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                        ForEach(suggestions) { person in
                            Button {
                                name = person.displayName
                                entityKind = person.entityKind
                                parentOrganizationID = person.parentOrganizationID
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: PersonActivityTags.icon(for: person.roleTagsRaw))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(person.displayName)
                                        Text(PersonMasterSuggestion.subtitle(for: person))
                                            .font(FavorecoTypography.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "checkmark.circle")
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button {
                    appendPerson()
                } label: {
                    Label(addButtonTitle, systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(trimmedName.isEmpty)
            }
        }
        .onAppear {
            guard !roleOptions.contains(selectedRole), let firstRole = roleOptions.first else { return }
            selectedRole = firstRole
            if firstRole.defaultsToOrganization {
                entityKind = .organization
            }
        }
    }

    private var peopleList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(existingLinks) { link in
                VStack(alignment: .leading, spacing: 8) {
                    PeopleLinkRow(
                        name: link.nameSnapshot.isEmpty ? link.person?.displayName ?? "人物・団体" : link.nameSnapshot,
                        role: link.displayRole.isEmpty ? PersonRoleOption.option(for: link.roleKey).name : link.displayRole,
                        sourceLabel: "保存済み",
                        tagTitles: relationshipTags(for: link).map { TheaterFocusReaction.title(for: $0) },
                        onDelete: {
                            deletedLinkIDs.insert(link.id)
                        }
                    )
                    if !relationshipTagOptions.isEmpty {
                        relationshipTagPicker(selection: existingRelationshipTagBinding(for: link))
                    }
                }
            }

            ForEach(pendingLinks) { link in
                VStack(alignment: .leading, spacing: 8) {
                    PeopleLinkRow(
                        name: link.name,
                        role: link.role.name,
                        sourceLabel: "追加予定",
                        tagTitles: link.relationshipTagKeys.map { TheaterFocusReaction.title(for: $0) },
                        onDelete: {
                            pendingLinks.removeAll { $0.id == link.id }
                        }
                    )
                    if !relationshipTagOptions.isEmpty {
                        relationshipTagPicker(selection: pendingRelationshipTagBinding(for: link))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func relationshipTagPicker(selection: Binding<Set<String>>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("この回での印象（複数選択可）")
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(relationshipTagOptions) { option in
                    let isSelected = selection.wrappedValue.contains(option.key)
                    Button {
                        if isSelected {
                            selection.wrappedValue.remove(option.key)
                        } else {
                            selection.wrappedValue.insert(option.key)
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            Text(option.title)
                        }
                        .font(FavorecoTypography.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .tint(isSelected ? Color.accentColor : Color.secondary)
                    .accessibilityValue(isSelected ? "選択中" : "未選択")
                }
            }
        }
    }

    private func relationshipTags(for link: EventPersonLink) -> [String] {
        if let override = existingRelationshipTagKeys.wrappedValue[link.id] {
            return orderedRelationshipTags(override)
        }
        return TheaterFocusLinkMetadata(memo: link.memo).reactionKeys
    }

    private func existingRelationshipTagBinding(for link: EventPersonLink) -> Binding<Set<String>> {
        Binding {
            Set(relationshipTags(for: link))
        } set: { values in
            existingRelationshipTagKeys.wrappedValue[link.id] = values
        }
    }

    private func pendingRelationshipTagBinding(for link: PendingPersonLink) -> Binding<Set<String>> {
        Binding {
            Set(pendingLinks.first(where: { $0.id == link.id })?.relationshipTagKeys ?? [])
        } set: { values in
            guard let index = pendingLinks.firstIndex(where: { $0.id == link.id }) else { return }
            pendingLinks[index].relationshipTagKeys = orderedRelationshipTags(values)
        }
    }

    private func orderedRelationshipTags(_ values: Set<String>) -> [String] {
        TheaterFocusReaction.orderedKeys(values)
    }

    private func appendPerson() {
        let resolvedRole = roleOptions.contains(selectedRole) ? selectedRole : (roleOptions.first ?? .defaultOption)
        let resolvedEntityKind = allowsOrganizations ? entityKind : .person
        pendingLinks.append(PendingPersonLink(
            name: trimmedName,
            role: resolvedRole,
            entityKind: resolvedEntityKind,
            parentOrganizationID: resolvedEntityKind == .organization ? parentOrganizationID : nil,
            relationshipTagKeys: orderedRelationshipTags(selectedRelationshipTagKeys)
        ))
        name = ""
        selectedRole = roleOptions.contains(.defaultOption) ? .defaultOption : (roleOptions.first ?? .defaultOption)
        entityKind = .person
        parentOrganizationID = nil
        selectedRelationshipTagKeys = []
    }
}

@MainActor
func resolvePersonMaster(
    for pending: PendingPersonLink,
    from personMasters: [PersonMaster],
    in modelContext: ModelContext
) -> PersonMaster {
    let normalizedName = normalizedPersonName(pending.name)
    if let person = PersonMasterSuggestion.exactMatch(
        in: personMasters,
        query: pending.name,
        entityKind: pending.entityKind
    ) {
        if pending.entityKind == .organization {
            person.entityKind = .organization
        } else if person.entityKindKey.isEmpty && !person.isOrganization {
            person.entityKind = .person
        }
        if pending.entityKind == .organization {
            person.parentOrganizationID = pending.parentOrganizationID
        }
        person.roleTagsRaw = PersonActivityTags.encode(
            PersonActivityTags.values(from: person.roleTagsRaw) + [activityTagValue(for: pending)]
        )
        person.updatedAt = Date()
        return person
    }

    let now = Date()
    let person = PersonMaster(
        displayName: pending.name.trimmingCharacters(in: .whitespacesAndNewlines),
        entityKindKey: pending.entityKind.rawValue,
        parentOrganizationIDRaw: pending.parentOrganizationID?.uuidString ?? "",
        roleTagsRaw: activityTagValue(for: pending),
        normalizedName: normalizedName,
        createdAt: now,
        updatedAt: now
    )
    modelContext.insert(person)
    return person
}

private func activityTagValue(for pending: PendingPersonLink) -> String {
    guard pending.entityKind == .organization else {
        // 「お目当て・注目」はこの観劇回との関係であり、人物の職業ではない。
        return pending.role.key == PersonRoleOption.theaterFocus.key ? "" : pending.role.key
    }
    switch pending.role.key {
    case "performing_organization": return "theater_company"
    case "production": return "production_company"
    case "organizer": return "organizer"
    case "publisher": return "publisher"
    default: return "organization"
    }
}

private struct PeopleLinkRow: View {
    let name: String
    let role: String
    let sourceLabel: String
    var tagTitles: [String] = []
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
                if !tagTitles.isEmpty {
                    Text(tagTitles.map { "#\($0)" }.joined(separator: "  "))
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(Color.accentColor)
                }
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
