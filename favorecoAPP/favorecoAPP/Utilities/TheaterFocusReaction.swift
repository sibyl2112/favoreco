import Foundation

struct TheaterFocusReaction: Identifiable, Hashable {
    let key: String
    let title: String

    var id: String { key }

    static let presets: [TheaterFocusReaction] = [
        .init(key: "target", title: "お目当て"),
        .init(key: "curious", title: "気になった"),
        .init(key: "resonated", title: "刺さった"),
        .init(key: "precious", title: "尊い"),
    ]

    static func title(for key: String) -> String {
        presets.first(where: { $0.key == key })?.title ?? key
    }

    static func orderedKeys<S: Sequence>(_ values: S) -> [String] where S.Element == String {
        let valueSet = Set(values)
        let presetKeys = presets.map(\.key)
        let known = presetKeys.filter(valueSet.contains)
        let custom = valueSet.subtracting(Set(presetKeys)).sorted()
        return known + custom
    }
}

struct TheaterFocusLinkMetadata: Equatable {
    var reactionKeys: [String] = []

    private static let memoPrefix = "favoreco:theater-focus:"

    init(reactionKeys: [String] = []) {
        self.reactionKeys = Self.normalized(reactionKeys)
    }

    init(memo: String) {
        guard memo.hasPrefix(Self.memoPrefix),
              let data = String(memo.dropFirst(Self.memoPrefix.count)).data(using: .utf8),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            self.init()
            return
        }
        self.init(reactionKeys: payload.reactionKeys)
    }

    var encodedMemo: String {
        guard !reactionKeys.isEmpty,
              let data = try? JSONEncoder().encode(Payload(reactionKeys: reactionKeys)),
              let json = String(data: data, encoding: .utf8) else { return "" }
        return Self.memoPrefix + json
    }

    private static func normalized(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { return nil }
            return trimmed
        }
    }

    private struct Payload: Codable {
        var version: Int = 1
        var reactionKeys: [String]
    }
}
