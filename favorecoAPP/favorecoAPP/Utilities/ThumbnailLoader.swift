//
//  ThumbnailLoader.swift
//  favorecoAPP
//
//  写真データをダウンサンプルしてサムネイル UIImage を生成・キャッシュする。
//  目的：Home などの一覧で、フル解像度の同期デコード（UIImage(data:) をbody内で毎回実行）による
//  スクロールの引っ掛かりを防ぐ。ImageIO のサムネイル生成で必要サイズだけデコードし、
//  メインスレッド外で実行、結果は NSCache（スレッドセーフ）で再利用する。
//

import UIKit
import ImageIO
import SwiftData
import SwiftUI

struct ThumbnailReference: Hashable, Sendable {
    enum Source: String, Hashable, Sendable {
        case photo
        case event
        case inbox
        case person
        case profileIcon
        case profileHero
    }

    let source: Source
    let id: UUID
    let fallbackSource: Source?
    let fallbackID: UUID?

    private init(source: Source, id: UUID, fallbackSource: Source? = nil, fallbackID: UUID? = nil) {
        self.source = source
        self.id = id
        self.fallbackSource = fallbackSource
        self.fallbackID = fallbackID
    }

    static func photo(_ id: UUID) -> Self { Self(source: .photo, id: id) }
    static func event(_ id: UUID) -> Self { Self(source: .event, id: id) }
    static func inbox(_ id: UUID) -> Self { Self(source: .inbox, id: id) }
    static func person(_ id: UUID) -> Self { Self(source: .person, id: id) }
    static func profileIcon(_ id: UUID, fallback: ThumbnailReference? = nil) -> Self {
        Self(
            source: .profileIcon,
            id: id,
            fallbackSource: fallback?.source,
            fallbackID: fallback?.id
        )
    }
    static func profileHero(_ id: UUID) -> Self { Self(source: .profileHero, id: id) }
}

nonisolated private final class ThumbnailCache: @unchecked Sendable {
    let images = NSCache<NSString, UIImage>()
}

enum ThumbnailLoader {
    /// NSCache はスレッドセーフ（複数スレッドからの set/object/remove を内部で同期）。
    /// そのため本ローダは actor でなくても競合しない。static let の初期化も一度だけ（スレッド安全）。
    /// メモリ警告時は NSCache が自動で退避するが、明示的にも全消去する。
    nonisolated private static let cache: ThumbnailCache = {
        let cache = ThumbnailCache()
        cache.images.countLimit = 240
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            cache.images.removeAllObjects()
        }
        return cache
    }()

    /// キャッシュを全消去する（メモリ警告時などに呼ぶ）。
    nonisolated static func purge() {
        cache.images.removeAllObjects()
    }

    /// キャッシュ済みサムネイルを即時取得（どのスレッドからも安全）。
    nonisolated static func cached(forKey key: String) -> UIImage? {
        cache.images.object(forKey: key as NSString)
    }

    nonisolated static func cacheKey(
        reference: ThumbnailReference,
        displaySize: CGSize,
        displayScale: CGFloat
    ) -> String {
        let pixelWidth = Int((displaySize.width * displayScale).rounded(.up))
        let pixelHeight = Int((displaySize.height * displayScale).rounded(.up))
        let fallback = reference.fallbackSource.flatMap { source in
            reference.fallbackID.map { "-fallback:\(source.rawValue)-\($0.uuidString)" }
        } ?? ""
        return "\(reference.source.rawValue)-\(reference.id.uuidString)\(fallback)@\(pixelWidth)x\(pixelHeight)"
    }

    @MainActor
    static func load(
        reference: ThumbnailReference,
        displaySize: CGSize,
        displayScale: CGFloat,
        modelContext: ModelContext
    ) async -> UIImage? {
        let key = cacheKey(reference: reference, displaySize: displaySize, displayScale: displayScale)
        if let cached = cached(forKey: key) {
            return cached
        }

        let primary = asset(source: reference.source, id: reference.id, modelContext: modelContext)
        let resolved = if primary.data != nil || primary.image != nil {
            primary
        } else if let fallbackSource = reference.fallbackSource, let fallbackID = reference.fallbackID {
            asset(source: fallbackSource, id: fallbackID, modelContext: modelContext)
        } else {
            primary
        }

        if let image = resolved.image {
            cache.images.setObject(image, forKey: key as NSString)
            return image
        }
        guard let data = resolved.data else { return nil }
        let maxPixelSize = max(displaySize.width, displaySize.height) * displayScale
        return await Task.detached(priority: .userInitiated) {
            makeThumbnail(from: data, maxPixelSize: maxPixelSize, cacheKey: key)
        }.value
    }

    @MainActor
    private static func asset(
        source: ThumbnailReference.Source,
        id: UUID,
        modelContext: ModelContext
    ) -> (data: Data?, image: UIImage?) {
        switch source {
        case .photo:
            var descriptor = FetchDescriptor<PhotoBlob>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            return ((try? modelContext.fetch(descriptor).first?.data) ?? nil, nil)
        case .event:
            var descriptor = FetchDescriptor<ExperienceEvent>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            return ((try? modelContext.fetch(descriptor).first?.eyecatchData) ?? nil, nil)
        case .inbox:
            var descriptor = FetchDescriptor<InboxItem>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            return ((try? modelContext.fetch(descriptor).first?.eyecatchData) ?? nil, nil)
        case .person:
            var descriptor = FetchDescriptor<PersonMaster>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            guard let person = try? modelContext.fetch(descriptor).first else { return (nil, nil) }
            if let data = person.imageData { return (data, nil) }
            return (nil, PersonImageStore.image(at: person.imagePath))
        case .profileIcon:
            var descriptor = FetchDescriptor<FavoriteProfile>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            return ((try? modelContext.fetch(descriptor).first?.iconImageData) ?? nil, nil)
        case .profileHero:
            var descriptor = FetchDescriptor<FavoriteProfile>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            return ((try? modelContext.fetch(descriptor).first?.heroImageData) ?? nil, nil)
        }
    }

    /// `maxPixelSize`（ピクセル）に収まるサムネイルを生成する。メインスレッド外での呼び出しを想定。
    /// `data` は値型（Sendable）で渡すこと（SwiftData モデルをスレッドを跨いで触らないため）。
    nonisolated static func makeThumbnail(from data: Data, maxPixelSize: CGFloat, cacheKey: String) -> UIImage? {
        if let cached = cache.images.object(forKey: cacheKey as NSString) {
            return cached
        }
        guard maxPixelSize > 0,
              !data.isEmpty,
              let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxPixelSize.rounded())
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        let image = UIImage(cgImage: cgImage)
        cache.images.setObject(image, forKey: cacheKey as NSString)
        return image
    }
}

struct ThumbnailImage<Placeholder: View>: View {
    let reference: ThumbnailReference?
    let displaySize: CGSize
    let contentMode: ContentMode
    @ViewBuilder let placeholder: Placeholder

    @Environment(\.displayScale) private var displayScale
    @Environment(\.modelContext) private var modelContext
    @State private var image: UIImage?

    init(
        reference: ThumbnailReference?,
        displaySize: CGSize,
        contentMode: ContentMode = .fill,
        @ViewBuilder placeholder: () -> Placeholder
    ) {
        self.reference = reference
        self.displaySize = displaySize
        self.contentMode = contentMode
        self.placeholder = placeholder()
    }

    private var taskID: String? {
        reference.map {
            ThumbnailLoader.cacheKey(
                reference: $0,
                displaySize: displaySize,
                displayScale: displayScale
            )
        }
    }

    var body: some View {
        ZStack {
            placeholder
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            }
        }
        .task(id: taskID) {
            guard let reference else {
                image = nil
                return
            }
            image = nil
            let loaded = await ThumbnailLoader.load(
                reference: reference,
                displaySize: displaySize,
                displayScale: displayScale,
                modelContext: modelContext
            )
            guard !Task.isCancelled, self.reference == reference else { return }
            image = loaded
        }
    }
}
