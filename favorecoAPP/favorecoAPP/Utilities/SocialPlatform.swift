//
//  SocialPlatform.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import Foundation

enum SocialPlatform: String, CaseIterable, Identifiable {
    case instagram
    case x
    case threads
    case facebook

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .instagram: return "Instagram"
        case .x: return "X"
        case .threads: return "Threads"
        case .facebook: return "Facebook"
        }
    }

    var symbolName: String {
        switch self {
        case .instagram: return "camera"
        case .x: return "xmark"
        case .threads: return "at"
        case .facebook: return "f.circle"
        }
    }

    var placeholder: String {
        switch self {
        case .instagram: return "@favoreco またはURL"
        case .x: return "@favoreco またはURL"
        case .threads: return "@favoreco またはURL"
        case .facebook: return "プロフィールURLまたはID"
        }
    }

    static func platform(for key: String) -> SocialPlatform {
        SocialPlatform(rawValue: key) ?? .instagram
    }

    func url(from input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let explicitURL = URL(string: trimmed), explicitURL.scheme != nil {
            return explicitURL
        }

        if let httpsURL = URL(string: "https://\(trimmed)"), trimmed.contains(".") {
            return httpsURL
        }

        let handle = trimmed
            .replacingOccurrences(of: "@", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard !handle.isEmpty else { return nil }

        switch self {
        case .instagram:
            return URL(string: "https://www.instagram.com/\(handle)")
        case .x:
            return URL(string: "https://x.com/\(handle)")
        case .threads:
            return URL(string: "https://www.threads.net/@\(handle)")
        case .facebook:
            return URL(string: "https://www.facebook.com/\(handle)")
        }
    }
}
