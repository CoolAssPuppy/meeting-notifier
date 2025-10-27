import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var popover: NSPopover?
    private var menuBarUpdateTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupPopover()
        startMenuBarUpdates()
        NSApp.setActivationPolicy(.accessory)

        _ = NotificationManager.shared

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

        if AppSettings.shared.showInMenuBar {
            if let nextMeeting = getNextMeetingForMenuBar() {
                let truncatedTitle = truncateTitle(nextMeeting.title, maxLength: 30)
                let icon = getIconForEvent(nextMeeting)
                button.title = "\(icon) \(truncatedTitle)"
                button.image = nil
            } else {
                button.title = ""
                button.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Calendar")
            }
        } else {
            button.title = ""
            button.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Calendar")
        }
    }

    private func getNextMeetingForMenuBar() -> CalendarEvent? {
        let now = Date()
        let threshold = now.addingTimeInterval(15 * 60)

        let upcomingMeetings = CalendarDataManager.shared.events.filter { event in
            event.startDate >= now && event.startDate <= threshold && event.endDate >= now
        }

        if AppSettings.shared.onlyShowMeetingsWithAttendees {
            return upcomingMeetings.first { $0.hasAttendees }
        } else {
            return upcomingMeetings.first
        }
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

    private func truncateTitle(_ title: String, maxLength: Int) -> String {
        if title.count <= maxLength {
            return title
        }
        let index = title.index(title.startIndex, offsetBy: maxLength - 3)
        return String(title[..<index]) + "..."
    }

    @objc private func menuBarButtonClicked() {
        guard let button = statusItem?.button else { return }

        if popover?.isShown == true {
            popover?.performClose(nil)
        } else {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    @objc private func handleAddAccountRequest(_ notification: Notification) {
        popover?.performClose(nil)

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
        popover?.performClose(nil)
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
                case .success(let account):
                    let alert = NSAlert()
                    alert.messageText = "Account Added"
                    alert.informativeText = "Successfully added Google account: \(account.email)"
                    alert.alertStyle = .informational
                    alert.runModal()
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
                case .success(let account):
                    let alert = NSAlert()
                    alert.messageText = "Account Added"
                    alert.informativeText = "Successfully added Microsoft account: \(account.email)"
                    alert.alertStyle = .informational
                    alert.runModal()
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
