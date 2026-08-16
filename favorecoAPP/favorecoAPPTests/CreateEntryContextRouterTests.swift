import XCTest
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
}
