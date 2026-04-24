import Cocoa
import Carbon
import UserNotifications
import os

@MainActor
class KeyboardShortcutManager: ObservableObject {
    static let shared = KeyboardShortcutManager()

    private var eventHandlers: [UInt32: () -> Void] = [:]
    private var installedHotKeys: [EventHotKeyRef?] = []
    private var nextHotKeyID: UInt32 = 1

    private init() {
        setupDefaultShortcuts()
    }

    private func setupDefaultShortcuts() {
        // ⌘⇧M - Join next meeting
        registerShortcut(
            keyCode: UInt32(kVK_ANSI_M),
            modifiers: [.command, .shift]
        ) { [weak self] in
            self?.joinNextMeeting()
        }

        // ⌘⇧O - Open dropdown menu
        registerShortcut(
            keyCode: UInt32(kVK_ANSI_O),
            modifiers: [.command, .shift]
        ) { [weak self] in
            self?.openDropdown()
        }

        // ⌘⇧R - Refresh meetings
        registerShortcut(
            keyCode: UInt32(kVK_ANSI_R),
            modifiers: [.command, .shift]
        ) { [weak self] in
            self?.refreshMeetings()
        }
    }

    private func registerShortcut(
        keyCode: UInt32,
        modifiers: [ShortcutModifier],
        handler: @escaping () -> Void
    ) {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        var hotKeyRef: EventHotKeyRef?

        let currentID = nextHotKeyID
        nextHotKeyID += 1

        // "MNTF" as FourCharCode = 0x4D4E5446
        let hotKeyID = EventHotKeyID(signature: 0x4D4E5446, id: currentID)

        let carbonModifiers = modifiers.reduce(UInt32(0)) { result, modifier in
            result | modifier.carbonModifier
        }

        let status = RegisterEventHotKey(
            keyCode,
            carbonModifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr {
            installedHotKeys.append(hotKeyRef)
            eventHandlers[currentID] = handler

            // Install event handler
            InstallEventHandler(
                GetEventDispatcherTarget(),
                { (_, inEvent, _) -> OSStatus in
                    var hotKeyID = EventHotKeyID()
                    GetEventParameter(
                        inEvent,
                        EventParamName(kEventParamDirectObject),
                        EventParamType(typeEventHotKeyID),
                        nil,
                        MemoryLayout<EventHotKeyID>.size,
                        nil,
                        &hotKeyID
                    )

                    Task { @MainActor in
                        KeyboardShortcutManager.shared.eventHandlers[hotKeyID.id]?()
                    }

                    return noErr
                },
                1,
                &eventType,
                nil,
                nil
            )
        }
    }

    private func joinNextMeeting() {
        Telemetry.capture("shortcut.used", properties: ["action": "join_next"])

        let events = CalendarDataManager.shared.events
        let now = Date()

        // Find the next meeting with a video link
        if let nextMeeting = events.first(where: { $0.startDate >= now && $0.hasVideoLink }) {
            if let conferenceLink = nextMeeting.conferenceLink,
               let url = URL(string: conferenceLink) {
                AppSettings.shared.openURL(url, accountEmail: nextMeeting.accountEmail)

                // Show notification
                showNotification(
                    title: "Joining Meeting",
                    message: nextMeeting.title
                )
            }
        } else {
            showNotification(
                title: "No Upcoming Meetings",
                message: "No meetings with video links found"
            )
        }
    }

    private func openDropdown() {
        Telemetry.capture("shortcut.used", properties: ["action": "open_menu"])
        // Post notification to trigger dropdown
        NotificationCenter.default.post(name: .toggleDropdown, object: nil)
    }

    private func refreshMeetings() {
        Telemetry.capture("shortcut.used", properties: ["action": "refresh"])
        Task {
            await CalendarDataManager.shared.refreshEvents()
            showNotification(
                title: "Meetings Refreshed",
                message: "Your calendar has been updated"
            )
        }
    }

    private func showNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = nil

        let identifier = "keyboard_shortcut_\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)

        Task {
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                Logger.notifications.error("Error showing keyboard shortcut notification: \(error)")
            }
        }
    }
}

// MARK: - Supporting Types

enum ShortcutModifier {
    case command
    case shift
    case option
    case control

    var carbonModifier: UInt32 {
        switch self {
        case .command: return UInt32(cmdKey)
        case .shift: return UInt32(shiftKey)
        case .option: return UInt32(optionKey)
        case .control: return UInt32(controlKey)
        }
    }
}

