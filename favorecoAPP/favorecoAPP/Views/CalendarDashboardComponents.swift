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

struct CalendarPeriodNavigationHeader: View {
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

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(FavorecoTypography.sectionTitle)

                if let resetTitle {
                    Button(resetTitle, action: onReset)
                        .font(FavorecoTypography.captionStrong)
                }
            }

            Spacer(minLength: 0)

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

struct CalendarMonthStrip: View {
    let months: [Date]
    let displayedMonth: Date
    let calendar: Calendar
    let onSelect: (Date) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(months, id: \.self) { month in
                    monthButton(month)
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private func monthButton(_ month: Date) -> some View {
        let isDisplayed = calendar.isDate(month, equalTo: displayedMonth, toGranularity: .month)

        return Button {
            onSelect(month)
        } label: {
            Text("\(calendar.component(.month, from: month))月")
                .font(FavorecoTypography.bodyStrong)
                .foregroundStyle(isDisplayed ? Color.white : Color.primary)
                .frame(minWidth: 64)
                .padding(.vertical, 8)
                .background {
                    Capsule(style: .continuous)
                        .fill(isDisplayed ? Color.accentColor : Color.clear)
                }
                .overlay {
                    if !isDisplayed {
                        Capsule(style: .continuous)
                            .stroke(Color.secondary.opacity(0.7), lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

struct CalendarExternalOverlayControl: View {
    @Binding var isEnabled: Bool
    let statusText: String
    let isLoading: Bool
    let canReadEvents: Bool
    let errorMessage: String
    let onRequestAccess: () -> Void
    let onReload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 1) {
                    Text("外部カレンダー")
                        .font(FavorecoTypography.captionStrong)
                    Text(statusText)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }

                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                }

                Spacer()

                actionControl

                Toggle("外部カレンダーを重ねる", isOn: $isEnabled)
                    .labelsHidden()
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var actionControl: some View {
        if isEnabled && !canReadEvents {
            Button("許可する", action: onRequestAccess)
                .font(FavorecoTypography.captionStrong)
        } else if isEnabled {
            Button(action: onReload) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("外部カレンダーを再読み込み")
        }
    }
}
