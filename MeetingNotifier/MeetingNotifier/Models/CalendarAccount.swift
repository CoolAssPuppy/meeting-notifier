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
    case needsAuth // Account synced from iCloud but no local OAuth tokens
}

struct CalendarAccount: Codable, Identifiable, Hashable {
    var id: String { email }
    var email: String
    var provider: CalendarProvider
    var isEnabled: Bool = true
    var selectedCalendarIds: Set<String> = []
    var authStatus: AuthStatus = .valid
    var lastAuthError: Date?
    var friendlyName: String?

    /// Shown wherever the user sees the account (sidebar, header, etc).
    /// Falls back to the raw email until the user sets a friendly name.
    var displayName: String {
        let trimmed = friendlyName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? email : trimmed
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
