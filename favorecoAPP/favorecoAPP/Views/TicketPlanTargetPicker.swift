import SwiftUI

struct EventPickerItem: Identifiable {
    let id: UUID
    let title: String
    let categoryName: String
    let categoryIcon: String
    let seriesName: String

    init(event: ExperienceEvent) {
        id = event.id
        title = event.title
        categoryName = event.category?.name ?? "未分類"
        categoryIcon = event.category?.iconSymbol ?? "rectangle.stack"
        seriesName = event.seriesName
    }
}

struct EventPicker: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let searchPrompt: String
    let items: [EventPickerItem]
    let selectedEventID: UUID?
    let onSelect: (UUID) -> Void

    @State private var searchText = ""

    private var filteredItems: [EventPickerItem] {
        let query = normalized(searchText)
        guard !query.isEmpty else { return items }
        return items.filter { item in
            normalized(item.title).contains(query)
                || normalized(item.seriesName).contains(query)
                || normalized(item.categoryName).contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredItems.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List(filteredItems) { item in
                        Button {
                            onSelect(item.id)
                        } label: {
                            HStack(spacing: 12) {
                                FavorecoIcon(systemName: item.categoryIcon, size: 18)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title)
                                        .font(FavorecoTypography.jpSans(15, weight: .semibold, relativeTo: .body))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.72)
                                        .allowsTightening(true)

                                    Text(eventDescription(item))
                                        .font(FavorecoTypography.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()
                                if item.id == selectedEventID {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: searchPrompt)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func eventDescription(_ item: EventPickerItem) -> String {
        let description = [item.categoryName, item.seriesName.isEmpty ? nil : item.seriesName]
            .compactMap { $0 }
            .joined(separator: " / ")
        return description.isEmpty ? "未分類" : description
    }

    private func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
    }
}
