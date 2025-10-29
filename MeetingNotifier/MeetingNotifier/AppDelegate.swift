import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var popover: NSPopover?
    private var menuBarUpdateTimer: Timer?
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupPopover()
        startMenuBarUpdates()
        NSApp.setActivationPolicy(.accessory)

        _ = NotificationManager.shared
        _ = KeyboardShortcutManager.shared
        _ = LocationManager.shared

        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAddAccountRequest),
            name: .addAccountRequested,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsRequest),
            name: .settingsRequested,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(toggleDropdown),
            name: .toggleDropdown,
            object: nil
        )
    }

    @objc private func toggleDropdown() {
        guard statusItem?.button != nil else { return }

        if popover?.isShown == true {
            closePopover()
        } else {
            showPopover()
        }
    }

    @objc func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString) else {
            return
        }

        Task { @MainActor in
            _ = AuthManager.shared.handleURLCallback(url)
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            updateMenuBarText()
            button.action = #selector(menuBarButtonClicked)
            button.target = self
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover?.contentViewController = NSHostingController(rootView: CalendarDropdownView())
        popover?.behavior = .transient
    }

    private func startMenuBarUpdates() {
        menuBarUpdateTimer?.invalidate()
        menuBarUpdateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMenuBarText()
            }
        }
    }

    private func updateMenuBarText() {
        guard let button = statusItem?.button else { return }

        // Check if any account has auth issues
        let hasAuthIssues = AppSettings.shared.accounts.contains { $0.authStatus != .valid }

        if hasAuthIssues {
            button.title = "⚠️"
            button.image = NSImage(systemSymbolName: "calendar.badge.exclamationmark", accessibilityDescription: "Calendar - Authentication Issue")
            return
        }

        let nextMeeting = getNextMeetingForMenuBar()
        let settings = AppSettings.shared

        // Apply display mode based on checkbox selections
        if let meeting = nextMeeting, settings.showInMenuBar {
            var displayComponents: [String] = []

            // Build display string based on selected options
            if settings.menuBarShowTime {
                displayComponents.append(meeting.formattedTime)
            }

            if settings.menuBarShowCountdown {
                displayComponents.append(meeting.timeUntilStart)
            }

            if settings.menuBarShowTitle {
                let truncatedTitle = truncateTitle(meeting.title, maxLength: 25)
                displayComponents.append(truncatedTitle)
            }

            // Handle icon
            if settings.menuBarShowIcon {
                if let iconImage = getIconImageForEvent(meeting) {
                    button.image = iconImage
                } else {
                    // If no PNG icon available, add emoji to title
                    let icon = getIconForEvent(meeting)
                    displayComponents.insert(icon, at: 0)
                    button.image = nil
                }
            } else {
                button.image = nil
            }

            // Set the title with all selected components
            button.title = displayComponents.joined(separator: " ")

            // If no options are selected, show default calendar icon
            if !settings.menuBarShowIcon && !settings.menuBarShowTitle && !settings.menuBarShowTime && !settings.menuBarShowCountdown {
                button.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Calendar")
                button.title = ""
            }

            // Add meeting count badge if enabled
            if settings.showMeetingCountBadge {
                let todayMeetingsCount = CalendarDataManager.shared.todayEvents().count
                if todayMeetingsCount > 1 {
                    button.title = button.title + " (\(todayMeetingsCount))"
                }
            }

        } else {
            // No meeting or showInMenuBar is false
            button.title = ""
            let calendarImage = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Calendar")

            // Add badge indicator for today's meeting count
            if settings.showMeetingCountBadge {
                let todayMeetingsCount = CalendarDataManager.shared.todayEvents().count
                if todayMeetingsCount > 0 {
                    // Create an attributed string with badge
                    button.title = String(todayMeetingsCount)
                    button.image = calendarImage
                } else {
                    button.image = calendarImage
                }
            } else {
                button.image = calendarImage
            }
        }
    }

    private func getNextMeetingForMenuBar() -> CalendarEvent? {
        let now = Date()
        let settings = AppSettings.shared

        // Find current meetings (meetings that are happening right now)
        let currentMeetings = CalendarDataManager.shared.events.filter { event in
            event.isHappening
        }

        // Apply attendee filter if enabled
        let currentMeeting = if settings.onlyShowMeetingsWithAttendees {
            currentMeetings.first { $0.hasAttendees }
        } else {
            currentMeetings.first
        }

        // Find upcoming meetings within threshold
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

        // Smart menu bar logic:
        // 1. If there's a current meeting and an upcoming meeting
        if let current = currentMeeting, let upcoming = upcomingMeeting {
            // Check if upcoming meeting is within 15 minutes
            let timeUntilUpcoming = upcoming.startDate.timeIntervalSince(now)
            let fifteenMinutes: TimeInterval = 15 * 60

            // Show upcoming meeting if it starts within 15 minutes OR before current meeting ends
            if timeUntilUpcoming <= fifteenMinutes || upcoming.startDate < current.endDate {
                return upcoming
            } else {
                // Show current meeting if next meeting is more than 15m away and after current ends
                return current
            }
        }

        // 2. If there's only a current meeting, show it
        if let current = currentMeeting {
            return current
        }

        // 3. If there's only an upcoming meeting, show it
        return upcomingMeeting
    }

    private func getIconForEvent(_ event: CalendarEvent) -> String {
        if let platform = event.videoPlatform {
            switch platform {
            case .meet:
                return "📞"
            case .zoom:
                return "💻"
            case .teams:
                return "👥"
            case .webex:
                return "📹"
            }
        }
        return "📅"
    }

    private func getIconImageForEvent(_ event: CalendarEvent) -> NSImage? {
        // If there's a recognized video platform, load its icon
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
            // Has a conference link but no recognized platform - likely a phone number
            if let image = NSImage(systemSymbolName: "phone.fill", accessibilityDescription: "Phone") {
                image.size = NSSize(width: 16, height: 16)
                return image
            }
        }

        // No conference link - return nil to use emoji fallback
        return nil
    }

    private func truncateTitle(_ title: String, maxLength: Int) -> String {
        if title.count <= maxLength {
            return title
        }
        let index = title.index(title.startIndex, offsetBy: maxLength - 3)
        return String(title[..<index]) + "..."
    }

    @objc private func menuBarButtonClicked() {
        guard statusItem?.button != nil else { return }

        if popover?.isShown == true {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem?.button else { return }
        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        startMonitoringForClicksOutsidePopover()
    }

    private func closePopover() {
        popover?.performClose(nil)
        stopMonitoringForClicksOutsidePopover()
    }

    private func startMonitoringForClicksOutsidePopover() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if self?.popover?.isShown == true {
                self?.closePopover()
            }
        }
    }

    private func stopMonitoringForClicksOutsidePopover() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    @objc private func handleAddAccountRequest(_ notification: Notification) {
        closePopover()

        if let provider = notification.userInfo?["provider"] as? String {
            if provider == "google" {
                addGoogleAccount()
            } else if provider == "microsoft" {
                addMicrosoftAccount()
            }
        } else {
            addAccount()
        }
    }

    @objc private func handleSettingsRequest() {
        closePopover()
        openSettings()
    }

    @objc private func addAccount() {
        let alert = NSAlert()
        alert.messageText = "Add Account"
        alert.informativeText = "Choose the type of account to add:"
        alert.addButton(withTitle: "Google")
        alert.addButton(withTitle: "Microsoft")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            addGoogleAccount()
        } else if response == .alertSecondButtonReturn {
            addMicrosoftAccount()
        }
    }

    private func addGoogleAccount() {
        AuthManager.shared.addGoogleAccount { result in
            Task { @MainActor in
                switch result {
                case .success:
                    break
                case .failure(let error):
                    let alert = NSAlert()
                    alert.messageText = "Failed to Add Account"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .critical
                    alert.runModal()
                }
            }
        }
    }

    private func addMicrosoftAccount() {
        AuthManager.shared.addMicrosoftAccount { result in
            Task { @MainActor in
                switch result {
                case .success:
                    break
                case .failure(let error):
                    let alert = NSAlert()
                    alert.messageText = "Failed to Add Account"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .critical
                    alert.runModal()
                }
            }
        }
    }

    @objc private func openSettings() {
        NSApp.setActivationPolicy(.regular)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }

            NSApp.activate(ignoringOtherApps: true)

            if let existingWindow = self.settingsWindow {
                existingWindow.makeKeyAndOrderFront(nil)
                return
            }

            for window in NSApp.windows {
                if window.styleMask.contains(.borderless) {
                    continue
                }
                self.settingsWindow = window
                window.delegate = self
                window.makeKeyAndOrderFront(nil)
                return
            }

            let settingsView = SettingsView()

            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            newWindow.contentView = NSHostingView(rootView: settingsView)
            newWindow.title = "MeetingNotifier Settings"
            newWindow.isReleasedWhenClosed = false
            newWindow.center()
            newWindow.makeKeyAndOrderFront(nil)

            self.settingsWindow = newWindow
            newWindow.delegate = self
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == settingsWindow {
            settingsWindow = nil
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
