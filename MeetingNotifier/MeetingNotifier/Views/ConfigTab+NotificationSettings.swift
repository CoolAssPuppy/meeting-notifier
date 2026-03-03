//
//  ConfigTab+NotificationSettings.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import SwiftUI

// MARK: - Notification settings

extension ConfigTab {
    var notificationsToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Enable notifications", isOn: $settings.notificationsEnabled)

            Text("Allow MeetingNotifier to send notifications about upcoming meetings")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    var oneMinuteWarningToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("One minute warning", isOn: $settings.oneMinuteWarningEnabled)
                .disabled(!settings.notificationsEnabled)

            Text("Receive a notification with a chime sound exactly 1 minute before any meeting starts")
                .font(.caption)
                .foregroundColor(settings.notificationsEnabled ? .secondary : Color.secondary.opacity(0.5))
        }
    }

    var customRemindersInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Custom Reminders")
                .font(.body)
                .foregroundColor(settings.notificationsEnabled ? .primary : .secondary)

            Text("Notifications will be sent based on reminder settings in your calendar events. These are configured in Google Calendar or Microsoft Outlook")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    var notificationPermissionsInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("Notification Permissions")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Text("If notifications are not working, check that MeetingNotifier has permission to send notifications in System Settings > Notifications")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}
