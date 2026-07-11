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

enum ThumbnailLoader {
    /// NSCache はスレッドセーフ（複数スレッドからの set/object/remove を内部で同期）。
    /// そのため本ローダは actor でなくても競合しない。static let の初期化も一度だけ（スレッド安全）。
    /// メモリ警告時は NSCache が自動で退避するが、明示的にも全消去する。
    nonisolated(unsafe) private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 240
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            cache.removeAllObjects()
        }
        return cache
    }()

    /// キャッシュを全消去する（メモリ警告時などに呼ぶ）。
    nonisolated static func purge() {
        cache.removeAllObjects()
    }

    /// キャッシュ済みサムネイルを即時取得（どのスレッドからも安全）。
    nonisolated static func cached(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    /// `maxPixelSize`（ピクセル）に収まるサムネイルを生成する。メインスレッド外での呼び出しを想定。
    /// `data` は値型（Sendable）で渡すこと（SwiftData モデルをスレッドを跨いで触らないため）。
    nonisolated static func makeThumbnail(from data: Data, maxPixelSize: CGFloat, cacheKey: String) -> UIImage? {
        if let cached = cache.object(forKey: cacheKey as NSString) {
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
        cache.setObject(image, forKey: cacheKey as NSString)
        return image
    }
}
