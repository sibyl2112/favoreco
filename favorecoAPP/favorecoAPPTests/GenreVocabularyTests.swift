import XCTest
@testable import favoreco

final class GenreVocabularyTests: XCTestCase {
    func testTheaterVocabularyUsesViewingTerms() {
        XCTAssertEqual(GenreVocabulary.targetNoun(for: "theater"), "公演")
        XCTAssertEqual(GenreVocabulary.actionNoun(for: "theater"), "観劇")
        XCTAssertEqual(GenreVocabulary.recordNoun(for: "theater"), "観劇記録")
        XCTAssertEqual(GenreVocabulary.plannedStatus(for: "theater"), "観劇予定")
        XCTAssertEqual(GenreVocabulary.completedStatus(for: "theater"), "観劇済み")
        XCTAssertEqual(GenreVocabulary.undatedSchedule(for: "theater"), "観劇日未定")
    }

    func testLiveVocabularyUsesAttendanceTerms() {
        XCTAssertEqual(GenreVocabulary.targetNoun(for: "live"), "ライブ")
        XCTAssertEqual(GenreVocabulary.actionNoun(for: "live"), "参戦")
        XCTAssertEqual(GenreVocabulary.recordNoun(for: "live"), "参戦記録")
        XCTAssertEqual(GenreVocabulary.plannedStatus(for: "live"), "参戦予定")
        XCTAssertEqual(GenreVocabulary.completedStatus(for: "live"), "参戦済み")
        XCTAssertEqual(GenreVocabulary.undatedSchedule(for: "live"), "参戦日未定")
    }

    func testScreenAndBookVocabularyDoNotReusePerformanceTerms() {
        XCTAssertEqual(GenreVocabulary.recordNoun(for: "movie"), "鑑賞記録")
        XCTAssertEqual(GenreVocabulary.completedStatus(for: "movie"), "鑑賞済み")
        XCTAssertEqual(GenreVocabulary.recordNoun(for: "book"), "読書記録")
        XCTAssertEqual(GenreVocabulary.completedStatus(for: "book"), "読了")
    }

    func testUnknownGenreFallsBackToNeutralExperienceTerms() {
        XCTAssertEqual(GenreVocabulary.targetNoun(for: "custom"), "体験")
        XCTAssertEqual(GenreVocabulary.recordNoun(for: "custom"), "体験記録")
        XCTAssertEqual(GenreVocabulary.completedStatus(for: "custom"), "体験済み")
        XCTAssertEqual(GenreVocabulary.undatedSchedule(for: "custom"), "参加日未定")
    }
}
