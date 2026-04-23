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

        // Honor user opt-in. When disabled, we not only skip writing but also
        // clear any previously-stored iCloud copy so emails don't linger in the
        // KV store after the user turns the feature off.
        guard accountSyncEnabled else {
            if iCloudStore.object(forKey: "syncedAccounts") != nil {
                iCloudStore.removeObject(forKey: "syncedAccounts")
                iCloudStore.synchronize()
                Logger.sync.info("Account sync disabled — cleared stored iCloud account list")
            }
            return
        }

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

    /// Hook called when the opt-in toggle flips. Re-syncs or purges as needed.
    func applyAccountSyncPreferenceChange() {
        syncAccountListToiCloud()
    }

    @objc nonisolated func iCloudStoreDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else {
            return
        }

        let store = NSUbiquitousKeyValueStore.default
        for key in keys {
            if let value = store.object(forKey: key) {
                UserDefaults.standard.set(value, forKey: key)
            }
        }

        Task { @MainActor [weak self] in
            guard let self else { return }

            self.isUpdatingFromiCloud = true
            defer { self.isUpdatingFromiCloud = false }

            self.applyiCloudChanges(forKeys: keys)
        }
    }

    private func applyiCloudChanges(forKeys keys: [String]) {
        if keys.contains("notificationsEnabled") {
            notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        }
        if keys.contains("oneMinuteWarningEnabled") {
            oneMinuteWarningEnabled = UserDefaults.standard.bool(forKey: "oneMinuteWarningEnabled")
        }
        if keys.contains("menuBarDisplayMode") {
            let raw = UserDefaults.standard.string(forKey: "menuBarDisplayMode") ?? MenuBarDisplayMode.none.rawValue
            menuBarDisplayMode = MenuBarDisplayMode(rawValue: raw) ?? .none
        }
        if keys.contains("onlyShowMeetingsWithAttendees") {
            onlyShowMeetingsWithAttendees = UserDefaults.standard.bool(forKey: "onlyShowMeetingsWithAttendees")
        }
        if keys.contains("muteSounds") {
            muteSounds = UserDefaults.standard.bool(forKey: "muteSounds")
        }
        if keys.contains("launchAtLogin") {
            launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        }
        if keys.contains("menuBarShowIcon") {
            menuBarShowIcon = UserDefaults.standard.bool(forKey: "menuBarShowIcon")
        }
        if keys.contains("menuBarShowTitle") {
            menuBarShowTitle = UserDefaults.standard.bool(forKey: "menuBarShowTitle")
        }
        if keys.contains("menuBarShowTime") {
            menuBarShowTime = UserDefaults.standard.bool(forKey: "menuBarShowTime")
        }
        if keys.contains("menuBarShowCountdown") {
            menuBarShowCountdown = UserDefaults.standard.bool(forKey: "menuBarShowCountdown")
        }
        if keys.contains("menuBarThresholdMinutes") {
            menuBarThresholdMinutes = UserDefaults.standard.integer(forKey: "menuBarThresholdMinutes")
        }
        if keys.contains("showAllDayInMenuBar") {
            showAllDayInMenuBar = UserDefaults.standard.bool(forKey: "showAllDayInMenuBar")
        }
        if keys.contains("showMeetingCountBadge") {
            showMeetingCountBadge = UserDefaults.standard.bool(forKey: "showMeetingCountBadge")
        }
        if keys.contains("showTravelTimeAlerts") {
            showTravelTimeAlerts = UserDefaults.standard.bool(forKey: "showTravelTimeAlerts")
        }
        if keys.contains("defaultMeetApp") {
            let raw = UserDefaults.standard.string(forKey: "defaultMeetApp") ?? MeetAppType.defaultBrowser.rawValue
            defaultMeetApp = MeetAppType(rawValue: raw) ?? .defaultBrowser
        }
        if keys.contains("defaultTravelMode") {
            let raw = UserDefaults.standard.string(forKey: "defaultTravelMode") ?? TravelMode.driving.rawValue
            defaultTravelMode = TravelMode(rawValue: raw) ?? .driving
        }
        if keys.contains("preferredMapProvider") {
            let raw = UserDefaults.standard.string(forKey: "preferredMapProvider") ?? MapProvider.apple.rawValue
            preferredMapProvider = MapProvider(rawValue: raw) ?? .apple
        }
        if keys.contains("doubleBookingPreference") {
            let raw = UserDefaults.standard.string(forKey: "doubleBookingPreference") ?? DoubleBookingPreference.fewerAttendees.rawValue
            doubleBookingPreference = DoubleBookingPreference(rawValue: raw) ?? .fewerAttendees
        }
        if keys.contains("transcriptionIndicatorMode") {
            let raw = UserDefaults.standard.string(forKey: "transcriptionIndicatorMode") ?? TranscriptionIndicatorMode.menuBarDropdown.rawValue
            transcriptionIndicatorMode = TranscriptionIndicatorMode(rawValue: raw) ?? .menuBarDropdown
        }
        if keys.contains("calendarSubfoldersEnabled") {
            calendarSubfoldersEnabled = UserDefaults.standard.bool(forKey: "calendarSubfoldersEnabled")
        }
        if keys.contains("calendarSubfolderMappings") {
            if let data = UserDefaults.standard.data(forKey: "calendarSubfolderMappings"),
               let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
                calendarSubfolderMappings = decoded
            }
        }
        if keys.contains("notetakerEnabled") {
            notetakerEnabled = UserDefaults.standard.bool(forKey: "notetakerEnabled")
        }
        if keys.contains("autoOfferTranscription") {
            autoOfferTranscription = UserDefaults.standard.bool(forKey: "autoOfferTranscription")
        }
        if keys.contains("transcriptionEngine") {
            let raw = UserDefaults.standard.string(forKey: "transcriptionEngine") ?? TranscriptionEngineType.apple.rawValue
            let loaded = TranscriptionEngineType(rawValue: raw) ?? .apple
            transcriptionEngine = loaded.isImplemented ? loaded : .apple
        }
        if keys.contains("transcriptionLocale") {
            transcriptionLocale = UserDefaults.standard.string(forKey: "transcriptionLocale") ?? "en_US"
        }
        if keys.contains("notesFolderPath") {
            notesFolderPath = UserDefaults.standard.string(forKey: "notesFolderPath") ?? notesFolderPath
        }
        if keys.contains("fileNamingSchema") {
            fileNamingSchema = UserDefaults.standard.string(forKey: "fileNamingSchema") ?? "{yyyy}{MM}{dd}-{title}"
        }
        if keys.contains("frontMatterTemplate") {
            frontMatterTemplate = UserDefaults.standard.string(forKey: "frontMatterTemplate") ?? ""
        }
        if keys.contains("speakerDisplayName") {
            speakerDisplayName = UserDefaults.standard.string(forKey: "speakerDisplayName") ?? "Me"
        }
        if keys.contains("othersDisplayName") {
            othersDisplayName = UserDefaults.standard.string(forKey: "othersDisplayName") ?? "Others"
        }
        if keys.contains("summarizationPlatform") {
            let raw = UserDefaults.standard.string(forKey: "summarizationPlatform") ?? SummarizationPlatform.openai.rawValue
            summarizationPlatform = SummarizationPlatform(rawValue: raw) ?? .openai
        }
        if keys.contains("customCalendarColors") {
            loadCustomCalendarColors()
        }
        if keys.contains("syncedAccounts") {
            if accountSyncEnabled {
                Logger.sync.info("Account list changed in iCloud - reloading accounts")
                loadAccounts()
            } else {
                Logger.sync.debug("Ignoring syncedAccounts iCloud change — account sync opt-in is off")
            }
        }
    }
}
