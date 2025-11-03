import SwiftUI
import AppKit

struct ConfigTab: View {
    @ObservedObject var settings = AppSettings.shared

    @State private var showingAppPicker = false
    @State private var customAppURL: URL?
    @State private var showingCoffee = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Form {
                    // NOTIFICATIONS - Most important section first
                    Section {
                        notificationsToggle
                        oneMinuteWarningToggle
                        customRemindersInfo
                        notificationPermissionsInfo
                    } header: {
                        sectionHeader(icon: "bell.fill", title: "Notifications", gradient: [.blue, .cyan])
                    }

                    // MEETING LINKS
                    Section {
                        meetAppPicker
                    } header: {
                        sectionHeader(icon: "link.circle.fill", title: "Meeting Links", gradient: [.purple, .pink])
                    }

                    // MENU BAR DISPLAY
                    Section {
                        menuBarToggle
                        if settings.showInMenuBar {
                            displayModePicker
                            thresholdSlider
                            showAllDayToggle
                        }
                        attendeesToggle
                        doubleBookingPicker
                        meetingCountBadgeToggle
                    } header: {
                        sectionHeader(icon: "menubar.rectangle", title: "Menu Bar Display", gradient: [.green, .mint])
                    }

                    // SOUNDS
                    Section {
                        soundsToggle
                    } header: {
                        sectionHeader(icon: "speaker.wave.2.fill", title: "Sounds", gradient: [.orange, .yellow])
                    }

                    // TRAVEL & LOCATION
                    Section {
                        travelTimeAlertsToggle
                        if settings.showTravelTimeAlerts {
                            travelModePicker
                        }
                        mapProviderPicker
                    } header: {
                        sectionHeader(icon: "location.circle.fill", title: "Travel & Location", gradient: [.teal, .cyan])
                    }

                    // STARTUP
                    Section {
                        launchAtLoginToggle
                    } header: {
                        sectionHeader(icon: "power.circle.fill", title: "Startup", gradient: [.indigo, .blue])
                    }

                    // KEYBOARD SHORTCUTS
                    Section {
                        keyboardShortcutsInfo
                    } header: {
                        sectionHeader(icon: "command.circle.fill", title: "Keyboard Shortcuts", gradient: [.red, .orange])
                    }

                    // SUPPORT
                    Section {
                        buyMeCoffeeButton
                    } header: {
                        sectionHeader(icon: "cup.and.saucer.fill", title: "Support", gradient: [.brown, .orange])
                    }
                }
                .formStyle(.grouped)
            }
            .padding(20)
        }
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.02),
                    Color.clear,
                    Color.purple.opacity(0.01)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .fileImporter(
            isPresented: $showingAppPicker,
            allowedContentTypes: [.application],
            allowsMultipleSelection: false
        ) { result in
            handleAppSelection(result)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(icon: String, title: String, gradient: [Color]) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.primary)
        }
    }

    // MARK: - Notifications Section

    private var notificationsToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Enable notifications", isOn: $settings.notificationsEnabled)

            Text("Allow MeetingNotifier to send notifications about upcoming meetings")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var oneMinuteWarningToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("One minute warning", isOn: $settings.oneMinuteWarningEnabled)
                .disabled(!settings.notificationsEnabled)

            Text("Receive a notification with a chime sound exactly 1 minute before any meeting starts")
                .font(.caption)
                .foregroundColor(settings.notificationsEnabled ? .secondary : Color.secondary.opacity(0.5))
        }
    }

    private var customRemindersInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Custom Reminders")
                .font(.body)
                .foregroundColor(settings.notificationsEnabled ? .primary : .secondary)

            Text("Notifications will be sent based on reminder settings in your calendar events. These are configured in Google Calendar or Microsoft Outlook")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var notificationPermissionsInfo: some View {
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

    // MARK: - Meeting Links Section

    private var meetAppPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Open Google Meet with:")
                .font(.body)

            Picker("", selection: $settings.defaultMeetApp) {
                ForEach(MeetAppType.availableApps) { app in
                    Text(app.rawValue).tag(app)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: settings.defaultMeetApp) { _, newValue in
                if newValue == .custom {
                    showingAppPicker = true
                }
            }

            if let customURL = customAppURL {
                HStack(spacing: 8) {
                    Image(systemName: "app.fill")
                        .foregroundColor(.secondary)
                    Text(customURL.lastPathComponent.replacingOccurrences(of: ".app", with: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("Change") {
                        showingAppPicker = true
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            }

            Text("Choose which app opens when you click on Google Meet links")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Menu Bar Display Section

    private var menuBarToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Display next meeting in Menu Bar", isOn: $settings.showInMenuBar)

            Text("Shows meeting title (truncated to 30 characters) with platform icon 15 minutes before it starts")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var displayModePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Display Style:")
                .font(.body)

            VStack(alignment: .leading, spacing: 8) {
                Toggle("Icon", isOn: $settings.menuBarShowIcon)
                Toggle("Title", isOn: $settings.menuBarShowTitle)
                Toggle("Time", isOn: $settings.menuBarShowTime)
                Toggle("Countdown", isOn: $settings.menuBarShowCountdown)
            }

            Text("Select which elements to show in the menu bar. If no Icon is selected, the default calendar icon will be shown")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var thresholdSlider: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Show meetings within:")
                    .font(.body)
                Spacer()
                Text("\(settings.menuBarThresholdMinutes) min")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            Slider(value: Binding(
                get: { Double(settings.menuBarThresholdMinutes) },
                set: { settings.menuBarThresholdMinutes = Int($0) }
            ), in: 5...60, step: 5)
            .disabled(settings.showAllDayInMenuBar)

            Text("Controls how far in advance to display upcoming meetings")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var showAllDayToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Always show next meeting", isOn: $settings.showAllDayInMenuBar)

            Text("When enabled, always shows the next meeting regardless of time")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var attendeesToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Only show meetings with attendees", isOn: $settings.onlyShowMeetingsWithAttendees)
                .disabled(!settings.showInMenuBar)

            Text("When enabled, only meetings with other attendees will be shown in the menu bar")
                .font(.caption)
                .foregroundColor(settings.showInMenuBar ? .secondary : Color.secondary.opacity(0.5))
        }
    }

    private var doubleBookingPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("When double-booked, show:")
                .font(.body)

            Picker("", selection: $settings.doubleBookingPreference) {
                ForEach(DoubleBookingPreference.allCases) { preference in
                    Text(preference.rawValue).tag(preference)
                }
            }
            .pickerStyle(.menu)
            .disabled(!settings.showInMenuBar)

            Text("Choose which meeting to display in the menu bar when you have overlapping meetings")
                .font(.caption)
                .foregroundColor(settings.showInMenuBar ? .secondary : Color.secondary.opacity(0.5))
        }
    }

    private var meetingCountBadgeToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Show meeting count badge", isOn: $settings.showMeetingCountBadge)

            Text("Display number of remaining meetings today")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Sounds Section

    private var soundsToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Mute sounds", isOn: $settings.muteSounds)

            Text("When enabled, notification sounds will not play")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Travel & Location Section

    private var travelTimeAlertsToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Enable travel time alerts", isOn: $settings.showTravelTimeAlerts)

            Text("Get notifications when it's time to leave for meetings with physical locations")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var travelModePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Default travel mode:")
                .font(.body)

            Picker("", selection: $settings.defaultTravelMode) {
                ForEach(TravelMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text("Used to calculate travel time and route to physical meeting locations")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var mapProviderPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preferred map:")
                .font(.body)

            Picker("", selection: $settings.preferredMapProvider) {
                ForEach(MapProvider.allCases) { provider in
                    Label(provider.rawValue, systemImage: provider.icon).tag(provider)
                }
            }
            .pickerStyle(.segmented)

            Text("Choose which map app to use when opening location directions")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Startup Section

    private var launchAtLoginToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Launch at login", isOn: $settings.launchAtLogin)

            Text("Automatically start MeetingNotifier when you log in")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Keyboard Shortcuts Section

    private var keyboardShortcutsInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            shortcutRow(keys: "⌘⇧M", description: "Join next meeting")
            shortcutRow(keys: "⌘⇧O", description: "Open/close dropdown")
            shortcutRow(keys: "⌘⇧R", description: "Refresh meetings")

            Text("Global keyboard shortcuts for quick access")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
    }

    private func shortcutRow(keys: String, description: String) -> some View {
        HStack {
            Text(keys)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.gray.opacity(0.8), .gray.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )

            Text(description)
                .font(.system(size: 12))
                .foregroundColor(.primary)

            Spacer()
        }
    }

    // MARK: - Support Section

    private var buyMeCoffeeButton: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                showingCoffee = true
            }) {
                HStack {
                    Image(systemName: "cup.and.saucer.fill")
                        .foregroundColor(.orange)
                    Text("Buy Me Coffee")
                }
            }

            Text("Support MeetingNotifier development")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .sheet(isPresented: $showingCoffee) {
            CoffeeView()
                .frame(width: 500, height: 500)
        }
    }

    // MARK: - Helper Methods

    private func handleAppSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                customAppURL = url
                UserDefaults.standard.set(url.path, forKey: "customMeetAppPath")
            }
        case .failure(let error):
            print("Error selecting app: \(error.localizedDescription)")
            settings.defaultMeetApp = .defaultBrowser
        }
    }
}

struct ConfigTab_Previews: PreviewProvider {
    static var previews: some View {
        ConfigTab()
            .frame(width: 500, height: 600)
    }
}
