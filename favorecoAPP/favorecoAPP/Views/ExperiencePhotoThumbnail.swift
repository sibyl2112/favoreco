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
    let fillsFrame: Bool
    let isCover: Bool
    let isHeroBackground: Bool
    let purpose: ExperiencePhotoPurpose
    let canSetCover: Bool
    let canSetHeroBackground: Bool
    let onSetCover: () -> Void
    let onSetHeroBackground: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var image: UIImage?

    var body: some View {
        PhotoThumbnail(
            image: image,
            title: title,
            aspectRatio: aspectRatio,
            fillsFrame: fillsFrame,
            isCover: isCover,
            isHeroBackground: isHeroBackground,
            purpose: purpose,
            canSetCover: canSetCover,
            canSetHeroBackground: canSetHeroBackground,
            onSetCover: onSetCover,
            onSetHeroBackground: onSetHeroBackground,
            onEdit: onEdit,
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
    let fillsFrame: Bool
    let isCover: Bool
    let isHeroBackground: Bool
    let purpose: ExperiencePhotoPurpose
    let canSetCover: Bool
    let canSetHeroBackground: Bool
    let onSetCover: () -> Void
    let onSetHeroBackground: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var image: UIImage?

    var body: some View {
        PhotoThumbnail(
            image: image,
            title: title,
            aspectRatio: aspectRatio,
            fillsFrame: fillsFrame,
            isCover: isCover,
            isHeroBackground: isHeroBackground,
            purpose: purpose,
            canSetCover: canSetCover,
            canSetHeroBackground: canSetHeroBackground,
            onSetCover: onSetCover,
            onSetHeroBackground: onSetHeroBackground,
            onEdit: onEdit,
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
    let fillsFrame: Bool
    let isCover: Bool
    let isHeroBackground: Bool
    let purpose: ExperiencePhotoPurpose
    let canSetCover: Bool
    let canSetHeroBackground: Bool
    let onSetCover: () -> Void
    let onSetHeroBackground: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: fillsFrame ? .fill : .fit)
                } else {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.secondarySystemGroupedBackground))
                }
            }
            .aspectRatio(CGFloat(aspectRatio), contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipped()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack {
                Label(purpose.title, systemImage: purpose.systemImage)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.62), in: Capsule())
                Spacer()
            }
            .padding(5)

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
                    if canSetCover {
                        Button(action: onSetCover) {
                            Image(systemName: isCover ? "star.fill" : "star")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(isCover ? Color.yellow : Color.white)
                                .padding(7)
                                .background(.black.opacity(0.55), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isCover ? "カバー写真に設定済み" : "カバー写真に設定")
                    }
                    if canSetHeroBackground {
                        Button(action: onSetHeroBackground) {
                            Image(systemName: isHeroBackground ? "rectangle.landscape.fill" : "rectangle.landscape")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(isHeroBackground ? Color.yellow : Color.white)
                                .padding(7)
                                .background(.black.opacity(0.55), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isHeroBackground ? "トップ背景に設定済み" : "トップ背景に設定")
                    }
                    Spacer()
                    Button(action: onEdit) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(7)
                            .background(.black.opacity(0.55), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title)の分類と情報を編集")
                }
            }
            .padding(5)
        }
    }
}
