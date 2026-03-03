//
//  URLOpener.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import AppKit

@MainActor
enum URLOpener {
    static func open(_ url: URL, accountEmail: String? = nil) {
        let urlString = url.absoluteString.lowercased()
        let isGoogleMeet = urlString.contains("meet.google.com") || urlString.contains("hangouts.google.com")

        var finalURL = url
        if isGoogleMeet, let email = accountEmail {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            var queryItems = components?.queryItems ?? []
            queryItems.append(URLQueryItem(name: "authuser", value: email))
            components?.queryItems = queryItems
            if let modifiedURL = components?.url {
                finalURL = modifiedURL
            }
        }

        guard isGoogleMeet else {
            NSWorkspace.shared.open(finalURL)
            return
        }

        let meetApp = AppSettings.shared.defaultMeetApp

        switch meetApp {
        case .defaultBrowser:
            NSWorkspace.shared.open(finalURL)

        case .custom:
            if let customPath = UserDefaults.standard.string(forKey: "customMeetAppPath"),
               let appURL = URL(fileURLWithPath: customPath) as URL? {
                NSWorkspace.shared.open(
                    [finalURL],
                    withApplicationAt: appURL,
                    configuration: NSWorkspace.OpenConfiguration()
                )
            } else {
                NSWorkspace.shared.open(finalURL)
            }

        default:
            if let bundleId = meetApp.bundleIdentifier,
               let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                NSWorkspace.shared.open(
                    [finalURL],
                    withApplicationAt: appURL,
                    configuration: NSWorkspace.OpenConfiguration()
                )
            } else {
                NSWorkspace.shared.open(finalURL)
            }
        }
    }
}
