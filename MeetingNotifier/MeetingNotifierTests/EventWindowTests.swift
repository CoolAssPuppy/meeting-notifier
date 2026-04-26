//
//  EventWindowTests.swift
//  MeetingNotifierTests
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import XCTest
@testable import MeetingNotifier

final class EventWindowTests: XCTestCase {

    // MARK: - Window selection

    func testBefore5pm_excludesTomorrow() {
        let now = makeDate(year: 2026, month: 4, day: 26, hour: 14, minute: 30)
        let window = EventWindow.current(now: now)

        XCTAssertFalse(window.includesTomorrow)
        XCTAssertEqual(window.start, now)

        // End is 23:59:59 today, not tomorrow.
        let cal = Calendar.current
        let expectedEnd = cal.date(bySettingHour: 23, minute: 59, second: 59, of: now)
        XCTAssertEqual(window.end, expectedEnd)
    }

    func testAfter5pm_includesTomorrow() {
        let now = makeDate(year: 2026, month: 4, day: 26, hour: 17, minute: 30)
        let window = EventWindow.current(now: now)

        XCTAssertTrue(window.includesTomorrow)

        // End is 23:59:59 tomorrow.
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now))!
        let expectedEnd = cal.date(bySettingHour: 23, minute: 59, second: 59, of: tomorrow)
        XCTAssertEqual(window.end, expectedEnd)
    }

    func testExactly5pm_includesTomorrow() {
        // The cutoff is "hour >= 17", so 17:00 sharp flips it on.
        let now = makeDate(year: 2026, month: 4, day: 26, hour: 17, minute: 0)
        let window = EventWindow.current(now: now)
        XCTAssertTrue(window.includesTomorrow)
    }

    // MARK: - Filter

    func testFilter_includesCurrentlyHappening() {
        let now = makeDate(year: 2026, month: 4, day: 26, hour: 10, minute: 0)
        let event = makeEvent(start: now.addingTimeInterval(-300), end: now.addingTimeInterval(900))

        let window = EventWindow.current(now: now)
        let filtered = window.filter([event], now: now)
        XCTAssertEqual(filtered.count, 1)
    }

    func testFilter_includesEventsLaterToday() {
        let now = makeDate(year: 2026, month: 4, day: 26, hour: 10, minute: 0)
        let later = makeDate(year: 2026, month: 4, day: 26, hour: 15, minute: 0)
        let event = makeEvent(start: later, end: later.addingTimeInterval(1800))

        let window = EventWindow.current(now: now)
        XCTAssertEqual(window.filter([event], now: now).count, 1)
    }

    func testFilter_excludesTomorrowEventBefore5pm() {
        let now = makeDate(year: 2026, month: 4, day: 26, hour: 10, minute: 0)
        let tomorrow = makeDate(year: 2026, month: 4, day: 27, hour: 10, minute: 0)
        let event = makeEvent(start: tomorrow, end: tomorrow.addingTimeInterval(1800))

        let window = EventWindow.current(now: now)
        XCTAssertEqual(window.filter([event], now: now).count, 0)
    }

    func testFilter_includesTomorrowEventAfter5pm() {
        let now = makeDate(year: 2026, month: 4, day: 26, hour: 18, minute: 0)
        let tomorrow = makeDate(year: 2026, month: 4, day: 27, hour: 10, minute: 0)
        let event = makeEvent(start: tomorrow, end: tomorrow.addingTimeInterval(1800))

        let window = EventWindow.current(now: now)
        XCTAssertEqual(window.filter([event], now: now).count, 1)
    }

    func testFilter_excludesEventsTwoDaysOut() {
        let now = makeDate(year: 2026, month: 4, day: 26, hour: 18, minute: 0)
        let dayAfter = makeDate(year: 2026, month: 4, day: 28, hour: 10, minute: 0)
        let event = makeEvent(start: dayAfter, end: dayAfter.addingTimeInterval(1800))

        let window = EventWindow.current(now: now)
        XCTAssertEqual(window.filter([event], now: now).count, 0)
    }

    // MARK: - Helpers

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        let cal = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return cal.date(from: components)!
    }

    private func makeEvent(start: Date, end: Date) -> CalendarEvent {
        CalendarEvent(
            id: "test-\(start.timeIntervalSince1970)",
            title: "Test event",
            startDate: start,
            endDate: end,
            location: nil,
            description: nil,
            conferenceLink: nil,
            calendarId: "primary",
            calendarName: "Test",
            calendarColorHex: "#000000",
            provider: .google
        )
    }
}
