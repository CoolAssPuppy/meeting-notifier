//
//  CalendarAPIResponsesTests.swift
//  MeetingNotifierTests
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//
//  These tests pin the Codable shapes we expect from each provider against
//  realistic JSON snippets. Pre-refactor, the calendar managers walked
//  `[String: Any]` and silently returned `[]` on shape mismatch — so a
//  field rename in either provider's API would have meant "no events" with
//  no log of why. These tests catch that class of break in CI.
//

import XCTest
@testable import MeetingNotifier

final class CalendarAPIResponsesTests: XCTestCase {

    // MARK: - Google

    func testDecodeGoogleCalendarList() throws {
        let json = """
        {
          "items": [
            {
              "id": "primary",
              "summary": "Work",
              "backgroundColor": "#4285F4",
              "primary": true
            },
            {
              "id": "team@x.com",
              "summary": "Team",
              "colorId": "5"
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(GoogleCalendarListResponse.self, from: json)
        XCTAssertEqual(response.items?.count, 2)
        XCTAssertEqual(response.items?[0].id, "primary")
        XCTAssertEqual(response.items?[0].backgroundColor, "#4285F4")
        XCTAssertEqual(response.items?[0].primary, true)
        XCTAssertEqual(response.items?[1].colorId, "5")
        XCTAssertNil(response.items?[1].backgroundColor)
    }

    func testDecodeGoogleEventsResponse() throws {
        let json = """
        {
          "items": [
            {
              "id": "evt1",
              "summary": "Standup",
              "start": { "dateTime": "2026-04-26T09:00:00-07:00" },
              "end":   { "dateTime": "2026-04-26T09:30:00-07:00" },
              "conferenceData": {
                "entryPoints": [{ "uri": "https://meet.google.com/abc-defg-hij" }]
              },
              "reminders": { "useDefault": true },
              "attendees": [
                { "email": "alice@x.com", "displayName": "Alice" },
                { "email": "bob@x.com" }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(GoogleEventsResponse.self, from: json)
        let event = response.items?.first
        XCTAssertEqual(event?.summary, "Standup")
        XCTAssertEqual(event?.conferenceData?.entryPoints?.first?.uri,
                       "https://meet.google.com/abc-defg-hij")
        XCTAssertEqual(event?.reminders?.useDefault, true)
        XCTAssertEqual(event?.attendees?.count, 2)
        XCTAssertEqual(event?.attendees?[0].displayName, "Alice")
    }

    func testDecodeGoogleAllDayEvent() throws {
        // All-day events use `date` instead of `dateTime`.
        let json = """
        {
          "items": [
            {
              "id": "allday",
              "summary": "Holiday",
              "start": { "date": "2026-04-26" },
              "end":   { "date": "2026-04-27" }
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(GoogleEventsResponse.self, from: json)
        XCTAssertEqual(response.items?.first?.start?.date, "2026-04-26")
        XCTAssertNil(response.items?.first?.start?.dateTime)
    }

    func testDecodeGoogleEmptyResponse() throws {
        // Both Google and Microsoft can return empty bodies — must decode cleanly.
        let json = "{}".data(using: .utf8)!
        let response = try JSONDecoder().decode(GoogleEventsResponse.self, from: json)
        XCTAssertNil(response.items)
    }

    // MARK: - Microsoft

    func testDecodeMicrosoftCalendarList() throws {
        let json = """
        {
          "value": [
            {
              "id": "AAA==",
              "name": "Calendar",
              "color": "auto",
              "isDefaultCalendar": true
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(MicrosoftCalendarListResponse.self, from: json)
        XCTAssertEqual(response.value?.first?.id, "AAA==")
        XCTAssertEqual(response.value?.first?.name, "Calendar")
        XCTAssertEqual(response.value?.first?.isDefaultCalendar, true)
    }

    func testDecodeMicrosoftEventsResponse() throws {
        let json = """
        {
          "value": [
            {
              "id": "AQMkA",
              "subject": "Sync",
              "start": { "dateTime": "2026-04-26T16:00:00.0000000" },
              "end":   { "dateTime": "2026-04-26T16:30:00.0000000" },
              "location": { "displayName": "Conference Room 4" },
              "bodyPreview": "Click https://teams.microsoft.com/l/abc to join",
              "onlineMeeting": { "joinUrl": "https://teams.microsoft.com/l/abc" },
              "isReminderOn": true,
              "reminderMinutesBeforeStart": 15,
              "attendees": [
                { "emailAddress": { "address": "alice@x.com", "name": "Alice" } }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(MicrosoftEventsResponse.self, from: json)
        let event = response.value?.first
        XCTAssertEqual(event?.subject, "Sync")
        XCTAssertEqual(event?.location?.displayName, "Conference Room 4")
        XCTAssertEqual(event?.onlineMeeting?.joinUrl, "https://teams.microsoft.com/l/abc")
        XCTAssertEqual(event?.reminderMinutesBeforeStart, 15)
        XCTAssertEqual(event?.attendees?.first?.emailAddress?.name, "Alice")
    }

    func testDecodeMicrosoftEventWithoutOnlineMeeting() throws {
        // In-person meetings have no `onlineMeeting`. Must still decode.
        let json = """
        {
          "value": [
            {
              "id": "AQMkB",
              "subject": "In-person",
              "start": { "dateTime": "2026-04-26T16:00:00.0000000" },
              "end":   { "dateTime": "2026-04-26T16:30:00.0000000" },
              "location": { "displayName": "" },
              "bodyPreview": ""
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(MicrosoftEventsResponse.self, from: json)
        XCTAssertNil(response.value?.first?.onlineMeeting)
    }
}
