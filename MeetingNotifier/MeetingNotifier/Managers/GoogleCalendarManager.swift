import Foundation

@MainActor
class GoogleCalendarManager {
    static let shared = GoogleCalendarManager()

    private init() {}

    func fetchCalendarList(forAccount account: CalendarAccount) async throws -> [CalendarInfo] {
        let accessToken = try await getValidToken(forAccount: account)

        let url = URL(string: "https://www.googleapis.com/calendar/v3/users/me/calendarList")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw CalendarError.apiError("Failed to fetch calendar list")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else {
            throw CalendarError.parseError("Invalid calendar list response")
        }

        return items.compactMap { item in
            guard let id = item["id"] as? String,
                  let summary = item["summary"] as? String else {
                return nil
            }

            // Prefer backgroundColor (actual color) over colorId (preset palette)
            let colorHex: String
            if let backgroundColor = item["backgroundColor"] as? String {
                colorHex = backgroundColor
            } else {
                let colorId = item["colorId"] as? String ?? "1"
                colorHex = googleColorIdToHex(colorId)
            }

            let isPrimary = item["primary"] as? Bool ?? false

            return CalendarInfo(
                id: id,
                name: summary,
                colorHex: colorHex,
                provider: .google,
                accountEmail: account.email,
                isPrimary: isPrimary
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
        let timeMin = dateFormatter.string(from: startDate)
        let timeMax = dateFormatter.string(from: endDate)

        var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/\(calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarId)/events")!
        components.queryItems = [
            URLQueryItem(name: "timeMin", value: timeMin),
            URLQueryItem(name: "timeMax", value: timeMax),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw CalendarError.apiError("Failed to fetch events")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else {
            return []
        }

        let calendarInfo = try await getCalendarInfo(calendarId: calendarId, account: account)

        return items.compactMap { item in
            parseGoogleEvent(item, calendarId: calendarId, calendarInfo: calendarInfo)
        }
    }

    private func parseGoogleEvent(
        _ item: [String: Any],
        calendarId: String,
        calendarInfo: CalendarInfo
    ) -> CalendarEvent? {
        guard let eventId = item["id"] as? String,
              let summary = item["summary"] as? String,
              let start = item["start"] as? [String: Any],
              let end = item["end"] as? [String: Any] else {
            return nil
        }

        let startDateString = start["dateTime"] as? String ?? start["date"] as? String ?? ""
        let endDateString = end["dateTime"] as? String ?? end["date"] as? String ?? ""

        let dateFormatter = ISO8601DateFormatter()
        guard let startDate = dateFormatter.date(from: startDateString),
              let endDate = dateFormatter.date(from: endDateString) else {
            return nil
        }

        let location = item["location"] as? String
        let description = item["description"] as? String

        let conferenceLink = extractConferenceLink(from: item, description: description, location: location)

        let reminders = parseReminders(from: item)

        let attendees = item["attendees"] as? [[String: Any]] ?? []
        let attendeeCount = attendees.count

        return CalendarEvent(
            id: eventId,
            title: summary,
            startDate: startDate,
            endDate: endDate,
            location: location,
            description: description,
            conferenceLink: conferenceLink,
            calendarId: calendarId,
            calendarName: calendarInfo.name,
            calendarColorHex: calendarInfo.colorHex,
            provider: .google,
            reminders: reminders,
            attendeeCount: attendeeCount
        )
    }

    private func extractConferenceLink(
        from item: [String: Any],
        description: String?,
        location: String?
    ) -> String? {
        if let conferenceData = item["conferenceData"] as? [String: Any],
           let entryPoints = conferenceData["entryPoints"] as? [[String: Any]] {
            for entryPoint in entryPoints {
                if let uri = entryPoint["uri"] as? String,
                   isValidMeetingLink(uri) {
                    return uri
                }
            }
        }

        if let description = description,
           let link = findMeetingLink(in: description) {
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
        guard let reminders = item["reminders"] as? [String: Any] else {
            return []
        }

        if let useDefault = reminders["useDefault"] as? Bool, useDefault {
            return [EventReminder(minutesBefore: 10)]
        }

        guard let overrides = reminders["overrides"] as? [[String: Any]] else {
            return []
        }

        return overrides.compactMap { override in
            guard let method = override["method"] as? String,
                  method == "popup",
                  let minutes = override["minutes"] as? Int else {
                return nil
            }
            return EventReminder(minutesBefore: minutes)
        }
    }

    private func getCalendarInfo(calendarId: String, account: CalendarAccount) async throws -> CalendarInfo {
        let calendars = try await fetchCalendarList(forAccount: account)
        guard let calendar = calendars.first(where: { $0.id == calendarId }) else {
            return CalendarInfo(
                id: calendarId,
                name: "Calendar",
                colorHex: "#4285F4",
                provider: .google,
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

    private func googleColorIdToHex(_ colorId: String) -> String {
        let colors = [
            "1": "#AC725E", "2": "#D06B64", "3": "#F83A22", "4": "#FA573C",
            "5": "#FF6B6B", "6": "#FFC107", "7": "#FFA000", "8": "#E4C441",
            "9": "#16A765", "10": "#43B581", "11": "#0B8043", "12": "#16A765"
        ]
        return colors[colorId] ?? "#4285F4"
    }
}

enum CalendarError: LocalizedError {
    case apiError(String)
    case parseError(String)
    case authError(String)

    var errorDescription: String? {
        switch self {
        case .apiError(let message):
            return "API Error: \(message)"
        case .parseError(let message):
            return "Parse Error: \(message)"
        case .authError(let message):
            return "Auth Error: \(message)"
        }
    }
}
