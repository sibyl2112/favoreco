//
//  PendingExperiencePhoto.swift
//  favorecoAPP
//

import Foundation
import UIKit
import ImageIO

nonisolated enum ExperiencePhotoPurpose: String, CaseIterable, Identifiable, Sendable {
    case memory
    case ticket
    case goods
    case benefit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .memory: return "思い出"
        case .ticket: return "チケット"
        case .goods: return "グッズ"
        case .benefit: return "ノベルティ・特典"
        }
    }

    var systemImage: String {
        switch self {
        case .memory: return "photo.on.rectangle"
        case .ticket: return "ticket"
        case .goods: return "bag"
        case .benefit: return "gift"
        }
    }

    var supportsAmount: Bool { self == .ticket || self == .goods }

    static func resolved(from rawValue: String) -> ExperiencePhotoPurpose {
        ExperiencePhotoPurpose(rawValue: rawValue) ?? .memory
    }
}

nonisolated struct PhotoMetadataDraft: Sendable {
    var purpose: ExperiencePhotoPurpose = .memory
    var ocrText: String = ""
    var amountText: String = ""

    init(
        purpose: ExperiencePhotoPurpose = .memory,
        ocrText: String = "",
        amountText: String = ""
    ) {
        self.purpose = purpose
        self.ocrText = ocrText
        self.amountText = amountText
    }

    @MainActor init(photo: PhotoBlob) {
        purpose = .resolved(from: photo.purpose)
        ocrText = photo.ocrText
        amountText = Self.formattedAmount(photo.amount)
    }

    var amount: Decimal {
        let normalized = amountText
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "￥", with: "")
            .replacingOccurrences(of: "円", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return Decimal(0) }
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) ?? Decimal(0)
    }

    mutating func normalizeForPurpose() {
        guard purpose == .memory else { return }
        ocrText = ""
        amountText = ""
    }

    private static func formattedAmount(_ amount: Decimal) -> String {
        guard amount != Decimal(0) else { return "" }
        return NSDecimalNumber(decimal: amount).stringValue
    }
}

nonisolated struct PendingPhoto: Identifiable, Sendable {
    let id = UUID()
    var data: Data
    var originalFilename: String
    var width: Int
    var height: Int
    var metadata = PhotoMetadataDraft()

    var relativePath: String {
        "local/\(id.uuidString).jpg"
    }

    @MainActor func makePhotoBlob(visit: Visit) -> PhotoBlob {
        PhotoBlob(
            relativePath: relativePath,
            originalFilename: originalFilename,
            mediaKind: "photo",
            purpose: metadata.purpose.rawValue,
            ocrText: metadata.ocrText.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: metadata.purpose.supportsAmount ? metadata.amount : Decimal(0),
            byteCount: data.count,
            width: width,
            height: height,
            createdAt: Date(),
            data: data,
            visit: visit
        )
    }

    nonisolated static func make(
        from data: Data,
        filename: String,
        compressionQuality: Double
    ) -> PendingPhoto? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: 1600,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        let safeQuality = min(max(compressionQuality, 0.5), 0.95)
        guard let compressedData = UIImage(cgImage: cgImage).jpegData(compressionQuality: safeQuality) else {
            return nil
        }

        return PendingPhoto(
            data: compressedData,
            originalFilename: filename,
            width: cgImage.width,
            height: cgImage.height
        )
    }
}
