//
//  CalendarEventTests.swift
//  MeetingNotifierTests
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import XCTest
@testable import MeetingNotifier

final class CalendarEventTests: XCTestCase {

    // MARK: - hasPhysicalLocation

    func testHasPhysicalLocation_emptyOrNil_returnsFalse() {
        XCTAssertFalse(makeEvent(location: nil).hasPhysicalLocation)
        XCTAssertFalse(makeEvent(location: "").hasPhysicalLocation)
        XCTAssertFalse(makeEvent(location: "   ").hasPhysicalLocation)
    }

    func testHasPhysicalLocation_commaPattern_returnsTrue() {
        // The classic English address-with-city form.
        XCTAssertTrue(makeEvent(location: "1 Apple Park Way, Cupertino").hasPhysicalLocation)
    }

    func testHasPhysicalLocation_acceptsNonEnglishAddresses() {
        // Pre-refactor, these failed because the old heuristic only matched
        // English street types ("street", "avenue", "road", etc.). They all
        // have either a comma or a digit (street number / postcode), so the
        // new rule accepts them.
        XCTAssertTrue(makeEvent(location: "Hauptstraße 12, Berlin").hasPhysicalLocation)
        XCTAssertTrue(makeEvent(location: "Calle de Alcalá 3, Madrid").hasPhysicalLocation)
        XCTAssertTrue(makeEvent(location: "梅田駅 1-1").hasPhysicalLocation)
    }

    func testHasPhysicalLocation_rejectsNonAddressRoomNames() {
        // A bare room name with no comma and no digits should still be
        // treated as not-a-physical-address. (MapKit would fail to geocode
        // it anyway, but the heuristic short-circuits before the network
        // call.)
        XCTAssertFalse(makeEvent(location: "Kitchen").hasPhysicalLocation)
    }

    func testHasPhysicalLocation_acceptsRoomWithNumber() {
        // "Conference Room 4" has a digit, so we accept it. MapKit will fail
        // to geocode and we'll skip the travel-time call gracefully.
        XCTAssertTrue(makeEvent(location: "Conference Room 4").hasPhysicalLocation)
    }

    // MARK: - formattedTime is locale-aware

    func testFormattedTime_usesLocaleAwareShortStyle() {
        let event = makeEvent(location: nil)
        // We can't pin the result because tests run in the user's locale, but
        // we can confirm the formatter ran — the result is non-empty and
        // doesn't contain the literal pattern characters.
        XCTAssertFalse(event.formattedTime.isEmpty)
        XCTAssertFalse(event.formattedTime.contains("h:"))
        XCTAssertFalse(event.formattedTime.contains("mm"))
    }

    // MARK: - Helpers

    private func makeEvent(location: String?) -> CalendarEvent {
        CalendarEvent(
            id: "test",
            title: "Test",
            startDate: Date(),
            endDate: Date().addingTimeInterval(1800),
            location: location,
            description: nil,
            conferenceLink: nil,
            calendarId: "primary",
            calendarName: "Test",
            calendarColorHex: "#000000",
            provider: .google
        )
    }
}
