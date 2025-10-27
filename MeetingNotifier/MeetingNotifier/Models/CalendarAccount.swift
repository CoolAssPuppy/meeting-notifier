import Foundation
import AppKit

enum CalendarProvider: String, Codable {
    case google
    case microsoft

    var iconName: String {
        switch self {
        case .google:
            return "google"
        case .microsoft:
            return "microsoft"
        }
    }

    var icon: NSImage? {
        guard let path = Bundle.main.path(forResource: iconName, ofType: "png") else {
            return nil
        }
        return NSImage(contentsOfFile: path)
    }
}

enum AuthStatus: String, Codable {
    case valid
    case expired
    case revoked
}

struct CalendarAccount: Codable, Identifiable, Hashable {
    var id: String { email }
    var email: String
    var provider: CalendarProvider
    var isEnabled: Bool = true
    var selectedCalendarIds: Set<String> = []
    var authStatus: AuthStatus = .valid
    var lastAuthError: Date?

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
