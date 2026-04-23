//
//  SubfolderResolver.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation
import os

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

    /// Sanitize a user-supplied folder name.
    ///
    /// Rejects reserved names and traversal segments so the result can only
    /// ever be a single-level folder name beneath the notes directory.
    /// Returns `nil` if the input cannot be safely used.
    static func sanitizePath(_ name: String) -> String? {
        let illegal = CharacterSet(charactersIn: ":/\\?*\"<>|")
        let filtered = name.unicodeScalars.filter { !illegal.contains($0) }
        let trimmed = String(String.UnicodeScalarView(filtered))
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))

        if trimmed.isEmpty { return nil }
        if trimmed == "." || trimmed == ".." { return nil }
        if trimmed.contains("/") || trimmed.contains("\\") { return nil }
        if trimmed.hasPrefix(".") { return nil }

        return trimmed
    }

    /// Resolve the destination folder URL, enforcing that it stays beneath `baseFolderURL`.
    ///
    /// Returns `baseFolderURL` if there is no valid subfolder component. If the candidate
    /// subfolder escapes the base (via any traversal that survives canonicalization) this
    /// also returns `baseFolderURL` as a safe fallback and logs a warning. This is the
    /// only sanctioned way to combine the base folder with user-chosen subfolder names.
    static func resolveFolderURL(
        baseFolderURL: URL,
        calendarName: String?,
        isEnabled: Bool,
        mappings: [String: String]
    ) -> URL {
        guard let subfolder = resolve(
            calendarName: calendarName,
            isEnabled: isEnabled,
            mappings: mappings
        ) else {
            return baseFolderURL
        }

        let candidate = baseFolderURL.appendingPathComponent(subfolder).standardizedFileURL
        let base = baseFolderURL.standardizedFileURL

        if isURL(candidate, containedWithin: base) {
            return candidate
        }

        Logger.transcription.warning("Rejected subfolder outside notes directory: \(subfolder, privacy: .public)")
        return baseFolderURL
    }

    private static func isURL(_ candidate: URL, containedWithin base: URL) -> Bool {
        let baseComponents = base.pathComponents
        let candidateComponents = candidate.pathComponents
        guard candidateComponents.count >= baseComponents.count else { return false }
        return Array(candidateComponents.prefix(baseComponents.count)) == baseComponents
    }
}
