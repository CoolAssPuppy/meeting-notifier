import Foundation
import os

@MainActor
class MicrosoftCalendarManager {
    static let shared = MicrosoftCalendarManager()

    private init() {}

    func fetchCalendarList(forAccount account: CalendarAccount, retryCount: Int = 0) async throws -> [CalendarInfo] {
        let accessToken = try await CalendarManagerSupport.getValidToken(forAccount: account)

        let url = URL(string: "https://graph.microsoft.com/v1.0/me/calendars")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CalendarError.apiError("Invalid response")
        }

        // Handle 401 Unauthorized - token expired
        if httpResponse.statusCode == 401 && retryCount == 0 {
            Logger.auth.warning("Access token expired for \(account.email, privacy: .private), refreshing...")
            // Clear cached token to force refresh
            _ = KeychainManager.shared.deleteAccessToken(forAccount: account.email)

            // Retry once with refreshed token
            return try await fetchCalendarList(forAccount: account, retryCount: 1)
        }

        guard httpResponse.statusCode == 200 else {
            // Mark account as having auth issues if retry also failed
            if httpResponse.statusCode == 401 {
                CalendarManagerSupport.markAccountAuthFailed(account, status: .expired)
            }
            throw CalendarError.apiError("Failed to fetch calendar list (HTTP \(httpResponse.statusCode))")
        }

        // Success - mark account as valid
        CalendarManagerSupport.markAccountAuthValid(account)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = json["value"] as? [[String: Any]] else {
            throw CalendarError.parseError("Invalid calendar list response")
        }

        return value.compactMap { item in
            guard let id = item["id"] as? String,
                  let name = item["name"] as? String else {
                return nil
            }

            let color = item["color"] as? String ?? "auto"
            let colorHex = microsoftColorToHex(color)
            let isDefaultCalendar = item["isDefaultCalendar"] as? Bool ?? false

            return CalendarInfo(
                id: id,
                name: name,
                colorHex: colorHex,
                provider: .microsoft,
                accountEmail: account.email,
                isPrimary: isDefaultCalendar
            )
        }
    }

    func fetchEvents(
        forCalendar calendarId: String,
        calendarInfo: CalendarInfo,
        account: CalendarAccount,
        startDate: Date,
        endDate: Date,
        retryCount: Int = 0
    ) async throws -> [CalendarEvent] {
        let accessToken = try await CalendarManagerSupport.getValidToken(forAccount: account)

        let dateFormatter = ISO8601DateFormatter()
        let startString = dateFormatter.string(from: startDate)
        let endString = dateFormatter.string(from: endDate)

        guard let encodedCalendarId = calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw CalendarError.apiError("Invalid calendar ID")
        }
        guard var components = URLComponents(string: "https://graph.microsoft.com/v1.0/me/calendars/\(encodedCalendarId)/events") else {
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

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CalendarError.apiError("Invalid response")
        }

        // Handle 401 Unauthorized - token expired
        if httpResponse.statusCode == 401 && retryCount == 0 {
            Logger.auth.warning("Access token expired for \(account.email, privacy: .private), refreshing...")
            // Clear cached token to force refresh
            _ = KeychainManager.shared.deleteAccessToken(forAccount: account.email)

            // Retry once with refreshed token
            return try await fetchEvents(
                forCalendar: calendarId,
                calendarInfo: calendarInfo,
                account: account,
                startDate: startDate,
                endDate: endDate,
                retryCount: 1
            )
        }

        guard httpResponse.statusCode == 200 else {
            // Mark account as having auth issues if retry also failed
            if httpResponse.statusCode == 401 {
                CalendarManagerSupport.markAccountAuthFailed(account, status: .expired)
            }
            throw CalendarError.apiError("Failed to fetch events (HTTP \(httpResponse.statusCode))")
        }

        // Success - mark account as valid
        CalendarManagerSupport.markAccountAuthValid(account)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = json["value"] as? [[String: Any]] else {
            return []
        }

        // Use the calendarInfo passed in (which includes custom colors)
        return value.compactMap { item in
            parseMicrosoftEvent(item, calendarId: calendarId, calendarInfo: calendarInfo)
        }
    }

    private func parseMicrosoftEvent(
        _ item: [String: Any],
        calendarId: String,
        calendarInfo: CalendarInfo
    ) -> CalendarEvent? {
        guard let eventId = item["id"] as? String,
              let subject = item["subject"] as? String,
              let start = item["start"] as? [String: Any],
              let end = item["end"] as? [String: Any] else {
            return nil
        }

        let startDateString = start["dateTime"] as? String ?? ""
        let endDateString = end["dateTime"] as? String ?? ""

        let dateFormatter = ISO8601DateFormatter()
        guard let startDate = dateFormatter.date(from: startDateString),
              let endDate = dateFormatter.date(from: endDateString) else {
            return nil
        }

        let locationDict = item["location"] as? [String: Any]
        let location = locationDict?["displayName"] as? String

        let bodyPreview = item["bodyPreview"] as? String

        let conferenceLink = extractConferenceLink(from: item, bodyPreview: bodyPreview, location: location)

        let reminders = parseReminders(from: item)

        let attendees = item["attendees"] as? [[String: Any]] ?? []
        let attendeeCount = attendees.count

        return CalendarEvent(
            id: eventId,
            title: subject,
            startDate: startDate,
            endDate: endDate,
            location: location,
            description: bodyPreview,
            conferenceLink: conferenceLink,
            calendarId: calendarId,
            calendarName: calendarInfo.name,
            calendarColorHex: calendarInfo.colorHex,
            provider: .microsoft,
            reminders: reminders,
            attendeeCount: attendeeCount,
            accountEmail: calendarInfo.accountEmail
        )
    }

    private func extractConferenceLink(
        from item: [String: Any],
        bodyPreview: String?,
        location: String?
    ) -> String? {
        if let onlineMeeting = item["onlineMeeting"] as? [String: Any],
           let joinUrl = onlineMeeting["joinUrl"] as? String,
           MeetingLinkParser.isValidMeetingLink(joinUrl) {
            return joinUrl
        }

        if let bodyPreview = bodyPreview,
           let link = MeetingLinkParser.findMeetingLink(in: bodyPreview) {
            return link
        }

        if let location = location,
           let link = MeetingLinkParser.findMeetingLink(in: location) {
            return link
        }

        return nil
    }

    private func parseReminders(from item: [String: Any]) -> [EventReminder] {
        guard let isReminderOn = item["isReminderOn"] as? Bool, isReminderOn,
              let minutesBefore = item["reminderMinutesBeforeStart"] as? Int else {
            return []
        }

        return [EventReminder(minutesBefore: minutesBefore)]
    }

    private func getCalendarInfo(calendarId: String, account: CalendarAccount) async throws -> CalendarInfo {
        let calendars = try await fetchCalendarList(forAccount: account)
        guard let calendar = calendars.first(where: { $0.id == calendarId }) else {
            return CalendarInfo(
                id: calendarId,
                name: "Calendar",
                colorHex: "#0078D4",
                provider: .microsoft,
                accountEmail: account.email
            )
        }
        return calendar
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

}
