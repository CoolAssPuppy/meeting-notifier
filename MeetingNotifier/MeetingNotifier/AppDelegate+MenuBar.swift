//
//  AppDelegate+MenuBar.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import AppKit

// MARK: - Menu bar text and icon updates

extension AppDelegate {
    func updateMenuBarText() {
        guard let button = statusItem?.button else { return }

        let hasAuthIssues = AppSettings.shared.accounts.contains { $0.authStatus != .valid }

        if hasAuthIssues {
            button.title = "\u{26A0}\u{FE0F}"
            button.image = NSImage(systemSymbolName: "calendar.badge.exclamationmark", accessibilityDescription: "Calendar - Authentication Issue")
            hidePeekWindow()
            return
        }

        let settings = AppSettings.shared

        switch settings.menuBarDisplayMode {
        case .none:
            hidePeekWindow()
            applyCalendarIconWithBadge(to: button, settings: settings)

        case .inMenuBar:
            hidePeekWindow()
            applyInMenuBarDisplay(to: button, settings: settings)

        case .peekWindow:
            button.title = ""
            button.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Calendar")

            if settings.showMeetingCountBadge {
                let todayMeetingsCount = CalendarDataManager.shared.todayEvents().count
                if todayMeetingsCount > 0 {
                    button.title = String(todayMeetingsCount)
                }
            }

            updatePeekWindow()
        }
    }

    private func applyCalendarIconWithBadge(to button: NSStatusBarButton, settings: AppSettings) {
        button.title = ""
        let calendarImage = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Calendar")

        if settings.showMeetingCountBadge {
            let todayMeetingsCount = CalendarDataManager.shared.todayEvents().count
            if todayMeetingsCount > 0 {
                button.title = String(todayMeetingsCount)
            }
        }
        button.image = calendarImage
    }

    private func applyInMenuBarDisplay(to button: NSStatusBarButton, settings: AppSettings) {
        let nextMeeting = getNextMeetingForMenuBar()

        guard let meeting = nextMeeting else {
            applyCalendarIconWithBadge(to: button, settings: settings)
            return
        }

        var displayComponents: [String] = []

        if settings.menuBarShowTime {
            displayComponents.append(meeting.formattedTime)
        }
        if settings.menuBarShowCountdown {
            displayComponents.append(meeting.timeUntilStart)
        }
        if settings.menuBarShowTitle {
            displayComponents.append(truncateTitle(meeting.title, maxLength: 25))
        }

        if settings.menuBarShowIcon {
            if let iconImage = getIconImageForEvent(meeting) {
                button.image = iconImage
            } else {
                displayComponents.insert(getIconForEvent(meeting), at: 0)
                button.image = nil
            }
        } else {
            button.image = nil
        }

        button.title = displayComponents.joined(separator: " ")

        if !settings.menuBarShowIcon && !settings.menuBarShowTitle && !settings.menuBarShowTime && !settings.menuBarShowCountdown {
            button.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Calendar")
            button.title = ""
        }

        if settings.showMeetingCountBadge {
            let todayMeetingsCount = CalendarDataManager.shared.todayEvents().count
            if todayMeetingsCount > 1 {
                button.title = button.title + " (\(todayMeetingsCount))"
            }
        }
    }

    func getNextMeetingForMenuBar() -> CalendarEvent? {
        let now = Date()
        let settings = AppSettings.shared

        let currentMeetings = CalendarDataManager.shared.events.filter { $0.isHappening }

        let sortedMeetings: [CalendarEvent]
        if settings.onlyShowMeetingsWithAttendees {
            sortedMeetings = currentMeetings.filter { $0.hasAttendees }
        } else {
            sortedMeetings = currentMeetings
        }

        let currentMeeting: CalendarEvent?
        switch settings.doubleBookingPreference {
        case .fewerAttendees:
            currentMeeting = sortedMeetings.sorted { $0.attendeeCount < $1.attendeeCount }.first
        case .moreAttendees:
            currentMeeting = sortedMeetings.sorted { $0.attendeeCount > $1.attendeeCount }.first
        }

        let threshold = settings.showAllDayInMenuBar ?
            Calendar.current.date(byAdding: .day, value: 1, to: now)! :
            now.addingTimeInterval(Double(settings.menuBarThresholdMinutes * 60))

        let upcomingMeetings = CalendarDataManager.shared.events.filter { event in
            event.startDate >= now && event.startDate <= threshold
        }

        let upcomingMeeting = if settings.onlyShowMeetingsWithAttendees {
            upcomingMeetings.first { $0.hasAttendees }
        } else {
            upcomingMeetings.first
        }

        if let current = currentMeeting, let upcoming = upcomingMeeting {
            let timeUntilUpcoming = upcoming.startDate.timeIntervalSince(now)
            let fifteenMinutes: TimeInterval = 15 * 60

            if timeUntilUpcoming <= fifteenMinutes || upcoming.startDate < current.endDate {
                return upcoming
            } else {
                return current
            }
        }

        if let current = currentMeeting {
            return current
        }

        return upcomingMeeting
    }

    private func getIconForEvent(_ event: CalendarEvent) -> String {
        if let platform = event.videoPlatform {
            switch platform {
            case .meet: return "\u{1F4DE}"
            case .zoom: return "\u{1F4BB}"
            case .teams: return "\u{1F465}"
            case .webex: return "\u{1F4F9}"
            }
        }
        return "\u{1F4C5}"
    }

    private func getIconImageForEvent(_ event: CalendarEvent) -> NSImage? {
        if let platform = event.videoPlatform {
            switch platform {
            case .meet:
                if let imagePath = Bundle.main.path(forResource: "meet", ofType: "png"),
                   let image = NSImage(contentsOfFile: imagePath) {
                    image.size = NSSize(width: 16, height: 16)
                    return image
                }
            case .zoom:
                if let imagePath = Bundle.main.path(forResource: "zoom", ofType: "png"),
                   let image = NSImage(contentsOfFile: imagePath) {
                    image.size = NSSize(width: 16, height: 16)
                    return image
                }
            case .teams:
                if let imagePath = Bundle.main.path(forResource: "teams", ofType: "png"),
                   let image = NSImage(contentsOfFile: imagePath) {
                    image.size = NSSize(width: 16, height: 16)
                    return image
                }
            case .webex:
                if let image = NSImage(systemSymbolName: "video.fill", accessibilityDescription: "Webex") {
                    image.size = NSSize(width: 16, height: 16)
                    return image
                }
            }
        } else if event.conferenceLink != nil {
            if let image = NSImage(systemSymbolName: "phone.fill", accessibilityDescription: "Phone") {
                image.size = NSSize(width: 16, height: 16)
                return image
            }
        }

        return nil
    }

    private func truncateTitle(_ title: String, maxLength: Int) -> String {
        if title.count <= maxLength { return title }
        let index = title.index(title.startIndex, offsetBy: maxLength - 3)
        return String(title[..<index]) + "..."
    }
}
