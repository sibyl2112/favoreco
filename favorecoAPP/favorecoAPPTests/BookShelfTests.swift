import SwiftData
import XCTest
@testable import favoreco

@MainActor
final class BookShelfTests: XCTestCase {
    private var retainedContainer: ModelContainer?

    override func tearDown() {
        retainedContainer = nil
        super.tearDown()
    }

    func testOneBookCanBelongToMultipleShelvesAndShelfDeletionPreservesBookAndVisit() throws {
        let context = try makeContext()
        let category = RecordCategory(name: "書籍", templateKey: "book")
        let book = ExperienceEvent(title: "森を読む", category: category)
        let visit = Visit(
            visitedAt: Date(timeIntervalSince1970: 1_700_000_000),
            endedAt: Date(timeIntervalSince1970: 1_700_003_600),
            event: book
        )
        let favorites = BookShelf(name: "お気に入り", sortOrder: 0)
        let research = BookShelf(name: "仕事の参考", sortOrder: 1)
        favorites.books = [book]
        research.books = [book]

        context.insert(category)
        context.insert(book)
        context.insert(visit)
        context.insert(favorites)
        context.insert(research)
        try context.save()

        XCTAssertEqual(Set(book.bookShelves?.map(\.id) ?? []), Set([favorites.id, research.id]))

        context.delete(favorites)
        try context.save()

        let books = try context.fetch(FetchDescriptor<ExperienceEvent>())
        let visits = try context.fetch(FetchDescriptor<Visit>())
        let shelves = try context.fetch(FetchDescriptor<BookShelf>())
        XCTAssertEqual(books.map(\.id), [book.id])
        XCTAssertEqual(visits.map(\.id), [visit.id])
        XCTAssertEqual(shelves.map(\.id), [research.id])
        XCTAssertEqual(shelves.first?.books?.map(\.id), [book.id])
        XCTAssertEqual(books.first?.bookShelves?.map(\.id), [research.id])
    }

    func testBookShelfNamesFollowManualShelfOrderAndIgnoreBlankNames() throws {
        let context = try makeContext()
        let book = ExperienceEvent(title: "青い装丁の詩集")
        let laterShelf = BookShelf(name: "  詩集  ", sortOrder: 2)
        let firstShelf = BookShelf(name: "青い本", sortOrder: 0)
        let blankShelf = BookShelf(name: "   ", sortOrder: 1)
        laterShelf.books = [book]
        firstShelf.books = [book]
        blankShelf.books = [book]

        context.insert(book)
        context.insert(laterShelf)
        context.insert(firstShelf)
        context.insert(blankShelf)
        try context.save()

        XCTAssertEqual(book.sortedBookShelfNames, ["青い本", "詩集"])
    }

    func testQuickRegistrationStatesMapToBookShelfStorage() {
        XCTAssertEqual(QuickBookRegistrationState.interested.eventStateKey, "interested")
        XCTAssertEqual(QuickBookRegistrationState.active.eventStateKey, "active")
        XCTAssertEqual(QuickBookRegistrationState.completed.eventStateKey, "active")
        XCTAssertFalse(QuickBookRegistrationState.interested.createsCompletedReadingRecord)
        XCTAssertFalse(QuickBookRegistrationState.active.createsCompletedReadingRecord)
        XCTAssertTrue(QuickBookRegistrationState.completed.createsCompletedReadingRecord)
    }

    func testShelfBooksUseTheSameReadingStatusAsBookTop() {
        let interested = ExperienceEvent(title: "気になる本", stateKey: "interested")
        let toRead = ExperienceEvent(title: "積読本", stateKey: "active")
        let reading = ExperienceEvent(title: "読書中の本", stateKey: "active")
        let read = ExperienceEvent(title: "読了本", stateKey: "active")

        let readingVisit = Visit(
            visitedAt: Date(timeIntervalSince1970: 1_700_000_000),
            unitFieldsRaw: VisitUnitFields(bookReadingHasEndDate: false).encodedRawValue,
            event: reading
        )
        let readVisit = Visit(
            visitedAt: Date(timeIntervalSince1970: 1_700_000_000),
            unitFieldsRaw: VisitUnitFields(bookReadingHasEndDate: true).encodedRawValue,
            event: read
        )
        reading.visits = [readingVisit]
        read.visits = [readVisit]

        XCTAssertEqual(bookStatus(for: interested), .interested)
        XCTAssertEqual(bookStatus(for: toRead), .toRead)
        XCTAssertEqual(bookStatus(for: reading), .reading)
        XCTAssertEqual(bookStatus(for: read), .read)
    }

    func testShelfDestinationUsesLatestMatchingReadingRecord() {
        let interested = ExperienceEvent(title: "気になる本", stateKey: "interested")
        let toRead = ExperienceEvent(title: "積読本", stateKey: "active")
        let reading = ExperienceEvent(title: "読書中の本", stateKey: "active")
        let read = ExperienceEvent(title: "読了本", stateKey: "active")

        let completedEarlier = Visit(
            visitedAt: Date(timeIntervalSince1970: 1_700_000_000),
            endedAt: Date(timeIntervalSince1970: 1_700_000_100),
            unitFieldsRaw: VisitUnitFields(bookReadingHasEndDate: true).encodedRawValue,
            event: reading
        )
        let currentReading = Visit(
            visitedAt: Date(timeIntervalSince1970: 1_700_001_000),
            unitFieldsRaw: VisitUnitFields(bookReadingHasEndDate: false).encodedRawValue,
            event: reading
        )
        reading.visits = [completedEarlier, currentReading]

        let completedOlder = Visit(
            visitedAt: Date(timeIntervalSince1970: 1_700_002_000),
            endedAt: Date(timeIntervalSince1970: 1_700_002_100),
            unitFieldsRaw: VisitUnitFields(bookReadingHasEndDate: true).encodedRawValue,
            event: read
        )
        let completedLatest = Visit(
            visitedAt: Date(timeIntervalSince1970: 1_700_003_000),
            endedAt: Date(timeIntervalSince1970: 1_700_003_100),
            unitFieldsRaw: VisitUnitFields(bookReadingHasEndDate: true).encodedRawValue,
            event: read
        )
        read.visits = [completedOlder, completedLatest]

        XCTAssertNil(bookReadingRecordToOpen(for: interested))
        XCTAssertNil(bookReadingRecordToOpen(for: toRead))
        XCTAssertEqual(bookReadingRecordToOpen(for: reading)?.id, currentReading.id)
        XCTAssertEqual(bookReadingRecordToOpen(for: read)?.id, completedLatest.id)
    }

    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(
            schema: FavorecoModelContainerBootstrap.schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: FavorecoModelContainerBootstrap.schema,
            configurations: [configuration]
        )
        retainedContainer = container
        return container.mainContext
    }
}
