import Foundation
import os

@MainActor
class MicrosoftCalendarManager {
    static let shared = MicrosoftCalendarManager()

    private init() {}

    func fetchCalendarList(forAccount account: CalendarAccount) async throws -> [CalendarInfo] {
        let url = URL.required("https://graph.microsoft.com/v1.0/me/calendars")
        let response: MicrosoftCalendarListResponse = try await CalendarManagerSupport.fetchAuthorizedJSON(
            url: url,
            account: account,
            decode: MicrosoftCalendarListResponse.self,
            operation: "fetch calendar list"
        )

        return (response.value ?? []).map { item in
            CalendarInfo(
                id: item.id,
                name: item.name,
                colorHex: microsoftColorToHex(item.color ?? "auto"),
                provider: .microsoft,
                accountEmail: account.email,
                isPrimary: item.isDefaultCalendar ?? false
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
        let startString = dateFormatter.string(from: startDate)
        let endString = dateFormatter.string(from: endDate)

        guard var components = try Self.makeEventsURLComponents(calendarId: calendarId) else {
            throw CalendarError.apiError("Invalid calendar ID")
        }

        components.queryItems = [
            URLQueryItem(name: "$filter", value: "start/dateTime ge '\(startString)' and end/dateTime le '\(endString)'"),
            URLQueryItem(name: "$orderby", value: "start/dateTime"),
            URLQueryItem(name: "$select", value: "id,subject,start,end,location,bodyPreview,onlineMeeting,isReminderOn,reminderMinutesBeforeStart,attendees")
        ]

        guard let url = components.url else {
            throw CalendarError.apiError("Failed to construct URL")
        }

        let response: MicrosoftEventsResponse = try await CalendarManagerSupport.fetchAuthorizedJSON(
            url: url,
            account: account,
            decode: MicrosoftEventsResponse.self,
            operation: "fetch events"
        )

        return (response.value ?? []).compactMap { event in
            parseMicrosoftEvent(event, calendarId: calendarId, calendarInfo: calendarInfo)
        }
    }

    private func parseMicrosoftEvent(
        _ event: MicrosoftCalendarEvent,
        calendarId: String,
        calendarInfo: CalendarInfo
    ) -> CalendarEvent? {
        guard let subject = event.subject,
              let start = event.start,
              let end = event.end else {
            return nil
        }

        let startDateString = start.dateTime ?? ""
        let endDateString = end.dateTime ?? ""

        let dateFormatter = ISO8601DateFormatter()
        guard let startDate = dateFormatter.date(from: startDateString),
              let endDate = dateFormatter.date(from: endDateString) else {
            return nil
        }

        let location = event.location?.displayName

        let conferenceLink = extractConferenceLink(
            joinUrl: event.onlineMeeting?.joinUrl,
            bodyPreview: event.bodyPreview,
            location: location
        )

        let reminders = parseReminders(
            isReminderOn: event.isReminderOn,
            minutes: event.reminderMinutesBeforeStart
        )

        let attendees = event.attendees ?? []
        let attendeeNames = attendees.compactMap { attendee -> String? in
            if let name = attendee.emailAddress?.name, !name.isEmpty { return name }
            return attendee.emailAddress?.address
        }

        return CalendarEvent(
            id: event.id,
            title: subject,
            startDate: startDate,
            endDate: endDate,
            location: location,
            description: event.bodyPreview,
            conferenceLink: conferenceLink,
            calendarId: calendarId,
            calendarName: calendarInfo.name,
            calendarColorHex: calendarInfo.colorHex,
            provider: .microsoft,
            reminders: reminders,
            attendeeCount: attendees.count,
            attendeeNames: attendeeNames,
            accountEmail: calendarInfo.accountEmail
        )
    }

    private func extractConferenceLink(
        joinUrl: String?,
        bodyPreview: String?,
        location: String?
    ) -> String? {
        if let joinUrl, MeetingLinkParser.isValidMeetingLink(joinUrl) {
            return joinUrl
        }

        if let bodyPreview, let link = MeetingLinkParser.findMeetingLink(in: bodyPreview) {
            return link
        }

        if let location, let link = MeetingLinkParser.findMeetingLink(in: location) {
            return link
        }

        return nil
    }

    private func parseReminders(isReminderOn: Bool?, minutes: Int?) -> [EventReminder] {
        guard isReminderOn == true, let minutes else { return [] }
        return [EventReminder(minutesBefore: minutes)]
    }

    private func microsoftColorToHex(_ color: String) -> String {
        let colors = [
            "lightBlue": "#0078D4",
            "lightGreen": "#16A765",
            "lightOrange": "#FF8C00",
            "lightGray": "#808080",
            "lightYellow": "#FFD700",
            "lightTeal": "#20B2AA",
            "lightPink": "#FFB6C1",
            "lightBrown": "#8B4513",
            "lightRed": "#FF6B6B",
            "maxColor": "#4B0082",
            "auto": "#0078D4"
        ]
        return colors[color] ?? "#0078D4"
    }

    /// Percent-encodes `calendarId` and composes the Graph events-collection URL.
    /// Returns `nil` if the URL string can't be formed. `nonisolated` because it's
    /// purely a string-manipulation helper.
    ///
    /// Note: `.urlPathAllowed` on its own is *not* safe for a single path
    /// segment — it permits `/`, which means a calendarId containing a slash
    /// would split the URL path and reach the wrong resource on Graph. We
    /// remove `/` from the allowed set so it is percent-encoded along with the
    /// other non-segment characters.
    nonisolated static func makeEventsURLComponents(calendarId: String) throws -> URLComponents? {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove("/")
        guard let encoded = calendarId.addingPercentEncoding(withAllowedCharacters: allowed) else {
            throw CalendarError.apiError("Invalid calendar ID")
        }
        return URLComponents(string: "https://graph.microsoft.com/v1.0/me/calendars/\(encoded)/events")
    }
}
