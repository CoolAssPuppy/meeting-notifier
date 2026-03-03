//
//  MeetingLinkParser.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation

enum MeetingLinkParser {
    private static let patterns = [
        "https://meet\\.google\\.com/[a-z-]+",
        "https://[a-z0-9]+\\.zoom\\.us/[^\\s<>\"]+",
        "https://zoom\\.us/[^\\s<>\"]+",
        "https://teams\\.microsoft\\.com/l/meetup-join/[^\\s<>\"]+",
        "https://[a-z0-9-]+\\.webex\\.com/[^\\s<>\"]+",
        "https://webex\\.com/[^\\s<>\"]+"
    ]

    static func findMeetingLink(in text: String) -> String? {
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                if let match = regex.firstMatch(in: text, range: range),
                   let swiftRange = Range(match.range, in: text) {
                    return String(text[swiftRange])
                }
            }
        }
        return nil
    }

    static func isValidMeetingLink(_ url: String) -> Bool {
        let lowercased = url.lowercased()
        return lowercased.contains("meet.google.com") ||
               lowercased.contains("zoom.us") ||
               lowercased.contains("zoom.com") ||
               lowercased.contains("teams.microsoft.com") ||
               lowercased.contains("teams.live.com") ||
               lowercased.contains("webex.com")
    }
}
