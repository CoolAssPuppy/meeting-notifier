import Foundation

@MainActor
class MicrosoftCalendarManager {
    static let shared = MicrosoftCalendarManager()

    private init() {}

    func fetchCalendarList(forAccount account: CalendarAccount, retryCount: Int = 0) async throws -> [CalendarInfo] {
        let accessToken = try await getValidToken(forAccount: account)

        let url = URL(string: "https://graph.microsoft.com/v1.0/me/calendars")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CalendarError.apiError("Invalid response")
        }

        // Handle 401 Unauthorized - token expired
        if httpResponse.statusCode == 401 && retryCount == 0 {
            print("Access token expired for \(account.email), refreshing...")
            // Clear cached token to force refresh
            _ = KeychainManager.shared.deleteAccessToken(forAccount: account.email)

            // Retry once with refreshed token
            return try await fetchCalendarList(forAccount: account, retryCount: 1)
        }

        guard httpResponse.statusCode == 200 else {
            // Mark account as having auth issues if retry also failed
            if httpResponse.statusCode == 401 {
                await markAccountAuthFailed(account, status: .expired)
            }
            throw CalendarError.apiError("Failed to fetch calendar list (HTTP \(httpResponse.statusCode))")
        }

        // Success - mark account as valid
        await markAccountAuthValid(account)

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
        endDate: Date,
        retryCount: Int = 0
    ) async throws -> [CalendarEvent] {
        let accessToken = try await getValidToken(forAccount: account)

        let dateFormatter = ISO8601DateFormatter()
        let startString = dateFormatter.string(from: startDate)
        let endString = dateFormatter.string(from: endDate)

        guard var components = URLComponents(string: "https://graph.microsoft.com/v1.0/me/calendars/\(calendarId)/events") else {
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
            print("Access token expired for \(account.email), refreshing...")
            // Clear cached token to force refresh
            _ = KeychainManager.shared.deleteAccessToken(forAccount: account.email)

            // Retry once with refreshed token
            return try await fetchEvents(
                forCalendar: calendarId,
                account: account,
                startDate: startDate,
                endDate: endDate,
                retryCount: 1
            )
        }

        guard httpResponse.statusCode == 200 else {
            // Mark account as having auth issues if retry also failed
            if httpResponse.statusCode == 401 {
                await markAccountAuthFailed(account, status: .expired)
            }
            throw CalendarError.apiError("Failed to fetch events (HTTP \(httpResponse.statusCode))")
        }

        // Success - mark account as valid
        await markAccountAuthValid(account)

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
            attendeeCount: attendeeCount
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

    private func markAccountAuthFailed(_ account: CalendarAccount, status: AuthStatus) async {
        await MainActor.run {
            var updatedAccount = account
            updatedAccount.authStatus = status
            updatedAccount.lastAuthError = Date()
            AppSettings.shared.updateAccount(updatedAccount)

            // Show notification
            NotificationManager.shared.showAuthFailureNotification(forAccount: account)
        }
    }

    private func markAccountAuthValid(_ account: CalendarAccount) async {
        // Only update if status changed to avoid unnecessary writes
        guard account.authStatus != .valid else { return }

        await MainActor.run {
            var updatedAccount = account
            updatedAccount.authStatus = .valid
            updatedAccount.lastAuthError = nil
            AppSettings.shared.updateAccount(updatedAccount)
        }
    }
}
