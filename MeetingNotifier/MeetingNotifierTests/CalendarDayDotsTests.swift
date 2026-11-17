//
//  CalendarDayDotsTests.swift
//  MeetingNotifierTests
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//
//  Failure list, written before the code:
//   1. A day with no events gets no dots.
//   2. An event on a calendar that is not selected gets no dot.
//   3. Two selected calendars with events get two dots, in selection order.
//   4. Several events on one calendar on one day still give one dot.
//   5. A past day's dots are muted.
//   6. A future day's dots are not muted.
//   7. Today, a calendar whose events have all ended is muted.
//   8. Today, one ended and one upcoming event on a calendar: not muted.
//   9. Today, an event in progress: not muted.
//  10. An event ending exactly now counts as ended.
//  11. An event that crosses midnight shows on both days.
//  12. An event ending exactly at midnight does not spill into the next day.
//  13. An all-day event (midnight to midnight) shows on its day only.
//  14. The same calendar id under two accounts is two calendars.
//  15. A zero-length event at the start of a day counts for that day.
//  16. Day boundaries follow the supplied calendar's time zone.
//  17. The dot uses the selected calendar's color, not the event's copy.
//

import XCTest
@testable import MeetingNotifier

final class CalendarDayDotsTests: XCTestCase {

    private let utc: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    // MARK: - Factories

    private func date(_ day: Int, _ hour: Int = 0, _ minute: Int = 0, in cal: Calendar? = nil) -> Date {
        let cal = cal ?? utc
        return cal.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    private func calendar(id: String = "work", email: String = "a@example.com", color: String = "#FF0000") -> CalendarInfo {
        CalendarInfo(id: id, name: id, colorHex: color, provider: .google, accountEmail: email)
    }

    private func event(calendar: CalendarInfo, start: Date, end: Date, color: String? = nil) -> CalendarEvent {
        CalendarEvent(
            id: UUID().uuidString,
            title: "Event",
            startDate: start,
            endDate: end,
            calendarId: calendar.id,
            calendarName: calendar.name,
            calendarColorHex: color ?? calendar.colorHex,
            provider: calendar.provider,
            accountEmail: calendar.accountEmail
        )
    }

    private func dots(day: Date, events: [CalendarEvent], calendars: [CalendarInfo],
                      now: Date, cal: Calendar? = nil) -> [CalendarDayDot] {
        CalendarDayDots.dots(for: day, events: events, calendars: calendars, now: now, calendar: cal ?? utc)
    }

    // MARK: - Cases

    func testEmptyDay_noDots() {                                         // 1
        let work = calendar()
        XCTAssertEqual(dots(day: date(20), events: [], calendars: [work], now: date(17, 12)), [])
    }

    func testUnselectedCalendar_noDot() {                                // 2
        let work = calendar(id: "work")
        let home = calendar(id: "home")
        let e = event(calendar: home, start: date(20, 9), end: date(20, 10))
        XCTAssertEqual(dots(day: date(20), events: [e], calendars: [work], now: date(17, 12)), [])
    }

    func testTwoCalendars_twoDotsInSelectionOrder() {                    // 3
        let work = calendar(id: "work", color: "#FF0000")
        let home = calendar(id: "home", color: "#00FF00")
        let events = [event(calendar: work, start: date(20, 9), end: date(20, 10)),
                      event(calendar: home, start: date(20, 8), end: date(20, 9))]
        let result = dots(day: date(20), events: events, calendars: [home, work], now: date(17, 12))
        XCTAssertEqual(result.map(\.colorHex), ["#00FF00", "#FF0000"])
    }

    func testManyEventsOneCalendar_oneDot() {                            // 4
        let work = calendar()
        let events = [event(calendar: work, start: date(20, 9), end: date(20, 10)),
                      event(calendar: work, start: date(20, 11), end: date(20, 12)),
                      event(calendar: work, start: date(20, 14), end: date(20, 15))]
        XCTAssertEqual(dots(day: date(20), events: events, calendars: [work], now: date(17, 12)).count, 1)
    }

    func testPastDay_muted() {                                           // 5
        let work = calendar()
        let e = event(calendar: work, start: date(10, 9), end: date(10, 10))
        XCTAssertEqual(dots(day: date(10), events: [e], calendars: [work], now: date(17, 12)).map(\.isMuted), [true])
    }

    func testFutureDay_notMuted() {                                      // 6
        let work = calendar()
        let e = event(calendar: work, start: date(20, 9), end: date(20, 10))
        XCTAssertEqual(dots(day: date(20), events: [e], calendars: [work], now: date(17, 12)).map(\.isMuted), [false])
    }

    func testToday_allEnded_muted() {                                    // 7
        let work = calendar()
        let events = [event(calendar: work, start: date(17, 8), end: date(17, 9)),
                      event(calendar: work, start: date(17, 10), end: date(17, 11))]
        XCTAssertEqual(dots(day: date(17), events: events, calendars: [work], now: date(17, 12)).map(\.isMuted), [true])
    }

    func testToday_oneEndedOneUpcoming_notMuted() {                      // 8
        let work = calendar()
        let events = [event(calendar: work, start: date(17, 8), end: date(17, 9)),
                      event(calendar: work, start: date(17, 15), end: date(17, 16))]
        XCTAssertEqual(dots(day: date(17), events: events, calendars: [work], now: date(17, 12)).map(\.isMuted), [false])
    }

    func testToday_inProgress_notMuted() {                               // 9
        let work = calendar()
        let e = event(calendar: work, start: date(17, 11), end: date(17, 13))
        XCTAssertEqual(dots(day: date(17), events: [e], calendars: [work], now: date(17, 12)).map(\.isMuted), [false])
    }

    func testToday_endingExactlyNow_muted() {                            // 10
        let work = calendar()
        let e = event(calendar: work, start: date(17, 11), end: date(17, 12))
        XCTAssertEqual(dots(day: date(17), events: [e], calendars: [work], now: date(17, 12)).map(\.isMuted), [true])
    }

    func testOvernightEvent_showsOnBothDays() {                          // 11
        let work = calendar()
        let e = event(calendar: work, start: date(20, 22), end: date(21, 2))
        XCTAssertEqual(dots(day: date(20), events: [e], calendars: [work], now: date(17, 12)).count, 1)
        XCTAssertEqual(dots(day: date(21), events: [e], calendars: [work], now: date(17, 12)).count, 1)
    }

    func testEndingAtMidnight_doesNotSpill() {                           // 12
        let work = calendar()
        let e = event(calendar: work, start: date(20, 23), end: date(21, 0))
        XCTAssertEqual(dots(day: date(21), events: [e], calendars: [work], now: date(17, 12)), [])
    }

    func testAllDayEvent_onlyItsDay() {                                  // 13
        let work = calendar()
        let e = event(calendar: work, start: date(20), end: date(21))
        XCTAssertEqual(dots(day: date(20), events: [e], calendars: [work], now: date(17, 12)).count, 1)
        XCTAssertEqual(dots(day: date(19), events: [e], calendars: [work], now: date(17, 12)), [])
        XCTAssertEqual(dots(day: date(21), events: [e], calendars: [work], now: date(17, 12)), [])
    }

    func testSameCalendarIdTwoAccounts_distinct() {                      // 14
        let a = calendar(id: "primary", email: "a@example.com", color: "#FF0000")
        let b = calendar(id: "primary", email: "b@example.com", color: "#0000FF")
        let e = event(calendar: b, start: date(20, 9), end: date(20, 10))
        XCTAssertEqual(dots(day: date(20), events: [e], calendars: [a], now: date(17, 12)), [])
        XCTAssertEqual(dots(day: date(20), events: [e], calendars: [a, b], now: date(17, 12)).map(\.colorHex), ["#0000FF"])
    }

    func testZeroLengthAtDayStart_counts() {                             // 15
        let work = calendar()
        let e = event(calendar: work, start: date(20), end: date(20))
        XCTAssertEqual(dots(day: date(20), events: [e], calendars: [work], now: date(17, 12)).count, 1)
        XCTAssertEqual(dots(day: date(19), events: [e], calendars: [work], now: date(17, 12)), [])
    }

    func testDayBoundariesFollowTimeZone() {                             // 16
        var lisbonPlus = Calendar(identifier: .gregorian)
        lisbonPlus.timeZone = TimeZone(secondsFromGMT: 5 * 3600)!
        let work = calendar()
        // 21:00 UTC on the 20th is 02:00 on the 21st at UTC+5.
        let e = event(calendar: work, start: date(20, 21), end: date(20, 22))
        let day21 = date(21, in: lisbonPlus)
        let day20 = date(20, in: lisbonPlus)
        XCTAssertEqual(dots(day: day21, events: [e], calendars: [work], now: date(17, 12), cal: lisbonPlus).count, 1)
        XCTAssertEqual(dots(day: day20, events: [e], calendars: [work], now: date(17, 12), cal: lisbonPlus), [])
    }

    func testUsesSelectedCalendarColor() {                               // 17
        let work = calendar(color: "#123456")
        let e = event(calendar: work, start: date(20, 9), end: date(20, 10), color: "#ABCDEF")
        XCTAssertEqual(dots(day: date(20), events: [e], calendars: [work], now: date(17, 12)).map(\.colorHex), ["#123456"])
    }
}
