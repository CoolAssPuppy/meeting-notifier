import Foundation
import os

@MainActor
class GoogleCalendarManager {
    static let shared = GoogleCalendarManager()

    private init() {}

    func fetchCalendarList(forAccount account: CalendarAccount, retryCount: Int = 0) async throws -> [CalendarInfo] {
        let accessToken = try await CalendarManagerSupport.getValidToken(forAccount: account)

        let url = URL(string: "https://www.googleapis.com/calendar/v3/users/me/calendarList")!
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
        calendarInfo: CalendarInfo,
        account: CalendarAccount,
        startDate: Date,
        endDate: Date,
        retryCount: Int = 0
    ) async throws -> [CalendarEvent] {
        let accessToken = try await CalendarManagerSupport.getValidToken(forAccount: account)

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
              let items = json["items"] as? [[String: Any]] else {
            return []
        }

        // Use the calendarInfo passed in (which includes custom colors)
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
        let attendeeNames = attendees.compactMap { attendee -> String? in
            if let name = attendee["displayName"] as? String, !name.isEmpty {
                return name
            }
            return attendee["email"] as? String
        }

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
            attendeeCount: attendeeCount,
            attendeeNames: attendeeNames,
            accountEmail: calendarInfo.accountEmail
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
                   MeetingLinkParser.isValidMeetingLink(uri) {
                    return uri
                }
            }
        }

        if let description = description,
           let link = MeetingLinkParser.findMeetingLink(in: description) {
            return link
        }

        if let location = location,
           let link = MeetingLinkParser.findMeetingLink(in: location) {
            return link
        }

        return nil
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
