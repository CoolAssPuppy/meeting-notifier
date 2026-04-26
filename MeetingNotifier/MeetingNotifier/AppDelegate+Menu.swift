//
//  AppDelegate+Menu.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import AppKit

// MARK: - Menu Item Tags

private enum MenuItemTag: Int {
    case refresh
    case transcriptionToggle
    case separatorBelowRefresh
    case separatorAboveSettings
}

// MARK: - Menu Creation

extension AppDelegate {
    func createNativeMenu() -> NSMenu {
        let menu = NSMenu()

        let refreshItem = NSMenuItem(
            title: NSLocalizedString("Refresh", comment: ""),
            action: #selector(refreshMeetings),
            keyEquivalent: ""
        )
        refreshItem.tag = MenuItemTag.refresh.rawValue
        menu.addItem(refreshItem)

        let transcriptionItem = NSMenuItem(
            title: NSLocalizedString("Start Transcription", comment: ""),
            action: #selector(toggleTranscription),
            keyEquivalent: ""
        )
        transcriptionItem.tag = MenuItemTag.transcriptionToggle.rawValue
        transcriptionItem.image = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: "Transcription")
        menu.addItem(transcriptionItem)

        let separatorBelowRefresh = NSMenuItem.separator()
        separatorBelowRefresh.tag = MenuItemTag.separatorBelowRefresh.rawValue
        menu.addItem(separatorBelowRefresh)

        let separatorAboveSettings = NSMenuItem.separator()
        separatorAboveSettings.tag = MenuItemTag.separatorAboveSettings.rawValue
        menu.addItem(separatorAboveSettings)

        menu.addItem(withTitle: NSLocalizedString("Settings...", comment: ""), action: #selector(openSettings), keyEquivalent: "")
        menu.addItem(withTitle: NSLocalizedString("Check for Updates…", comment: ""), action: #selector(checkForUpdates), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: NSLocalizedString("Quit MeetingNotifier", comment: ""), action: #selector(NSApp.terminate(_:)), keyEquivalent: "")

        return menu
    }

    func updateNativeMenu(_ menu: NSMenu) {
        updateTranscriptionMenuItem(in: menu)

        let indexBelowRefresh = menu.indexOfItem(withTag: MenuItemTag.separatorBelowRefresh.rawValue)
        let indexAboveSettings = menu.indexOfItem(withTag: MenuItemTag.separatorAboveSettings.rawValue)

        // Remove existing meeting items
        for index in ((indexBelowRefresh + 1)..<indexAboveSettings).reversed() {
            menu.removeItem(at: index)
        }

        // Insert meeting items
        var offset = indexBelowRefresh + 1
        let items = createMeetingMenuItems()

        for item in items {
            menu.insertItem(item, at: offset)
            offset += 1
        }
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

// MARK: - Meeting Menu Items

private extension AppDelegate {
    func createMeetingMenuItems() -> [NSMenuItem] {
        var items = [NSMenuItem]()
        let dataManager = CalendarDataManager.shared
        let appSettings = AppSettings.shared

        // Check for auth errors
        let accountsWithAuthErrors = appSettings.accounts.filter { $0.authStatus != .valid }
        if !accountsWithAuthErrors.isEmpty {
            let authItem = NSMenuItem(
                title: NSLocalizedString("Authentication required", comment: ""),
                action: #selector(openSettings),
                keyEquivalent: ""
            )
            authItem.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Warning")
            authItem.image?.isTemplate = false
            items.append(authItem)
            items.append(NSMenuItem.separator())
        }

        // Loading state
        if dataManager.isLoading && dataManager.events.isEmpty {
            let loadingItem = NSMenuItem(
                title: NSLocalizedString("Loading...", comment: ""),
                action: nil,
                keyEquivalent: ""
            )
            items.append(loadingItem)
            return items
        }

        // Empty state
        if dataManager.events.isEmpty {
            let emptyItem = NSMenuItem(
                title: NSLocalizedString("No upcoming meetings", comment: ""),
                action: nil,
                keyEquivalent: ""
            )
            items.append(emptyItem)
            return items
        }

        let todayEvents = dataManager.todayEvents()
        let tomorrowEvents = dataManager.tomorrowEvents()

        // Today section
        if !todayEvents.isEmpty {
            let todayHeader = NSMenuItem(
                title: NSLocalizedString("Today", comment: ""),
                action: nil,
                keyEquivalent: ""
            )
            todayHeader.isEnabled = false
            items.append(todayHeader)

            for event in todayEvents {
                items.append(createMenuItem(for: event))
            }
        }

        // Tomorrow section
        if !tomorrowEvents.isEmpty {
            if !todayEvents.isEmpty {
                items.append(NSMenuItem.separator())
            }

            let tomorrowHeader = NSMenuItem(
                title: NSLocalizedString("Tomorrow", comment: ""),
                action: nil,
                keyEquivalent: ""
            )
            tomorrowHeader.isEnabled = false
            items.append(tomorrowHeader)

            for event in tomorrowEvents {
                items.append(createMenuItem(for: event))
            }
        }

        return items
    }

    func createMenuItem(for event: CalendarEvent) -> NSMenuItem {
        // Format: "10:00 AM  Team Standup"
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let timeString = timeFormatter.string(from: event.startDate)

        let title = "\(timeString)  \(event.title)"

        // Parent menu item has no action - submenu provides all actions
        let menuItem = NSMenuItem(
            title: title,
            action: nil,
            keyEquivalent: ""
        )
        menuItem.representedObject = event

        // Add calendar color indicator
        let colorDot = createColorDotImage(hex: event.calendarColorHex)
        menuItem.image = colorDot

        // Create submenu for all events
        let submenu = NSMenu()

        // Open in Calendar - always available
        let openCalendarItem = NSMenuItem(
            title: NSLocalizedString("Open in Calendar", comment: ""),
            action: #selector(openEventInCalendar(_:)),
            keyEquivalent: ""
        )
        openCalendarItem.representedObject = event
        openCalendarItem.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Calendar")
        submenu.addItem(openCalendarItem)

        // Join Video Conference - only if video link exists
        if let platform = event.videoPlatform {
            let platformName = platform.displayName
            let joinItem = NSMenuItem(
                title: String(format: NSLocalizedString("Join %@", comment: "Join video conference"), platformName),
                action: #selector(openMeeting(_:)),
                keyEquivalent: ""
            )
            joinItem.representedObject = event

            if let iconImage = loadPlatformIcon(platform) {
                joinItem.image = iconImage
            }
            submenu.addItem(joinItem)
        }

        submenu.addItem(NSMenuItem.separator())

        // Informational rows: no action (purely descriptive). isEnabled=false
        // styles them as inert; we still set image+title.
        submenu.addItem(infoMenuItem(
            title: event.calendarName,
            symbolName: "tray.full",
            symbolDescription: "Calendar"
        ))

        if event.attendeeCount > 1 {
            submenu.addItem(infoMenuItem(
                title: String(format: NSLocalizedString("%d People", comment: "Number of attendees"), event.attendeeCount),
                symbolName: "person.2",
                symbolDescription: "Attendees"
            ))
        }

        if event.hasPhysicalLocation,
           let travelInfo = LocationManager.shared.travelTimeCache[event.id] {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short

            let title: String
            if travelInfo.shouldLeaveNow {
                title = NSLocalizedString("Leave now to arrive in time", comment: "Travel time alert")
            } else {
                let leaveByString = timeFormatter.string(from: travelInfo.leaveByTime)
                title = String(format: NSLocalizedString("Leave at %@ to arrive in time", comment: "Travel time with departure time"), leaveByString)
            }

            submenu.addItem(infoMenuItem(
                title: title,
                symbolName: AppSettings.shared.defaultTravelMode.icon,
                symbolDescription: "Travel time"
            ))
        }

        menuItem.submenu = submenu

        return menuItem
    }

    func createColorDotImage(hex: String) -> NSImage {
        let size = NSSize(width: 8, height: 8)
        let image = NSImage(size: size)

        image.lockFocus()
        let color = NSColor(hex: hex) ?? NSColor.systemBlue
        color.setFill()
        let path = NSBezierPath(ovalIn: NSRect(origin: .zero, size: size))
        path.fill()
        image.unlockFocus()

        image.isTemplate = false
        return image
    }

    func loadPlatformIcon(_ platform: VideoPlatform) -> NSImage? {
        let imageName = platform.iconName

        if let path = Bundle.main.path(forResource: imageName, ofType: "png"),
           let image = NSImage(contentsOfFile: path) {
            image.size = NSSize(width: 16, height: 16)
            return image
        }

        let platformName = platform.rawValue.capitalized
        return NSImage(systemSymbolName: "video.fill", accessibilityDescription: platformName)
    }

    @objc func openMeeting(_ sender: NSMenuItem) {
        guard let event = sender.representedObject as? CalendarEvent,
              let conferenceLink = event.conferenceLink,
              let url = URL(string: conferenceLink) else {
            return
        }

        AppSettings.shared.openURL(url, accountEmail: event.accountEmail)
        Telemetry.capture("meeting.join_clicked", properties: [
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

    @objc func openEventInCalendar(_ sender: NSMenuItem) {
        guard let event = sender.representedObject as? CalendarEvent else {
            return
        }

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

    /// Build a non-actionable submenu row (calendar name, attendee count, etc.).
    /// `isEnabled = false` styles it as informational and prevents click feedback.
    func infoMenuItem(title: String, symbolName: String, symbolDescription: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: symbolDescription)
        return item
    }
}
