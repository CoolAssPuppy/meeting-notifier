//
//  AppDelegate+Menu.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import AppKit

// MARK: - Menu Item Tags

private enum MenuItemTag: Int {
    case transcriptionToggle
}

// MARK: - Right-click menu

extension AppDelegate {
    /// The menu a right-click (or control-click) on the status item opens, in
    /// either dropdown style. Meetings never appear here — that is the
    /// left-click dropdown's job.
    func createRightClickMenu() -> NSMenu {
        let menu = NSMenu()

        menu.addItem(withTitle: NSLocalizedString("Refresh", comment: ""),
                     action: #selector(refreshMeetings),
                     keyEquivalent: "")

        let transcriptionItem = NSMenuItem(
            title: NSLocalizedString("Start Transcription", comment: ""),
            action: #selector(toggleTranscription),
            keyEquivalent: ""
        )
        transcriptionItem.tag = MenuItemTag.transcriptionToggle.rawValue
        transcriptionItem.image = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: "Transcription")
        menu.addItem(transcriptionItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(withTitle: NSLocalizedString("Settings...", comment: ""),
                     action: #selector(openSettings),
                     keyEquivalent: ",")
        menu.addItem(withTitle: NSLocalizedString("Check for Updates…", comment: ""),
                     action: #selector(checkForUpdates),
                     keyEquivalent: "")

        menu.addItem(NSMenuItem.separator())

        menu.addItem(withTitle: NSLocalizedString("Quit MeetingNotifier", comment: ""),
                     action: #selector(NSApp.terminate(_:)),
                     keyEquivalent: "q")

        return menu
    }

    @objc func refreshMeetings() {
        Task {
            await CalendarDataManager.shared.refreshEvents()
        }
    }

    @objc func toggleTranscription() {
        let coordinator = TranscriptionCoordinator.shared
        Task { @MainActor in
            if coordinator.state.isActive {
                await coordinator.stopTranscription()
            } else {
                // Find active/upcoming meeting
                let now = Date()
                let activeMeeting = CalendarDataManager.shared.events.first { event in
                    event.startDate <= now.addingTimeInterval(60) && event.endDate > now
                }
                await coordinator.startTranscription(for: activeMeeting)
            }
        }
    }

    func updateTranscriptionMenuItem(in menu: NSMenu) {
        guard let item = menu.item(withTag: MenuItemTag.transcriptionToggle.rawValue) else { return }
        let coordinator = TranscriptionCoordinator.shared

        if coordinator.state.isActive {
            item.title = NSLocalizedString("Stop Transcription", comment: "")
            item.image = NSImage(systemSymbolName: "stop.circle.fill", accessibilityDescription: "Stop")
        } else {
            item.title = NSLocalizedString("Start Transcription", comment: "")
            item.image = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: "Transcription")
        }

        item.isHidden = !AppSettings.shared.notetakerEnabled
    }
}

// MARK: - Classic menu content and actions

extension AppDelegate {
    /// Snapshot of what the classic menu should render right now. Built fresh
    /// on every click: meetings, countdowns and travel times all change
    /// between openings, and an `NSMenu` is a snapshot, not a live view.
    func classicMenuContent() -> ClassicMenuBuilder.Content {
        let dataManager = CalendarDataManager.shared
        let settings = AppSettings.shared

        return ClassicMenuBuilder.Content(
            today: dataManager.todayEvents(),
            tomorrow: dataManager.tomorrowEvents(),
            isLoading: dataManager.isLoading,
            hasAccounts: !settings.accounts.isEmpty,
            hasAuthError: settings.accounts.contains { $0.authStatus != .valid },
            isNotetakerEnabled: settings.notetakerEnabled,
            travelInfo: { event in
                guard settings.showTravelTimeAlerts else { return nil }
                return LocationManager.shared.travelTimeCache[event.id]
            },
            travelModeIcon: settings.defaultTravelMode.icon
        )
    }

    func classicMenuActions() -> ClassicMenuBuilder.Actions {
        ClassicMenuBuilder.Actions(
            join: { [weak self] event in
                self?.joinMeeting(event)
            },
            openInCalendar: { [weak self] event in
                self?.openEventInCalendar(event)
            },
            copyLink: { event in
                guard let link = event.conferenceLink else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(link, forType: .string)
            },
            startTranscription: { event in
                Task { @MainActor in
                    await TranscriptionCoordinator.shared.startTranscription(for: event)
                }
            },
            reauthorize: { [weak self] in
                self?.openSettings()
            },
            refresh: { [weak self] in
                self?.refreshMeetings()
            },
            openWindow: { [weak self] in
                self?.openMainWindow()
            },
            openSettings: { [weak self] in
                self?.openSettings()
            },
            openTranscription: { [weak self] in
                self?.openTranscriptionDrawer()
            },
            quit: {
                NSApp.terminate(nil)
            }
        )
    }
}

// MARK: - Meeting actions

extension AppDelegate {
    func joinMeeting(_ event: CalendarEvent) {
        guard let conferenceLink = event.conferenceLink,
              let url = URL(string: conferenceLink) else {
            return
        }

        TranscriptionCoordinator.shared.registerUserSelectedMeeting(event)
        AppSettings.shared.openURL(url, accountEmail: event.accountEmail)
        Telemetry.capture(.meetingJoinClicked, properties: [
            "provider": Self.meetingPlatformTag(for: conferenceLink)
        ])
    }

    /// Classifies a conference URL into a short provider tag suitable for a
    /// telemetry property. Falls back to `other` on unknown hosts so no
    /// user-identifying URL leaks into events.
    private static func meetingPlatformTag(for urlString: String) -> String {
        let lower = urlString.lowercased()
        if lower.contains("zoom.us") || lower.contains("zoom.com")        { return "zoom" }
        if lower.contains("meet.google.com")                              { return "meet" }
        if lower.contains("teams.microsoft.com") || lower.contains("teams.live.com") { return "teams" }
        if lower.contains("webex.com")                                    { return "webex" }
        return "other"
    }

    func openEventInCalendar(_ event: CalendarEvent) {
        let url: URL?

        switch event.provider {
        case .google:
            // Google Calendar event URL
            // Format: https://calendar.google.com/calendar/event?eid=BASE64_EVENT_ID
            // The event ID needs to be combined with calendar ID and base64 encoded
            let compositeId = "\(event.id) \(event.calendarId)"
            if let encoded = compositeId.data(using: .utf8)?.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "") {
                url = URL(string: "https://calendar.google.com/calendar/event?eid=\(encoded)")
            } else {
                // Fallback to calendar view
                url = URL(string: "https://calendar.google.com/calendar")
            }

        case .microsoft:
            // Microsoft Outlook calendar
            // Direct event links require the full weblink which we don't have
            // Fall back to calendar view
            url = URL(string: "https://outlook.office.com/calendar")
        }

        if let url = url {
            NSWorkspace.shared.open(url)
        }
    }
}
