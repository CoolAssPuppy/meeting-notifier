import Foundation
import Combine
import AppKit

@MainActor
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var accounts: [CalendarAccount] {
        didSet {
            saveAccounts()
        }
    }

    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
        }
    }

    @Published var oneMinuteWarningEnabled: Bool {
        didSet {
            UserDefaults.standard.set(oneMinuteWarningEnabled, forKey: "oneMinuteWarningEnabled")
        }
    }

    @Published var notificationTracking: NotificationTracking {
        didSet {
            saveNotificationTracking()
        }
    }

    @Published var defaultMeetApp: MeetAppType {
        didSet {
            UserDefaults.standard.set(defaultMeetApp.rawValue, forKey: "defaultMeetApp")
        }
    }

    @Published var showInMenuBar: Bool {
        didSet {
            UserDefaults.standard.set(showInMenuBar, forKey: "showInMenuBar")
        }
    }

    @Published var onlyShowMeetingsWithAttendees: Bool {
        didSet {
            UserDefaults.standard.set(onlyShowMeetingsWithAttendees, forKey: "onlyShowMeetingsWithAttendees")
        }
    }

    @Published var muteSounds: Bool {
        didSet {
            UserDefaults.standard.set(muteSounds, forKey: "muteSounds")
        }
    }

    private init() {
        self.accounts = []
        self.notificationsEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        self.oneMinuteWarningEnabled = UserDefaults.standard.object(forKey: "oneMinuteWarningEnabled") as? Bool ?? true
        self.notificationTracking = NotificationTracking()

        let meetAppRawValue = UserDefaults.standard.string(forKey: "defaultMeetApp") ?? MeetAppType.defaultBrowser.rawValue
        self.defaultMeetApp = MeetAppType(rawValue: meetAppRawValue) ?? .defaultBrowser

        self.showInMenuBar = UserDefaults.standard.object(forKey: "showInMenuBar") as? Bool ?? false
        self.onlyShowMeetingsWithAttendees = UserDefaults.standard.object(forKey: "onlyShowMeetingsWithAttendees") as? Bool ?? false
        self.muteSounds = UserDefaults.standard.object(forKey: "muteSounds") as? Bool ?? false

        loadAccounts()
        loadNotificationTracking()
    }

    private func loadAccounts() {
        if let data = UserDefaults.standard.data(forKey: "accounts"),
           let decoded = try? JSONDecoder().decode([CalendarAccount].self, from: data) {
            self.accounts = decoded
        }
    }

    private func saveAccounts() {
        if let encoded = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(encoded, forKey: "accounts")
        }
    }

    private func loadNotificationTracking() {
        if let data = UserDefaults.standard.data(forKey: "notificationTracking"),
           let decoded = try? JSONDecoder().decode(NotificationTracking.self, from: data) {
            self.notificationTracking = decoded
        }
    }

    private func saveNotificationTracking() {
        if let encoded = try? JSONEncoder().encode(notificationTracking) {
            UserDefaults.standard.set(encoded, forKey: "notificationTracking")
        }
    }

    func addAccount(_ account: CalendarAccount) {
        if !accounts.contains(where: { $0.id == account.id }) {
            accounts.append(account)
        }
    }

    func removeAccount(_ account: CalendarAccount) {
        accounts.removeAll { $0.id == account.id }
        _ = KeychainManager.shared.deleteAccessToken(forAccount: account.email)
        _ = KeychainManager.shared.deleteRefreshToken(forAccount: account.email)
    }

    func updateAccount(_ account: CalendarAccount) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
        }
    }

    func account(forEmail email: String) -> CalendarAccount? {
        accounts.first { $0.email == email }
    }
}

enum MeetAppType: String, CaseIterable, Identifiable {
    case defaultBrowser = "Default Browser"
    case safari = "Safari"
    case chrome = "Google Chrome"
    case arc = "Arc"
    case brave = "Brave Browser"
    case firefox = "Firefox"
    case custom = "Select App..."

    var id: String { rawValue }

    var bundleIdentifier: String? {
        switch self {
        case .defaultBrowser, .custom:
            return nil
        case .safari:
            return "com.apple.Safari"
        case .chrome:
            return "com.google.Chrome"
        case .arc:
            return "company.thebrowser.Browser"
        case .brave:
            return "com.brave.Browser"
        case .firefox:
            return "org.mozilla.firefox"
        }
    }

    var isInstalled: Bool {
        guard let bundleId = bundleIdentifier else { return true }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil
    }

    static var availableApps: [MeetAppType] {
        return MeetAppType.allCases.filter { $0.isInstalled }
    }
}
