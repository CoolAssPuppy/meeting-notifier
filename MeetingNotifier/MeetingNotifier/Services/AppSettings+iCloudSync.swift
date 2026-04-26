//
//  AppSettings+iCloudSync.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation
import os

// MARK: - iCloud sync

extension AppSettings {
    func setupiCloudSync() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudStoreDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: iCloudStore
        )

        verifyiCloudAvailability()
        iCloudStore.synchronize()
    }

    /// Writes a sentinel key and reports whether the ubiquity KV store is
    /// actually provisioned. A `false` from `synchronize()` means either the
    /// user is signed out of iCloud or the app's provisioning profile is
    /// missing the Key-Value Storage capability. See SPARKLE.md for how to
    /// enable it in the Apple Developer portal.
    private func verifyiCloudAvailability() {
        let probeKey = "__kvstore_probe_last_launch"
        iCloudStore.set(Date().timeIntervalSince1970, forKey: probeKey)
        let persisted = iCloudStore.synchronize()
        if persisted {
            Logger.sync.info("iCloud KV store is provisioned and reachable")
        } else {
            Logger.sync.error("iCloud KV store NOT provisioned — check entitlement and Apple Developer portal Key-Value Storage capability")
        }
    }

    func syncAllSettingsFromiCloudToUserDefaults() {
        // Respect the user's settings-sync preference. Account list and calendar
        // color sync are orthogonal and always on.
        guard settingsSyncEnabled else {
            Logger.sync.debug("Skipping startup iCloud-to-UserDefaults sync - settings sync is off")
            return
        }
        let settingsKeys = [
            "notificationsEnabled", "oneMinuteWarningEnabled", "defaultMeetApp",
            "menuBarDisplayMode", "onlyShowMeetingsWithAttendees", "muteSounds", "launchAtLogin",
            "menuBarShowIcon", "menuBarShowTitle", "menuBarShowTime", "menuBarShowCountdown",
            "menuBarThresholdMinutes", "showAllDayInMenuBar", "showMeetingCountBadge",
            "showTravelTimeAlerts", "defaultTravelMode", "preferredMapProvider", "doubleBookingPreference",
            "transcriptionIndicatorMode",
            "calendarSubfoldersEnabled", "calendarSubfolderMappings",
            "notetakerEnabled", "autoOfferTranscription", "transcriptionEngine",
            "transcriptionLocale", "notesFolderPath", "fileNamingSchema",
            "frontMatterTemplate", "speakerDisplayName", "othersDisplayName",
            "summarizationPlatform"
        ]

        for key in settingsKeys {
            if let value = iCloudStore.object(forKey: key) {
                UserDefaults.standard.set(value, forKey: key)
            }
        }
    }

    func syncAccountListToiCloud() {
        if isUpdatingFromiCloud { return }
        // Account list sync is gated by the user's settings-sync opt-in, just
        // like every other preference. Users who opt out keep their account
        // list device-local; first-run on a new Mac requires re-adding accounts.
        guard settingsSyncEnabled else { return }

        let syncedAccounts = accounts.map { account in
            SyncedAccountInfo(
                email: account.email,
                provider: account.provider,
                isEnabled: account.isEnabled
            )
        }

        if let encoded = try? JSONEncoder().encode(syncedAccounts) {
            iCloudStore.set(encoded, forKey: "syncedAccounts")
            iCloudStore.synchronize()
            Logger.sync.debug("Synced \(syncedAccounts.count) accounts to iCloud")
        }
    }

    @objc nonisolated func iCloudStoreDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else {
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }

            // If the user has opted out of sync, ignore inbound iCloud changes
            // entirely. Local UserDefaults stays the source of truth.
            guard self.settingsSyncEnabled else {
                Logger.sync.debug("Ignoring inbound iCloud change — settings sync is off")
                return
            }

            self.isUpdatingFromiCloud = true
            defer { self.isUpdatingFromiCloud = false }

            let store = NSUbiquitousKeyValueStore.default

            for key in keys {
                if let value = store.object(forKey: key) {
                    UserDefaults.standard.set(value, forKey: key)
                }
            }

            self.applyiCloudChanges(forKeys: keys)
        }
    }

    private func applyiCloudChanges(forKeys keys: [String]) {
        let changed = Set(keys)
        let defaults = UserDefaults.standard

        // Composite keys with custom shape
        if changed.contains("customCalendarColors") {
            loadCustomCalendarColors()
        }
        if changed.contains("syncedAccounts") {
            Logger.sync.info("Account list changed in iCloud - reloading accounts")
            loadAccounts()
        }

        // Bools — apply only if iCloud advertised that key changed.
        applyBool("notificationsEnabled",         changed: changed, defaults: defaults) { self.notificationsEnabled = $0 }
        applyBool("oneMinuteWarningEnabled",      changed: changed, defaults: defaults) { self.oneMinuteWarningEnabled = $0 }
        applyBool("onlyShowMeetingsWithAttendees", changed: changed, defaults: defaults) { self.onlyShowMeetingsWithAttendees = $0 }
        applyBool("muteSounds",                   changed: changed, defaults: defaults) { self.muteSounds = $0 }
        applyBool("launchAtLogin",                changed: changed, defaults: defaults) { self.launchAtLogin = $0 }
        applyBool("menuBarShowIcon",              changed: changed, defaults: defaults) { self.menuBarShowIcon = $0 }
        applyBool("menuBarShowTitle",             changed: changed, defaults: defaults) { self.menuBarShowTitle = $0 }
        applyBool("menuBarShowTime",              changed: changed, defaults: defaults) { self.menuBarShowTime = $0 }
        applyBool("menuBarShowCountdown",         changed: changed, defaults: defaults) { self.menuBarShowCountdown = $0 }
        applyBool("showAllDayInMenuBar",          changed: changed, defaults: defaults) { self.showAllDayInMenuBar = $0 }
        applyBool("showMeetingCountBadge",        changed: changed, defaults: defaults) { self.showMeetingCountBadge = $0 }
        applyBool("showTravelTimeAlerts",         changed: changed, defaults: defaults) { self.showTravelTimeAlerts = $0 }
        applyBool("notetakerEnabled",             changed: changed, defaults: defaults) { self.notetakerEnabled = $0 }
        applyBool("autoOfferTranscription",       changed: changed, defaults: defaults) { self.autoOfferTranscription = $0 }
        applyBool("calendarSubfoldersEnabled",    changed: changed, defaults: defaults) { self.calendarSubfoldersEnabled = $0 }

        // Ints
        if changed.contains("menuBarThresholdMinutes") {
            self.menuBarThresholdMinutes = defaults.integer(forKey: "menuBarThresholdMinutes")
        }

        // Free-form strings (preserve current value if defaults missing).
        applyString("transcriptionLocale",        changed: changed, defaults: defaults, default: "en_US") { self.transcriptionLocale = $0 }
        applyString("notesFolderPath",            changed: changed, defaults: defaults, default: self.notesFolderPath) { self.notesFolderPath = $0 }
        applyString("fileNamingSchema",           changed: changed, defaults: defaults, default: "{yyyy}{MM}{dd}-{title}") { self.fileNamingSchema = $0 }
        applyString("frontMatterTemplate",        changed: changed, defaults: defaults, default: "") { self.frontMatterTemplate = $0 }
        applyString("speakerDisplayName",         changed: changed, defaults: defaults, default: "Me") { self.speakerDisplayName = $0 }
        applyString("othersDisplayName",          changed: changed, defaults: defaults, default: "Others") { self.othersDisplayName = $0 }

        // Enums (RawRepresentable<String>) — fall back to current value on parse failure.
        applyEnum("menuBarDisplayMode",           changed: changed, defaults: defaults, current: self.menuBarDisplayMode) { self.menuBarDisplayMode = $0 }
        applyEnum("defaultMeetApp",               changed: changed, defaults: defaults, current: self.defaultMeetApp) { self.defaultMeetApp = $0 }
        applyEnum("defaultTravelMode",            changed: changed, defaults: defaults, current: self.defaultTravelMode) { self.defaultTravelMode = $0 }
        applyEnum("preferredMapProvider",         changed: changed, defaults: defaults, current: self.preferredMapProvider) { self.preferredMapProvider = $0 }
        applyEnum("doubleBookingPreference",      changed: changed, defaults: defaults, current: self.doubleBookingPreference) { self.doubleBookingPreference = $0 }
        applyEnum("transcriptionIndicatorMode",   changed: changed, defaults: defaults, current: self.transcriptionIndicatorMode) { self.transcriptionIndicatorMode = $0 }
        applyEnum("summarizationPlatform",        changed: changed, defaults: defaults, current: self.summarizationPlatform) { self.summarizationPlatform = $0 }

        // transcriptionEngine has the extra "coerce non-implemented to apple" rule.
        if changed.contains("transcriptionEngine"),
           let raw = defaults.string(forKey: "transcriptionEngine"),
           let loaded = TranscriptionEngineType(rawValue: raw) {
            self.transcriptionEngine = loaded.isImplemented ? loaded : .apple
        }

        // Subfolder mappings — encoded as Data.
        if changed.contains("calendarSubfolderMappings"),
           let data = defaults.data(forKey: "calendarSubfolderMappings"),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            self.calendarSubfolderMappings = decoded
        }
    }

    // MARK: - Apply helpers

    private func applyBool(_ key: String, changed: Set<String>, defaults: UserDefaults, set: (Bool) -> Void) {
        guard changed.contains(key) else { return }
        set(defaults.bool(forKey: key))
    }

    private func applyString(_ key: String, changed: Set<String>, defaults: UserDefaults, default defaultValue: String, set: (String) -> Void) {
        guard changed.contains(key) else { return }
        set(defaults.string(forKey: key) ?? defaultValue)
    }

    private func applyEnum<T: RawRepresentable>(_ key: String, changed: Set<String>, defaults: UserDefaults, current: T, set: (T) -> Void) where T.RawValue == String {
        guard changed.contains(key) else { return }
        if let raw = defaults.string(forKey: key), let value = T(rawValue: raw) {
            set(value)
        } else {
            set(current)
        }
    }
}
