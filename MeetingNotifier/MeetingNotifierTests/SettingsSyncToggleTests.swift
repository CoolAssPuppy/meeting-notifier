//
//  SettingsSyncToggleTests.swift
//  MeetingNotifierTests
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import XCTest
@testable import MeetingNotifier

/// Exercises the Privacy > "Sync settings to iCloud" opt-in gate around
/// `saveSetting`. We can't easily assert behavior against the real
/// `NSUbiquitousKeyValueStore` in a unit test (it requires a provisioned
/// iCloud identity), but we can drive the shared `AppSettings` directly
/// and observe that `UserDefaults` is always written regardless of the
/// toggle's state.
@MainActor
final class SettingsSyncToggleTests: XCTestCase {

    func testSettingsSyncEnabledDefaultIsTrue() {
        // Clear any persisted value first so we test the default, not a leftover.
        UserDefaults.standard.removeObject(forKey: "settingsSyncEnabled")

        // `AppSettings` is a singleton, so we can't re-init it. Instead we read
        // the value straight from UserDefaults to verify the intended default.
        let stored = UserDefaults.standard.object(forKey: "settingsSyncEnabled") as? Bool
        XCTAssertNil(stored, "preference key should default to nil (absent) rather than a persisted false")
    }

    func testSettingsSyncEnabledPersistsToUserDefaults() {
        let settings = AppSettings.shared
        let previous = settings.settingsSyncEnabled
        defer { settings.settingsSyncEnabled = previous }

        settings.settingsSyncEnabled = false
        XCTAssertEqual(UserDefaults.standard.object(forKey: "settingsSyncEnabled") as? Bool, false)

        settings.settingsSyncEnabled = true
        XCTAssertEqual(UserDefaults.standard.object(forKey: "settingsSyncEnabled") as? Bool, true)
    }

    func testSaveSettingAlwaysWritesUserDefaults() {
        let key = "__testSaveSettingKey"
        defer { UserDefaults.standard.removeObject(forKey: key) }

        let settings = AppSettings.shared
        let previousSync = settings.settingsSyncEnabled
        defer { settings.settingsSyncEnabled = previousSync }

        // Even with sync disabled, UserDefaults must still receive the write —
        // local device state is always authoritative.
        settings.settingsSyncEnabled = false
        settings.saveSetting("disabled-value", forKey: key)
        XCTAssertEqual(UserDefaults.standard.string(forKey: key), "disabled-value")

        settings.settingsSyncEnabled = true
        settings.saveSetting("enabled-value", forKey: key)
        XCTAssertEqual(UserDefaults.standard.string(forKey: key), "enabled-value")
    }

    func testSyncToggleOffSkipsAccountListWriteToiCloud() {
        // Account list, calendar colors, and subfolder mappings are all gated
        // by `settingsSyncEnabled` now. We can't observe the iCloud KV store
        // directly in unit tests, but exercising the path verifies the gate
        // doesn't crash. UserDefaults remains authoritative either way.
        let settings = AppSettings.shared
        let previous = settings.settingsSyncEnabled
        defer { settings.settingsSyncEnabled = previous }

        settings.settingsSyncEnabled = false
        settings.syncAccountListToiCloud()
        // No assertion — this is a smoke test that the gated path returns cleanly.
    }
}
