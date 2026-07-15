//
//  PendingExperiencePhoto.swift
//  favorecoAPP
//

import Foundation
import UIKit
import ImageIO

struct PendingPhoto: Identifiable, Sendable {
    let id = UUID()
    var data: Data
    var originalFilename: String
    var width: Int
    var height: Int

    var relativePath: String {
        "local/\(id.uuidString).jpg"
    }

    func makePhotoBlob(visit: Visit) -> PhotoBlob {
        PhotoBlob(
            relativePath: relativePath,
            originalFilename: originalFilename,
            mediaKind: "photo",
            purpose: "memory",
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
