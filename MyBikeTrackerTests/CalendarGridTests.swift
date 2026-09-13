import XCTest
@testable import MyBikeTracker

final class CalendarGridTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testMonthSequenceCrossesYearBoundary() {
        let months = CalendarMonth.sequence(
            from: CalendarMonth(year: 2025, month: 11),
            through: CalendarMonth(year: 2026, month: 2)
        )
        XCTAssertEqual(months, [
            CalendarMonth(year: 2025, month: 11),
            CalendarMonth(year: 2025, month: 12),
            CalendarMonth(year: 2026, month: 1),
            CalendarMonth(year: 2026, month: 2)
        ])
    }

    func testAddingMonthsWalksBackward() {
        XCTAssertEqual(
            CalendarMonth(year: 2026, month: 1).adding(months: -1),
            CalendarMonth(year: 2025, month: 12)
        )
    }

    func testSeptember2026GridStartsOnTuesdayWithMondayFirstWeekday() throws {
        let september = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))
        )
        let days = CalendarGrid.days(for: september, calendar: calendar, minimumRows: 6)

        XCTAssertEqual(days.count, 42)
        XCTAssertFalse(days[0].isInDisplayedMonth)
        XCTAssertEqual(calendar.component(.day, from: days[1].date), 1)
        XCTAssertTrue(days[1].isInDisplayedMonth)
        XCTAssertEqual(calendar.component(.day, from: days[30].date), 30)
        XCTAssertTrue(days[30].isInDisplayedMonth)
    }
}
