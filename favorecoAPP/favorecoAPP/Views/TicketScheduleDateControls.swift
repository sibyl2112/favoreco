import SwiftUI

struct DateToggleRow: View {
    @Environment(\.favorecoThemePalette) private var themePalette
    let title: String
    @Binding var isOn: Bool
    @Binding var date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ExplicitFormControlRow(
                title: title
                    .replacingOccurrences(of: "（任意）", with: ""),
                isOptional: title.contains("任意")
            ) {
                Toggle(title, isOn: $isOn)
                    .labelsHidden()
                    .tint(themePalette.prominentAction)
                    .accessibilityLabel(title)
            }
            if isOn {
                FiveMinuteDateTimeRow(title: title, selection: $date, showsLabel: false)
            }
        }
    }
}

struct TicketMilestoneDateGuidance: View {
    var body: some View {
        Text("分かる日程だけ登録してください")
            .font(FavorecoTypography.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("工程日は、分かる日程だけ登録してください")
    }
}

/// チケット工程日の共通入力ユニット。
/// 日付と時刻を同じ54pt枠に収め、未設定の工程は追加ボタンだけを表示する。
struct TicketMilestoneDateField: View {
    @Environment(\.favorecoThemePalette) private var themePalette
    let title: String
    @Binding var isOn: Bool
    @Binding var date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if isOn {
                HStack(spacing: 8) {
                    Text(title)
                        .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .body))
                        .foregroundStyle(.primary)

                    Spacer(minLength: 8)

                    Button {
                        isOn = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Color.secondary.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title)を削除")
                }

                HStack(spacing: 8) {
                    DatePicker(
                        "\(title)の日付",
                        selection: $date,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "ja_JP"))

                    Divider()
                        .frame(height: 26)

                    DatePicker(
                        "\(title)の時刻",
                        selection: $date,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "ja_JP"))
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(
                    TheaterLifecycleFlatStyle.fieldBackground,
                    in: RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius)
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius,
                        style: .continuous
                    )
                        .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
                }
            } else {
                Button {
                    isOn = true
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                        Text("\(title)を追加")
                            .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .body))
                    }
                    .foregroundStyle(themePalette.prominentAction)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(themePalette.prominentAction.opacity(0.62), lineWidth: 1)
                }
                .accessibilityLabel("\(title)を追加")
            }
        }
    }
}

struct FiveMinuteDateTimeRow: View {
    let title: String
    @Binding var selection: Date
    var showsLabel = true

    var body: some View {
        ExplicitFormControlRow(title: showsLabel ? title : "日時") {
            HStack(spacing: 8) {
                DatePicker(
                    title,
                    selection: $selection,
                    displayedComponents: .date
                )
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "ja_JP"))
                .controlSize(.small)
                .fixedSize()
                .scaleEffect(ExplicitFormMetrics.dateControlScale)

                FiveMinuteTimeField(selection: $selection, accessibilityLabel: title)
            }
        }
    }
}

struct TheaterScheduleDateRow: View {
    @Binding var selection: Date
    @Binding var isSet: Bool
    let onClear: () -> Void
    var usesHorizontalLayout = false
    var emphasizesHorizontalLabel = false

    var body: some View {
        ExplicitFormControlRow(
            title: "日付",
            density: .compactSchedule,
            layout: usesHorizontalLayout ? .horizontal : .stacked,
            emphasizesHorizontalLabel: emphasizesHorizontalLabel
        ) {
            HStack(spacing: 6) {
                if isSet {
                    DatePicker(
                        "日付",
                        selection: $selection,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "ja_JP"))
                    .controlSize(.small)
                    .fixedSize()

                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("体験日時を未定に戻す")
                } else {
                    Text("日時未定")
                        .foregroundStyle(.secondary)

                    Button("日付を設定") {
                        isSet = true
                    }
                    .buttonStyle(.borderless)
                    .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .body))
                    .accessibilityLabel("体験日を設定")
                }
            }
        }
    }
}

struct TenMinuteTimeRow: View {
    let title: String
    @Binding var selection: Date
    var usesHorizontalLayout = false
    var emphasizesHorizontalLabel = false

    var body: some View {
        ExplicitFormControlRow(
            title: title,
            density: .compactSchedule,
            layout: usesHorizontalLayout ? .horizontal : .stacked,
            emphasizesHorizontalLabel: emphasizesHorizontalLabel
        ) {
            TenMinuteTimeField(
                selection: $selection,
                accessibilityLabel: "\(title)時刻"
            )
        }
    }
}

struct OptionalTenMinuteTimeRow: View {
    let title: String
    @Binding var selection: Date
    @Binding var isSet: Bool
    let defaultValue: Date
    var usesHorizontalLayout = false
    var emphasizesHorizontalLabel = false

    var body: some View {
        ExplicitFormControlRow(
            title: title,
            isOptional: true,
            density: .compactSchedule,
            layout: usesHorizontalLayout ? .horizontal : .stacked,
            emphasizesHorizontalLabel: emphasizesHorizontalLabel
        ) {
            HStack(spacing: 6) {
                TenMinuteTimeField(
                    selection: $selection,
                    isSet: $isSet,
                    defaultValue: defaultValue,
                    accessibilityLabel: "\(title)時刻"
                )

                if isSet {
                    Button {
                        isSet = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title)時刻を未設定に戻す")
                }
            }
        }
    }
}

private struct TenMinuteTimeField: View {
    @Binding var selection: Date
    var isSet: Binding<Bool>?
    var defaultValue: Date?
    let accessibilityLabel: String

    @State private var isShowingPicker = false
    @State private var pendingSelection = Date()

    private var isTimeSet: Bool {
        isSet?.wrappedValue ?? true
    }

    private var displayText: String {
        guard isTimeSet else { return "--:--" }
        return selection.formatted(
            Date.FormatStyle()
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
                .locale(Locale(identifier: "ja_JP"))
        )
    }

    var body: some View {
        Button {
            pendingSelection = (isTimeSet ? selection : (defaultValue ?? selection))
                .roundedToNearestTenMinutes()
            isShowingPicker = true
        } label: {
            Text(displayText)
                .font(FavorecoTypography.jpSans(13, weight: .regular, relativeTo: .body))
                .monospacedDigit()
                .foregroundStyle(isTimeSet ? Color.primary : Color.secondary)
                .frame(minWidth: 72)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(.secondarySystemFill), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isTimeSet ? displayText : "未設定")
        .popover(isPresented: $isShowingPicker, attachmentAnchor: .rect(.bounds)) {
            VStack(spacing: 8) {
                TenMinuteWheelTimePicker(
                    selection: $pendingSelection,
                    accessibilityLabel: accessibilityLabel,
                    onUserChange: { newValue in
                        selection = newValue.roundedToNearestTenMinutes()
                        isSet?.wrappedValue = true
                    }
                )
                .frame(width: 180, height: 170)

                Button("完了") {
                    isShowingPicker = false
                }
                .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .body))
                .buttonStyle(.borderedProminent)
                .favorecoProminentActionStyle()
            }
            .padding(12)
            .presentationCompactAdaptation(.popover)
        }
    }
}

private struct TenMinuteWheelTimePicker: View {
    @Binding var selection: Date
    let accessibilityLabel: String
    let onUserChange: (Date) -> Void

    private static let minuteValues = Array(stride(from: 0, to: 24 * 60, by: 10))

    private var minuteOfDay: Binding<Int> {
        Binding(
            get: {
                let rounded = selection.roundedToNearestTenMinutes()
                let components = Calendar.current.dateComponents([.hour, .minute], from: rounded)
                return (components.hour ?? 0) * 60 + (components.minute ?? 0)
            },
            set: { newMinuteOfDay in
                let hour = newMinuteOfDay / 60
                let minute = newMinuteOfDay % 60
                guard let updated = Calendar.current.date(
                    bySettingHour: hour,
                    minute: minute,
                    second: 0,
                    of: selection
                ) else { return }
                selection = updated
                onUserChange(updated)
            }
        )
    }

    var body: some View {
        Picker(accessibilityLabel, selection: minuteOfDay) {
            ForEach(Self.minuteValues, id: \.self) { minuteOfDay in
                Text(
                    String(
                        format: "%02d:%02d",
                        minuteOfDay / 60,
                        minuteOfDay % 60
                    )
                )
                .font(FavorecoTypography.jpSans(17, weight: .regular, relativeTo: .body))
                .monospacedDigit()
                .tag(minuteOfDay)
            }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct FiveMinuteTimeField: View {
    @Binding var selection: Date
    let accessibilityLabel: String

    @State private var isShowingPicker = false
    @State private var pendingSelection = Date()

    private var displayText: String {
        selection
            .roundedToNearestFiveMinutes()
            .formatted(
                Date.FormatStyle()
                    .hour(.twoDigits(amPM: .omitted))
                    .minute(.twoDigits)
                    .locale(Locale(identifier: "ja_JP"))
            )
    }

    var body: some View {
        Button {
            pendingSelection = selection.roundedToNearestFiveMinutes()
            isShowingPicker = true
        } label: {
            Text(displayText)
                .font(FavorecoTypography.jpSans(15, weight: .regular, relativeTo: .body))
                .monospacedDigit()
                .foregroundStyle(Color.primary)
                .frame(minWidth: 68)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color(.secondarySystemFill), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(displayText)
        .onAppear {
            normalizeSelectionIfNeeded()
        }
        .onChange(of: selection) { _, newValue in
            let rounded = newValue.roundedToNearestFiveMinutes()
            if abs(newValue.timeIntervalSince(rounded)) >= 1 {
                selection = rounded
            }
        }
        .popover(isPresented: $isShowingPicker, attachmentAnchor: .rect(.bounds)) {
            VStack(spacing: 8) {
                FiveMinuteWheelTimePicker(
                    selection: $pendingSelection,
                    accessibilityLabel: accessibilityLabel
                ) { newValue in
                    selection = newValue.roundedToNearestFiveMinutes()
                }
                .frame(width: 180, height: 170)

                Button("完了") {
                    isShowingPicker = false
                }
                .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .body))
                .buttonStyle(.borderedProminent)
                .favorecoProminentActionStyle()
            }
            .padding(12)
            .presentationCompactAdaptation(.popover)
        }
    }

    private func normalizeSelectionIfNeeded() {
        let rounded = selection.roundedToNearestFiveMinutes()
        if abs(selection.timeIntervalSince(rounded)) >= 1 {
            selection = rounded
        }
    }
}

private struct FiveMinuteWheelTimePicker: View {
    @Binding var selection: Date
    let accessibilityLabel: String
    let onUserChange: (Date) -> Void

    private static let minuteValues = Array(stride(from: 0, to: 24 * 60, by: 5))

    private var minuteOfDay: Binding<Int> {
        Binding(
            get: {
                let rounded = selection.roundedToNearestFiveMinutes()
                let components = Calendar.current.dateComponents([.hour, .minute], from: rounded)
                return (components.hour ?? 0) * 60 + (components.minute ?? 0)
            },
            set: { newMinuteOfDay in
                let hour = newMinuteOfDay / 60
                let minute = newMinuteOfDay % 60
                guard let updated = Calendar.current.date(
                    bySettingHour: hour,
                    minute: minute,
                    second: 0,
                    of: selection
                ) else { return }
                selection = updated
                onUserChange(updated)
            }
        )
    }

    var body: some View {
        Picker(accessibilityLabel, selection: minuteOfDay) {
            ForEach(Self.minuteValues, id: \.self) { minuteOfDay in
                Text(
                    String(
                        format: "%02d:%02d",
                        minuteOfDay / 60,
                        minuteOfDay % 60
                    )
                )
                .font(FavorecoTypography.jpSans(17, weight: .regular, relativeTo: .body))
                .monospacedDigit()
                .tag(minuteOfDay)
            }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
        .accessibilityLabel(accessibilityLabel)
    }
}

extension Date {
    func roundedToNearestFiveMinutes() -> Date {
        let interval: TimeInterval = 5 * 60
        return Date(timeIntervalSinceReferenceDate: (timeIntervalSinceReferenceDate / interval).rounded() * interval)
    }

    func roundedToNearestTenMinutes() -> Date {
        let interval: TimeInterval = 10 * 60
        return Date(timeIntervalSinceReferenceDate: (timeIntervalSinceReferenceDate / interval).rounded() * interval)
    }
}
