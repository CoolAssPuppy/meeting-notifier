import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var popover: NSPopover?
    var nativeMenu: NSMenu?
    private var menuBarUpdateTimer: Timer?
    private var eventMonitor: Any?
    var peekWindowPanel: PeekWindowPanel?
    var transcriptionBannerPanel: TranscriptionBannerPanel?
    var isRecordingIndicatorActive = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Recover any transcript from a prior crash before anything else
        TranscriptionCoordinator.recoverTranscriptIfNeeded()

        setupMenuBar()
        setupPopover()
        setupNativeMenu()
        startMenuBarUpdates()
        NSApp.setActivationPolicy(.accessory)

        _ = NotificationManager.shared
        _ = KeyboardShortcutManager.shared
        _ = LocationManager.shared
        _ = MeetingDetector.shared
        _ = TranscriptionCoordinator.shared

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

        NotificationCenter.default.addObserver(self, selector: #selector(handleAddAccountRequest), name: .addAccountRequested, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSettingsRequest), name: .settingsRequested, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(toggleDropdown), name: .toggleDropdown, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAccountsDidUpdate), name: .accountsDidUpdate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(showTranscriptionBanner), name: .transcriptionDidStart, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(hideTranscriptionBanner), name: .transcriptionDidStop, object: nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        TranscriptionCoordinator.shared.emergencySave()
    }

    // MARK: - Setup

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
        popover?.behavior = .semitransient
        popover?.appearance = NSAppearance(named: .aqua)
    }

    private func setupNativeMenu() {
        nativeMenu = createNativeMenu()
        nativeMenu?.delegate = self
    }

    private func startMenuBarUpdates() {
        menuBarUpdateTimer?.invalidate()
        menuBarUpdateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMenuBarText()
            }
        }
    }

    // MARK: - Dropdown toggle

    @objc private func toggleDropdown() {
        guard let button = statusItem?.button else { return }

        if AppSettings.shared.dropDownStyle == .simple {
            if let menu = nativeMenu {
                updateNativeMenu(menu)
                applySystemAppearance(to: menu)
                menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 5), in: button)
            }
        } else {
            if popover?.isShown == true {
                closePopover()
            } else {
                showPopover()
            }
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

    @objc private func menuBarButtonClicked() {
        guard let button = statusItem?.button else { return }

        if AppSettings.shared.dropDownStyle == .simple {
            if let menu = nativeMenu {
                updateNativeMenu(menu)
                applySystemAppearance(to: menu)
                menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 5), in: button)
            }
        } else {
            if popover?.isShown == true {
                closePopover()
            } else {
                showPopover()
            }
        }
    }

    // MARK: - Popover

    private func showPopover() {
        guard let button = statusItem?.button else { return }
        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

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
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor [weak self] in
                if self?.popover?.isShown == true {
                    self?.closePopover()
                }
            }
        }
    }

    private func stopMonitoringForClicksOutsidePopover() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    // MARK: - Account management

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
                if case .failure(let error) = result {
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
                if case .failure(let error) = result {
                    let alert = NSAlert()
                    alert.messageText = "Failed to Add Account"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .critical
                    alert.runModal()
                }
            }
        }
    }

    // MARK: - Settings window

    @objc func openSettings() {
        NSApp.setActivationPolicy(.regular)

        Task { @MainActor [weak self] in
            // Small delay to let activation policy change take effect
            try? await Task.sleep(for: .milliseconds(100))

            guard let self else { return }

            NSApp.activate(ignoringOtherApps: true)

            if let existingWindow = self.settingsWindow {
                existingWindow.makeKeyAndOrderFront(nil)
                return
            }

            for window in NSApp.windows {
                if window.styleMask.contains(.borderless) { continue }
                self.settingsWindow = window
                window.delegate = self
                window.makeKeyAndOrderFront(nil)
                return
            }

            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            newWindow.contentView = NSHostingView(rootView: SettingsView())
            newWindow.title = "MeetingNotifier Settings"
            newWindow.isReleasedWhenClosed = false
            newWindow.center()
            newWindow.makeKeyAndOrderFront(nil)

            self.settingsWindow = newWindow
            newWindow.delegate = self
        }
    }
}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == settingsWindow {
            settingsWindow = nil
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

// MARK: - Menu appearance

extension AppDelegate {
    func applySystemAppearance(to menu: NSMenu) {
        let isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        menu.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)
    }
}

// MARK: - NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        if menu == nativeMenu {
            applySystemAppearance(to: menu)
            updateNativeMenu(menu)
        }
    }
}
