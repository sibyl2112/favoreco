import XCTest
import SwiftData
import SwiftUI
import UIKit
@testable import favoreco

@MainActor
final class CreateEntryContextRouterTests: XCTestCase {
    func testCategoryContextPersistsUntilHomeActuallyAppears() async {
        let router = CreateEntryContextRouter()
        let theaterCategoryID = UUID()

        router.activate(categoryID: theaterCategoryID)
        await drainMainActorTasks()

        XCTAssertEqual(router.activeContext?.categoryID, theaterCategoryID)

        router.resetToHome()

        XCTAssertNil(router.activeContext)
    }

    func testCategorySwitchReplacesContextSynchronously() async {
        let router = CreateEntryContextRouter()
        let museumCategoryID = UUID()
        let theaterCategoryID = UUID()

        router.activate(categoryID: museumCategoryID)
        router.activate(categoryID: theaterCategoryID)

        XCTAssertEqual(router.activeContext?.categoryID, theaterCategoryID)
    }

    func testCreateMenuUsesStoredCategoryOnlyWhileHomeTabIsActive() async {
        let router = CreateEntryContextRouter()
        let theaterCategoryID = UUID()

        router.activate(categoryID: theaterCategoryID)

        XCTAssertEqual(
            router.categoryIDForCreateMenu(isHomeTabActive: true),
            theaterCategoryID
        )
        XCTAssertNil(router.categoryIDForCreateMenu(isHomeTabActive: false))
        XCTAssertEqual(
            router.categoryIDForCreateMenu(isHomeTabActive: true),
            theaterCategoryID
        )
    }

    func testFrontmostDetailContextOverridesAndThenRestoresBaseContext() async {
        let router = CreateEntryContextRouter()
        let baseCategoryID = UUID()
        let detailCategoryID = UUID()
        let detailToken = UUID()

        router.activate(categoryID: baseCategoryID)
        router.activateDetail(categoryID: detailCategoryID, token: detailToken)

        XCTAssertEqual(
            router.categoryIDForCreateMenu(isHomeTabActive: true),
            detailCategoryID
        )

        router.deactivateDetail(token: detailToken)

        XCTAssertEqual(
            router.categoryIDForCreateMenu(isHomeTabActive: true),
            baseCategoryID
        )
    }

    func testRemovingCoveredDetailKeepsFrontmostDetailContext() async {
        let router = CreateEntryContextRouter()
        let firstCategoryID = UUID()
        let frontmostCategoryID = UUID()
        let firstToken = UUID()
        let frontmostToken = UUID()

        router.activateDetail(categoryID: firstCategoryID, token: firstToken)
        router.activateDetail(categoryID: frontmostCategoryID, token: frontmostToken)
        router.deactivateDetail(token: firstToken)

        XCTAssertEqual(
            router.categoryIDForCreateMenu(isHomeTabActive: true),
            frontmostCategoryID
        )

        router.deactivateDetail(token: frontmostToken)

        XCTAssertNil(router.categoryIDForCreateMenu(isHomeTabActive: true))
    }

    func testCategoryNavigationActivatesDestinationContext() {
        let theaterCategoryID = UUID()

        XCTAssertEqual(
            HomeCategoryContextTransition.resolve(
                previous: nil,
                current: theaterCategoryID
            ),
            .activate(theaterCategoryID)
        )
    }

    func testCreateMenuRequestCapturesCategoryAtomically() async {
        let router = CreateEntryContextRouter()
        let theaterCategoryID = UUID()

        router.activate(categoryID: theaterCategoryID)
        let request = router.createMenuRequest(isHomeTabActive: true)
        router.resetToHome()

        XCTAssertEqual(request.categoryID, theaterCategoryID)
        XCTAssertNil(router.activeContext)
    }

    func testEveryBuiltInGenreCreateMenuResolvesEveryButtonToExpectedRegistrationActions() {
        let expectedActions: [String: [CreateAction]] = [
            "theater": [.theaterRegistration, .theaterMemory],
            "live": [.theaterRegistration, .record],
            "book": [.quick],
            "movie": [.simpleCategoryRegistration, .record],
            "museum": [.simpleCategoryRegistration, .record, .placeCatalog],
            "sake": [.plan, .record, .quick, .ticketSchedule],
            "theme_park": [.plan, .record, .placeCatalog],
            "nature_living": [.plan, .record, .placeCatalog],
            "outing_facility": [.plan, .record, .placeCatalog],
            "goshuin": [.plan, .record, .quick, .ticketSchedule],
            "random_goods": [.plan, .record, .quick, .ticketSchedule],
        ]

        for (templateKey, expectedGenreActions) in expectedActions {
            let definition = CreateEntryMenuDefinition.resolve(templateKey: templateKey)
            XCTAssertEqual(definition.templateKey, templateKey)
            XCTAssertEqual(
                definition.items.map(\.action),
                expectedGenreActions,
                "\(templateKey) の登録・編集ボタンが想定外の画面へ遷移しています"
            )
        }
    }

    func testLiveAndTheaterUseTheSameStableRegistrationPresentation() {
        let theaterItems = CreateEntryMenuDefinition.resolve(templateKey: "theater").items
        let liveItems = CreateEntryMenuDefinition.resolve(templateKey: "live").items

        XCTAssertEqual(theaterItems.first?.action, .theaterRegistration)
        XCTAssertEqual(liveItems.first?.action, .theaterRegistration)
        XCTAssertEqual(
            theaterItems.map(\.title),
            ["公演・チケットを登録", "観劇の思い出を記録"]
        )
        XCTAssertEqual(
            theaterItems.map(\.detail),
            ["気になる・予定・申込・取得済みを追加", "観劇した公演を選んで思い出を残す"]
        )
        XCTAssertEqual(liveItems.map(\.title), ["ライブを登録", "参戦記録を追加"])
        XCTAssertEqual(
            liveItems.map(\.detail),
            ["ライブ情報を登録して参戦予定・チケットへ進む", "登録済みライブへ今回の記録を追加"]
        )
    }

    func testTheaterAndLiveRegistrationViewsMaterializeWithoutBlocking() throws {
        let configuration = ModelConfiguration(
            schema: FavorecoModelContainerBootstrap.schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: FavorecoModelContainerBootstrap.schema,
            configurations: [configuration]
        )
        let categories = [
            RecordCategory(name: "観劇", templateKey: "theater"),
            RecordCategory(name: "LIVE", sortOrder: 1, templateKey: "live"),
        ]
        categories.forEach(container.mainContext.insert)
        try container.mainContext.save()

        let purposes: [TheaterLifecycleRegistrationPurpose] = [
            .interested,
            .plan,
            .application,
            .acquired,
        ]
        for category in categories {
            for purpose in purposes {
                let rootView = TheaterLifecycleEditorSheet(
                    initialPurpose: purpose,
                    initialCategoryID: category.id
                )
                .environmentObject(PurchaseManager.shared)
                .modelContainer(container)
                let controller = UIHostingController(rootView: rootView)
                controller.loadViewIfNeeded()
                controller.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
                controller.view.layoutIfNeeded()

                XCTAssertNotNil(
                    controller.view,
                    "\(category.templateKey) / \(purpose.rawValue) の統合登録画面を生成できませんでした"
                )
            }
        }
    }

    func testMuseumAndFacilityRegistrationViewsMaterializeWithSharedLifecycleStructure() throws {
        let configuration = ModelConfiguration(
            schema: FavorecoModelContainerBootstrap.schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: FavorecoModelContainerBootstrap.schema,
            configurations: [configuration]
        )
        let categories = [
            RecordCategory(name: "ミュージアム", templateKey: "museum"),
            RecordCategory(name: "テーマパーク", sortOrder: 1, templateKey: "theme_park"),
            RecordCategory(name: "自然・生き物", sortOrder: 2, templateKey: "nature_living"),
            RecordCategory(name: "おでかけ施設", sortOrder: 3, templateKey: "outing_facility"),
        ]
        categories.forEach(container.mainContext.insert)
        try container.mainContext.save()

        let museum = categories[0]
        let museumLifecycle = AnyView(
            SimpleCategoryRegistrationView(category: museum)
                .environmentObject(PurchaseManager.shared)
                .modelContainer(container)
        )
        assertMaterializes(museumLifecycle, context: "museum / interested-plan-visited")

        for category in categories.dropFirst() {
            let forms: [(String, AnyView)] = [
                (
                    "interested",
                    AnyView(
                        QuickRegistrationView(
                            initialTemplateKey: category.templateKey,
                            screenTitle: "気になる対象を登録",
                            locksCategory: true
                        )
                        .modelContainer(container)
                    )
                ),
                (
                    "plan",
                    AnyView(
                        AddTicketPlanView(entryMode: .plan, initialCategoryID: category.id)
                            .environmentObject(PurchaseManager.shared)
                            .modelContainer(container)
                    )
                ),
                (
                    "visited",
                    AnyView(
                        AddExperienceView(category: category)
                            .modelContainer(container)
                    )
                ),
            ]

            for (state, form) in forms {
                assertMaterializes(form, context: "\(category.templateKey) / \(state)")
            }
        }
    }

    func testEveryBuiltInGenreCreateButtonDestinationMaterializesWithoutBlocking() throws {
        let configuration = ModelConfiguration(
            schema: FavorecoModelContainerBootstrap.schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: FavorecoModelContainerBootstrap.schema,
            configurations: [configuration]
        )
        let categoryDefinitions = [
            ("観劇", "theater"),
            ("LIVE", "live"),
            ("書籍", "book"),
            ("映像作品", "movie"),
            ("ミュージアム", "museum"),
            ("酒", "sake"),
            ("テーマパーク", "theme_park"),
            ("自然・生き物", "nature_living"),
            ("おでかけ施設", "outing_facility"),
            ("御朱印", "goshuin"),
            ("ランダムグッズ", "random_goods"),
        ]
        let categories = categoryDefinitions.enumerated().map { index, definition in
            RecordCategory(
                name: definition.0,
                sortOrder: index,
                templateKey: definition.1
            )
        }
        categories.forEach(container.mainContext.insert)
        try container.mainContext.save()

        for category in categories {
            let definition = CreateEntryMenuDefinition.resolve(templateKey: category.templateKey)
            for item in definition.items {
                let destination = createDestinationView(
                    for: item.action,
                    category: category,
                    container: container
                )
                assertMaterializes(
                    destination,
                    context: "\(category.templateKey) / \(item.action.rawValue)"
                )
            }
        }

        assertMaterializes(
            rooted(MainTabView(), container: container),
            context: "main tab / all create presentations"
        )
    }

    func testCategoryReturnResetsOnlyAfterPresentedDestinationCloses() {
        XCTAssertEqual(
            HomeCategoryContextTransition.resolve(
                previous: UUID(),
                current: nil
            ),
            .resetToHome
        )
        XCTAssertEqual(
            HomeCategoryContextTransition.resolve(
                previous: nil,
                current: nil
            ),
            .none
        )
    }

    private func drainMainActorTasks() async {
        for _ in 0..<3 {
            await Task.yield()
        }
    }

    private func assertMaterializes(_ rootView: AnyView, context: String) {
        let controller = UIHostingController(rootView: rootView)
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        controller.view.layoutIfNeeded()
        XCTAssertNotNil(controller.view, "\(context) の登録画面を生成できませんでした")
    }

    private func createDestinationView(
        for action: CreateAction,
        category: RecordCategory,
        container: ModelContainer
    ) -> AnyView {
        switch action {
        case .plan:
            rooted(
                AddTicketPlanView(entryMode: .plan, initialCategoryID: category.id),
                container: container
            )
        case .record:
            rooted(
                RecordTargetSelectionView(
                    categories: [category],
                    preferredCategory: category,
                    screenTitle: "\(GenreVocabulary.recordNoun(for: category.templateKey))を追加",
                    locksCategory: true,
                    onSelect: { _ in }
                ),
                container: container
            )
        case .theaterMemory:
            rooted(
                TheaterMemoryTargetSelectionView(category: category, onSelect: { _ in }),
                container: container
            )
        case .quick:
            rooted(
                QuickRegistrationView(
                    initialTemplateKey: category.templateKey,
                    screenTitle: "\(category.name)を登録",
                    locksCategory: true
                ),
                container: container
            )
        case .placeCatalog:
            rooted(
                PublicPlaceCatalogView(scope: publicPlaceCatalogScope(for: category.templateKey)),
                container: container
            )
        case .theaterRegistration:
            rooted(
                TheaterLifecycleEditorSheet(
                    initialPurpose: .interested,
                    initialCategoryID: category.id
                ),
                container: container
            )
        case .simpleCategoryRegistration:
            rooted(
                SimpleCategoryRegistrationView(category: category),
                container: container
            )
        case .ticketSchedule:
            rooted(
                AddTicketPlanView(entryMode: .ticketSchedule, initialCategoryID: category.id),
                container: container
            )
        }
    }

    private func rooted<Content: View>(
        _ content: Content,
        container: ModelContainer
    ) -> AnyView {
        AnyView(
            content
                .environmentObject(PurchaseManager.shared)
                .modelContainer(container)
        )
    }

    private func publicPlaceCatalogScope(for templateKey: String) -> PublicPlaceCatalogScope {
        switch templateKey {
        case "museum": .museum
        case "theme_park": .themePark
        case "nature_living": .natureLiving
        default: .facility
        }
    }
}
