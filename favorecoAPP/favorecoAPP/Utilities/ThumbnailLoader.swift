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
import Combine

struct ThumbnailReference: Hashable, Sendable {
    enum Source: String, Hashable, Sendable {
        case photo
        case event
        case inbox
        case person
        case place
        case profileIcon
        case profileHero
        case collectibleItem
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
    static func place(_ id: UUID) -> Self { Self(source: .place, id: id) }
    static func profileIcon(_ id: UUID, fallback: ThumbnailReference? = nil) -> Self {
        Self(
            source: .profileIcon,
            id: id,
            fallbackSource: fallback?.source,
            fallbackID: fallback?.id
        )
    }
    static func profileHero(_ id: UUID, fallback: ThumbnailReference? = nil) -> Self {
        Self(
            source: .profileHero,
            id: id,
            fallbackSource: fallback?.source,
            fallbackID: fallback?.id
        )
    }
    static func collectibleItem(_ id: UUID) -> Self { Self(source: .collectibleItem, id: id) }
}

nonisolated private final class ThumbnailCache: @unchecked Sendable {
    let images = NSCache<NSString, UIImage>()
    private let lock = NSLock()
    private var keys: Set<String> = []

    func store(_ image: UIImage, forKey key: String, cost: Int? = nil) {
        lock.lock()
        keys.insert(key)
        if let cost {
            images.setObject(image, forKey: key as NSString, cost: cost)
        } else {
            images.setObject(image, forKey: key as NSString)
        }
        lock.unlock()
    }

    func removeAll() {
        lock.lock()
        keys.removeAll()
        lock.unlock()
        images.removeAllObjects()
    }

    func removeKeys(withPrefix prefix: String) {
        lock.lock()
        let matchedKeys = keys.filter { $0.hasPrefix(prefix) }
        keys.subtract(matchedKeys)
        for key in matchedKeys {
            images.removeObject(forKey: key as NSString)
        }
        lock.unlock()
    }
}

enum ThumbnailLoader {
    nonisolated static let didInvalidateReferenceNotification = Notification.Name(
        "favoreco.thumbnail-reference-invalidated"
    )

    /// NSCache はスレッドセーフ（複数スレッドからの set/object/remove を内部で同期）。
    /// そのため本ローダは actor でなくても競合しない。static let の初期化も一度だけ（スレッド安全）。
    /// メモリ警告時は NSCache が自動で退避するが、明示的にも全消去する。
    nonisolated private static let cache: ThumbnailCache = {
        let cache = ThumbnailCache()
        cache.images.countLimit = 240
        cache.images.totalCostLimit = 64 * 1_024 * 1_024
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            cache.removeAll()
        }
        return cache
    }()

    /// キャッシュを全消去する（メモリ警告時などに呼ぶ）。
    nonisolated static func purge() {
        cache.removeAll()
    }

    /// 1対象のアイキャッチ変更時は、その対象から生成したサムネイルだけを破棄する。
    /// 一覧全体のキャッシュを消すと、保存直後に全カードの再生成が集中するため避ける。
    nonisolated static func purge(reference: ThumbnailReference) {
        cache.removeKeys(withPrefix: "\(reference.source.rawValue)-\(reference.id.uuidString)")
        NotificationCenter.default.post(
            name: didInvalidateReferenceNotification,
            object: nil,
            userInfo: [
                "source": reference.source.rawValue,
                "id": reference.id.uuidString,
            ]
        )
    }

    nonisolated static func invalidation(_ notification: Notification, matches reference: ThumbnailReference) -> Bool {
        notification.userInfo?["source"] as? String == reference.source.rawValue
            && notification.userInfo?["id"] as? String == reference.id.uuidString
    }

    /// キャッシュ済みサムネイルを即時取得（どのスレッドからも安全）。
    nonisolated static func cached(forKey key: String) -> UIImage? {
        cache.images.object(forKey: key as NSString)
    }

    nonisolated static func store(_ image: UIImage, forKey key: String) {
        let pixelCost = Int(image.size.width * image.scale)
            * Int(image.size.height * image.scale)
            * 4
        cache.store(image, forKey: key, cost: pixelCost)
    }

    nonisolated static func cacheKey(
        reference: ThumbnailReference,
        displaySize: CGSize,
        displayScale: CGFloat
    ) -> String {
        let pixelSize = thumbnailPixelTier(
            for: max(displaySize.width, displaySize.height) * displayScale
        )
        let fallback = reference.fallbackSource.flatMap { source in
            reference.fallbackID.map { "-fallback:\(source.rawValue)-\($0.uuidString)" }
        } ?? ""
        return "\(reference.source.rawValue)-\(reference.id.uuidString)\(fallback)@\(pixelSize)"
    }

    nonisolated static func thumbnailPixelTier(for requestedSize: CGFloat) -> Int {
        let tiers = [160, 480, 960, 1600]
        let requested = max(1, Int(requestedSize.rounded(.up)))
        return tiers.first(where: { $0 >= requested }) ?? requested
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
            cache.store(image, forKey: key)
            return image
        }
        guard let data = resolved.data else { return nil }
        let maxPixelSize = CGFloat(
            thumbnailPixelTier(for: max(displaySize.width, displaySize.height) * displayScale)
        )
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
            guard let event = try? modelContext.fetch(descriptor).first else { return (nil, nil) }
            if let eyecatchData = event.eyecatchData {
                return (eyecatchData, nil)
            }
            let path = event.representativeEyecatchPath
            guard !path.isEmpty else { return (nil, nil) }
            var photoDescriptor = FetchDescriptor<PhotoBlob>(
                predicate: #Predicate { $0.relativePath == path }
            )
            photoDescriptor.fetchLimit = 1
            return ((try? modelContext.fetch(photoDescriptor).first?.data) ?? nil, nil)
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
        case .place:
            var descriptor = FetchDescriptor<PlaceMaster>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            return ((try? modelContext.fetch(descriptor).first?.imageData) ?? nil, nil)
        case .profileIcon:
            var descriptor = FetchDescriptor<FavoriteProfile>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            return ((try? modelContext.fetch(descriptor).first?.iconImageData) ?? nil, nil)
        case .profileHero:
            var descriptor = FetchDescriptor<FavoriteProfile>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            return ((try? modelContext.fetch(descriptor).first?.heroImageData) ?? nil, nil)
        case .collectibleItem:
            var descriptor = FetchDescriptor<CollectibleItem>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            return ((try? modelContext.fetch(descriptor).first?.imageData) ?? nil, nil)
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
        cache.store(image, forKey: cacheKey)
        return image
    }
}

enum CategoryDefaultArtwork {
    nonisolated static func resourceName(for templateKey: String) -> String {
        switch templateKey {
        case "theater":
            return "theater-hero-venue-v2"
        case "goshuin":
            return "goshuin-hero-bright-shrine"
        case "nature_living":
            return "nature_living-hero-zoo"
        case "movie", "book", "museum", "live", "sake", "theme_park",
             "outing_facility", "random_goods":
            return "\(templateKey)-hero-default"
        default:
            return "nature_living-hero-zoo"
        }
    }
}

struct CategoryDefaultArtworkImage: View {
    let templateKey: String
    let displaySize: CGSize
    var contentMode: ContentMode = .fill

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    private var taskID: String {
        let tier = ThumbnailLoader.thumbnailPixelTier(
            for: max(displaySize.width, displaySize.height) * displayScale
        )
        return "\(CategoryDefaultArtwork.resourceName(for: templateKey))@\(tier)"
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Color(.secondarySystemFill)
            }
        }
        .task(id: taskID) {
            let resourceName = CategoryDefaultArtwork.resourceName(for: templateKey)
            let tier = ThumbnailLoader.thumbnailPixelTier(
                for: max(displaySize.width, displaySize.height) * displayScale
            )
            let key = "category-default-\(resourceName)@\(tier)"
            if let cached = ThumbnailLoader.cached(forKey: key) {
                image = cached
                return
            }
            guard let url = Bundle.main.url(forResource: resourceName, withExtension: "jpg") else {
                image = nil
                return
            }
            let loaded = await Task.detached(priority: .utility) { () -> UIImage? in
                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
                let options: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceShouldCacheImmediately: true,
                    kCGImageSourceThumbnailMaxPixelSize: tier,
                ]
                guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
                    source,
                    0,
                    options as CFDictionary
                ) else {
                    return nil
                }
                return UIImage(cgImage: cgImage)
            }.value
            guard !Task.isCancelled, taskID == self.taskID else { return }
            if let loaded {
                ThumbnailLoader.store(loaded, forKey: key)
            }
            image = loaded
        }
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
    @State private var reloadVersion = 0

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
            let key = ThumbnailLoader.cacheKey(
                reference: $0,
                displaySize: displaySize,
                displayScale: displayScale
            )
            return "\(key)-reload:\(reloadVersion)"
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
        .onReceive(
            NotificationCenter.default.publisher(
                for: ThumbnailLoader.didInvalidateReferenceNotification
            )
        ) { notification in
            guard let reference,
                  ThumbnailLoader.invalidation(notification, matches: reference) else { return }
            image = nil
            reloadVersion += 1
        }
    }
}
