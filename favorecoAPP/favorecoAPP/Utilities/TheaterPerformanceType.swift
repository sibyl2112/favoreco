import SwiftUI

enum TheaterPerformanceType: String, CaseIterable, Identifiable {
    case play = "theater_play"
    case twoPointFiveD = "theater_2_5d"
    case musical = "theater_musical"
    case kabuki = "theater_kabuki"
    case rakugoYose = "theater_rakugo_yose"
    case danceBallet = "theater_dance_ballet"
    case opera = "theater_opera"
    case other = "theater_other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .play: "演劇"
        case .twoPointFiveD: "2.5次元舞台"
        case .musical: "ミュージカル"
        case .kabuki: "歌舞伎"
        case .rakugoYose: "落語・寄席"
        case .danceBallet: "ダンス・バレエ"
        case .opera: "オペラ"
        case .other: "その他"
        }
    }

    static func displayName(for key: String, customName: String) -> String {
        let trimmedCustomName = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let type = TheaterPerformanceType(rawValue: key) else {
            return trimmedCustomName.isEmpty ? key : trimmedCustomName
        }
        if type == .other, !trimmedCustomName.isEmpty {
            return trimmedCustomName
        }
        return type.displayName
    }

    static func customNameForStorage(key: String, input: String) -> String {
        guard key == TheaterPerformanceType.other.rawValue else { return "" }
        return input.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isValidSelection(key: String, customName: String) -> Bool {
        key != TheaterPerformanceType.other.rawValue
            || !customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct TheaterPerformanceTypePicker: View {
    @Binding var selection: String
    @Binding var customName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("公演種別", selection: $selection) {
                Text("未設定").tag("")
                ForEach(TheaterPerformanceType.allCases) { type in
                    Text(type.displayName).tag(type.rawValue)
                }
                if isLegacySelection {
                    Text(TheaterPerformanceType.displayName(for: selection, customName: customName))
                        .tag(selection)
                }
            }
            .pickerStyle(.menu)

            if selection == TheaterPerformanceType.other.rawValue {
                TextField("具体的な種別（例：能、狂言、朗読劇）", text: $customName)
                Text("入力した名称を公演種別として保存します。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var isLegacySelection: Bool {
        !selection.isEmpty && TheaterPerformanceType(rawValue: selection) == nil
    }
}
