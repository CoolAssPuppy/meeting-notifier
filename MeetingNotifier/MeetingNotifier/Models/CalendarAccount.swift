import Foundation

enum CalendarProvider: String, Codable {
    case google
    case microsoft
}

struct CalendarAccount: Codable, Identifiable, Hashable {
    var id: String { email }
    var email: String
    var provider: CalendarProvider
    var isEnabled: Bool = true
    var selectedCalendarIds: Set<String> = []

    var displayName: String {
        email
    }

    var providerName: String {
        switch provider {
        case .google:
            return "Google"
        case .microsoft:
            return "Microsoft"
        }
    }
}

extension CalendarAccount {
    static let preview = CalendarAccount(
        email: "user@example.com",
        provider: .google,
        isEnabled: true,
        selectedCalendarIds: ["primary"]
    )
}
