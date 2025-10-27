import SwiftUI

struct NotificationsTab: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Notification Settings")
                .font(.headline)

            VStack(alignment: .leading, spacing: 16) {
                Toggle("Enable notifications", isOn: $settings.notificationsEnabled)
                    .font(.body)

                Text("Allow MeetingNotifier to send notifications about upcoming meetings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                Divider()

                Toggle("One minute warning", isOn: $settings.oneMinuteWarningEnabled)
                    .font(.body)
                    .disabled(!settings.notificationsEnabled)

                Text("Receive a notification with a chime sound exactly 1 minute before any meeting starts.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom Reminders")
                        .font(.body)
                        .foregroundColor(settings.notificationsEnabled ? .primary : .secondary)

                    Text("Notifications will be sent based on reminder settings in your calendar events. These are configured in Google Calendar or Microsoft Outlook.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 20)
                }
            }

            Spacer()

            infoBox
        }
        .padding(20)
    }

    private var infoBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("Notification Permissions")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Text("If notifications are not working, check that MeetingNotifier has permission to send notifications in System Settings > Notifications.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

struct NotificationsTab_Previews: PreviewProvider {
    static var previews: some View {
        NotificationsTab()
            .frame(width: 500, height: 600)
    }
}
