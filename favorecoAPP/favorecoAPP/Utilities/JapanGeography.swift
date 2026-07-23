import Foundation

nonisolated enum JapanArea: String, CaseIterable, Identifiable {
    case hokkaido
    case tohoku
    case kanto
    case chubu
    case kinki
    case chugoku
    case shikoku
    case kyushuOkinawa

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hokkaido: "北海道"
        case .tohoku: "東北"
        case .kanto: "関東"
        case .chubu: "中部"
        case .kinki: "近畿"
        case .chugoku: "中国"
        case .shikoku: "四国"
        case .kyushuOkinawa: "九州・沖縄"
        }
    }

    var prefectures: [String] {
        switch self {
        case .hokkaido: ["北海道"]
        case .tohoku: ["青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県"]
        case .kanto: ["茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県"]
        case .chubu: ["新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県", "岐阜県", "静岡県", "愛知県"]
        case .kinki: ["三重県", "滋賀県", "京都府", "大阪府", "兵庫県", "奈良県", "和歌山県"]
        case .chugoku: ["鳥取県", "島根県", "岡山県", "広島県", "山口県"]
        case .shikoku: ["徳島県", "香川県", "愛媛県", "高知県"]
        case .kyushuOkinawa: ["福岡県", "佐賀県", "長崎県", "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県"]
        }
    }

    func includes(prefecture: String) -> Bool {
        prefectures.contains(prefecture)
    }
}

nonisolated enum JapanPrefecture {
    static let all = JapanArea.allCases.flatMap(\.prefectures)

    static func extract(from text: String) -> String {
        all.first(where: { text.contains($0) }) ?? ""
    }

    static func area(for prefecture: String) -> JapanArea? {
        JapanArea.allCases.first(where: { $0.includes(prefecture: prefecture) })
    }
}
