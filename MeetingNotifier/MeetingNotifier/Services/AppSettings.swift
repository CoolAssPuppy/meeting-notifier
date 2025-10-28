import Foundation
import Combine
import AppKit
import ServiceManagement

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

    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            updateLoginItem()
        }
    }

    // New settings for enhanced features
    @Published var menuBarShowIcon: Bool {
        didSet {
            UserDefaults.standard.set(menuBarShowIcon, forKey: "menuBarShowIcon")
        }
    }

    @Published var menuBarShowTitle: Bool {
        didSet {
            UserDefaults.standard.set(menuBarShowTitle, forKey: "menuBarShowTitle")
        }
    }

    @Published var menuBarShowTime: Bool {
        didSet {
            UserDefaults.standard.set(menuBarShowTime, forKey: "menuBarShowTime")
        }
    }

    @Published var menuBarShowCountdown: Bool {
        didSet {
            UserDefaults.standard.set(menuBarShowCountdown, forKey: "menuBarShowCountdown")
        }
    }

    @Published var menuBarThresholdMinutes: Int {
        didSet {
            UserDefaults.standard.set(menuBarThresholdMinutes, forKey: "menuBarThresholdMinutes")
        }
    }

    @Published var showAllDayInMenuBar: Bool {
        didSet {
            UserDefaults.standard.set(showAllDayInMenuBar, forKey: "showAllDayInMenuBar")
        }
    }

    @Published var showMeetingCountBadge: Bool {
        didSet {
            UserDefaults.standard.set(showMeetingCountBadge, forKey: "showMeetingCountBadge")
        }
    }

    @Published var showTravelTimeAlerts: Bool {
        didSet {
            UserDefaults.standard.set(showTravelTimeAlerts, forKey: "showTravelTimeAlerts")
        }
    }

    @Published var defaultTravelMode: TravelMode {
        didSet {
            UserDefaults.standard.set(defaultTravelMode.rawValue, forKey: "defaultTravelMode")
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
        self.launchAtLogin = UserDefaults.standard.object(forKey: "launchAtLogin") as? Bool ?? false

        // Initialize new settings
        self.menuBarShowIcon = UserDefaults.standard.object(forKey: "menuBarShowIcon") as? Bool ?? true
        self.menuBarShowTitle = UserDefaults.standard.object(forKey: "menuBarShowTitle") as? Bool ?? true
        self.menuBarShowTime = UserDefaults.standard.object(forKey: "menuBarShowTime") as? Bool ?? false
        self.menuBarShowCountdown = UserDefaults.standard.object(forKey: "menuBarShowCountdown") as? Bool ?? false

        self.menuBarThresholdMinutes = UserDefaults.standard.object(forKey: "menuBarThresholdMinutes") as? Int ?? 15
        self.showAllDayInMenuBar = UserDefaults.standard.object(forKey: "showAllDayInMenuBar") as? Bool ?? false
        self.showMeetingCountBadge = UserDefaults.standard.object(forKey: "showMeetingCountBadge") as? Bool ?? true
        self.showTravelTimeAlerts = UserDefaults.standard.object(forKey: "showTravelTimeAlerts") as? Bool ?? true

        let travelModeRaw = UserDefaults.standard.string(forKey: "defaultTravelMode") ?? TravelMode.driving.rawValue
        self.defaultTravelMode = TravelMode(rawValue: travelModeRaw) ?? .driving

        loadAccounts()
        loadNotificationTracking()
    }

    private func loadAccounts() {
        if let data = UserDefaults.standard.data(forKey: "accounts") {
            do {
                let decoded = try JSONDecoder().decode([CalendarAccount].self, from: data)
                self.accounts = decoded
                print("Successfully loaded \(decoded.count) accounts")
            } catch {
                print("Error loading accounts: \(error)")
                print("Error details: \(error.localizedDescription)")
            }
        } else {
            print("No account data found in UserDefaults")
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

    private func updateLoginItem() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update login item: \(error)")
        }
    }

    func openURL(_ url: URL) {
        let urlString = url.absoluteString.lowercased()
        let isGoogleMeet = urlString.contains("meet.google.com") || urlString.contains("hangouts.google.com")

        guard isGoogleMeet else {
            NSWorkspace.shared.open(url)
            return
        }

        switch defaultMeetApp {
        case .defaultBrowser:
            NSWorkspace.shared.open(url)

        case .custom:
            if let customPath = UserDefaults.standard.string(forKey: "customMeetAppPath"),
               let appURL = URL(fileURLWithPath: customPath) as URL? {
                NSWorkspace.shared.open(
                    [url],
                    withApplicationAt: appURL,
                    configuration: NSWorkspace.OpenConfiguration()
                )
            } else {
                NSWorkspace.shared.open(url)
            }

        default:
            if let bundleId = defaultMeetApp.bundleIdentifier,
               let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                NSWorkspace.shared.open(
                    [url],
                    withApplicationAt: appURL,
                    configuration: NSWorkspace.OpenConfiguration()
                )
            } else {
                NSWorkspace.shared.open(url)
            }
        }
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

// MARK: - Travel Mode

enum TravelMode: String, CaseIterable, Identifiable {
    case driving = "Driving"
    case walking = "Walking"
    case transit = "Transit"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .driving: return "car.fill"
        case .walking: return "figure.walk"
        case .transit: return "bus.fill"
        }
    }
}
