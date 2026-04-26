//
//  AutoOfferDeciderTests.swift
//  MeetingNotifierTests
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import XCTest
@testable import MeetingNotifier

final class AutoOfferDeciderTests: XCTestCase {

    // MARK: - Guard matrix

    func testDecide_skipsWhenStateIsNotIdle() {
        let result = AutoOfferDecider.decide(
            state: .recording,
            suppressAutoStart: false,
            notetakerEnabled: true,
            autoOfferEnabled: true,
            isMicActive: true,
            candidates: [],
            doubleBookingPreference: .fewerAttendees
        )
        XCTAssertEqual(result, .skip)
    }

    func testDecide_skipsWhenSuppressed() {
        let result = AutoOfferDecider.decide(
            state: .idle,
            suppressAutoStart: true,
            notetakerEnabled: true,
            autoOfferEnabled: true,
            isMicActive: true,
            candidates: [],
            doubleBookingPreference: .fewerAttendees
        )
        XCTAssertEqual(result, .skip)
    }

    func testDecide_skipsWhenNotetakerDisabled() {
        let result = AutoOfferDecider.decide(
            state: .idle,
            suppressAutoStart: false,
            notetakerEnabled: false,
            autoOfferEnabled: true,
            isMicActive: true,
            candidates: [],
            doubleBookingPreference: .fewerAttendees
        )
        XCTAssertEqual(result, .skip)
    }

    func testDecide_skipsWhenAutoOfferDisabled() {
        let result = AutoOfferDecider.decide(
            state: .idle,
            suppressAutoStart: false,
            notetakerEnabled: true,
            autoOfferEnabled: false,
            isMicActive: true,
            candidates: [],
            doubleBookingPreference: .fewerAttendees
        )
        XCTAssertEqual(result, .skip)
    }

    func testDecide_skipsWhenMicNotActive() {
        let result = AutoOfferDecider.decide(
            state: .idle,
            suppressAutoStart: false,
            notetakerEnabled: true,
            autoOfferEnabled: true,
            isMicActive: false,
            candidates: [],
            doubleBookingPreference: .fewerAttendees
        )
        XCTAssertEqual(result, .skip)
    }

    func testDecide_startsWithNilMeetingWhenNoCalendarMatch() {
        let result = AutoOfferDecider.decide(
            state: .idle,
            suppressAutoStart: false,
            notetakerEnabled: true,
            autoOfferEnabled: true,
            isMicActive: true,
            candidates: [],
            doubleBookingPreference: .fewerAttendees
        )
        XCTAssertEqual(result, .start(nil))
    }

    func testDecide_startsWithMeetingWhenSingleCandidateActive() {
        let now = Date()
        let event = makeEvent(id: "a", start: now.addingTimeInterval(-60), end: now.addingTimeInterval(1800))
        let result = AutoOfferDecider.decide(
            state: .idle,
            suppressAutoStart: false,
            notetakerEnabled: true,
            autoOfferEnabled: true,
            isMicActive: true,
            candidates: [event],
            doubleBookingPreference: .fewerAttendees,
            now: now
        )
        XCTAssertEqual(result, .start(event))
    }

    // MARK: - selectMeeting window

    func testSelectMeeting_includesEventStartingWithinFiveMinutes() {
        let now = Date()
        let event = makeEvent(id: "a", start: now.addingTimeInterval(240), end: now.addingTimeInterval(1800))
        let picked = AutoOfferDecider.selectMeeting(
            from: [event], now: now, preference: .fewerAttendees
        )
        XCTAssertEqual(picked, event)
    }

    func testSelectMeeting_excludesEventStartingAfterFiveMinutes() {
        let now = Date()
        let event = makeEvent(id: "a", start: now.addingTimeInterval(360), end: now.addingTimeInterval(1800))
        let picked = AutoOfferDecider.selectMeeting(
            from: [event], now: now, preference: .fewerAttendees
        )
        XCTAssertNil(picked)
    }

    func testSelectMeeting_excludesEventThatAlreadyEnded() {
        let now = Date()
        let event = makeEvent(id: "a", start: now.addingTimeInterval(-3600), end: now.addingTimeInterval(-60))
        let picked = AutoOfferDecider.selectMeeting(
            from: [event], now: now, preference: .fewerAttendees
        )
        XCTAssertNil(picked)
    }

    // MARK: - Double-booking tie-breakers

    func testSelectMeeting_doubleBookedFewerAttendees_picksSmallerMeeting() {
        let now = Date()
        let small = makeEvent(id: "small", start: now, end: now.addingTimeInterval(1800), attendeeCount: 3)
        let large = makeEvent(id: "large", start: now, end: now.addingTimeInterval(1800), attendeeCount: 12)
        let picked = AutoOfferDecider.selectMeeting(
            from: [large, small], now: now, preference: .fewerAttendees
        )
        XCTAssertEqual(picked, small)
    }

    func testSelectMeeting_doubleBookedMoreAttendees_picksLargerMeeting() {
        let now = Date()
        let small = makeEvent(id: "small", start: now, end: now.addingTimeInterval(1800), attendeeCount: 3)
        let large = makeEvent(id: "large", start: now, end: now.addingTimeInterval(1800), attendeeCount: 12)
        let picked = AutoOfferDecider.selectMeeting(
            from: [small, large], now: now, preference: .moreAttendees
        )
        XCTAssertEqual(picked, large)
    }

    func testSelectMeeting_doubleBookedSameSize_returnsAStableChoice() {
        let now = Date()
        let a = makeEvent(id: "a", start: now, end: now.addingTimeInterval(1800), attendeeCount: 5)
        let b = makeEvent(id: "b", start: now, end: now.addingTimeInterval(1800), attendeeCount: 5)
        let picked = AutoOfferDecider.selectMeeting(
            from: [a, b], now: now, preference: .fewerAttendees
        )
        XCTAssertNotNil(picked)
    }

    // MARK: - Helpers

    private func makeEvent(
        id: String,
        start: Date,
        end: Date,
        attendeeCount: Int = 0
    ) -> CalendarEvent {
        CalendarEvent(
            id: id,
            title: "Event \(id)",
            startDate: start,
            endDate: end,
            location: nil,
            description: nil,
            conferenceLink: nil,
            calendarId: "primary",
            calendarName: "Test",
            calendarColorHex: "#000000",
            provider: .google,
            attendeeCount: attendeeCount
        )
    }
}
