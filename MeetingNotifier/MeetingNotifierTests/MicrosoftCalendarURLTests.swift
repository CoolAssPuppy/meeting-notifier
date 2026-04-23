//
//  MicrosoftCalendarURLTests.swift
//  MeetingNotifierTests
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import XCTest
@testable import MeetingNotifier

/// Regression tests for audit finding #7 — Microsoft Graph calendarId paths
/// were being interpolated without percent-encoding, which both broke
/// requests for IDs containing reserved characters and risked path-shape
/// manipulation.
final class MicrosoftCalendarURLTests: XCTestCase {

    func testPlainCalendarIdProducesWellFormedURL() throws {
        let components = try MicrosoftCalendarManager.makeEventsURLComponents(calendarId: "AAMkAB123==")
        XCTAssertNotNil(components)
        XCTAssertEqual(components?.host, "graph.microsoft.com")
        XCTAssertTrue(components?.percentEncodedPath.hasSuffix("/calendars/AAMkAB123==/events") ?? false)
    }

    func testCalendarIdWithSlashIsPercentEncoded() throws {
        // A raw `/` in the calendarId previously split the path segment,
        // turning `/me/calendars/id-with/slash/events` into a wrong URL.
        let components = try MicrosoftCalendarManager.makeEventsURLComponents(calendarId: "foo/bar")
        XCTAssertNotNil(components)
        XCTAssertEqual(components?.percentEncodedPath, "/v1.0/me/calendars/foo%2Fbar/events")
    }

    func testCalendarIdWithSpaceIsPercentEncoded() throws {
        let components = try MicrosoftCalendarManager.makeEventsURLComponents(calendarId: "with space")
        XCTAssertNotNil(components)
        XCTAssertTrue(components?.percentEncodedPath.contains("with%20space") ?? false)
    }

    func testCalendarIdWithPlusIsPreservedAndEqualsSignsSurvive() throws {
        // Base64 IDs legitimately contain `+` and `=`; both belong to
        // `.urlPathAllowed` and do not need to be escaped.
        let components = try MicrosoftCalendarManager.makeEventsURLComponents(calendarId: "a+b=")
        XCTAssertNotNil(components)
        XCTAssertTrue(components?.percentEncodedPath.contains("a+b=") ?? false,
                      "unreserved subset of .urlPathAllowed should stay as-is")
    }
}
