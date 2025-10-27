import Foundation

@MainActor
class MicrosoftCalendarManager {
    static let shared = MicrosoftCalendarManager()

    private init() {}

    func fetchCalendarList(forAccount account: CalendarAccount) async throws -> [CalendarInfo] {
        let accessToken = try await getValidToken(forAccount: account)

        let url = URL(string: "https://graph.microsoft.com/v1.0/me/calendars")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw CalendarError.apiError("Failed to fetch calendar list")
        }

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
        account: CalendarAccount,
        startDate: Date,
        endDate: Date
    ) async throws -> [CalendarEvent] {
        let accessToken = try await getValidToken(forAccount: account)

        let dateFormatter = ISO8601DateFormatter()
        let startString = dateFormatter.string(from: startDate)
        let endString = dateFormatter.string(from: endDate)

        var components = URLComponents(string: "https://graph.microsoft.com/v1.0/me/calendars/\(calendarId)/events")!
        components.queryItems = [
            URLQueryItem(name: "$filter", value: "start/dateTime ge '\(startString)' and end/dateTime le '\(endString)'"),
            URLQueryItem(name: "$orderby", value: "start/dateTime"),
            URLQueryItem(name: "$select", value: "id,subject,start,end,location,bodyPreview,onlineMeeting,isReminderOn,reminderMinutesBeforeStart")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw CalendarError.apiError("Failed to fetch events")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = json["value"] as? [[String: Any]] else {
            return []
        }

        let calendarInfo = try await getCalendarInfo(calendarId: calendarId, account: account)

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
            reminders: reminders
        )
    }

    private func extractConferenceLink(
        from item: [String: Any],
        bodyPreview: String?,
        location: String?
    ) -> String? {
        if let onlineMeeting = item["onlineMeeting"] as? [String: Any],
           let joinUrl = onlineMeeting["joinUrl"] as? String,
           isValidMeetingLink(joinUrl) {
            return joinUrl
        }

        if let bodyPreview = bodyPreview,
           let link = findMeetingLink(in: bodyPreview) {
            return link
        }

        if let location = location,
           let link = findMeetingLink(in: location) {
            return link
        }

        return nil
    }

    private func findMeetingLink(in text: String) -> String? {
        let patterns = [
            "https://meet\\.google\\.com/[a-z-]+",
            "https://[a-z0-9-]+\\.zoom\\.us/j/[0-9]+",
            "https://zoom\\.us/j/[0-9]+",
            "https://teams\\.microsoft\\.com/l/meetup-join/[^\\s]+",
            "https://[a-z0-9-]+\\.webex\\.com/[^\\s]+"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                if let match = regex.firstMatch(in: text, range: range) {
                    if let swiftRange = Range(match.range, in: text) {
                        return String(text[swiftRange])
                    }
                }
            }
        }

        return nil
    }

    private func isValidMeetingLink(_ url: String) -> Bool {
        let validPrefixes = [
            "https://meet.google.com",
            "https://zoom.us",
            "https://teams.microsoft.com",
            "https://webex.com"
        ]

        return validPrefixes.contains { url.lowercased().hasPrefix($0) }
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

    private func getValidToken(forAccount account: CalendarAccount) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            AuthManager.shared.getValidAccessToken(forAccount: account) { result in
                continuation.resume(with: result)
            }
        }
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
