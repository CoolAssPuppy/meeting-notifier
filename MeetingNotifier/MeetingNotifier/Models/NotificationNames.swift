//
//  NotificationNames.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation

extension Notification.Name {
    static let addAccountRequested = Notification.Name("addAccountRequested")
    static let settingsRequested = Notification.Name("settingsRequested")
    static let accountsDidUpdate = Notification.Name("accountsDidUpdate")
    static let toggleDropdown = Notification.Name("toggleDropdown")

    // Subscription

    /// The cached entitlement changed. `CalendarDataManager` builds its event
    /// list from the entitlement, so a change has to reach it and the menu
    /// bar, not only the SwiftUI views bound to `EntitlementManager.record`.
    static let entitlementChanged = Notification.Name("entitlementChanged")

    /// Ask the main window to show the paywall. The object is the
    /// `PaywallTrigger` that asked, which the telemetry reads to tell which
    /// entry point converts.
    static let showPaywall = Notification.Name("showPaywall")

    // Notetaker notifications
    static let microphoneDidActivate = Notification.Name("microphoneDidActivate")
    static let microphoneDidDeactivate = Notification.Name("microphoneDidDeactivate")
    static let transcriptionDidStart = Notification.Name("transcriptionDidStart")
    static let transcriptionDidStop = Notification.Name("transcriptionDidStop")
    static let startTranscriptionRequested = Notification.Name("startTranscriptionRequested")
    static let stopTranscriptionRequested = Notification.Name("stopTranscriptionRequested")
}
