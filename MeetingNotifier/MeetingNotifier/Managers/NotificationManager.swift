import Foundation
import UserNotifications
import AppKit

@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    private var notificationCheckTimer: Timer?
    @Published var permissionGranted = false

    override init() {
        super.init()
        requestNotificationPermission()
        startNotificationChecking()
    }

    func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            Task { @MainActor in
                self?.permissionGranted = granted
                if let error = error {
                    print("Notification permission error: \(error)")
                }
            }
        }

        center.getNotificationSettings { [weak self] settings in
            let isAuthorized = settings.authorizationStatus == .authorized
            Task { @MainActor [weak self] in
                self?.permissionGranted = isAuthorized
            }
        }
    }

    func startNotificationChecking() {
        notificationCheckTimer?.invalidate()
        notificationCheckTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkAndScheduleNotifications()
            }
        }

        Task {
            await checkAndScheduleNotifications()
        }
    }

    func stopNotificationChecking() {
        notificationCheckTimer?.invalidate()
        notificationCheckTimer = nil
    }

    func checkAndScheduleNotifications() async {
        guard AppSettings.shared.notificationsEnabled else { return }

        let events = CalendarDataManager.shared.events
        let now = Date()

        for event in events {
            guard event.startDate > now else { continue }

            if AppSettings.shared.oneMinuteWarningEnabled {
                await scheduleOneMinuteWarning(for: event)
            }

            await scheduleCustomReminders(for: event)
        }

        cleanupNotificationTracking(for: events)
    }

    private func scheduleOneMinuteWarning(for event: CalendarEvent) async {
        let now = Date()
        let oneMinuteBefore = event.startDate.addingTimeInterval(-60)

        guard oneMinuteBefore > now else { return }

        guard !AppSettings.shared.notificationTracking.wasSent(eventId: event.id, type: .oneMinuteWarning) else {
            return
        }

        let timeInterval = oneMinuteBefore.timeIntervalSince(now)
        guard timeInterval > 0 && timeInterval <= 300 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Meeting starting soon"
        content.body = "\(event.title) starts in 1 minute"
        if !AppSettings.shared.muteSounds {
            content.sound = UNNotificationSound(named: UNNotificationSoundName("short-chimes.aiff"))
        }
        content.userInfo = [
            "eventId": event.id,
            "conferenceLink": event.conferenceLink ?? ""
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let identifier = "\(event.id)_oneMinute"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
            markNotificationAsSent(eventId: event.id, type: .oneMinuteWarning)
        } catch {
            print("Error scheduling one minute warning: \(error)")
        }
    }

    private func scheduleCustomReminders(for event: CalendarEvent) async {
        let now = Date()

        for reminder in event.reminders {
            let reminderTime = event.startDate.addingTimeInterval(-Double(reminder.minutesBefore * 60))

            guard reminderTime > now else { continue }

            guard !AppSettings.shared.notificationTracking.wasSent(eventId: "\(event.id)_\(reminder.minutesBefore)", type: .customReminder) else {
                continue
            }

            let timeInterval = reminderTime.timeIntervalSince(now)
            guard timeInterval > 0 && timeInterval <= 300 else { continue }

            let content = UNMutableNotificationContent()
            content.title = event.title
            content.body = "Starts in \(reminder.minutesBefore) minute\(reminder.minutesBefore == 1 ? "" : "s")"
            if !AppSettings.shared.muteSounds {
                content.sound = UNNotificationSound(named: UNNotificationSoundName("long-chimes.aiff"))
            }
            content.userInfo = [
                "eventId": event.id,
                "conferenceLink": event.conferenceLink ?? ""
            ]

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
            let identifier = "\(event.id)_reminder_\(reminder.minutesBefore)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            do {
                try await UNUserNotificationCenter.current().add(request)
                markNotificationAsSent(eventId: "\(event.id)_\(reminder.minutesBefore)", type: .customReminder)
            } catch {
                print("Error scheduling custom reminder: \(error)")
            }
        }
    }

    private func markNotificationAsSent(eventId: String, type: NotificationType) {
        var tracking = AppSettings.shared.notificationTracking
        tracking.markAsSent(eventId: eventId, type: type)
        AppSettings.shared.notificationTracking = tracking
    }

    private func cleanupNotificationTracking(for events: [CalendarEvent]) {
        var tracking = AppSettings.shared.notificationTracking
        tracking.cleanup(events: events)
        AppSettings.shared.notificationTracking = tracking
    }

    func showAuthFailureNotification(forAccount account: CalendarAccount) {
        let content = UNMutableNotificationContent()
        content.title = "Authentication Expired"
        content.body = "Calendar access for \(account.email) has expired. Click to reconnect."
        content.sound = UNNotificationSound.default
        content.userInfo = [
            "type": "authFailure",
            "accountEmail": account.email
        ]

        let identifier = "auth_failure_\(account.email)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)

        Task {
            do {
                try await UNUserNotificationCenter.current().add(request)
                print("Auth failure notification shown for \(account.email)")
            } catch {
                print("Error showing auth failure notification: \(error)")
            }
        }
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let muteSounds = UserDefaults.standard.bool(forKey: "muteSounds")
        let options: UNNotificationPresentationOptions = muteSounds ? [.banner] : [.banner, .sound]
        completionHandler(options)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if let linkString = userInfo["conferenceLink"] as? String,
           !linkString.isEmpty,
           let url = URL(string: linkString) {
            Task { @MainActor in
                NSWorkspace.shared.open(url)
            }
        }

        completionHandler()
    }
}
