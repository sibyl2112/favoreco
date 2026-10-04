import XCTest
import SwiftData
import SwiftUI
import UIKit
@testable import favoreco

/// Actually attach views to a window. loadViewIfNeeded alone does not exercise
/// onAppear or a presented hierarchy, so it cannot establish UI readiness.
@MainActor
final class ReleaseSmokeTests: XCTestCase {
    // Match the app-root router lifetime; MapKit releases detached trait environments asynchronously.
    private static let router = CreateEntryContextRouter()
    func testSevenGenreDetailsAndRepeatFormsRenderInWindow() async throws {
        let container = try ModelContainer(
            for: FavorecoModelContainerBootstrap.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)]
        )
        let router = Self.router
        for key in ["theater", "live", "book", "movie", "museum", "theme_park", "nature_living"] {
            let category = RecordCategory(name: key, templateKey: key)
            let event = ExperienceEvent(title: "Release audit \(key)", category: category)
            let visit = Visit(event: event)
            container.mainContext.insert(category)
            container.mainContext.insert(event)
            container.mainContext.insert(visit)
            try container.mainContext.save()
            try await render(ExperienceDetailView(visit: visit), container: container, router: router)
            try await render(AddVisitView(event: event), container: container, router: router)
        }
    }

    func testSevenGenreHeroScreenshotsAndDefaultImageDimensions() async throws {
        let container = try ModelContainer(for: FavorecoModelContainerBootstrap.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        let keys = ["theater", "live", "book", "movie", "museum", "theme_park", "nature_living"]
        for preset in CategoryPresetSeeder.presets where keys.contains(preset.templateKey) {
            container.mainContext.insert(RecordCategory(name: preset.name, iconSymbol: preset.iconSymbol,
                colorHex: preset.colorHex, sortOrder: preset.sortOrder, isBuiltIn: true,
                templateKey: preset.templateKey, enabledUnitsRaw: preset.enabledUnitsRaw,
                templateTypeKey: preset.templateTypeKey, targetNameLabel: preset.targetNameLabel,
                recordUnitName: preset.recordUnitName, dateLabel: preset.dateLabel))
        }
        try container.mainContext.save()
        _ = try SampleDataSeeder.replaceSamples(in: container.mainContext)
        let visits = try container.mainContext.fetch(FetchDescriptor<Visit>())
        let plans = try container.mainContext.fetch(FetchDescriptor<Plan>())
        let router = Self.router
        for key in keys {
            let preset = try XCTUnwrap(HeroBackgroundPreset.presets(for: key).first)
            let url = Bundle.main.url(forResource: preset.resourceName, withExtension: "jpg", subdirectory: "CategoryHeroBackgrounds")
                ?? Bundle.main.url(forResource: preset.resourceName, withExtension: "jpg")
            let image = try XCTUnwrap(UIImage(contentsOfFile: try XCTUnwrap(url).path))
            XCTAssertEqual(image.size.width / image.size.height, 16.0 / 9.0, accuracy: 0.001)
            let visit = try XCTUnwrap(visits.first { $0.event?.category?.templateKey == key })
            let event = try XCTUnwrap(visit.event)
            try await render(EventDetailView(event: event), container: container, router: router, captureName: key + "-event")
            try await render(ExperienceDetailView(visit: visit, onBack: {}), container: container, router: router, captureName: key + "-visit")
            if key != "book" {
                let plan = try XCTUnwrap(plans.first { $0.event?.category?.templateKey == key })
                try await render(PlanDetailView(plan: plan, onBack: {}), container: container, router: router, captureName: key + "-plan")
            }
        }
    }

    func testAllGenreEyecatchesAtCompactAndStandardWidths() async throws {
        let container = try ModelContainer(for: FavorecoModelContainerBootstrap.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        let keys = ["theater", "live", "book", "movie", "museum", "theme_park", "nature_living", "goshuin", "sake", "random_goods"]
        for preset in CategoryPresetSeeder.presets where keys.contains(preset.templateKey) {
            container.mainContext.insert(RecordCategory(name: preset.name, iconSymbol: preset.iconSymbol,
                colorHex: preset.colorHex, templateKey: preset.templateKey))
        }
        try container.mainContext.save()
        _ = try SampleDataSeeder.replaceSamples(in: container.mainContext)
        let events = try container.mainContext.fetch(FetchDescriptor<ExperienceEvent>())
        let visits = try container.mainContext.fetch(FetchDescriptor<Visit>())
        let plans = try container.mainContext.fetch(FetchDescriptor<Plan>())
        for key in keys {
            let event = try XCTUnwrap(events.first { $0.category?.templateKey == key })
            let visit = visits.first { $0.event?.category?.templateKey == key }
            let plan = plans.first { $0.event?.category?.templateKey == key }
            if key != "random_goods" { XCTAssertNotNil(visit, key) }
            if !["random_goods", "book"].contains(key) { XCTAssertNotNil(plan, key) }
            for width in [402, 375] {
                if width == 375 {
                    for target in [event, visit?.event, plan?.event].compactMap({ $0 }) {
                        target.title = "長いタイトルの表示確認・記憶に残る特別な一日とその続き"
                    }
                    plan?.title = "長いタイトルの表示確認・記憶に残る特別な一日とその続き"
                    plan?.venueNameSnapshot = "国立総合文化芸術センター・新館地下二階特別展示会場"
                    try container.mainContext.save()
                }
                let size = CGSize(width: width, height: width == 375 ? 812 : 874)
                let prefix = "all-\(width)-\(key)"
                try await render(EventDetailView(event: event), container: container, router: Self.router,
                    captureName: prefix + "-event", size: size)
                if let visit {
                    try await render(ExperienceDetailView(visit: visit, onBack: {}), container: container, router: Self.router,
                        captureName: prefix + "-visit", size: size)
                }
                if let plan {
                    try await render(PlanDetailView(plan: plan, onBack: {}), container: container, router: Self.router,
                        captureName: prefix + "-plan", size: size)
                }
            }
        }
    }

    func testTenGenreAddedBackgroundsRenderInDetails() async throws {
        let container = try ModelContainer(for: FavorecoModelContainerBootstrap.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        let keys = ["theater", "live", "movie", "museum", "book", "theme_park", "nature_living", "goshuin", "sake", "random_goods"]
        for preset in CategoryPresetSeeder.presets where keys.contains(preset.templateKey) {
            let category = RecordCategory(name: preset.name, iconSymbol: preset.iconSymbol,
                colorHex: preset.colorHex, templateKey: preset.templateKey)
            container.mainContext.insert(category)
            for background in HeroBackgroundPreset.presets(for: preset.templateKey).suffix(2) {
                let event = ExperienceEvent(title: background.title, category: category)
                let visit = Visit(event: event)
                let fields = VisitUnitFields(heroBackgroundPresetKey: background.key)
                event.unitFieldsRaw = fields.encodedRawValue
                visit.unitFieldsRaw = fields.encodedRawValue
                container.mainContext.insert(event)
                container.mainContext.insert(visit)
                try container.mainContext.save()
                try await render(ExperienceDetailView(visit: visit, onBack: {}), container: container,
                    router: Self.router, captureName: "variant-" + background.key)
            }
        }
    }

    func testFiveHundredRecordsAndFiftyPhotoPayloadsSurviveStoreReopen() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = ModelConfiguration(
            "ReleaseAudit", schema: FavorecoModelContainerBootstrap.schema,
            url: directory.appendingPathComponent("audit.store"), cloudKitDatabase: .none
        )
        let keys = ["theater", "live", "book", "movie", "museum", "theme_park", "nature_living"]
        let payload = Data(repeating: 42, count: 4096)
        // Persistence integrity, not a claim about decoding 50 full-size images or scroll speed.
        try autoreleasepool {
            let container = try ModelContainer(for: FavorecoModelContainerBootstrap.schema, configurations: [configuration])
            let context = container.mainContext
            let categories = keys.map { RecordCategory(name: $0, templateKey: $0) }
            categories.forEach(context.insert)
            for index in 0..<500 {
                let event = ExperienceEvent(title: "audit-\(index)", category: categories[index % keys.count])
                let visit = Visit(note: "note-\(index)", event: event)
                context.insert(event)
                context.insert(visit)
                if index < 50 {
                    context.insert(PhotoBlob(relativePath: "audit-\(index).bin", byteCount: payload.count, data: payload, visit: visit))
                }
            }
            try context.save()
        }
        try autoreleasepool {
            let reopened = try ModelContainer(for: FavorecoModelContainerBootstrap.schema, configurations: [configuration])
            let events = try reopened.mainContext.fetch(FetchDescriptor<ExperienceEvent>())
            let visits = try reopened.mainContext.fetch(FetchDescriptor<Visit>())
            let photos = try reopened.mainContext.fetch(FetchDescriptor<PhotoBlob>())
            XCTAssertEqual(events.count, 500)
            XCTAssertEqual(visits.count, 500)
            XCTAssertEqual(photos.count, 50)
            XCTAssertEqual(Set(events.compactMap { $0.category?.templateKey }), Set(keys))
            XCTAssertEqual(Set(events.map(\.id)).count, 500)
            for visit in visits {
                let title = try XCTUnwrap(visit.event?.title)
                XCTAssertEqual(visit.note, title.replacingOccurrences(of: "audit-", with: "note-"))
            }
            for photo in photos {
                XCTAssertEqual(photo.data, payload)
                XCTAssertNotNil(photo.visit?.event)
            }
        }
    }

    func testPrivacyManifestIsBundledWithKnownAPIReasons() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any])
        let entries = try XCTUnwrap(plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        for (category, reason) in [("UserDefaults", "CA92.1"), ("FileTimestamp", "C617.1"), ("DiskSpace", "E174.1")] {
            let entry = try XCTUnwrap(entries.first { ($0["NSPrivacyAccessedAPIType"] as? String) == "NSPrivacyAccessedAPICategory" + category })
            XCTAssertTrue((entry["NSPrivacyAccessedAPITypeReasons"] as? [String] ?? []).contains(reason))
        }
    }

    func testMuseumSampleDetailCanScrollToHistoryAndBack() async throws {
        let container = try ModelContainer(
            for: FavorecoModelContainerBootstrap.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)]
        )
        container.mainContext.insert(RecordCategory(name: "ミュージアム", templateKey: "museum"))
        try container.mainContext.save()
        _ = try SampleDataSeeder.replaceSamples(in: container.mainContext, categoryTemplateKeys: ["museum"])
        let visits = try container.mainContext.fetch(FetchDescriptor<Visit>())
        let visit = try XCTUnwrap(visits.first { $0.event?.title == "透明な記憶" })
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        let controller = UIHostingController(rootView:
            CategoryDetailPanelOverlay(selection: .visit(visit.id), onClose: {}, onOpenEvent: { _ in }, onOpenVisit: { _ in })
                .modelContainer(container)
                .environmentObject(PurchaseManager.shared)
                .environmentObject(Self.router)
        )
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        controller.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(250))
        let scroll = try XCTUnwrap(scrollViews(in: controller.view).max { $0.contentSize.height < $1.contentSize.height })
        XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.height)
        // Exercise off-screen layout in the real sample detail, including photos/map.
        // Actual repeat-button/save transitions are also checked separately through UI.
        for fraction in [0.65, 1.0, 0.0, 1.0] {
            let bottom = max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
            scroll.setContentOffset(CGPoint(x: 0, y: bottom * fraction), animated: true)
            try await Task.sleep(for: .milliseconds(450))
            XCTAssertTrue(scroll.contentOffset.y.isFinite)
            XCTAssertNotNil(controller.view.window)
        }
        XCTAssertGreaterThan(scroll.contentOffset.y, 0)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Visit>()), visits.count)
    }

    private func scrollViews(in view: UIView) -> [UIScrollView] {
        ((view as? UIScrollView).map { [$0] } ?? [])
            + view.subviews.flatMap { scrollViews(in: $0) }
    }

    private func render<V: View>(_ view: V, container: ModelContainer, router: CreateEntryContextRouter, captureName: String? = nil, size: CGSize? = nil) async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        let controller = UIHostingController(rootView: NavigationStack { view }
            .modelContainer(container)
            .environmentObject(PurchaseManager.shared)
            .environmentObject(router))
        window.rootViewController = controller
        if let size { window.frame = CGRect(origin: .zero, size: size) }
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        controller.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertFalse(controller.view.bounds.isEmpty)
        XCTAssertNotNil(controller.view.window)
        if let size { XCTAssertEqual(controller.view.bounds.width, size.width, accuracy: 1) }
        if let captureName {
            try await Task.sleep(for: .milliseconds(300))
            let image = UIGraphicsImageRenderer(bounds: controller.view.bounds).image { context in
                controller.view.layer.render(in: context.cgContext)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "hero-" + captureName
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
