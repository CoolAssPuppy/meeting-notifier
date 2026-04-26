//
//  CalendarAPIResponses.swift
//  MeetingNotifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//
//  Codable response shapes for Google Calendar API and Microsoft Graph
//  Calendar API. We previously walked `[String: Any]` dictionaries; that
//  silently swallowed type drift and made schema changes invisible until a
//  user reported "no events showing". Now we throw on shape mismatch and
//  the error reaches the UI.
//

import Foundation

// MARK: - Google

struct GoogleCalendarListResponse: Decodable {
    let items: [GoogleCalendarListItem]?
}

struct GoogleCalendarListItem: Decodable {
    let id: String
    let summary: String
    let backgroundColor: String?
    let colorId: String?
    let primary: Bool?
}

struct GoogleEventsResponse: Decodable {
    let items: [GoogleCalendarEvent]?
}

struct GoogleCalendarEvent: Decodable {
    let id: String
    let summary: String?
    let description: String?
    let location: String?
    let start: GoogleEventTimeRef?
    let end: GoogleEventTimeRef?
    let conferenceData: GoogleConferenceData?
    let reminders: GoogleReminders?
    let attendees: [GoogleAttendee]?
}

struct GoogleEventTimeRef: Decodable {
    let dateTime: String?
    let date: String?
}

struct GoogleConferenceData: Decodable {
    let entryPoints: [GoogleEntryPoint]?
}

struct GoogleEntryPoint: Decodable {
    let uri: String?
}

struct GoogleReminders: Decodable {
    let useDefault: Bool?
    let overrides: [GoogleReminderOverride]?
}

struct GoogleReminderOverride: Decodable {
    let method: String?
    let minutes: Int?
}

struct GoogleAttendee: Decodable {
    let email: String?
    let displayName: String?
}

// MARK: - Microsoft

struct MicrosoftCalendarListResponse: Decodable {
    let value: [MicrosoftCalendarListItem]?
}

struct MicrosoftCalendarListItem: Decodable {
    let id: String
    let name: String
    let color: String?
    let isDefaultCalendar: Bool?
}

struct MicrosoftEventsResponse: Decodable {
    let value: [MicrosoftCalendarEvent]?
}

struct MicrosoftCalendarEvent: Decodable {
    let id: String
    let subject: String?
    let bodyPreview: String?
    let start: MicrosoftEventTimeRef?
    let end: MicrosoftEventTimeRef?
    let location: MicrosoftLocation?
    let onlineMeeting: MicrosoftOnlineMeeting?
    let isReminderOn: Bool?
    let reminderMinutesBeforeStart: Int?
    let attendees: [MicrosoftAttendee]?
}

struct MicrosoftEventTimeRef: Decodable {
    let dateTime: String?
}

struct MicrosoftLocation: Decodable {
    let displayName: String?
}

struct MicrosoftOnlineMeeting: Decodable {
    let joinUrl: String?
}

struct MicrosoftAttendee: Decodable {
    let emailAddress: MicrosoftEmailAddress?
}

struct MicrosoftEmailAddress: Decodable {
    let address: String?
    let name: String?
}
