//
//  ExperiencePhotoThumbnail.swift
//  favorecoAPP
//

import SwiftUI
import UIKit

struct PendingPhotoThumbnail: View {
    let photo: PendingPhoto
    let title: String
    let aspectRatio: Double
    let isCover: Bool
    let onSetCover: () -> Void
    let onDelete: () -> Void
    @State private var image: UIImage?

    var body: some View {
        PhotoThumbnail(
            image: image,
            title: title,
            aspectRatio: aspectRatio,
            isCover: isCover,
            onSetCover: onSetCover,
            onDelete: onDelete
        )
        .task(id: cacheKey) {
            image = nil
            if let cached = ThumbnailLoader.cached(forKey: cacheKey) {
                image = cached
                return
            }
            let data = photo.data
            let key = cacheKey
            image = await Task.detached(priority: .userInitiated) {
                ThumbnailLoader.makeThumbnail(from: data, maxPixelSize: 420, cacheKey: key)
            }.value
        }
    }

    private var cacheKey: String {
        "pending-editor-\(photo.id.uuidString)-\(photo.data.count)"
    }
}

struct SavedPhotoThumbnail: View {
    let photo: PhotoBlob
    let title: String
    let aspectRatio: Double
    let isCover: Bool
    let onSetCover: () -> Void
    let onDelete: () -> Void
    @State private var image: UIImage?

    var body: some View {
        PhotoThumbnail(
            image: image,
            title: title,
            aspectRatio: aspectRatio,
            isCover: isCover,
            onSetCover: onSetCover,
            onDelete: onDelete
        )
        .task(id: cacheKey) {
            image = nil
            if let cached = ThumbnailLoader.cached(forKey: cacheKey) {
                image = cached
                return
            }
            let data = photo.data
            let key = cacheKey
            image = await Task.detached(priority: .userInitiated) {
                ThumbnailLoader.makeThumbnail(from: data, maxPixelSize: 420, cacheKey: key)
            }.value
        }
    }

    private var cacheKey: String {
        "editor-\(photo.id.uuidString)-\(photo.byteCount)"
    }
}

private struct PhotoThumbnail: View {
    let image: UIImage?
    let title: String
    let aspectRatio: Double
    let isCover: Bool
    let onSetCover: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.secondarySystemGroupedBackground))
                }
            }
            .aspectRatio(CGFloat(aspectRatio), contentMode: .fill)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.55))
                    .padding(5)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title)の写真を削除")

            VStack {
                Spacer()
                HStack {
                    Button(action: onSetCover) {
                        Image(systemName: isCover ? "star.fill" : "star")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(isCover ? Color.yellow : Color.white)
                            .padding(7)
                            .background(.black.opacity(0.55), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isCover ? "カバー写真に設定済み" : "カバー写真に設定")
                    Spacer()
                }
            }
            .padding(5)
        }
    }
}
