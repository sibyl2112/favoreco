import Foundation
import LinkPresentation

struct URLMetadataCandidate: Sendable {
    let title: String
    let resolvedURL: URL
}

enum URLMetadataService {
    @MainActor
    static func fetch(from rawValue: String) async throws -> URLMetadataCandidate {
        guard let url = normalizedURL(from: rawValue) else {
            throw URLMetadataError.invalidURL
        }

        let provider = LPMetadataProvider()
        provider.timeout = 15
        let metadata = try await provider.startFetchingMetadata(for: url)
        let title = metadata.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !title.isEmpty else {
            throw URLMetadataError.titleNotFound
        }
        return URLMetadataCandidate(title: title, resolvedURL: metadata.originalURL ?? metadata.url ?? url)
    }

    nonisolated static func normalizedURL(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let value = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: value), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            return nil
        }
        return url
    }
}

enum URLMetadataError: LocalizedError {
    case invalidURL
    case titleNotFound

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "httpまたはhttpsのURLを入力してください。"
        case .titleNotFound:
            return "このページからタイトルを取得できませんでした。"
        }
    }
}
