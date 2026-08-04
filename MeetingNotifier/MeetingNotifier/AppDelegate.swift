import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?

    var statusItem: NSStatusItem?
    var settingsWindow: NSWindow?
    private var popover: NSPopover?
    var rightClickMenu: NSMenu?
    private let menuStyleStore = MenuStyleStore.shared
    private var menuBarUpdateTimer: Timer?
    private var eventMonitor: Any?
    var peekWindowPanel: PeekWindowPanel?
    var transcriptionBannerPanel: TranscriptionBannerPanel?
    var isRecordingIndicatorActive = false

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Telemetry.setup()

        TranscriptionCoordinator.recoverTranscriptIfNeeded()

        setupMenuBar()
        setupPopover()
        startMenuBarUpdates()
        NSApp.setActivationPolicy(.accessory)

        Telemetry.capture(.appLaunched)
        reportUpdateInstalledIfNeeded()

        _ = NotificationManager.shared
        _ = KeyboardShortcutManager.shared
        _ = LocationManager.shared
        _ = MeetingDetector.shared
        _ = TranscriptionCoordinator.shared
        _ = UpdaterManager.shared

        #if DEBUG
        if CommandLine.arguments.contains("--uitesting") {
            setupTestDataForUITesting()
        }
        handleUITestingArguments()
        #endif

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

    /// Fires `update.installed` when the short-version changes between
    /// launches. Silent on first ever launch. See Linear Bar's equivalent
    /// for rationale.
    private func reportUpdateInstalledIfNeeded() {
        let key = "com.strategicnerds.meetingnotifier.telemetry.lastLaunchedVersion"
        let defaults = UserDefaults.standard
        let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let previous = defaults.string(forKey: key)
        defaults.set(current, forKey: key)
        guard let previous, !previous.isEmpty, previous != current else { return }
        Telemetry.capture(.updateInstalled, properties: ["from": previous, "to": current])
    }

    // MARK: - Setup

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            updateMenuBarText()
            button.target = self
            button.action = #selector(menuBarButtonClicked)
            // Without this the button only fires on left-mouse-up, and
            // `menuBarButtonClicked` would never see a right-click to route.
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        rightClickMenu = createRightClickMenu()
    }

    private func setupPopover() {
        popover = NSPopover()
        let hostingController = NSHostingController(rootView: CalendarDropdownView())
        popover?.contentViewController = hostingController
        popover?.behavior = .semitransient
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

    // MARK: - Dropdown toggle

    /// The keyboard shortcut and the notification both open whichever dropdown
    /// the user picked, so the two styles behave the same everywhere.
    @objc func toggleDropdown() {
        if menuStyleStore.current == .classic {
            showClassicMenu()
        } else {
            togglePopover()
        }
    }

    @objc private func handleAccountsDidUpdate() {
        Task { @MainActor in
            updateMenuBarText()
        }
    }

    @objc private func menuBarButtonClicked() {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp
            || (event?.modifierFlags.contains(.control) ?? false)

        if isRightClick {
            showRightClickMenu()
        } else {
            toggleDropdown()
        }
    }

    // MARK: - Classic menu

    private func showRightClickMenu() {
        guard let menu = rightClickMenu else { return }
        updateTranscriptionMenuItem(in: menu)
        applySystemAppearance(to: menu)
        present(menu: menu)
    }

    /// Built fresh on every click: meetings, countdowns and travel times all
    /// change between openings, and an `NSMenu` is a snapshot, not a live view.
    private func showClassicMenu() {
        // A popover left open from a style switch would otherwise sit under
        // the menu.
        closePopover()

        let menu = ClassicMenuBuilder.makeMenu(content: classicMenuContent(),
                                               actions: classicMenuActions())
        applySystemAppearance(to: menu)
        present(menu: menu)
        Telemetry.capture(.menuOpened, properties: ["style": MenuStyle.classic.rawValue])
    }

    /// Pops a menu from the status item, then detaches it so the next
    /// left-click still reaches `menuBarButtonClicked`.
    private func present(menu: NSMenu) {
        guard let statusItem else { return }
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        DispatchQueue.main.async { [weak statusItem] in
            statusItem?.menu = nil
        }
    }

    private func togglePopover() {
        guard statusItem?.button != nil else { return }
        if popover?.isShown == true {
            closePopover()
        } else {
            showPopover()
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
        Telemetry.capture(.menuOpened, properties: ["style": MenuStyle.pretty.rawValue])
    }

    func closePopover() {
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

    @objc func addAccount() {
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

    @objc func addGoogleAccount() {
        AuthManager.shared.addGoogleAccount { result in
            Task { @MainActor in
                switch result {
                case .success:
                    Telemetry.capture(.accountAdded, properties: ["provider": "google"])
                case .failure(let error):
                    Telemetry.capture(.accountSigninFailed, properties: ["provider": "google"])
                    let alert = NSAlert()
                    alert.messageText = "Failed to Add Account"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .critical
                    alert.runModal()
                }
            }
        }
    }

    @objc func addMicrosoftAccount() {
        AuthManager.shared.addMicrosoftAccount { result in
            Task { @MainActor in
                switch result {
                case .success:
                    Telemetry.capture(.accountAdded, properties: ["provider": "microsoft"])
                case .failure(let error):
                    Telemetry.capture(.accountSigninFailed, properties: ["provider": "microsoft"])
                    let alert = NSAlert()
                    alert.messageText = "Failed to Add Account"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .critical
                    alert.runModal()
                }
            }
        }
    }

    func reauthorizeAccount(_ account: CalendarAccount) {
        switch account.provider {
        case .google:
            addGoogleAccount()
        case .microsoft:
            addMicrosoftAccount()
        }
    }

    // MARK: - Updater

    @objc func checkForUpdates() {
        UpdaterManager.shared.checkForUpdates()
    }

    // MARK: - Settings / transcription drawers

    @objc func openSettings() {
        showMainWindow()
        DrawerState.shared.open(.settings)
    }

    @objc func openMainWindow() {
        showMainWindow()
        DrawerState.shared.openDrawer = .none
    }

    func openTranscriptionDrawer() {
        showMainWindow()
        DrawerState.shared.open(.transcription)
    }

    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)

        if let existingWindow = settingsWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            existingWindow.orderFrontRegardless()
            return
        }

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newWindow.contentView = NSHostingView(rootView: MainView())
        newWindow.title = "Meeting Notifier"
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .hidden
        newWindow.isMovableByWindowBackground = true
        newWindow.isReleasedWhenClosed = false
        newWindow.minSize = NSSize(width: 880, height: 580)
        newWindow.center()
        newWindow.makeKeyAndOrderFront(nil)
        newWindow.orderFrontRegardless()

        settingsWindow = newWindow
        newWindow.delegate = self
    }
}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == settingsWindow {
            settingsWindow = nil
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
