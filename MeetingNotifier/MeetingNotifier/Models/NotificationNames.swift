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

    // Notetaker notifications
    static let microphoneDidActivate = Notification.Name("microphoneDidActivate")
    static let microphoneDidDeactivate = Notification.Name("microphoneDidDeactivate")
    static let transcriptionDidStart = Notification.Name("transcriptionDidStart")
    static let transcriptionDidStop = Notification.Name("transcriptionDidStop")
    static let startTranscriptionRequested = Notification.Name("startTranscriptionRequested")
    static let stopTranscriptionRequested = Notification.Name("stopTranscriptionRequested")
}
