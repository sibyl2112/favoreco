import XCTest
@testable import favoreco

final class ScreenWorkMetadataTests: XCTestCase {
    private let response = Data(#"{"results":[{"id":1,"media_type":"movie","title":"テスト映画","original_title":"Test Movie","release_date":"2026-01-02","overview":"映画の説明","poster_path":"/movie.jpg","genre_ids":[18]},{"id":2,"media_type":"tv","name":"テストドラマ","original_name":"Test Drama","first_air_date":"2025-10-01","overview":"ドラマの説明","poster_path":"/drama.jpg","genre_ids":[18]},{"id":3,"media_type":"tv","name":"テストアニメ","original_name":"Test Anime","first_air_date":"2024-04-01","overview":"アニメの説明","poster_path":"/anime.jpg","genre_ids":[16,10759]},{"id":4,"media_type":"movie","title":"アニメ映画","original_title":"Anime Film","release_date":"2023-08-01","overview":"アニメ映画の説明","poster_path":"/anime-film.jpg","genre_ids":[16]}]}"#.utf8)

    func testLegacyEmptySubtypeRemainsMovie() {
        XCTAssertEqual(ScreenWorkType.resolved(from: ""), .movie)
    }

    func testSeasonRoundTripAcceptsOnlyOneThroughTen() {
        let encoded = VisitUnitFields(screenWorkSeasonNumber: 7).encodedRawValue
        XCTAssertEqual(VisitUnitFields(rawValue: encoded).screenWorkSeasonNumber, 7)
        XCTAssertEqual(VisitUnitFields(screenWorkSeasonNumber: 11).screenWorkSeasonNumber, 0)
        XCTAssertEqual(VisitUnitFields(screenWorkSeasonNumber: -1).screenWorkSeasonNumber, 0)
    }

    func testFiltersIncludeOnlySelectedWorkType() {
        XCTAssertTrue(ScreenWorkFilter.all.includes(.anime))
        XCTAssertTrue(ScreenWorkFilter.drama.includes(.drama))
        XCTAssertFalse(ScreenWorkFilter.drama.includes(.movie))
    }

    @MainActor
    func testExistingWorkCanBeReclassifiedFromVisitForm() {
        let event = ExperienceEvent(title: "分類前")

        event.applyScreenWorkClassification(typeKey: ScreenWorkType.anime.rawValue, seasonNumber: 10)

        XCTAssertEqual(event.screenWorkType, .anime)
        XCTAssertEqual(event.screenWorkSeasonNumber, 10)
        XCTAssertTrue(ScreenWorkFilter.anime.includes(event.screenWorkType))

        event.applyScreenWorkClassification(typeKey: ScreenWorkType.movie.rawValue, seasonNumber: 10)
        XCTAssertEqual(event.screenWorkType, .movie)
        XCTAssertEqual(event.screenWorkSeasonNumber, 0)
    }

    func testMovieSearchKeepsNonAnimationMovies() throws {
        let candidates = try ScreenWorkMetadataLookupService.candidates(from: response, requestedType: .movie)
        XCTAssertEqual(candidates.map(\.title), ["テスト映画"])
        XCTAssertEqual(candidates.first?.yearText, "2026")
    }

    func testDramaSearchKeepsNonAnimationTV() throws {
        let candidates = try ScreenWorkMetadataLookupService.candidates(from: response, requestedType: .drama)
        XCTAssertEqual(candidates.map(\.title), ["テストドラマ"])
        XCTAssertEqual(candidates.first?.type, .drama)
    }

    func testAnimeSearchIncludesTVAndMoviesWithAnimationGenre() throws {
        let candidates = try ScreenWorkMetadataLookupService.candidates(from: response, requestedType: .anime)
        XCTAssertEqual(candidates.map(\.title), ["テストアニメ", "アニメ映画"])
        XCTAssertTrue(candidates.allSatisfy { $0.type == .anime })
    }

    func testScreenWorkMetadataRoundTrip() {
        let rawValue = VisitUnitFields(
            screenWorkSeasonNumber: 2,
            screenWorkOriginalTitle: "Original Work",
            screenWorkReleaseDate: "2026-04-03",
            screenWorkOverview: "Overview",
            screenWorkTMDBID: 12345,
            screenWorkTMDBMediaType: "tv"
        ).encodedRawValue
        let restored = VisitUnitFields(rawValue: rawValue)

        XCTAssertEqual(restored.screenWorkSeasonNumber, 2)
        XCTAssertEqual(restored.screenWorkOriginalTitle, "Original Work")
        XCTAssertEqual(restored.screenWorkReleaseDate, "2026-04-03")
        XCTAssertEqual(restored.screenWorkOverview, "Overview")
        XCTAssertEqual(restored.screenWorkTMDBID, 12345)
        XCTAssertEqual(restored.screenWorkTMDBMediaType, "tv")
    }

    func testLegacyScreenWorkMetadataDefaultsRemainEmpty() {
        let restored = VisitUnitFields(rawValue: #"{"screenWorkSeasonNumber":1}"#)
        XCTAssertTrue(restored.screenWorkOriginalTitle.isEmpty)
        XCTAssertTrue(restored.screenWorkReleaseDate.isEmpty)
        XCTAssertTrue(restored.screenWorkOverview.isEmpty)
        XCTAssertEqual(restored.screenWorkTMDBID, 0)
        XCTAssertTrue(restored.screenWorkTMDBMediaType.isEmpty)
    }
}
