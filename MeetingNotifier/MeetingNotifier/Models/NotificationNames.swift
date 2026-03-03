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
}
