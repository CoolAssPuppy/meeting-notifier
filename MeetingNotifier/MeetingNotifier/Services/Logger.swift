//
//  Logger.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation
import os

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.strategicnerds.meetingnotifier"

    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let sync = Logger(subsystem: subsystem, category: "sync")
    static let calendar = Logger(subsystem: subsystem, category: "calendar")
    static let location = Logger(subsystem: subsystem, category: "location")
    static let keychain = Logger(subsystem: subsystem, category: "keychain")
    static let notifications = Logger(subsystem: subsystem, category: "notifications")
    static let storekit = Logger(subsystem: subsystem, category: "storekit")
    static let settings = Logger(subsystem: subsystem, category: "settings")
    static let transcription = Logger(subsystem: subsystem, category: "transcription")
    static let audio = Logger(subsystem: subsystem, category: "audio")
}
