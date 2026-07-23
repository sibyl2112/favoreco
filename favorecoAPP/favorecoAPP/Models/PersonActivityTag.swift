import Foundation

struct PersonActivityTag: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String
    let aliases: Set<String>

    nonisolated init(id: String, title: String, systemImage: String, aliases: [String] = []) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.aliases = Set(([id, title] + aliases).map(Self.normalize))
    }

    nonisolated func matches(_ value: String) -> Bool {
        aliases.contains(Self.normalize(value))
    }

    nonisolated private static func normalize(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .widthInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum PersonActivityTags {
    nonisolated static let presets: [PersonActivityTag] = [
        PersonActivityTag(id: "actor", title: "俳優", systemImage: "theatermasks", aliases: ["役者", "出演者", "cast", "lead"]),
        PersonActivityTag(id: "stage_actor", title: "舞台俳優・ミュージカル俳優", systemImage: "theatermasks.fill", aliases: ["舞台俳優", "舞台役者", "ミュージカル俳優"]),
        PersonActivityTag(id: "voice_actor", title: "声優", systemImage: "waveform", aliases: ["voiceactor"]),
        PersonActivityTag(id: "idol", title: "アイドル", systemImage: "star.fill"),
        PersonActivityTag(id: "model", title: "モデル", systemImage: "person.crop.rectangle"),
        PersonActivityTag(id: "comedian", title: "お笑い芸人", systemImage: "face.smiling", aliases: ["芸人"]),
        PersonActivityTag(id: "narrator", title: "ナレーター", systemImage: "mic", aliases: ["ナレーション"]),
        PersonActivityTag(id: "artist", title: "アーティスト", systemImage: "sparkles", aliases: ["artist"]),
        PersonActivityTag(id: "singer", title: "歌手", systemImage: "music.mic", aliases: ["ボーカル", "vocal"]),
        PersonActivityTag(id: "musician", title: "ミュージシャン", systemImage: "music.note", aliases: ["演奏家", "performer"]),
        PersonActivityTag(id: "band", title: "バンド・音楽グループ", systemImage: "music.note.list", aliases: ["バンド", "音楽グループ"]),
        PersonActivityTag(id: "dj", title: "DJ", systemImage: "headphones"),
        PersonActivityTag(id: "composer", title: "作曲家", systemImage: "music.quarternote.3", aliases: ["作曲", "music"]),
        PersonActivityTag(id: "lyricist", title: "作詞家", systemImage: "pencil.line", aliases: ["作詞"]),
        PersonActivityTag(id: "dancer", title: "ダンサー", systemImage: "figure.dance"),
        PersonActivityTag(id: "choreographer", title: "振付師", systemImage: "figure.dance", aliases: ["振付"]),
        PersonActivityTag(id: "author", title: "作家", systemImage: "books.vertical", aliases: ["著者", "作者", "小説家", "writer", "author", "original_work"]),
        PersonActivityTag(id: "screenwriter", title: "脚本家・劇作家", systemImage: "text.document", aliases: ["脚本家", "劇作家", "脚本", "screenplay", "playwright"]),
        PersonActivityTag(id: "translator", title: "翻訳者", systemImage: "character.book.closed", aliases: ["翻訳"]),
        PersonActivityTag(id: "editor", title: "編集者", systemImage: "text.badge.checkmark", aliases: ["編集"]),
        PersonActivityTag(id: "photographer", title: "写真家", systemImage: "camera", aliases: ["フォトグラファー"]),
        PersonActivityTag(id: "cinematographer", title: "撮影監督", systemImage: "video", aliases: ["撮影"]),
        PersonActivityTag(id: "director", title: "監督", systemImage: "movieclapper", aliases: ["映画監督"]),
        PersonActivityTag(id: "stage_director", title: "演出家", systemImage: "theatermasks.fill", aliases: ["演出"]),
        PersonActivityTag(id: "creator", title: "クリエイター", systemImage: "paintbrush", aliases: ["制作者"]),
        PersonActivityTag(id: "illustrator", title: "イラストレーター", systemImage: "pencil.and.outline"),
        PersonActivityTag(id: "manga_artist", title: "漫画家", systemImage: "character.book.closed.fill"),
        PersonActivityTag(id: "visual_artist", title: "美術家・画家", systemImage: "paintpalette", aliases: ["美術家", "画家"]),
        PersonActivityTag(id: "sculptor", title: "彫刻家", systemImage: "cube", aliases: ["彫刻"]),
        PersonActivityTag(id: "designer", title: "デザイナー", systemImage: "pencil.and.ruler", aliases: ["デザイン"]),
        PersonActivityTag(id: "architect", title: "建築家", systemImage: "building.columns", aliases: ["建築"]),
        PersonActivityTag(id: "curator", title: "キュレーター", systemImage: "rectangle.3.group", aliases: ["curator"]),
        PersonActivityTag(id: "producer", title: "プロデューサー", systemImage: "person.3", aliases: ["producer"]),
        PersonActivityTag(id: "theater_company", title: "劇団", systemImage: "theatermasks.circle"),
        PersonActivityTag(id: "production_company", title: "制作会社・制作団体", systemImage: "person.3.sequence", aliases: ["制作会社", "制作団体", "production"]),
        PersonActivityTag(id: "talent_agency", title: "芸能事務所", systemImage: "building.2.crop.circle"),
        PersonActivityTag(id: "publisher", title: "出版社", systemImage: "books.vertical.fill", aliases: ["publisher"]),
        PersonActivityTag(id: "organizer", title: "主催者・主催団体", systemImage: "megaphone", aliases: ["主催者", "主催団体", "organizer"]),
        PersonActivityTag(id: "brewer", title: "醸造家・杜氏", systemImage: "drop", aliases: ["醸造家", "杜氏", "蔵人"]),
        PersonActivityTag(id: "brewery", title: "酒蔵・醸造所", systemImage: "building.2", aliases: ["酒蔵", "醸造所", "ブルワリー", "蒸溜所", "ワイナリー"]),
    ]

    nonisolated static func values(from rawValue: String) -> [String] {
        rawValue.components(separatedBy: CharacterSet(charactersIn: ",、\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func encode(_ values: [String]) -> String {
        var seen = Set<String>()
        return values.compactMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let key = normalizedKey(trimmed)
            guard seen.insert(key).inserted else { return nil }
            return trimmed
        }.joined(separator: ", ")
    }

    nonisolated static func preset(matching value: String) -> PersonActivityTag? {
        presets.first { $0.matches(value) }
    }

    nonisolated static func selectedPresetIDs(from rawValue: String) -> Set<String> {
        Set(values(from: rawValue).compactMap { preset(matching: $0)?.id })
    }

    static func customValues(from rawValue: String) -> [String] {
        values(from: rawValue).filter { preset(matching: $0) == nil }
    }

    static func replacingPresets(with selectedIDs: Set<String>, customValues: [String]) -> String {
        let selectedTitles = presets.filter { selectedIDs.contains($0.id) }.map(\.title)
        return encode(selectedTitles + customValues)
    }

    static func icon(for rawValue: String, isFavorite: Bool = false) -> String {
        for value in values(from: rawValue) {
            if let preset = preset(matching: value) {
                return preset.systemImage
            }
        }
        return isFavorite ? "person.crop.circle.fill.badge.heart" : "person.crop.circle"
    }

    static func displayTitles(from rawValue: String) -> [String] {
        values(from: rawValue).map { preset(matching: $0)?.title ?? $0 }
    }

    static func matchesAny(_ selectedIDs: Set<String>, rawValue: String) -> Bool {
        guard !selectedIDs.isEmpty else { return true }
        return !selectedPresetIDs(from: rawValue).isDisjoint(with: selectedIDs)
    }

    private static func normalizedKey(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .widthInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
