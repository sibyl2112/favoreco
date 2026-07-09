//
//  VisitSummaryRow.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/10.
//

import SwiftUI
import UIKit

struct VisitSummaryRow: View {
    let visit: Visit
    var showsCategory: Bool = true

    private var title: String {
        visit.event?.title.isEmpty == false ? visit.event?.title ?? "記録" : "記録"
    }

    private var category: RecordCategory? {
        visit.event?.category
    }

    private var categoryColor: Color {
        Color(hex: category?.colorHex ?? "#147C88")
    }

    private var firstPhotoImage: UIImage? {
        guard let photo = visit.photos?.first(where: { $0.mediaKind == "photo" }),
              !photo.data.isEmpty else {
            return nil
        }
        return UIImage(data: photo.data)
    }

    private var unitFields: VisitUnitFields {
        VisitUnitFields(rawValue: visit.unitFieldsRaw)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(FavorecoTypography.cardTitle)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    if let statusText = VisitSummaryFormatter.ticketStatusText(visit.outcomeKey) {
                        Text(statusText)
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(categoryColor)
                            .lineLimit(1)
                    }
                }

                VisitSummaryMetaLine(items: metaItems)

                if !visit.note.isEmpty {
                    Text(visit.note)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if hasBadges {
                    HStack(spacing: 6) {
                        if visit.amount != Decimal(0) {
                            VisitSummaryBadge(text: VisitSummaryFormatter.amount(visit.amount), icon: "yensign.circle")
                        }
                        if !unitFields.ocrText.isEmpty {
                            VisitSummaryBadge(text: "OCR", icon: "text.viewfinder")
                        }
                        if !unitFields.advancedEntries.isEmpty {
                            VisitSummaryBadge(text: "詳細", icon: "slider.horizontal.3")
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let firstPhotoImage {
            Image(uiImage: firstPhotoImage)
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            Image(systemName: category?.iconSymbol ?? "sparkles.rectangle.stack")
                .font(.title3)
                .foregroundStyle(categoryColor)
                .frame(width: 64, height: 64)
                .background(categoryColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var metaItems: [VisitSummaryMetaItem] {
        var items: [VisitSummaryMetaItem] = [
            VisitSummaryMetaItem(icon: "calendar", text: visit.visitedAt.formatted(date: .numeric, time: .omitted))
        ]
        if showsCategory, let categoryName = category?.name, !categoryName.isEmpty {
            items.append(VisitSummaryMetaItem(icon: category?.iconSymbol ?? "square.grid.2x2", text: categoryName))
        }
        if !visit.venueNameSnapshot.isEmpty {
            items.append(VisitSummaryMetaItem(icon: "mappin.and.ellipse", text: visit.venueNameSnapshot))
        }
        if visit.overallRating > 0 {
            items.append(VisitSummaryMetaItem(icon: "star.fill", text: String(format: "%.1f", visit.overallRating)))
        }
        return items
    }

    private var hasBadges: Bool {
        visit.amount != Decimal(0) || !unitFields.ocrText.isEmpty || !unitFields.advancedEntries.isEmpty
    }
}

private struct VisitSummaryMetaItem: Identifiable {
    let id = UUID()
    var icon: String
    var text: String
}

private struct VisitSummaryMetaLine: View {
    let items: [VisitSummaryMetaItem]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(items) { item in
                Label(item.text, systemImage: item.icon)
                    .lineLimit(1)
            }
        }
        .font(FavorecoTypography.caption)
        .foregroundStyle(.secondary)
    }
}

private struct VisitSummaryBadge: View {
    let text: String
    let icon: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(FavorecoTypography.jpSans(11, weight: .semibold, relativeTo: .caption2))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.secondarySystemGroupedBackground), in: Capsule())
    }
}

private enum VisitSummaryFormatter {
    static func ticketStatusText(_ key: String) -> String? {
        switch key {
        case "planned": return "予定"
        case "applied": return "申込中"
        case "won": return "当選"
        case "paid": return "入金済み"
        case "ticketed": return "発券済み"
        case "attended": return "参加済み"
        case "canceled": return "中止"
        default: return nil
        }
    }

    static func amount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "JPY"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "¥\(NSDecimalNumber(decimal: amount).stringValue)"
    }
}
