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

    /// User-facing opt-in for mirroring preferences (Settings drawer toggles,
    /// transcription defaults, menu-bar layout, etc.) to the iCloud
    /// key-value store. Defaults to true so existing users keep the
    /// behavior they had before the toggle existed. Persisted in
    /// UserDefaults only so the preference itself doesn't ride the sync it
    /// controls.
    @Published var settingsSyncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(settingsSyncEnabled, forKey: "settingsSyncEnabled")
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

    // MARK: - Init readers
    //
    // The four helpers below replace ~30 instances of the
    // `iCloudStore.object(forKey:) ?? UserDefaults.standard.object(forKey:) ?? default`
    // boilerplate that used to live in `init`. Adding a new setting now
    // means picking the right helper instead of typing the whole chain.

    private static let iCloud = NSUbiquitousKeyValueStore.default
    private static let userDefaults = UserDefaults.standard

    private static func readBool(_ key: String, default defaultValue: Bool) -> Bool {
        readOptionalBool(key) ?? defaultValue
    }

    private static func readOptionalBool(_ key: String) -> Bool? {
        (iCloud.object(forKey: key) as? Bool) ?? (userDefaults.object(forKey: key) as? Bool)
    }

    private static func readInt(_ key: String, default defaultValue: Int) -> Int {
        (iCloud.object(forKey: key) as? Int) ?? (userDefaults.object(forKey: key) as? Int) ?? defaultValue
    }

    private static func readString(_ key: String, default defaultValue: String) -> String {
        readOptionalString(key) ?? defaultValue
    }

    private static func readOptionalString(_ key: String) -> String? {
        iCloud.string(forKey: key) ?? userDefaults.string(forKey: key)
    }

    private static func readOptionalData(_ key: String) -> Data? {
        iCloud.data(forKey: key) ?? userDefaults.data(forKey: key)
    }

    private static func readEnum<T: RawRepresentable>(_ key: String, default defaultValue: T) -> T where T.RawValue == String {
        guard let raw = readOptionalString(key), let value = T(rawValue: raw) else { return defaultValue }
        return value
    }

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

        // The opt-in itself isn't synced, so the user has to take the action
        // on each device. Defaults to true to preserve the legacy
        // always-synced behavior.
        self.settingsSyncEnabled = UserDefaults.standard.object(forKey: "settingsSyncEnabled") as? Bool ?? true

        // Bools — read iCloud first, then UserDefaults, then default.
        self.notificationsEnabled         = Self.readBool("notificationsEnabled",       default: true)
        self.oneMinuteWarningEnabled      = Self.readBool("oneMinuteWarningEnabled",    default: true)
        self.onlyShowMeetingsWithAttendees = Self.readBool("onlyShowMeetingsWithAttendees", default: false)
        self.muteSounds                   = Self.readBool("muteSounds",                 default: false)
        self.launchAtLogin                = Self.readBool("launchAtLogin",              default: false)
        self.menuBarShowIcon              = Self.readBool("menuBarShowIcon",            default: true)
        self.menuBarShowTitle             = Self.readBool("menuBarShowTitle",           default: true)
        self.menuBarShowTime              = Self.readBool("menuBarShowTime",            default: false)
        self.menuBarShowCountdown         = Self.readBool("menuBarShowCountdown",       default: false)
        self.showAllDayInMenuBar          = Self.readBool("showAllDayInMenuBar",        default: false)
        self.showMeetingCountBadge        = Self.readBool("showMeetingCountBadge",      default: true)
        self.showTravelTimeAlerts         = Self.readBool("showTravelTimeAlerts",       default: true)
        self.notetakerEnabled             = Self.readBool("notetakerEnabled",           default: true)
        self.autoOfferTranscription       = Self.readBool("autoOfferTranscription",     default: true)
        self.calendarSubfoldersEnabled    = Self.readBool("calendarSubfoldersEnabled",  default: false)

        // Ints
        self.menuBarThresholdMinutes      = Self.readInt("menuBarThresholdMinutes",     default: 15)

        // Strings (free-form text, no enum decode)
        self.transcriptionLocale          = Self.readString("transcriptionLocale",      default: "en_US")
        self.fileNamingSchema             = Self.readString("fileNamingSchema",         default: "{yyyy}{MM}{dd}-{title}")
        self.speakerDisplayName           = Self.readString("speakerDisplayName",       default: "Me")
        self.othersDisplayName            = Self.readString("othersDisplayName",        default: "Others")

        // Enums (RawRepresentable<String>) with safe fallback to default case.
        self.defaultMeetApp                = Self.readEnum("defaultMeetApp",            default: .defaultBrowser)
        self.defaultTravelMode             = Self.readEnum("defaultTravelMode",         default: .driving)
        self.preferredMapProvider          = Self.readEnum("preferredMapProvider",      default: .apple)
        self.doubleBookingPreference       = Self.readEnum("doubleBookingPreference",   default: .fewerAttendees)
        self.transcriptionIndicatorMode    = Self.readEnum("transcriptionIndicatorMode", default: .menuBarDropdown)
        self.summarizationPlatform         = Self.readEnum("summarizationPlatform",     default: .openai)

        // menuBarDisplayMode: legacy `showInMenuBar` Bool needs to migrate
        // forward into the newer enum-based key.
        if let raw = Self.readOptionalString("menuBarDisplayMode") {
            self.menuBarDisplayMode = MenuBarDisplayMode(rawValue: raw) ?? .none
        } else if let legacy = Self.readOptionalBool("showInMenuBar") {
            self.menuBarDisplayMode = legacy ? .inMenuBar : .none
        } else {
            self.menuBarDisplayMode = .none
        }

        // transcriptionEngine: coerce non-implemented engines (placeholders
        // that were briefly user-selectable) back to Apple on load.
        let loadedEngine: TranscriptionEngineType = Self.readEnum("transcriptionEngine", default: .apple)
        self.transcriptionEngine = loadedEngine.isImplemented ? loadedEngine : .apple

        // Subfolder mappings — encoded as Data, not a primitive.
        if let mappingsData = Self.readOptionalData("calendarSubfolderMappings"),
           let decoded = try? JSONDecoder().decode([String: String].self, from: mappingsData) {
            self.calendarSubfolderMappings = decoded
        } else {
            self.calendarSubfolderMappings = [:]
        }

        // Notes folder path — default depends on FileManager so it's separate
        // from the simple-string helper.
        let defaultNotesPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? "~/Documents"
        self.notesFolderPath = Self.readString("notesFolderPath", default: defaultNotesPath + "/MeetingNotes")

        // Front-matter template — has a one-shot v1→v2 default migration.
        let storedFrontMatter = Self.readOptionalString("frontMatterTemplate")
        let hasMigrated = UserDefaults.standard.bool(forKey: "frontMatterTemplateMigratedV2")
        if !hasMigrated, let stored = storedFrontMatter, stored == Self.legacyFrontMatterDefault {
            self.frontMatterTemplate = Self.defaultFrontMatterTemplate
            UserDefaults.standard.set(true, forKey: "frontMatterTemplateMigratedV2")
        } else {
            self.frontMatterTemplate = storedFrontMatter ?? Self.defaultFrontMatterTemplate
        }

        // Defaults for properties that don't read at init.
        self.notificationTracking = NotificationTracking()
        self.customCalendarColors = [:]

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
        guard let encoded = try? JSONEncoder().encode(customCalendarColors) else { return }
        UserDefaults.standard.set(encoded, forKey: "customCalendarColors")

        // Respect the user's settings-sync opt-in. Calendar colors are a user
        // preference and shouldn't ride iCloud unless they've consented.
        if !isUpdatingFromiCloud && settingsSyncEnabled {
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

    private func saveSubfolderMappings() {
        guard let encoded = try? JSONEncoder().encode(calendarSubfolderMappings) else { return }
        UserDefaults.standard.set(encoded, forKey: "calendarSubfolderMappings")
        if !isUpdatingFromiCloud && settingsSyncEnabled {
            iCloudStore.set(encoded, forKey: "calendarSubfolderMappings")
            iCloudStore.synchronize()
        }
    }

    func saveSetting<T>(_ value: T, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)

        // Skip the iCloud write when the user has opted out of settings sync.
        // Local UserDefaults is always the source of truth for this device.
        if !isUpdatingFromiCloud && settingsSyncEnabled {
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
