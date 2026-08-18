//
//  CategoryTopBasicRows.swift
//  favorecoAPP
//

import SwiftUI

struct EventRow: View {
    let snapshot: CategoryEventSnapshot
    let event: ExperienceEvent
    let onAddVisit: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            NavigationLink {
                CategoryEventDestination(eventID: event.id)
            } label: {
                HStack(spacing: 12) {
                    CategoryEyecatchArtwork(
                        reference: .event(event.id),
                        templateKey: event.category?.templateKey ?? "",
                        backgroundColor: Color(.secondarySystemFill),
                        defaultContentMode: EyecatchAspectRatio.usesEyecatchFill(for: event.category) ? .fill : .fit
                    ) { size in
                        CategoryDefaultArtworkImage(
                            templateKey: event.category?.templateKey ?? "",
                            displaySize: size
                        )
                    }
                    .frame(width: 68, height: representativeImageHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(event.title.isEmpty ? "記録" : event.title)
                            .font(FavorecoTypography.cardTitle)
                            .lineLimit(2)

                        HStack(spacing: 10) {
                            if !event.seriesName.isEmpty {
                                FavorecoIconLabel(event.seriesName, systemImage: "rectangle.stack", iconSize: 12)
                                    .lineLimit(1)
                            }
                            FavorecoIconLabel("\(snapshot.visitCount)件", systemImage: "number", iconSize: 12)
                            if let latestVisitDate = snapshot.latestVisitDate {
                                FavorecoIconLabel(
                                    FavorecoDateText.compactDate(latestVisitDate),
                                    systemImage: "calendar",
                                    iconSize: 12
                                )
                            }
                        }
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            Button(action: onAddVisit) {
                FavorecoIcon(systemName: "plus.circle.fill", size: 20)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("この対象に回を追加")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var representativeImageHeight: CGFloat {
        let ratio = EyecatchAspectRatio.resolved(for: event).value
        return 68 / CGFloat(ratio)
    }
}

struct EmptyStateMessage: View {
    let icon: String
    let title: String
    let message: String
    var tint: Color = .secondary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            FavorecoIcon(systemName: icon, size: 20)
                .foregroundStyle(tint)
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
