import AppKit
import SwiftUI

// Empty - removed complex hosting controller

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var popover: NSPopover?
    private var menuBarUpdateTimer: Timer?
    private var eventMonitor: Any?
    private var peekWindowPanel: PeekWindowPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupPopover()
        startMenuBarUpdates()
        NSApp.setActivationPolicy(.accessory)

        _ = NotificationManager.shared
        _ = KeyboardShortcutManager.shared
        _ = LocationManager.shared

        // Setup test data if UI testing
        #if DEBUG
        if CommandLine.arguments.contains("--uitesting") {
            setupTestDataForUITesting()
        }
        #endif

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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAccountsDidUpdate),
            name: .accountsDidUpdate,
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

    @objc private func handleAccountsDidUpdate() {
        Task { @MainActor in
            updateMenuBarText()
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
        let hostingController = NSHostingController(rootView: CalendarDropdownView())
        popover?.contentViewController = hostingController
        // Use semitransient - designed for interactive popovers per Apple HIG
        // Allows clicking inside without dismissing, while maintaining key window status for materials
        popover?.behavior = .semitransient
        // Ensure vibrant appearance for proper material rendering
        popover?.appearance = NSAppearance(named: .aqua)
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
            hidePeekWindow()
            return
        }

        let settings = AppSettings.shared

        // Handle display mode
        switch settings.menuBarDisplayMode {
        case .none:
            // No meeting display - just show calendar icon
            hidePeekWindow()
            button.title = ""
            let calendarImage = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Calendar")

            if settings.showMeetingCountBadge {
                let todayMeetingsCount = CalendarDataManager.shared.todayEvents().count
                if todayMeetingsCount > 0 {
                    button.title = String(todayMeetingsCount)
                    button.image = calendarImage
                } else {
                    button.image = calendarImage
                }
            } else {
                button.image = calendarImage
            }

        case .inMenuBar:
            // Original behavior - show next meeting in menu bar
            hidePeekWindow()
            let nextMeeting = getNextMeetingForMenuBar()

            if let meeting = nextMeeting {
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
                // No meeting
                button.title = ""
                let calendarImage = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Calendar")

                if settings.showMeetingCountBadge {
                    let todayMeetingsCount = CalendarDataManager.shared.todayEvents().count
                    if todayMeetingsCount > 0 {
                        button.title = String(todayMeetingsCount)
                        button.image = calendarImage
                    } else {
                        button.image = calendarImage
                    }
                } else {
                    button.image = calendarImage
                }
            }

        case .peekWindow:
            // Show all imminent meetings in peek window
            button.title = ""
            button.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Calendar")

            if settings.showMeetingCountBadge {
                let todayMeetingsCount = CalendarDataManager.shared.todayEvents().count
                if todayMeetingsCount > 0 {
                    button.title = String(todayMeetingsCount)
                }
            }

            // Update or show peek window
            updatePeekWindow()
        }
    }

    private func getNextMeetingForMenuBar() -> CalendarEvent? {
        let now = Date()
        let settings = AppSettings.shared

        // Find current meetings (meetings that are happening right now)
        let currentMeetings = CalendarDataManager.shared.events.filter { event in
            event.isHappening
        }

        // Apply attendee filter if enabled, then sort by attendee count based on user preference
        let currentMeeting: CalendarEvent?
        let sortedMeetings: [CalendarEvent]

        if settings.onlyShowMeetingsWithAttendees {
            sortedMeetings = currentMeetings.filter { $0.hasAttendees }
        } else {
            sortedMeetings = currentMeetings
        }

        // Sort based on double-booking preference
        switch settings.doubleBookingPreference {
        case .fewerAttendees:
            currentMeeting = sortedMeetings.sorted { $0.attendeeCount < $1.attendeeCount }.first
        case .moreAttendees:
            currentMeeting = sortedMeetings.sorted { $0.attendeeCount > $1.attendeeCount }.first
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

    // MARK: - Peek Window Management

    private func updatePeekWindow() {
        // Defer to next run loop to avoid layout recursion
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let meeting = self.getNextMeetingForMenuBar()
            let settings = AppSettings.shared

            if meeting == nil {
                self.hidePeekWindow()
                return
            }

            if let existingPanel = self.peekWindowPanel {
                // Update existing panel
                existingPanel.updateMeeting(
                    meeting,
                    settings: settings,
                    onTap: { [weak self] in
                        self?.handlePeekMeetingTap()
                    },
                    onClose: { [weak self] in
                        self?.hidePeekWindow()
                    }
                )
                if let statusItem = self.statusItem {
                    existingPanel.positionBelowStatusItem(statusItem, animated: false)
                }
            } else {
                // Create new panel with animation
                let panel = PeekWindowPanel(
                    meeting: meeting,
                    settings: settings,
                    onTap: { [weak self] in
                        self?.handlePeekMeetingTap()
                    },
                    onClose: { [weak self] in
                        self?.hidePeekWindow()
                    }
                )

                panel.orderFrontRegardless()
                self.peekWindowPanel = panel

                if let statusItem = self.statusItem {
                    panel.positionBelowStatusItem(statusItem, animated: true)
                }
            }
        }
    }

    private func hidePeekWindow() {
        DispatchQueue.main.async { [weak self] in
            self?.peekWindowPanel?.close()
            self?.peekWindowPanel = nil
        }
    }

    private func handlePeekMeetingTap() {
        guard let meeting = getNextMeetingForMenuBar(),
              let conferenceLink = meeting.conferenceLink,
              let url = URL(string: conferenceLink) else {
            return
        }
        AppSettings.shared.openURL(url, accountEmail: meeting.accountEmail)
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

        // Ensure popover appears above peek window
        if let popoverWindow = popover?.contentViewController?.view.window {
            popoverWindow.level = .popUpMenu
        }

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

    // MARK: - UI Testing Support

    #if DEBUG
    private func setupTestDataForUITesting() {
        // Note: UI tests run in a sandboxed container, so this won't affect your real app data
        // But to be extra safe, we'll just add fake test data without clearing real accounts

        // Create test events for UI testing with clean, professional times
        let calendar = Calendar.current
        let now = Date()

        // Get today at specific times
        var components = calendar.dateComponents([.year, .month, .day], from: now)

        // Today's meetings at clean times
        components.hour = 9
        components.minute = 0
        let meeting1Start = calendar.date(from: components)!

        components.hour = 10
        components.minute = 30
        let meeting2Start = calendar.date(from: components)!

        components.hour = 14
        components.minute = 0
        let meeting3Start = calendar.date(from: components)!

        // Tomorrow's meetings
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        var tomorrowComponents = calendar.dateComponents([.year, .month, .day], from: tomorrow)

        tomorrowComponents.hour = 9
        tomorrowComponents.minute = 0
        let meeting4Start = calendar.date(from: tomorrowComponents)!

        tomorrowComponents.hour = 11
        tomorrowComponents.minute = 0
        let meeting5Start = calendar.date(from: tomorrowComponents)!

        let testEvents = [
            createTestEvent(
                title: "Team Standup",
                startDate: meeting1Start,
                duration: 15,
                conferenceType: "zoom"
            ),
            createTestEvent(
                title: "Client Meeting - Q4 Review",
                startDate: meeting2Start,
                duration: 60,
                conferenceType: "meet"
            ),
            createTestEvent(
                title: "1:1 with Manager",
                startDate: meeting3Start,
                duration: 30,
                conferenceType: "teams"
            ),
            createTestEvent(
                title: "Design Review",
                startDate: meeting4Start,
                duration: 45,
                conferenceType: "zoom"
            ),
            createTestEvent(
                title: "Sprint Planning",
                startDate: meeting5Start,
                duration: 90,
                conferenceType: "meet"
            )
        ]

        CalendarDataManager.shared.setTestEvents(testEvents)
    }

    private func createTestEvent(
        title: String,
        startDate: Date,
        duration: Int,
        conferenceType: String
    ) -> CalendarEvent {
        let endDate = Calendar.current.date(byAdding: .minute, value: duration, to: startDate)!

        let conferenceLink: String
        switch conferenceType {
        case "zoom":
            conferenceLink = "https://zoom.us/j/1234567890"
        case "meet":
            conferenceLink = "https://meet.google.com/abc-defg-hij"
        case "teams":
            conferenceLink = "https://teams.microsoft.com/l/meetup-join/123"
        default:
            conferenceLink = ""
        }

        return CalendarEvent(
            id: UUID().uuidString,
            title: title,
            startDate: startDate,
            endDate: endDate,
            location: nil,
            description: "Test meeting for screenshots",
            conferenceLink: conferenceLink,
            calendarId: "test-calendar",
            calendarName: "Test Calendar",
            calendarColorHex: "#4285F4",
            provider: .google,
            reminders: [],
            attendeeCount: 3,
            accountEmail: "test@example.com"
        )
    }
    #endif
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == settingsWindow {
            settingsWindow = nil
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
