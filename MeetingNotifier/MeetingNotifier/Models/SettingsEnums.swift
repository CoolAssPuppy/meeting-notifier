//
//  SettingsEnums.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import AppKit
import Foundation

// MARK: - Synced account data for iCloud (excludes sensitive info)

struct SyncedAccountInfo: Codable {
    let email: String
    let provider: CalendarProvider
    var isEnabled: Bool
}

// MARK: - Menu bar display mode

enum MenuBarDisplayMode: String, CaseIterable, Codable, Identifiable {
    case none = "None"
    case inMenuBar = "In Menu Bar"
    case peekWindow = "Peek Below Menu Bar"

    var id: String { rawValue }
}

// MARK: - Meet app type

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

// MARK: - Travel mode

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

// MARK: - Map provider

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

// MARK: - Double booking preference

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

// MARK: - Dropdown style

enum DropDownStyle: String, CaseIterable, Identifiable {
    case simple = "Simple"
    case glass = "Glass"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .simple:
            return "Clean, minimal Apple-style design"
        case .glass:
            return "Modern glassmorphic design with effects"
        }
    }
}
