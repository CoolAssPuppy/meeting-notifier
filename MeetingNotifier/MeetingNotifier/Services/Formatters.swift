//
//  Formatters.swift
//  MeetingNotifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import Foundation

/// Cached DateFormatters. Allocating a DateFormatter is expensive; the popover
/// re-renders often so they need to be static.
enum AppDateFormatters {
    static let shortTime: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "H:mm"
        return df
    }()

    static let weekdayMonthDay: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEE MMM d"
        return df
    }()

    /// "April 21, 2026" — the subscription card's renewal date.
    static let longDate: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .long
        df.timeStyle = .none
        return df
    }()

    /// Parses an ISO 8601 timestamp with or without fractional seconds. Polar
    /// sends fractional seconds on some fields and not others, and
    /// `ISO8601DateFormatter` returns nil rather than tolerating the mismatch.
    static func parseISO8601(_ string: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: string) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }
}

extension Error {
    /// The message to show a person for a thrown error. Prefers a
    /// `LocalizedError` description, because ours are written for humans, and
    /// falls back to the `NSError` description, which is where URLError's "The
    /// Internet connection appears to be offline." and friends live.
    var userMessage: String {
        if let localized = (self as? LocalizedError)?.errorDescription, !localized.isEmpty {
            return localized
        }
        return (self as NSError).localizedDescription
    }
}

extension Date {
    /// "14:30" — local 24-hour time.
    var shortTimeString: String { AppDateFormatters.shortTime.string(from: self) }

    /// "TUE APR 21" — uppercased weekday + month + day for section headers.
    var headerDateString: String {
        AppDateFormatters.weekdayMonthDay.string(from: self).uppercased()
    }
}

extension Bundle {
    /// "1.2.0" — marketing version only.
    var appVersionString: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// An Info.plist string that the build substitutes from an xcodebuild
    /// setting, or nil when it was never set.
    ///
    /// An unresolved build setting does not arrive as an empty string: it
    /// arrives as the literal "$(NAME)". Every reader of these keys has to know
    /// that, so the rule lives here once rather than in each of them.
    func substitutedString(forInfoDictionaryKey key: String) -> String? {
        guard let raw = object(forInfoDictionaryKey: key) as? String else { return nil }
        if raw.isEmpty || raw.hasPrefix("$(") { return nil }
        return raw
    }

    /// "1.2.0 (build 4)" — marketing version + build number.
    var appVersionWithBuild: String {
        let v = appVersionString
        let b = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (build \(b))"
    }
}
