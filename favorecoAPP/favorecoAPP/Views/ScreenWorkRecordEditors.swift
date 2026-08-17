import SwiftUI

struct ScreenWorkMinimumEditor: View {
    let fixedTitle: String?
    let title: Binding<String>?
    @Binding var typeKey: String
    @Binding var viewedAt: Date
    @Binding var endedAt: Date
    @Binding var overallRating: Double
    let ratingText: String
    var showsRating: Bool = true

    private var type: ScreenWorkType {
        ScreenWorkType.resolved(from: typeKey)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                ExplicitFormTextField(
                    title: "作品タイトル",
                    prompt: "作品タイトルを入力",
                    text: title,
                    labelStyle: .horizontal
                )
            } else {
                ExplicitFormControlRow(title: "作品タイトル") {
                    Text(fixedTitle?.isEmpty == false ? fixedTitle! : "未設定")
                        .lineLimit(2)
                }
            }

            divider
            Picker("作品区分", selection: typeSelection) {
                ForEach(ScreenWorkType.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .padding(.vertical, 8)

            divider
            if type == .movie {
                ExperienceDateTimeRangeEditor(
                    startsAt: $viewedAt,
                    endsAt: $endedAt,
                    dateLabel: "鑑賞日",
                    startTimeLabel: "開始時刻",
                    endTimeLabel: "終了時刻"
                )
            } else {
                screenWorkYearAndSeason
            }

            if showsRating {
                divider
                ExperienceRatingUnitEditor(
                    overallRating: $overallRating,
                    ratingText: ratingText,
                    title: "評価"
                )
                .padding(.vertical, 8)
            }
        }
    }

    private var typeSelection: Binding<ScreenWorkType> {
        Binding(
            get: { type },
            set: { typeKey = $0.rawValue }
        )
    }

    private var screenWorkYearAndSeason: some View {
        VStack(alignment: .leading, spacing: 0) {
            ExplicitFormControlRow(title: "鑑賞年") {
                Picker("鑑賞年", selection: yearSelection) {
                    ForEach(years, id: \.self) { year in
                        Text(verbatim: FavorecoDateText.year(year)).tag(year)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            divider
            ExplicitFormControlRow(title: "季節") {
                Picker("季節", selection: broadcastSeasonSelection) {
                    ForEach(ScreenWorkBroadcastSeason.allCases) { season in
                        Text(season.label(for: type)).tag(season)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        }
    }

    private var years: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array(stride(from: currentYear + 1, through: 1900, by: -1))
    }

    private var yearSelection: Binding<Int> {
        Binding(
            get: { Calendar.current.component(.year, from: viewedAt) },
            set: { newYear in
                var components = Calendar.current.dateComponents(
                    [.month, .day, .hour, .minute, .second],
                    from: viewedAt
                )
                components.year = newYear
                viewedAt = Calendar.current.date(from: components) ?? viewedAt
            }
        )
    }

    private var broadcastSeasonSelection: Binding<ScreenWorkBroadcastSeason> {
        Binding(
            get: { ScreenWorkBroadcastSeason(date: viewedAt) },
            set: { season in
                var components = Calendar.current.dateComponents(
                    [.year, .hour, .minute, .second],
                    from: viewedAt
                )
                components.month = season.startMonth
                components.day = 1
                viewedAt = Calendar.current.date(from: components) ?? viewedAt
            }
        )
    }

    private var divider: some View {
        Divider().overlay(ExplicitFormMetrics.rowSeparatorColor)
    }
}

struct ScreenWorkViewingDetailsEditor: View {
    @Binding var typeKey: String
    @Binding var styleNamesText: String
    @Binding var venueName: String
    @Binding var seatText: String
    @Binding var advancedEntries: [AdvancedFieldEntry]

    private var type: ScreenWorkType {
        ScreenWorkType.resolved(from: typeKey)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ExplicitFormTextField(
                title: "作品時間（任意）",
                prompt: "例：120分",
                text: advancedValue(label: "作品時間"),
                labelStyle: .horizontal
            )

            divider
            ExplicitFormTextField(
                title: "鑑賞方法（任意）",
                prompt: "例：映画館、配信、自宅",
                text: $styleNamesText,
                labelStyle: .horizontal
            )

            if type == .movie {
                divider
                ExplicitFormTextField(
                    title: "映画館・場所（任意）",
                    prompt: "映画館名や鑑賞場所",
                    text: $venueName,
                    labelStyle: .horizontal
                )

                divider
                ExplicitFormTextField(
                    title: "チケット・座席（任意）",
                    prompt: "例：スクリーン3・E列12番",
                    text: $seatText,
                    axis: .vertical,
                    minimumLines: 1,
                    maximumLines: 2,
                    labelStyle: .horizontal
                )
            }
        }
    }

    private func advancedValue(label: String) -> Binding<String> {
        Binding(
            get: {
                advancedEntries
                    .first(where: { $0.trimmedLabel == label })?
                    .value ?? ""
            },
            set: { newValue in
                if let index = advancedEntries.firstIndex(where: { $0.trimmedLabel == label }) {
                    advancedEntries[index].value = newValue
                } else if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    advancedEntries.append(AdvancedFieldEntry(label: label, value: newValue))
                }
            }
        )
    }

    private var divider: some View {
        Divider().overlay(ExplicitFormMetrics.rowSeparatorColor)
    }
}

struct ScreenWorkAdditionalDetailsEditor: View {
    @Binding var entries: [AdvancedFieldEntry]

    var body: some View {
        ExperienceAdvancedUnitEditor(entries: additionalEntries)
    }

    private var additionalEntries: Binding<[AdvancedFieldEntry]> {
        Binding(
            get: {
                entries.filter { $0.trimmedLabel != "作品時間" }
            },
            set: { newEntries in
                let durationEntries = entries.filter { $0.trimmedLabel == "作品時間" }
                entries = durationEntries + newEntries
            }
        )
    }
}

private enum ScreenWorkBroadcastSeason: Int, CaseIterable, Identifiable {
    case winter = 1
    case spring = 4
    case summer = 7
    case autumn = 10

    var id: Int { rawValue }
    var startMonth: Int { rawValue }

    init(date: Date) {
        switch Calendar.current.component(.month, from: date) {
        case 1...3: self = .winter
        case 4...6: self = .spring
        case 7...9: self = .summer
        default: self = .autumn
        }
    }

    func label(for type: ScreenWorkType) -> String {
        let season = switch self {
        case .winter: "冬"
        case .spring: "春"
        case .summer: "夏"
        case .autumn: "秋"
        }
        return season + (type == .drama ? "ドラマ" : "アニメ")
    }
}
