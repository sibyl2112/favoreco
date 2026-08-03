//
//  FavorecoIcon.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/29.
//

import SwiftUI
import UIKit

/// Favoreco's primary icon renderer.
///
/// Known SF Symbol names are translated to the bundled Phosphor Light font.
/// Unknown and system-specific symbols intentionally fall back to SF Symbols.
struct FavorecoIcon: View {
    let systemName: String
    var size: CGFloat = 18
    var fallbackWeight: Font.Weight = .regular

    var body: some View {
        Group {
            if let glyph = PhosphorIconGlyph.glyph(for: systemName) {
                Text(glyph)
                    .font(.custom("Phosphor-Light", fixedSize: size))
            } else {
                Image(systemName: systemName)
                    .font(.system(size: size, weight: fallbackWeight))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Text-and-icon rows that should follow Favoreco's icon system.
///
/// Navigation chrome, selection indicators, rating stars, and Apple-specific
/// symbols intentionally keep using SwiftUI's native `Label` / `Image`.
struct FavorecoIconLabel: View {
    let title: String
    let systemImage: String
    var iconSize: CGFloat = 16
    var spacing: CGFloat = 6

    init(
        _ title: String,
        systemImage: String,
        iconSize: CGFloat = 16,
        spacing: CGFloat = 6
    ) {
        self.title = title
        self.systemImage = systemImage
        self.iconSize = iconSize
        self.spacing = spacing
    }

    var body: some View {
        HStack(spacing: spacing) {
            FavorecoIcon(systemName: systemImage, size: iconSize)
            Text(title)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Empty-state presentation that keeps its illustration in Favoreco's icon system.
struct FavorecoContentUnavailableView: View {
    let title: String
    let systemImage: String
    var description: String?

    init(_ title: String, systemImage: String, description: String? = nil) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
    }

    var body: some View {
        ContentUnavailableView {
            VStack(spacing: 8) {
                FavorecoIcon(systemName: systemImage, size: 42)
                Text(title)
                    .font(.headline)
            }
        } description: {
            if let description {
                Text(description)
            }
        }
    }
}

/// TabView only extracts image-backed content from `tabItem`.
/// Render the icon-font glyph to a template UIImage so the standard tab bar
/// can tint and display it just like an SF Symbol.
struct FavorecoTabIcon: View {
    let systemName: String
    var size: CGFloat = 23

    var body: some View {
        if let image = PhosphorIconImage.image(for: systemName, size: size) {
            Image(uiImage: image)
        } else {
            Image(systemName: systemName)
        }
    }
}

enum PhosphorIconImage {
    private static var cache: [String: UIImage] = [:]

    static func image(for systemName: String, size: CGFloat) -> UIImage? {
        guard let glyph = PhosphorIconGlyph.glyph(for: systemName),
              let font = UIFont(name: "Phosphor-Light", size: size)
        else {
            return nil
        }

        let cacheKey = "\(systemName.lowercased())-\(size)"
        if let cached = cache[cacheKey] {
            return cached
        }

        let canvasSize = CGSize(width: size + 4, height: size + 4)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraph,
        ]
        let glyphBounds = (glyph as NSString).boundingRect(
            with: canvasSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        let drawRect = CGRect(
            x: 0,
            y: ((canvasSize.height - glyphBounds.height) / 2) - glyphBounds.minY,
            width: canvasSize.width,
            height: glyphBounds.height
        )
        let image = UIGraphicsImageRenderer(size: canvasSize).image { _ in
            (glyph as NSString).draw(
                with: drawRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )
        }
        .withRenderingMode(.alwaysTemplate)
        cache[cacheKey] = image
        return image
    }
}

enum PhosphorIconGlyph {
    private static func scalar(_ value: UInt32) -> String {
        UnicodeScalar(value).map(String.init) ?? ""
    }

    static func glyph(for systemName: String) -> String? {
        let name = systemName.lowercased()

        if name == "calendar" || name == "calendar.fill" { return scalar(0xE108) }
        if name.hasPrefix("person.text.rectangle") { return scalar(0xE2C8) }
        if name == "person" || name == "person.fill" { return scalar(0xE4C4) }
        if name == "photo" || name == "photo.fill"
            || name == "rectangle.landscape" || name == "rectangle.landscape.fill" {
            return scalar(0xE2CA)
        }
        if name.hasPrefix("photo.on.rectangle") { return scalar(0xE836) }
        if name.hasPrefix("bookmark") { return scalar(0xE0E8) }
        if name.hasPrefix("doc.viewfinder") { return scalar(0xEBB6) }
        if name.hasPrefix("sparkles") || name.hasPrefix("wand.") {
            return scalar(0xE6A2)
        }
        if name == "bell" || name == "bell.fill" { return scalar(0xE0CE) }
        if name.hasPrefix("ticket") || name == "wallet.pass" {
            return scalar(0xE490)
        }
        if name.hasPrefix("book") { return scalar(0xE758) }
        if name.hasPrefix("pawprint") { return scalar(0xE648) }
        if name.hasPrefix("theatermasks") { return scalar(0xE9F4) }
        if name.hasPrefix("paintpalette") { return scalar(0xE6C8) }
        if name.hasPrefix("movieclapper") { return scalar(0xE8C2) }
        if name.hasPrefix("music.mic") { return scalar(0xE75C) }
        if name.hasPrefix("wineglass") { return scalar(0xE6B2) }
        if name.hasPrefix("seal") { return scalar(0xEA48) }
        if name.hasPrefix("shippingbox") { return scalar(0xE390) }
        if name.hasPrefix("archivebox") { return scalar(0xE00C) }
        if name.hasPrefix("questionmark.folder") { return scalar(0xE24A) }
        if name.hasPrefix("mappin") || name == "map" { return scalar(0xE316) }
        if name.hasPrefix("magnifyingglass") { return scalar(0xE30C) }
        if name.hasPrefix("pencil") { return scalar(0xE3AE) }
        if name.hasPrefix("trash") { return scalar(0xE4A6) }
        if name.hasPrefix("camera") { return scalar(0xE10E) }
        if name.hasPrefix("clock") { return scalar(0xE19A) }
        if name.hasPrefix("tag") { return scalar(0xE478) }
        if name.hasPrefix("chair") { return scalar(0xE950) }
        if name.hasPrefix("link") { return scalar(0xE2E2) }
        if name.hasPrefix("info") { return scalar(0xE2CE) }
        if name.hasPrefix("exclamationmark") { return scalar(0xE4E0) }
        if name == "checkmark.circle" { return scalar(0xE184) }
        if name == "xmark.circle" { return scalar(0xE4F8) }
        if name.hasPrefix("chevron.right") { return scalar(0xE13A) }
        if name.hasPrefix("chevron.left") { return scalar(0xE138) }
        if name.hasPrefix("chevron.up") { return scalar(0xE13C) }
        if name.hasPrefix("chevron.down") { return scalar(0xE136) }
        if name.hasPrefix("cloud.sun") { return scalar(0xE540) }
        if name.hasPrefix("cloud.rain") { return scalar(0xE1B4) }
        if name.hasPrefix("cloud.bolt") { return scalar(0xE1B2) }
        if name.hasPrefix("cloud.fog") { return scalar(0xE53C) }
        if name.hasPrefix("cloud") { return scalar(0xE1AA) }
        if name.hasPrefix("sun") { return scalar(0xE472) }
        if name.hasPrefix("moon") { return scalar(0xE58E) }
        if name.hasPrefix("snowflake") { return scalar(0xE5AA) }
        if name.hasPrefix("wind") { return scalar(0xE5D2) }

        switch name {
        case "house", "house.fill":
            return scalar(0xE2C2)
        case "heart", "heart.fill", "heart.circle", "heart.text.square.fill":
            return scalar(0xE2A8)
        case "plus", "plus.circle", "plus.circle.fill":
            return scalar(0xE3D4)
        case "chart.bar", "chart.bar.fill":
            return scalar(0xE150)
        case "square.grid.2x2", "square.grid.2x2.fill":
            return scalar(0xE150)
        case "castle", "castle.fill", "castle.turret", "castle.turret.fill":
            return scalar(0xE9D0)
        case "folder", "folder.fill":
            return scalar(0xE24A)
        case "safari":
            return scalar(0xE1C8)
        case "star":
            return scalar(0xE46A)
        default:
            return nil
        }
    }

    static func categorySystemName(templateKey: String, storedSystemName: String) -> String {
        switch templateKey {
        case "theme_park":
            return "castle.turret"
        case "nature_living":
            return "pawprint"
        default:
            return storedSystemName
        }
    }
}
