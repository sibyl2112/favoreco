//
//  CalendarDashboardComponents.swift
//  favorecoAPP
//

import SwiftUI

enum CalendarDisplayMode: String, CaseIterable, Identifiable {
    case month
    case week
    case day
    case planList

    var id: String { rawValue }

    var title: String {
        switch self {
        case .month: "月"
        case .week: "週"
        case .day: "日"
        case .planList: "予定"
        }
    }
}

struct CalendarDisplayToolbar: View {
    @Binding var displayMode: CalendarDisplayMode

    var body: some View {
        HStack(spacing: 10) {
            Picker("表示", selection: $displayMode) {
                ForEach(CalendarDisplayMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            NavigationLink {
                TicketOverviewView()
            } label: {
                Image(systemName: "ticket")
                    .font(.title3)
                    .frame(width: 42, height: 32)
            }
            .accessibilityLabel("予定・チケット")
        }
    }
}

struct CalendarPeriodStepControls: View {
    let title: String
    let previousAccessibilityLabel: String
    let nextAccessibilityLabel: String
    let resetTitle: String?
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onReset: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            navigationButton(
                systemImage: "chevron.left",
                accessibilityLabel: previousAccessibilityLabel,
                action: onPrevious
            )

            VStack(spacing: 2) {
                Text(title)
                    .font(FavorecoTypography.jpSans(17, weight: .semibold, relativeTo: .headline))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if let resetTitle {
                    Button(resetTitle, action: onReset)
                        .font(FavorecoTypography.captionStrong)
                }
            }
            .frame(maxWidth: .infinity)

            navigationButton(
                systemImage: "chevron.right",
                accessibilityLabel: nextAccessibilityLabel,
                action: onNext
            )
        }
    }

    private func navigationButton(
        systemImage: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
