import Foundation

struct CalendarEvent: Identifiable, Hashable, Codable {
    var id: String
    var title: String
    var startDate: Date
    var endDate: Date
    var location: String?
    var description: String?
    var conferenceLink: String?
    var calendarId: String
    var calendarName: String
    var calendarColorHex: String
    var provider: CalendarProvider
    var reminders: [EventReminder] = []

    var timeUntilStart: String {
        let now = Date()
        let interval = startDate.timeIntervalSince(now)

        if interval < 0 {
            return "Started"
        }

        let minutes = Int(interval / 60)
        let hours = minutes / 60
        let days = hours / 24

        if days > 0 {
            return "in \(days)d"
        } else if hours > 0 {
            return "in \(hours)h"
        } else if minutes > 0 {
            return "in \(minutes)m"
        } else {
            return "Starting now"
        }
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: startDate)
    }

    var formattedDateSection: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(startDate) {
            return "Today"
        } else if calendar.isDateInTomorrow(startDate) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: startDate)
        }
    }

    var hasVideoLink: Bool {
        conferenceLink != nil
    }
}

struct EventReminder: Codable, Hashable {
    var minutesBefore: Int
}

extension CalendarEvent {
    static let preview = CalendarEvent(
        id: "event1",
        title: "Team Standup",
        startDate: Date().addingTimeInterval(900),
        endDate: Date().addingTimeInterval(2700),
        location: nil,
        description: "Daily team standup meeting",
        conferenceLink: "https://meet.google.com/abc-defg-hij",
        calendarId: "primary",
        calendarName: "Work Calendar",
        calendarColorHex: "#4285F4",
        provider: .google,
        reminders: [EventReminder(minutesBefore: 1)]
    )

    static let previewNoVideo = CalendarEvent(
        id: "event2",
        title: "Lunch with Sarah",
        startDate: Date().addingTimeInterval(7200),
        endDate: Date().addingTimeInterval(9000),
        location: "Downtown Cafe",
        description: nil,
        conferenceLink: nil,
        calendarId: "primary",
        calendarName: "Personal",
        calendarColorHex: "#E67C73",
        provider: .google,
        reminders: []
    )
}
