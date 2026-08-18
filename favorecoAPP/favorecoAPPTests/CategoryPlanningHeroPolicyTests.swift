import XCTest
@testable import favoreco

final class CategoryPlanningHeroPolicyTests: XCTestCase {
    func testMemoryHeroIndexIsEmptySafeAndStableWithinTheDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let categoryID = UUID(uuidString: "3FBFCB97-DC33-42B4-BCCF-0C79F874A654")!
        let morning = Date(timeIntervalSince1970: 1_786_665_600)
        let evening = morning.addingTimeInterval(60 * 60 * 12)

        XCTAssertNil(
            CategoryMemoryHeroPolicy.stableIndex(
                itemCount: 0,
                categoryID: categoryID,
                now: morning,
                calendar: calendar
            )
        )

        let morningIndex = CategoryMemoryHeroPolicy.stableIndex(
            itemCount: 5,
            categoryID: categoryID,
            now: morning,
            calendar: calendar
        )
        XCTAssertEqual(
            morningIndex,
            CategoryMemoryHeroPolicy.stableIndex(
                itemCount: 5,
                categoryID: categoryID,
                now: evening,
                calendar: calendar
            )
        )
        XCTAssertTrue((0..<5).contains(morningIndex ?? -1))
    }

    func testCategoryChapterNavigationKeepsEdgeAndMiddleNeighbors() {
        XCTAssertNil(
            CategoryChapterNavigationPolicy.neighborIndices(
                categoryCount: 0,
                currentIndex: nil
            )
        )
        XCTAssertEqual(
            CategoryChapterNavigationPolicy.neighborIndices(
                categoryCount: 1,
                currentIndex: 0
            ),
            CategoryChapterNeighborIndices(previous: nil, next: nil)
        )
        XCTAssertEqual(
            CategoryChapterNavigationPolicy.neighborIndices(
                categoryCount: 3,
                currentIndex: 0
            ),
            CategoryChapterNeighborIndices(previous: nil, next: 1)
        )
        XCTAssertEqual(
            CategoryChapterNavigationPolicy.neighborIndices(
                categoryCount: 3,
                currentIndex: 1
            ),
            CategoryChapterNeighborIndices(previous: 0, next: 2)
        )
        XCTAssertEqual(
            CategoryChapterNavigationPolicy.neighborIndices(
                categoryCount: 3,
                currentIndex: 2
            ),
            CategoryChapterNeighborIndices(previous: 1, next: nil)
        )
        XCTAssertNil(
            CategoryChapterNavigationPolicy.neighborIndices(
                categoryCount: 3,
                currentIndex: 3
            )
        )
    }

    func testCategoryTopPresentationKeepsDisplayNames() {
        XCTAssertEqual(
            CategoryTopPresentationPolicy.displayName(name: "ライブ", templateKey: "live"),
            "LIVE"
        )
        XCTAssertEqual(
            CategoryTopPresentationPolicy.displayName(name: "", templateKey: "custom"),
            "ジャンル"
        )
        XCTAssertEqual(
            CategoryTopPresentationPolicy.displayName(name: "観劇", templateKey: "theater"),
            "観劇"
        )
    }

    func testCategoryTopPresentationKeepsVisitedMapScope() {
        for templateKey in ["museum", "live", "outing_facility", "theme_park", "nature_living"] {
            XCTAssertTrue(
                CategoryTopPresentationPolicy.supportsVisitedPlacesMap(templateKey: templateKey),
                templateKey
            )
        }
        for templateKey in ["theater", "movie", "book", "goshuin", "custom"] {
            XCTAssertFalse(
                CategoryTopPresentationPolicy.supportsVisitedPlacesMap(templateKey: templateKey),
                templateKey
            )
        }
    }

    func testCategoryTopPresentationKeepsAtmosphericStyles() {
        for templateKey in ["theater", "live"] {
            XCTAssertTrue(
                CategoryTopPresentationPolicy.usesAtmosphericDarkStyle(templateKey: templateKey),
                templateKey
            )
            XCTAssertNotNil(
                CategoryTopPresentationPolicy.brandGradient(templateKey: templateKey),
                templateKey
            )
            XCTAssertNotNil(
                CategoryTopPresentationPolicy.headerForeground(templateKey: templateKey),
                templateKey
            )
        }

        XCTAssertFalse(CategoryTopPresentationPolicy.usesAtmosphericDarkStyle(templateKey: "movie"))
        XCTAssertNil(CategoryTopPresentationPolicy.brandGradient(templateKey: "movie"))
        XCTAssertNil(CategoryTopPresentationPolicy.headerForeground(templateKey: "movie"))
    }

    func testCategoryTopPresentationKeepsBackgroundStyles() {
        XCTAssertEqual(CategoryTopPresentationPolicy.backgroundStyle(templateKey: "theater"), .theater)
        XCTAssertEqual(CategoryTopPresentationPolicy.backgroundStyle(templateKey: "live"), .live)

        for templateKey in ["movie", "museum", "book", "goshuin", "custom"] {
            XCTAssertEqual(
                CategoryTopPresentationPolicy.backgroundStyle(templateKey: templateKey),
                .themed,
                templateKey
            )
        }
    }

    func testForwardPlanningGenresKeepCombinedHeroAvailableButUseMemoryLayout() {
        for templateKey in ["movie", "museum", "theme_park", "nature_living"] {
            XCTAssertTrue(CategoryPlanningHeroPolicy.supports(templateKey), templateKey)
            XCTAssertFalse(CategoryPlanningHeroPolicy.usesIntegratedHero(templateKey), templateKey)
            XCTAssertTrue(CategoryMemoryHeroPolicy.supports(templateKey), templateKey)
        }
    }

    func testSpecializedAndAfterTheFactGenresDoNotUseCombinedHero() {
        for templateKey in ["theater", "live", "book", "goshuin", "sake", "random_goods", "outing_facility"] {
            XCTAssertFalse(CategoryPlanningHeroPolicy.supports(templateKey), templateKey)
        }
    }

    func testLiveActionableTicketStagesStayInTicketManagement() {
        for statusKey in ["beforeApply", "onSaleSoon", "waitingResult", "won", "waitingPayment", "waitingIssue"] {
            XCTAssertTrue(LiveTicketPlacementPolicy.showsInTicketManagement(statusKey: statusKey), statusKey)
        }
    }

    func testLiveComingUpAllowsNoTicketOrCompletedTicketFlow() {
        XCTAssertTrue(LiveTicketPlacementPolicy.allowsComingUp(statusKeys: []))
        XCTAssertTrue(LiveTicketPlacementPolicy.allowsComingUp(statusKeys: ["issued"]))
        XCTAssertTrue(LiveTicketPlacementPolicy.allowsComingUp(statusKeys: ["lost", "skipped"]))
        XCTAssertFalse(LiveTicketPlacementPolicy.allowsComingUp(statusKeys: ["waitingPayment"]))
        XCTAssertFalse(LiveTicketPlacementPolicy.allowsComingUp(statusKeys: ["issued", "waitingIssue"]))
    }

    func testTheaterAndLiveInformationUseParentEventCards() {
        for templateKey in ["theater", "live"] {
            XCTAssertTrue(
                CategoryEventInformationPolicy.usesParentEventCard(
                    templateKey: templateKey,
                    sectionKey: "productions"
                ),
                templateKey
            )
        }
    }

    func testPlanningAndHistorySectionsDoNotUseParentEventCards() {
        for sectionKey in ["interests", "coming-up", "history"] {
            XCTAssertFalse(
                CategoryEventInformationPolicy.usesParentEventCard(
                    templateKey: "live",
                    sectionKey: sectionKey
                ),
                sectionKey
            )
        }
    }

    func testTheaterAndLiveUseFullTicketManagementPlanCards() {
        XCTAssertTrue(PerformanceTicketManagementPolicy.usesFullPlanCard(templateKey: "theater"))
        XCTAssertTrue(PerformanceTicketManagementPolicy.usesFullPlanCard(templateKey: "live"))
        XCTAssertFalse(PerformanceTicketManagementPolicy.usesFullPlanCard(templateKey: "movie"))
    }

    func testCategoryTopVocabularyKeepsRegistrationAndSectionNames() {
        XCTAssertEqual(
            CategoryTopVocabulary.interestRegistrationTitle(templateKey: "movie"),
            "観たい作品を追加"
        )
        XCTAssertEqual(
            CategoryTopVocabulary.interestAddActionTitle(templateKey: "theater"),
            "公演を追加"
        )
        XCTAssertEqual(
            CategoryTopVocabulary.librarySectionTitle(templateKey: "book", fallback: "対象"),
            "Library"
        )
        XCTAssertEqual(
            CategoryTopVocabulary.featureCarouselJapaneseTitle(templateKey: "museum"),
            "観覧予定 / 気になる"
        )
        XCTAssertEqual(
            CategoryTopVocabulary.sectionJapaneseTitle(
                englishTitle: "Ticket Management",
                templateKey: "theater"
            ),
            "チケット管理"
        )
    }

    func testCategoryTopVocabularyKeepsUnknownFallbacks() {
        XCTAssertEqual(
            CategoryTopVocabulary.interestRegistrationTitle(templateKey: "custom"),
            "気になる対象を追加"
        )
        XCTAssertEqual(
            CategoryTopVocabulary.interestAddActionTitle(templateKey: "custom"),
            "追加する"
        )
        XCTAssertEqual(
            CategoryTopVocabulary.librarySectionTitle(templateKey: "custom", fallback: "体験"),
            "体験"
        )
        XCTAssertNil(
            CategoryTopVocabulary.sectionJapaneseTitle(
                englishTitle: "Unknown",
                templateKey: "custom"
            )
        )
    }

    func testCategoryTopLibraryPolicyKeepsFacilityScopeAndPageSizes() {
        for templateKey in ["theme_park", "nature_living", "outing_facility"] {
            XCTAssertTrue(CategoryTopLibraryPolicy.isPlaceExperience(templateKey: templateKey))
        }
        for templateKey in ["theater", "live", "movie", "museum", "book", "goshuin"] {
            XCTAssertFalse(CategoryTopLibraryPolicy.isPlaceExperience(templateKey: templateKey))
        }

        XCTAssertEqual(CategoryTopLibraryPolicy.pageSize(for: .gallery), 6)
        XCTAssertEqual(CategoryTopLibraryPolicy.pageSize(for: .compact), 6)
        XCTAssertEqual(CategoryTopLibraryPolicy.pageSize(for: .banner), 4)
        XCTAssertEqual(
            CategoryTopLibraryPolicy.summaryMessage(eventCount: 0, visitCount: 0),
            "登録した対象をここへまとめ、体験を重ねていけます。"
        )
        XCTAssertEqual(
            CategoryTopLibraryPolicy.summaryMessage(eventCount: 3, visitCount: 7),
            "3件の対象と、7件の体験をまとめています。"
        )
    }

    func testCategoryTopLibraryPolicyNormalizesSupportedLayouts() {
        for templateKey in ["theme_park", "nature_living", "outing_facility"] {
            XCTAssertEqual(
                CategoryTopLibraryPolicy.normalizedLayout(.gallery, templateKey: templateKey),
                .compact,
                templateKey
            )
            XCTAssertEqual(
                CategoryTopLibraryPolicy.normalizedLayout(.banner, templateKey: templateKey),
                .banner,
                templateKey
            )
        }

        XCTAssertEqual(CategoryTopLibraryPolicy.normalizedLayout(.compact, templateKey: "movie"), .gallery)
        XCTAssertEqual(CategoryTopLibraryPolicy.normalizedLayout(.banner, templateKey: "movie"), .banner)
        XCTAssertEqual(CategoryTopLibraryPolicy.normalizedLayout(.gallery, templateKey: "live"), .banner)
        XCTAssertEqual(CategoryTopLibraryPolicy.normalizedLayout(.compact, templateKey: "book"), .compact)
        XCTAssertEqual(CategoryTopLibraryPolicy.normalizedLayout(.gallery, templateKey: "theater"), .gallery)
    }

    func testCategoryTopLibraryPolicyKeepsFacilityStorageAndDisplayKeys() {
        XCTAssertEqual(
            CategoryTopLibraryPolicy.facilityStorageKey(templateKey: "museum"),
            "museum.facilities"
        )
        XCTAssertEqual(
            CategoryTopLibraryPolicy.facilityStorageKey(templateKey: "theme_park"),
            "theme_park"
        )
        XCTAssertEqual(CategoryTopLibraryPolicy.normalizedFacilityLayout(.gallery), .compact)
        XCTAssertEqual(CategoryTopLibraryPolicy.normalizedFacilityLayout(.banner), .banner)

        let categoryID = UUID(uuidString: "3FBFCB97-DC33-42B4-BCCF-0C79F874A654")!
        XCTAssertEqual(
            CategoryTopLibraryPolicy.displayKey(
                categoryID: categoryID,
                sectionKey: "interests",
                layout: .gallery
            ),
            "3FBFCB97-DC33-42B4-BCCF-0C79F874A654-interests-gallery"
        )
    }
}
