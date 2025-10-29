import Foundation
import Combine
import AppKit
import ServiceManagement

@MainActor
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let iCloudStore = NSUbiquitousKeyValueStore.default

    @Published var accounts: [CalendarAccount] {
        didSet {
            saveAccounts()
        }
    }

    @Published var notificationsEnabled: Bool {
        didSet {
            saveSetting(notificationsEnabled, forKey: "notificationsEnabled")
        }
    }

    @Published var oneMinuteWarningEnabled: Bool {
        didSet {
            saveSetting(oneMinuteWarningEnabled, forKey: "oneMinuteWarningEnabled")
        }
    }

    @Published var notificationTracking: NotificationTracking {
        didSet {
            saveNotificationTracking()
        }
    }

    @Published var defaultMeetApp: MeetAppType {
        didSet {
            saveSetting(defaultMeetApp.rawValue, forKey: "defaultMeetApp")
        }
    }

    @Published var showInMenuBar: Bool {
        didSet {
            saveSetting(showInMenuBar, forKey: "showInMenuBar")
        }
    }

    @Published var onlyShowMeetingsWithAttendees: Bool {
        didSet {
            saveSetting(onlyShowMeetingsWithAttendees, forKey: "onlyShowMeetingsWithAttendees")
        }
    }

    @Published var muteSounds: Bool {
        didSet {
            saveSetting(muteSounds, forKey: "muteSounds")
        }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            saveSetting(launchAtLogin, forKey: "launchAtLogin")
            updateLoginItem()
        }
    }

    // New settings for enhanced features
    @Published var menuBarShowIcon: Bool {
        didSet {
            saveSetting(menuBarShowIcon, forKey: "menuBarShowIcon")
        }
    }

    @Published var menuBarShowTitle: Bool {
        didSet {
            saveSetting(menuBarShowTitle, forKey: "menuBarShowTitle")
        }
    }

    @Published var menuBarShowTime: Bool {
        didSet {
            saveSetting(menuBarShowTime, forKey: "menuBarShowTime")
        }
    }

    @Published var menuBarShowCountdown: Bool {
        didSet {
            saveSetting(menuBarShowCountdown, forKey: "menuBarShowCountdown")
        }
    }

    @Published var menuBarThresholdMinutes: Int {
        didSet {
            saveSetting(menuBarThresholdMinutes, forKey: "menuBarThresholdMinutes")
        }
    }

    @Published var showAllDayInMenuBar: Bool {
        didSet {
            saveSetting(showAllDayInMenuBar, forKey: "showAllDayInMenuBar")
        }
    }

    @Published var showMeetingCountBadge: Bool {
        didSet {
            saveSetting(showMeetingCountBadge, forKey: "showMeetingCountBadge")
        }
    }

    @Published var showTravelTimeAlerts: Bool {
        didSet {
            saveSetting(showTravelTimeAlerts, forKey: "showTravelTimeAlerts")
        }
    }

    @Published var defaultTravelMode: TravelMode {
        didSet {
            saveSetting(defaultTravelMode.rawValue, forKey: "defaultTravelMode")
        }
    }

    @Published var preferredMapProvider: MapProvider {
        didSet {
            saveSetting(preferredMapProvider.rawValue, forKey: "preferredMapProvider")
        }
    }

    // Custom calendar colors: [accountEmail: [calendarId: hexColor]]
    @Published var customCalendarColors: [String: [String: String]] {
        didSet {
            saveCustomCalendarColors()
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

        let mapProviderRaw = UserDefaults.standard.string(forKey: "preferredMapProvider") ?? MapProvider.apple.rawValue
        self.preferredMapProvider = MapProvider(rawValue: mapProviderRaw) ?? .apple

        self.customCalendarColors = [:]

        loadAccounts()
        loadNotificationTracking()
        loadCustomCalendarColors()
        setupiCloudSync()
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

    private func loadCustomCalendarColors() {
        if let data = UserDefaults.standard.data(forKey: "customCalendarColors"),
           let decoded = try? JSONDecoder().decode([String: [String: String]].self, from: data) {
            self.customCalendarColors = decoded
        }
    }

    private func saveCustomCalendarColors() {
        if let encoded = try? JSONEncoder().encode(customCalendarColors) {
            UserDefaults.standard.set(encoded, forKey: "customCalendarColors")
            iCloudStore.set(encoded, forKey: "customCalendarColors")
            iCloudStore.synchronize()
        }
    }

    func setCustomColor(forCalendar calendarId: String, account accountEmail: String, color: String) {
        if customCalendarColors[accountEmail] == nil {
            customCalendarColors[accountEmail] = [:]
        }
        customCalendarColors[accountEmail]?[calendarId] = color
    }

    func getCustomColor(forCalendar calendarId: String, account accountEmail: String) -> String? {
        return customCalendarColors[accountEmail]?[calendarId]
    }

    func removeCustomColor(forCalendar calendarId: String, account accountEmail: String) {
        customCalendarColors[accountEmail]?[calendarId] = nil
        if customCalendarColors[accountEmail]?.isEmpty == true {
            customCalendarColors[accountEmail] = nil
        }
    }

    // MARK: - iCloud Sync

    private func setupiCloudSync() {
        // Observe iCloud changes from other devices
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudStoreDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: iCloudStore
        )

        // Synchronize with iCloud
        iCloudStore.synchronize()
    }

    @objc private func iCloudStoreDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else {
            return
        }

        // Update local settings from iCloud
        for key in keys {
            if let value = iCloudStore.object(forKey: key) {
                UserDefaults.standard.set(value, forKey: key)
            }
        }

        // Reload affected settings
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if keys.contains("notificationsEnabled") {
                self.notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
            }
            if keys.contains("oneMinuteWarningEnabled") {
                self.oneMinuteWarningEnabled = UserDefaults.standard.bool(forKey: "oneMinuteWarningEnabled")
            }
            if keys.contains("showInMenuBar") {
                self.showInMenuBar = UserDefaults.standard.bool(forKey: "showInMenuBar")
            }
            if keys.contains("onlyShowMeetingsWithAttendees") {
                self.onlyShowMeetingsWithAttendees = UserDefaults.standard.bool(forKey: "onlyShowMeetingsWithAttendees")
            }
            if keys.contains("muteSounds") {
                self.muteSounds = UserDefaults.standard.bool(forKey: "muteSounds")
            }
            if keys.contains("launchAtLogin") {
                self.launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
            }
            if keys.contains("menuBarShowIcon") {
                self.menuBarShowIcon = UserDefaults.standard.bool(forKey: "menuBarShowIcon")
            }
            if keys.contains("menuBarShowTitle") {
                self.menuBarShowTitle = UserDefaults.standard.bool(forKey: "menuBarShowTitle")
            }
            if keys.contains("menuBarShowTime") {
                self.menuBarShowTime = UserDefaults.standard.bool(forKey: "menuBarShowTime")
            }
            if keys.contains("menuBarShowCountdown") {
                self.menuBarShowCountdown = UserDefaults.standard.bool(forKey: "menuBarShowCountdown")
            }
            if keys.contains("menuBarThresholdMinutes") {
                self.menuBarThresholdMinutes = UserDefaults.standard.integer(forKey: "menuBarThresholdMinutes")
            }
            if keys.contains("showAllDayInMenuBar") {
                self.showAllDayInMenuBar = UserDefaults.standard.bool(forKey: "showAllDayInMenuBar")
            }
            if keys.contains("showMeetingCountBadge") {
                self.showMeetingCountBadge = UserDefaults.standard.bool(forKey: "showMeetingCountBadge")
            }
            if keys.contains("showTravelTimeAlerts") {
                self.showTravelTimeAlerts = UserDefaults.standard.bool(forKey: "showTravelTimeAlerts")
            }
            if keys.contains("defaultMeetApp") {
                let meetAppRawValue = UserDefaults.standard.string(forKey: "defaultMeetApp") ?? MeetAppType.defaultBrowser.rawValue
                self.defaultMeetApp = MeetAppType(rawValue: meetAppRawValue) ?? .defaultBrowser
            }
            if keys.contains("defaultTravelMode") {
                let travelModeRaw = UserDefaults.standard.string(forKey: "defaultTravelMode") ?? TravelMode.driving.rawValue
                self.defaultTravelMode = TravelMode(rawValue: travelModeRaw) ?? .driving
            }
            if keys.contains("preferredMapProvider") {
                let mapProviderRaw = UserDefaults.standard.string(forKey: "preferredMapProvider") ?? MapProvider.apple.rawValue
                self.preferredMapProvider = MapProvider(rawValue: mapProviderRaw) ?? .apple
            }
            if keys.contains("customCalendarColors") {
                self.loadCustomCalendarColors()
            }
        }
    }

    private func saveSetting<T>(_ value: T, forKey key: String) {
        // Save to local UserDefaults
        UserDefaults.standard.set(value, forKey: key)

        // Save to iCloud
        iCloudStore.set(value, forKey: key)
        iCloudStore.synchronize()
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

    func openURL(_ url: URL, accountEmail: String? = nil) {
        let urlString = url.absoluteString.lowercased()
        let isGoogleMeet = urlString.contains("meet.google.com") || urlString.contains("hangouts.google.com")

        // For Google Meet, append authuser parameter to open with correct account
        var finalURL = url
        if isGoogleMeet, let email = accountEmail {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            var queryItems = components?.queryItems ?? []
            queryItems.append(URLQueryItem(name: "authuser", value: email))
            components?.queryItems = queryItems
            if let modifiedURL = components?.url {
                finalURL = modifiedURL
            }
        }

        guard isGoogleMeet else {
            NSWorkspace.shared.open(finalURL)
            return
        }

        switch defaultMeetApp {
        case .defaultBrowser:
            NSWorkspace.shared.open(finalURL)

        case .custom:
            if let customPath = UserDefaults.standard.string(forKey: "customMeetAppPath"),
               let appURL = URL(fileURLWithPath: customPath) as URL? {
                NSWorkspace.shared.open(
                    [finalURL],
                    withApplicationAt: appURL,
                    configuration: NSWorkspace.OpenConfiguration()
                )
            } else {
                NSWorkspace.shared.open(finalURL)
            }

        default:
            if let bundleId = defaultMeetApp.bundleIdentifier,
               let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                NSWorkspace.shared.open(
                    [finalURL],
                    withApplicationAt: appURL,
                    configuration: NSWorkspace.OpenConfiguration()
                )
            } else {
                NSWorkspace.shared.open(finalURL)
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

// MARK: - Map Provider

enum MapProvider: String, CaseIterable, Identifiable {
    case apple = "Apple Maps"
    case google = "Google Maps"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .apple: return "map.fill"
        case .google: return "globe"
        }
    }
}
