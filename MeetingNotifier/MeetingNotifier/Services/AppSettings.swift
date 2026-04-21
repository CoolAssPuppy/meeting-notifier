import Foundation
import Combine
import AppKit
import ServiceManagement
import os

@MainActor
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // Internal access for iCloud sync extension
    let iCloudStore = NSUbiquitousKeyValueStore.default
    var isUpdatingFromiCloud = false

    @Published var accounts: [CalendarAccount] {
        didSet {
            if !isUpdatingFromiCloud {
                saveAccounts()
                syncAccountListToiCloud()
                NotificationCenter.default.post(name: .accountsDidUpdate, object: nil)
            }
        }
    }

    @Published var notificationsEnabled: Bool {
        didSet { saveSetting(notificationsEnabled, forKey: "notificationsEnabled") }
    }

    @Published var oneMinuteWarningEnabled: Bool {
        didSet { saveSetting(oneMinuteWarningEnabled, forKey: "oneMinuteWarningEnabled") }
    }

    @Published var notificationTracking: NotificationTracking {
        didSet { saveNotificationTracking() }
    }

    @Published var defaultMeetApp: MeetAppType {
        didSet { saveSetting(defaultMeetApp.rawValue, forKey: "defaultMeetApp") }
    }

    @Published var menuBarDisplayMode: MenuBarDisplayMode {
        didSet { saveSetting(menuBarDisplayMode.rawValue, forKey: "menuBarDisplayMode") }
    }

    var showInMenuBar: Bool {
        get { menuBarDisplayMode != .none }
        set { menuBarDisplayMode = newValue ? .inMenuBar : .none }
    }

    @Published var onlyShowMeetingsWithAttendees: Bool {
        didSet { saveSetting(onlyShowMeetingsWithAttendees, forKey: "onlyShowMeetingsWithAttendees") }
    }

    @Published var muteSounds: Bool {
        didSet { saveSetting(muteSounds, forKey: "muteSounds") }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            saveSetting(launchAtLogin, forKey: "launchAtLogin")
            updateLoginItem()
        }
    }

    @Published var menuBarShowIcon: Bool {
        didSet { saveSetting(menuBarShowIcon, forKey: "menuBarShowIcon") }
    }

    @Published var menuBarShowTitle: Bool {
        didSet { saveSetting(menuBarShowTitle, forKey: "menuBarShowTitle") }
    }

    @Published var menuBarShowTime: Bool {
        didSet { saveSetting(menuBarShowTime, forKey: "menuBarShowTime") }
    }

    @Published var menuBarShowCountdown: Bool {
        didSet { saveSetting(menuBarShowCountdown, forKey: "menuBarShowCountdown") }
    }

    @Published var menuBarThresholdMinutes: Int {
        didSet { saveSetting(menuBarThresholdMinutes, forKey: "menuBarThresholdMinutes") }
    }

    @Published var showAllDayInMenuBar: Bool {
        didSet { saveSetting(showAllDayInMenuBar, forKey: "showAllDayInMenuBar") }
    }

    @Published var showMeetingCountBadge: Bool {
        didSet { saveSetting(showMeetingCountBadge, forKey: "showMeetingCountBadge") }
    }

    @Published var showTravelTimeAlerts: Bool {
        didSet { saveSetting(showTravelTimeAlerts, forKey: "showTravelTimeAlerts") }
    }

    @Published var defaultTravelMode: TravelMode {
        didSet { saveSetting(defaultTravelMode.rawValue, forKey: "defaultTravelMode") }
    }

    @Published var preferredMapProvider: MapProvider {
        didSet { saveSetting(preferredMapProvider.rawValue, forKey: "preferredMapProvider") }
    }

    @Published var doubleBookingPreference: DoubleBookingPreference {
        didSet { saveSetting(doubleBookingPreference.rawValue, forKey: "doubleBookingPreference") }
    }

    @Published var customCalendarColors: [String: [String: String]] {
        didSet { saveCustomCalendarColors() }
    }

    nonisolated static let defaultFrontMatterTemplate = "title: {title}\ndate: {date}\nend_date: {end_date}\nduration: {duration}\nengine: {engine}\nlocale: {locale}\nword_count: {words}\nspeakers: [{speakers}]\nattendees: {attendees}\nattendee_names: [{attendee_names}]\nconference_link: {link}\ncalendar_event_id: {event_id}\ntags: [meeting]"

    nonisolated private static let legacyFrontMatterDefault = "tags: [meeting]\nspeakers: [{speakers}]\nattendees: {attendees}\nduration: {duration}\nengine: {engine}"

    // MARK: - Notetaker settings

    @Published var transcriptionIndicatorMode: TranscriptionIndicatorMode {
        didSet { saveSetting(transcriptionIndicatorMode.rawValue, forKey: "transcriptionIndicatorMode") }
    }

    @Published var notetakerEnabled: Bool {
        didSet { saveSetting(notetakerEnabled, forKey: "notetakerEnabled") }
    }

    @Published var autoOfferTranscription: Bool {
        didSet { saveSetting(autoOfferTranscription, forKey: "autoOfferTranscription") }
    }

    @Published var transcriptionEngine: TranscriptionEngineType {
        didSet { saveSetting(transcriptionEngine.rawValue, forKey: "transcriptionEngine") }
    }

    @Published var transcriptionLocale: String {
        didSet { saveSetting(transcriptionLocale, forKey: "transcriptionLocale") }
    }

    @Published var notesFolderPath: String {
        didSet { saveSetting(notesFolderPath, forKey: "notesFolderPath") }
    }

    /// Security-scoped bookmark for the user-chosen notes folder.
    /// Stored in UserDefaults only (not iCloud -- bookmarks are device-specific).
    var notesFolderBookmark: Data? {
        get { UserDefaults.standard.data(forKey: "notesFolderBookmark") }
        set { UserDefaults.standard.set(newValue, forKey: "notesFolderBookmark") }
    }

    /// Resolve the security-scoped bookmark to a URL the sandbox allows access to.
    /// Returns nil if no bookmark is stored or if the bookmark is stale.
    func resolveNotesFolderURL() -> URL? {
        guard let bookmarkData = notesFolderBookmark else {
            return nil
        }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            Logger.settings.error("Failed to resolve notes folder bookmark")
            return nil
        }

        if isStale {
            Logger.settings.warning("Notes folder bookmark is stale, re-saving")
            saveNotesFolderBookmark(for: url)
        }

        return url
    }

    /// Create and persist a security-scoped bookmark for a folder URL.
    func saveNotesFolderBookmark(for url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            notesFolderBookmark = bookmarkData
            notesFolderPath = url.path
        } catch {
            Logger.settings.error("Failed to create bookmark for notes folder: \(error.localizedDescription)")
        }
    }

    @Published var calendarSubfoldersEnabled: Bool {
        didSet { saveSetting(calendarSubfoldersEnabled, forKey: "calendarSubfoldersEnabled") }
    }

    @Published var calendarSubfolderMappings: [String: String] {
        didSet { saveSubfolderMappings() }
    }

    @Published var fileNamingSchema: String {
        didSet { saveSetting(fileNamingSchema, forKey: "fileNamingSchema") }
    }

    @Published var frontMatterTemplate: String {
        didSet { saveSetting(frontMatterTemplate, forKey: "frontMatterTemplate") }
    }

    @Published var speakerDisplayName: String {
        didSet { saveSetting(speakerDisplayName, forKey: "speakerDisplayName") }
    }

    @Published var othersDisplayName: String {
        didSet { saveSetting(othersDisplayName, forKey: "othersDisplayName") }
    }

    @Published var summarizationPlatform: SummarizationPlatform {
        didSet { saveSetting(summarizationPlatform.rawValue, forKey: "summarizationPlatform") }
    }

    // MARK: - Initialization

    private init() {
        self.accounts = []

        // CRITICAL: Set this flag BEFORE initializing properties to prevent crash
        // during initialization due to infinite iCloud sync loop
        self.isUpdatingFromiCloud = true
        defer { self.isUpdatingFromiCloud = false }

        iCloudStore.synchronize()

        self.notificationsEnabled = iCloudStore.object(forKey: "notificationsEnabled") as? Bool
            ?? UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        self.oneMinuteWarningEnabled = iCloudStore.object(forKey: "oneMinuteWarningEnabled") as? Bool
            ?? UserDefaults.standard.object(forKey: "oneMinuteWarningEnabled") as? Bool ?? true
        self.notificationTracking = NotificationTracking()

        let meetAppRawValue = iCloudStore.string(forKey: "defaultMeetApp")
            ?? UserDefaults.standard.string(forKey: "defaultMeetApp") ?? MeetAppType.defaultBrowser.rawValue
        self.defaultMeetApp = MeetAppType(rawValue: meetAppRawValue) ?? .defaultBrowser

        if let displayModeRaw = iCloudStore.string(forKey: "menuBarDisplayMode") ?? UserDefaults.standard.string(forKey: "menuBarDisplayMode") {
            self.menuBarDisplayMode = MenuBarDisplayMode(rawValue: displayModeRaw) ?? .none
        } else if let legacyShowInMenuBar = iCloudStore.object(forKey: "showInMenuBar") as? Bool ?? UserDefaults.standard.object(forKey: "showInMenuBar") as? Bool {
            self.menuBarDisplayMode = legacyShowInMenuBar ? .inMenuBar : .none
        } else {
            self.menuBarDisplayMode = .none
        }

        self.onlyShowMeetingsWithAttendees = iCloudStore.object(forKey: "onlyShowMeetingsWithAttendees") as? Bool
            ?? UserDefaults.standard.object(forKey: "onlyShowMeetingsWithAttendees") as? Bool ?? false
        self.muteSounds = iCloudStore.object(forKey: "muteSounds") as? Bool
            ?? UserDefaults.standard.object(forKey: "muteSounds") as? Bool ?? false
        self.launchAtLogin = iCloudStore.object(forKey: "launchAtLogin") as? Bool
            ?? UserDefaults.standard.object(forKey: "launchAtLogin") as? Bool ?? false

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

        // Notetaker settings
        let indicatorRaw = iCloudStore.string(forKey: "transcriptionIndicatorMode")
            ?? UserDefaults.standard.string(forKey: "transcriptionIndicatorMode") ?? TranscriptionIndicatorMode.menuBarDropdown.rawValue
        self.transcriptionIndicatorMode = TranscriptionIndicatorMode(rawValue: indicatorRaw) ?? .menuBarDropdown

        self.notetakerEnabled = iCloudStore.object(forKey: "notetakerEnabled") as? Bool
            ?? UserDefaults.standard.object(forKey: "notetakerEnabled") as? Bool ?? true
        self.autoOfferTranscription = iCloudStore.object(forKey: "autoOfferTranscription") as? Bool
            ?? UserDefaults.standard.object(forKey: "autoOfferTranscription") as? Bool ?? true

        let engineRaw = iCloudStore.string(forKey: "transcriptionEngine")
            ?? UserDefaults.standard.string(forKey: "transcriptionEngine") ?? TranscriptionEngineType.apple.rawValue
        self.transcriptionEngine = TranscriptionEngineType(rawValue: engineRaw) ?? .apple

        self.transcriptionLocale = iCloudStore.string(forKey: "transcriptionLocale")
            ?? UserDefaults.standard.string(forKey: "transcriptionLocale") ?? "en_US"

        self.calendarSubfoldersEnabled = iCloudStore.object(forKey: "calendarSubfoldersEnabled") as? Bool
            ?? UserDefaults.standard.object(forKey: "calendarSubfoldersEnabled") as? Bool ?? false
        if let mappingsData = iCloudStore.data(forKey: "calendarSubfolderMappings")
            ?? UserDefaults.standard.data(forKey: "calendarSubfolderMappings"),
           let decoded = try? JSONDecoder().decode([String: String].self, from: mappingsData) {
            self.calendarSubfolderMappings = decoded
        } else {
            self.calendarSubfolderMappings = [:]
        }

        let defaultNotesPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? "~/Documents"
        self.notesFolderPath = iCloudStore.string(forKey: "notesFolderPath")
            ?? UserDefaults.standard.string(forKey: "notesFolderPath") ?? defaultNotesPath + "/MeetingNotes"
        self.fileNamingSchema = iCloudStore.string(forKey: "fileNamingSchema")
            ?? UserDefaults.standard.string(forKey: "fileNamingSchema") ?? "{yyyy}{MM}{dd}-{title}"
        let storedFrontMatter = iCloudStore.string(forKey: "frontMatterTemplate")
            ?? UserDefaults.standard.string(forKey: "frontMatterTemplate")
        let hasMigrated = UserDefaults.standard.bool(forKey: "frontMatterTemplateMigratedV2")
        if !hasMigrated, let stored = storedFrontMatter, stored == Self.legacyFrontMatterDefault {
            self.frontMatterTemplate = Self.defaultFrontMatterTemplate
            UserDefaults.standard.set(true, forKey: "frontMatterTemplateMigratedV2")
        } else {
            self.frontMatterTemplate = storedFrontMatter ?? Self.defaultFrontMatterTemplate
        }
        self.speakerDisplayName = iCloudStore.string(forKey: "speakerDisplayName")
            ?? UserDefaults.standard.string(forKey: "speakerDisplayName") ?? "Me"
        self.othersDisplayName = iCloudStore.string(forKey: "othersDisplayName")
            ?? UserDefaults.standard.string(forKey: "othersDisplayName") ?? "Others"

        let platformRaw = iCloudStore.string(forKey: "summarizationPlatform")
            ?? UserDefaults.standard.string(forKey: "summarizationPlatform") ?? SummarizationPlatform.openai.rawValue
        self.summarizationPlatform = SummarizationPlatform(rawValue: platformRaw) ?? .openai

        loadAccounts()
        loadNotificationTracking()
        loadCustomCalendarColors()

        syncAllSettingsFromiCloudToUserDefaults()
        setupiCloudSync()
        verifyLoginItemStatus()
        syncAccountListToiCloud()
    }

    // MARK: - Account management

    func loadAccounts() {
        var syncedAccounts: [SyncedAccountInfo] = []
        if let data = iCloudStore.data(forKey: "syncedAccounts"),
           let decoded = try? JSONDecoder().decode([SyncedAccountInfo].self, from: data) {
            syncedAccounts = decoded
            Logger.sync.debug("Loaded \(syncedAccounts.count) accounts from iCloud")
        }

        var localAccounts: [CalendarAccount] = []
        if let data = UserDefaults.standard.data(forKey: "accounts") {
            do {
                localAccounts = try JSONDecoder().decode([CalendarAccount].self, from: data)
                Logger.sync.debug("Loaded \(localAccounts.count) accounts from local storage")
            } catch {
                Logger.sync.error("Error loading local accounts: \(error)")
            }
        }

        var mergedAccounts = localAccounts

        for syncedAccount in syncedAccounts {
            if !mergedAccounts.contains(where: { $0.email == syncedAccount.email }) {
                let newAccount = CalendarAccount(
                    email: syncedAccount.email,
                    provider: syncedAccount.provider,
                    isEnabled: syncedAccount.isEnabled,
                    selectedCalendarIds: [],
                    authStatus: .needsAuth,
                    lastAuthError: nil
                )
                mergedAccounts.append(newAccount)
                Logger.sync.info("Added new account from iCloud: \(syncedAccount.email, privacy: .private) - needs authentication")
            } else {
                if let index = mergedAccounts.firstIndex(where: { $0.email == syncedAccount.email }) {
                    mergedAccounts[index].isEnabled = syncedAccount.isEnabled
                }
            }
        }

        for i in 0..<mergedAccounts.count {
            let account = mergedAccounts[i]
            let hasAccessToken = KeychainManager.shared.retrieveAccessToken(forAccount: account.email) != nil
            let hasRefreshToken = KeychainManager.shared.retrieveRefreshToken(forAccount: account.email) != nil

            if !hasAccessToken && !hasRefreshToken {
                mergedAccounts[i].authStatus = .needsAuth
                Logger.sync.info("Account \(account.email, privacy: .private) has no local tokens - marked as needsAuth")
            } else if mergedAccounts[i].authStatus == .needsAuth {
                mergedAccounts[i].authStatus = .valid
                Logger.sync.debug("Account \(account.email, privacy: .private) now has tokens - marked as valid")
            }
        }

        self.accounts = mergedAccounts
        Logger.sync.debug("Successfully loaded \(mergedAccounts.count) total accounts")
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

    // MARK: - Persistence helpers

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

    func loadCustomCalendarColors() {
        if let data = UserDefaults.standard.data(forKey: "customCalendarColors"),
           let decoded = try? JSONDecoder().decode([String: [String: String]].self, from: data) {
            self.customCalendarColors = decoded
        }
    }

    private func saveCustomCalendarColors() {
        if let encoded = try? JSONEncoder().encode(customCalendarColors) {
            UserDefaults.standard.set(encoded, forKey: "customCalendarColors")

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

    private func saveSubfolderMappings() {
        if let encoded = try? JSONEncoder().encode(calendarSubfolderMappings) {
            UserDefaults.standard.set(encoded, forKey: "calendarSubfolderMappings")
            if !isUpdatingFromiCloud {
                iCloudStore.set(encoded, forKey: "calendarSubfolderMappings")
                iCloudStore.synchronize()
            }
        }
    }

    func saveSetting<T>(_ value: T, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)

        if !isUpdatingFromiCloud {
            iCloudStore.set(value, forKey: key)
            iCloudStore.synchronize()
        }
    }

    // MARK: - Login item

    private func verifyLoginItemStatus() {
        let systemStatus = SMAppService.mainApp.status

        switch systemStatus {
        case .enabled:
            if !launchAtLogin {
                Logger.settings.warning("Login item is enabled in system but setting is false - syncing")
                UserDefaults.standard.set(true, forKey: "launchAtLogin")
                iCloudStore.set(true, forKey: "launchAtLogin")
                iCloudStore.synchronize()
                Task { @MainActor [weak self] in
                    self?.launchAtLogin = true
                }
            }
        case .notRegistered:
            if launchAtLogin {
                Logger.settings.warning("Login item setting is true but not registered - registering")
                do {
                    try SMAppService.mainApp.register()
                } catch {
                    Logger.settings.error("Failed to register login item: \(error)")
                }
            }
        case .requiresApproval:
            Logger.settings.warning("Login item requires approval in System Settings")
        case .notFound:
            Logger.settings.warning("Login item service not found")
        @unknown default:
            Logger.settings.warning("Unknown login item status: \(systemStatus.rawValue)")
        }
    }

    private func updateLoginItem() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Logger.settings.error("Failed to update login item: \(error)")
        }
    }

    // MARK: - URL opening (delegates to URLOpener)

    func openURL(_ url: URL, accountEmail: String? = nil) {
        URLOpener.open(url, accountEmail: accountEmail)
    }
}
