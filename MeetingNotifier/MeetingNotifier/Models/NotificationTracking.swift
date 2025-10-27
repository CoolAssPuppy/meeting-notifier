import Foundation

struct NotificationTracking: Codable {
    var sentNotifications: Set<String> = []

    mutating func markAsSent(eventId: String, type: NotificationType) {
        let key = "\(eventId)_\(type.rawValue)"
        sentNotifications.insert(key)
    }

    func wasSent(eventId: String, type: NotificationType) -> Bool {
        let key = "\(eventId)_\(type.rawValue)"
        return sentNotifications.contains(key)
    }

    mutating func cleanup(events: [CalendarEvent]) {
        let validKeys = Set(events.flatMap { event in
            NotificationType.allCases.map { "\(event.id)_\($0.rawValue)" }
        })

        sentNotifications = sentNotifications.intersection(validKeys)
    }
}

enum NotificationType: String, Codable, CaseIterable {
    case oneMinuteWarning
    case customReminder
}
