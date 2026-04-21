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

    /// "1.2.0 (build 4)" — marketing version + build number.
    var appVersionWithBuild: String {
        let v = appVersionString
        let b = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (build \(b))"
    }
}
