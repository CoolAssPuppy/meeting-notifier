//
//  MeetingLinkParser.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation

enum MeetingLinkParser {
    private static let patterns = [
        "https://meet\\.google\\.com/[a-z0-9-]+",
        "https://[a-z0-9-]+\\.zoom\\.us/[^\\s<>\"]+",
        "https://zoom\\.us/[^\\s<>\"]+",
        "https://teams\\.microsoft\\.com/l/meetup-join/[^\\s<>\"]+",
        "https://teams\\.live\\.com/meet/[^\\s<>\"]+",
        "https://[a-z0-9-]+\\.webex\\.com/[^\\s<>\"]+",
        "https://webex\\.com/[^\\s<>\"]+"
    ]

    /// Exact hosts that are accepted as-is.
    private static let exactHosts: Set<String> = [
        "meet.google.com",
        "hangouts.google.com",
        "zoom.us",
        "teams.microsoft.com",
        "teams.live.com",
        "webex.com"
    ]

    /// Domain suffixes where any subdomain is accepted (must match `.<suffix>`).
    private static let allowedSuffixes: [String] = [
        ".zoom.us",
        ".webex.com"
    ]

    static func findMeetingLink(in text: String) -> String? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                continue
            }
            let range = NSRange(text.startIndex..., in: text)
            guard let match = regex.firstMatch(in: text, range: range),
                  let swiftRange = Range(match.range, in: text) else {
                continue
            }
            let candidate = String(text[swiftRange])
            if isValidMeetingLink(candidate) {
                return candidate
            }
        }
        return nil
    }

    /// Strictly validates that the URL is an https meeting link on a known host.
    /// Rejects userinfo components, non-https schemes, and lookalike hosts.
    static func isValidMeetingLink(_ url: String) -> Bool {
        guard let components = URLComponents(string: url),
              let host = components.host?.lowercased(),
              !host.isEmpty else {
            return false
        }

        guard components.scheme?.lowercased() == "https" else { return false }

        // Reject credentials in URL (user@host) which can mask the real host.
        if components.user != nil || components.password != nil {
            return false
        }

        if exactHosts.contains(host) {
            return true
        }

        for suffix in allowedSuffixes where host.hasSuffix(suffix) {
            return true
        }

        return false
    }
}
