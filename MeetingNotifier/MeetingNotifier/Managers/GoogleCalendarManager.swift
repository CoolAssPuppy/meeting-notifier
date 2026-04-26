import Foundation
import os

@MainActor
class GoogleCalendarManager {
    static let shared = GoogleCalendarManager()

    private init() {}

    func fetchCalendarList(forAccount account: CalendarAccount) async throws -> [CalendarInfo] {
        let url = URL.required("https://www.googleapis.com/calendar/v3/users/me/calendarList")
        let response: GoogleCalendarListResponse = try await CalendarManagerSupport.fetchAuthorizedJSON(
            url: url,
            account: account,
            decode: GoogleCalendarListResponse.self,
            operation: "fetch calendar list"
        )

        return (response.items ?? []).map { item in
            let colorHex: String
            if let backgroundColor = item.backgroundColor {
                colorHex = backgroundColor
            } else {
                colorHex = googleColorIdToHex(item.colorId ?? "1")
            }

            return CalendarInfo(
                id: item.id,
                name: item.summary,
                colorHex: colorHex,
                provider: .google,
                accountEmail: account.email,
                isPrimary: item.primary ?? false
            )
        }
    }

    func fetchEvents(
        forCalendar calendarId: String,
        calendarInfo: CalendarInfo,
        account: CalendarAccount,
        startDate: Date,
        endDate: Date
    ) async throws -> [CalendarEvent] {
        let dateFormatter = ISO8601DateFormatter()
        let timeMin = dateFormatter.string(from: startDate)
        let timeMax = dateFormatter.string(from: endDate)

        let encodedCalendarId = calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarId
        guard var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/\(encodedCalendarId)/events") else {
            throw CalendarError.apiError("Invalid calendar ID")
        }

        components.queryItems = [
            URLQueryItem(name: "timeMin", value: timeMin),
            URLQueryItem(name: "timeMax", value: timeMax),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime")
        ]

        guard let url = components.url else {
            throw CalendarError.apiError("Failed to construct URL")
        }

        let response: GoogleEventsResponse = try await CalendarManagerSupport.fetchAuthorizedJSON(
            url: url,
            account: account,
            decode: GoogleEventsResponse.self,
            operation: "fetch events"
        )

        return (response.items ?? []).compactMap { event in
            parseGoogleEvent(event, calendarId: calendarId, calendarInfo: calendarInfo)
        }
    }

    private func parseGoogleEvent(
        _ event: GoogleCalendarEvent,
        calendarId: String,
        calendarInfo: CalendarInfo
    ) -> CalendarEvent? {
        guard let summary = event.summary,
              let start = event.start,
              let end = event.end else {
            return nil
        }

        let startDateString = start.dateTime ?? start.date ?? ""
        let endDateString = end.dateTime ?? end.date ?? ""

        let dateFormatter = ISO8601DateFormatter()
        guard let startDate = dateFormatter.date(from: startDateString),
              let endDate = dateFormatter.date(from: endDateString) else {
            return nil
        }

        let conferenceLink = extractConferenceLink(
            entryPoints: event.conferenceData?.entryPoints,
            description: event.description,
            location: event.location
        )

        let reminders = parseReminders(event.reminders)

        let attendees = event.attendees ?? []
        let attendeeNames = attendees.compactMap { attendee -> String? in
            if let name = attendee.displayName, !name.isEmpty { return name }
            return attendee.email
        }

        return CalendarEvent(
            id: event.id,
            title: summary,
            startDate: startDate,
            endDate: endDate,
            location: event.location,
            description: event.description,
            conferenceLink: conferenceLink,
            calendarId: calendarId,
            calendarName: calendarInfo.name,
            calendarColorHex: calendarInfo.colorHex,
            provider: .google,
            reminders: reminders,
            attendeeCount: attendees.count,
            attendeeNames: attendeeNames,
            accountEmail: calendarInfo.accountEmail
        )
    }

    private func extractConferenceLink(
        entryPoints: [GoogleEntryPoint]?,
        description: String?,
        location: String?
    ) -> String? {
        if let entryPoints {
            for entryPoint in entryPoints {
                if let uri = entryPoint.uri, MeetingLinkParser.isValidMeetingLink(uri) {
                    return uri
                }
            }
        }

        if let description, let link = MeetingLinkParser.findMeetingLink(in: description) {
            return link
        }

        if let location, let link = MeetingLinkParser.findMeetingLink(in: location) {
            return link
        }

        return nil
    }

    private func parseReminders(_ reminders: GoogleReminders?) -> [EventReminder] {
        guard let reminders else { return [] }

        if reminders.useDefault == true {
            return [EventReminder(minutesBefore: 10)]
        }

        guard let overrides = reminders.overrides else { return [] }

        return overrides.compactMap { override in
            guard override.method == "popup", let minutes = override.minutes else { return nil }
            return EventReminder(minutesBefore: minutes)
        }
    }

    private func googleColorIdToHex(_ colorId: String) -> String {
        let colors = [
            "1": "#AC725E", "2": "#D06B64", "3": "#F83A22", "4": "#FA573C",
            "5": "#FF6B6B", "6": "#FFC107", "7": "#FFA000", "8": "#E4C441",
            "9": "#16A765", "10": "#43B581", "11": "#0B8043", "12": "#16A765"
        ]
        return colors[colorId] ?? "#4285F4"
    }
}
