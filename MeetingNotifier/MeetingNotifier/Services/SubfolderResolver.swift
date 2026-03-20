//
//  SubfolderResolver.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation

enum SubfolderResolver {

    static func resolve(
        calendarName: String?,
        isEnabled: Bool,
        mappings: [String: String]
    ) -> String? {
        guard isEnabled, let calendarName, !calendarName.isEmpty else {
            return nil
        }

        let subfolder = mappings[calendarName] ?? calendarName
        return sanitizePath(subfolder)
    }

    private static func sanitizePath(_ name: String) -> String {
        let illegal = CharacterSet(charactersIn: ":/\\?*\"<>|")
        let sanitized = name.unicodeScalars.filter { !illegal.contains($0) }
        return String(String.UnicodeScalarView(sanitized)).trimmingCharacters(in: .whitespaces)
    }
}
