import Foundation
import Combine
import AppKit
import ServiceManagement

@MainActor
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let iCloudStore = NSUbiquitousKeyValueStore.default
    private var isUpdatingFromiCloud = false

    @Published var accounts: [CalendarAccount] {
        didSet {
            // Only save if we're not initializing from iCloud
            if !isUpdatingFromiCloud {
                saveAccounts()
                NotificationCenter.default.post(name: .accountsDidUpdate, object: nil)
            }
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

    @Published var doubleBookingPreference: DoubleBookingPreference {
        didSet {
            saveSetting(doubleBookingPreference.rawValue, forKey: "doubleBookingPreference")
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

        // CRITICAL: Set this flag BEFORE initializing properties to prevent crash
        // during initialization due to infinite iCloud sync loop
        self.isUpdatingFromiCloud = true
        defer { self.isUpdatingFromiCloud = false }

        // First, sync with iCloud to get latest values
        iCloudStore.synchronize()

        // Load from iCloud first, fallback to UserDefaults, then use defaults
        // This ensures fresh values from iCloud take priority
        self.notificationsEnabled = iCloudStore.object(forKey: "notificationsEnabled") as? Bool
            ?? UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        self.oneMinuteWarningEnabled = iCloudStore.object(forKey: "oneMinuteWarningEnabled") as? Bool
            ?? UserDefaults.standard.object(forKey: "oneMinuteWarningEnabled") as? Bool ?? true
        self.notificationTracking = NotificationTracking()

        let meetAppRawValue = iCloudStore.string(forKey: "defaultMeetApp")
            ?? UserDefaults.standard.string(forKey: "defaultMeetApp") ?? MeetAppType.defaultBrowser.rawValue
        self.defaultMeetApp = MeetAppType(rawValue: meetAppRawValue) ?? .defaultBrowser

        self.showInMenuBar = iCloudStore.object(forKey: "showInMenuBar") as? Bool
            ?? UserDefaults.standard.object(forKey: "showInMenuBar") as? Bool ?? false
        self.onlyShowMeetingsWithAttendees = iCloudStore.object(forKey: "onlyShowMeetingsWithAttendees") as? Bool
            ?? UserDefaults.standard.object(forKey: "onlyShowMeetingsWithAttendees") as? Bool ?? false
        self.muteSounds = iCloudStore.object(forKey: "muteSounds") as? Bool
            ?? UserDefaults.standard.object(forKey: "muteSounds") as? Bool ?? false
        self.launchAtLogin = iCloudStore.object(forKey: "launchAtLogin") as? Bool
            ?? UserDefaults.standard.object(forKey: "launchAtLogin") as? Bool ?? false

        // Initialize new settings
        self.menuBarShowIcon = iCloudStore.object(forKey: "menuBarShowIcon") as? Bool
            ?? UserDefaults.standard.object(forKey: "menuBarShowIcon") as? Bool ?? true
        self.menuBarShowTitle = iCloudStore.object(forKey: "menuBarShowTitle") as? Bool
            ?? UserDefaults.standard.object(forKey: "menuBarShowTitle") as? Bool ?? true
        self.menuBarShowTime = iCloudStore.object(forKey: "menuBarShowTime") as? Bool
            ?? UserDefaults.standard.object(forKey: "menuBarShowTime") as? Bool ?? false
        self.menuBarShowCountdown = iCloudStore.object(forKey: "menuBarShowCountdown") as? Bool
            ?? UserDefaults.standard.object(forKey: "menuBarShowCountdown") as? Bool ?? false

        self.menuBarThresholdMinutes = iCloudStore.object(forKey: "menuBarThresholdMinutes") as? Int
            ?? UserDefaults.standard.object(forKey: "menuBarThresholdMinutes") as? Int ?? 15
        self.showAllDayInMenuBar = iCloudStore.object(forKey: "showAllDayInMenuBar") as? Bool
            ?? UserDefaults.standard.object(forKey: "showAllDayInMenuBar") as? Bool ?? false
        self.showMeetingCountBadge = iCloudStore.object(forKey: "showMeetingCountBadge") as? Bool
            ?? UserDefaults.standard.object(forKey: "showMeetingCountBadge") as? Bool ?? true
        self.showTravelTimeAlerts = iCloudStore.object(forKey: "showTravelTimeAlerts") as? Bool
            ?? UserDefaults.standard.object(forKey: "showTravelTimeAlerts") as? Bool ?? true

        let travelModeRaw = iCloudStore.string(forKey: "defaultTravelMode")
            ?? UserDefaults.standard.string(forKey: "defaultTravelMode") ?? TravelMode.driving.rawValue
        self.defaultTravelMode = TravelMode(rawValue: travelModeRaw) ?? .driving

        let mapProviderRaw = iCloudStore.string(forKey: "preferredMapProvider")
            ?? UserDefaults.standard.string(forKey: "preferredMapProvider") ?? MapProvider.apple.rawValue
        self.preferredMapProvider = MapProvider(rawValue: mapProviderRaw) ?? .apple

        let doubleBookingRaw = iCloudStore.string(forKey: "doubleBookingPreference")
            ?? UserDefaults.standard.string(forKey: "doubleBookingPreference") ?? DoubleBookingPreference.fewerAttendees.rawValue
        self.doubleBookingPreference = DoubleBookingPreference(rawValue: doubleBookingRaw) ?? .fewerAttendees

        self.customCalendarColors = [:]

        loadAccounts()
        loadNotificationTracking()
        loadCustomCalendarColors()

        // Copy iCloud values to UserDefaults to keep them in sync
        syncAllSettingsFromiCloudToUserDefaults()

        // Setup iCloud sync AFTER initialization is complete
        setupiCloudSync()

        // Verify and sync login item status
        verifyLoginItemStatus()

        // Flag will be reset to false by defer when init completes
    }

    private func loadAccounts() {
        if let data = UserDefaults.standard.data(forKey: "accounts") {
            do {
                var decoded = try JSONDecoder().decode([CalendarAccount].self, from: data)

                // Check if each account has local OAuth tokens
                for i in 0..<decoded.count {
                    let account = decoded[i]
                    let hasAccessToken = KeychainManager.shared.retrieveAccessToken(forAccount: account.email) != nil
                    let hasRefreshToken = KeychainManager.shared.retrieveRefreshToken(forAccount: account.email) != nil

                    // If account has no local tokens, mark as needing auth
                    if !hasAccessToken && !hasRefreshToken {
                        decoded[i].authStatus = .needsAuth
                        print("Account \(account.email) has no local tokens - marked as needsAuth")
                    } else if decoded[i].authStatus == .needsAuth {
                        // If account was marked as needsAuth but now has tokens, mark as valid
                        decoded[i].authStatus = .valid
                        print("Account \(account.email) now has tokens - marked as valid")
                    }
                }

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

            // Only save to iCloud if we're not currently syncing FROM iCloud
            if !isUpdatingFromiCloud {
                iCloudStore.set(encoded, forKey: "customCalendarColors")
                iCloudStore.synchronize()
            }
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

    private func syncAllSettingsFromiCloudToUserDefaults() {
        // Sync all settings from iCloud to UserDefaults to ensure consistency
        let settingsKeys = [
            "notificationsEnabled", "oneMinuteWarningEnabled", "defaultMeetApp",
            "showInMenuBar", "onlyShowMeetingsWithAttendees", "muteSounds", "launchAtLogin",
            "menuBarShowIcon", "menuBarShowTitle", "menuBarShowTime", "menuBarShowCountdown",
            "menuBarThresholdMinutes", "showAllDayInMenuBar", "showMeetingCountBadge",
            "showTravelTimeAlerts", "defaultTravelMode", "preferredMapProvider", "doubleBookingPreference"
        ]

        for key in settingsKeys {
            if let value = iCloudStore.object(forKey: key) {
                UserDefaults.standard.set(value, forKey: key)
            }
        }
    }

    private func verifyLoginItemStatus() {
        // Check actual system registration status and sync with our setting
        let systemStatus = SMAppService.mainApp.status

        switch systemStatus {
        case .enabled:
            // System says enabled - ensure our setting matches
            if !launchAtLogin {
                print("Login item is enabled in system but setting is false - syncing")
                // Update our setting without triggering didSet (to avoid re-registering)
                UserDefaults.standard.set(true, forKey: "launchAtLogin")
                iCloudStore.set(true, forKey: "launchAtLogin")
                iCloudStore.synchronize()
                // Manually update the property
                DispatchQueue.main.async { [weak self] in
                    self?.launchAtLogin = true
                }
            }
        case .notRegistered:
            // System says not registered - register if setting says we should
            if launchAtLogin {
                print("Login item setting is true but not registered - registering")
                do {
                    try SMAppService.mainApp.register()
                } catch {
                    print("Failed to register login item: \(error)")
                }
            }
        case .requiresApproval:
            // User needs to approve in System Settings
            print("Login item requires approval in System Settings")
        case .notFound:
            // App service not found
            print("Login item service not found")
        @unknown default:
            print("Unknown login item status: \(systemStatus.rawValue)")
        }
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

            // Set flag to prevent writing back to iCloud while syncing FROM iCloud
            self.isUpdatingFromiCloud = true
            defer { self.isUpdatingFromiCloud = false }

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
            if keys.contains("doubleBookingPreference") {
                let doubleBookingRaw = UserDefaults.standard.string(forKey: "doubleBookingPreference") ?? DoubleBookingPreference.fewerAttendees.rawValue
                self.doubleBookingPreference = DoubleBookingPreference(rawValue: doubleBookingRaw) ?? .fewerAttendees
            }
            if keys.contains("customCalendarColors") {
                self.loadCustomCalendarColors()
            }
        }
    }

    private func saveSetting<T>(_ value: T, forKey key: String) {
        // Save to local UserDefaults
        UserDefaults.standard.set(value, forKey: key)

        // Only save to iCloud if we're not currently syncing FROM iCloud
        // This prevents an infinite loop where iCloud changes trigger writes back to iCloud
        if !isUpdatingFromiCloud {
            iCloudStore.set(value, forKey: key)
            iCloudStore.synchronize()
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

// MARK: - Double Booking Preference

enum DoubleBookingPreference: String, CaseIterable, Identifiable {
    case fewerAttendees = "Meetings with fewer attendees"
    case moreAttendees = "Meetings with more attendees"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .fewerAttendees:
            return "Show smaller meetings first"
        case .moreAttendees:
            return "Show larger meetings first"
        }
    }
}
