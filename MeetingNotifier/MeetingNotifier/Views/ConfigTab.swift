import SwiftUI
import AppKit

struct ConfigTab: View {
    @ObservedObject var settings = AppSettings.shared
    @Environment(\.dismiss) var dismiss

    @State private var tempDefaultMeetApp: MeetAppType
    @State private var tempShowInMenuBar: Bool
    @State private var tempOnlyShowMeetingsWithAttendees: Bool
    @State private var tempMuteSounds: Bool
    @State private var tempLaunchAtLogin: Bool
    @State private var tempMenuBarShowIcon: Bool
    @State private var tempMenuBarShowTitle: Bool
    @State private var tempMenuBarShowTime: Bool
    @State private var tempMenuBarShowCountdown: Bool
    @State private var tempMenuBarThresholdMinutes: Int
    @State private var tempShowAllDayInMenuBar: Bool
    @State private var tempShowMeetingCountBadge: Bool
    @State private var tempShowTravelTimeAlerts: Bool
    @State private var tempDefaultTravelMode: TravelMode
    @State private var showingAppPicker = false
    @State private var customAppURL: URL?
    @State private var showingCoffee = false

    init() {
        let settings = AppSettings.shared
        _tempDefaultMeetApp = State(initialValue: settings.defaultMeetApp)
        _tempShowInMenuBar = State(initialValue: settings.showInMenuBar)
        _tempOnlyShowMeetingsWithAttendees = State(initialValue: settings.onlyShowMeetingsWithAttendees)
        _tempMuteSounds = State(initialValue: settings.muteSounds)
        _tempLaunchAtLogin = State(initialValue: settings.launchAtLogin)
        _tempMenuBarShowIcon = State(initialValue: settings.menuBarShowIcon)
        _tempMenuBarShowTitle = State(initialValue: settings.menuBarShowTitle)
        _tempMenuBarShowTime = State(initialValue: settings.menuBarShowTime)
        _tempMenuBarShowCountdown = State(initialValue: settings.menuBarShowCountdown)
        _tempMenuBarThresholdMinutes = State(initialValue: settings.menuBarThresholdMinutes)
        _tempShowAllDayInMenuBar = State(initialValue: settings.showAllDayInMenuBar)
        _tempShowMeetingCountBadge = State(initialValue: settings.showMeetingCountBadge)
        _tempShowTravelTimeAlerts = State(initialValue: settings.showTravelTimeAlerts)
        _tempDefaultTravelMode = State(initialValue: settings.defaultTravelMode)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Form {
                        Section {
                            meetAppPicker
                        } header: {
                            sectionHeader(icon: "link.circle.fill", title: "Meeting Links", gradient: [.blue, .cyan])
                        }

                        Section {
                            menuBarToggle
                            if tempShowInMenuBar {
                                displayModePicker
                                thresholdSlider
                                showAllDayToggle
                            }
                            attendeesToggle
                            meetingCountBadgeToggle
                        } header: {
                            sectionHeader(icon: "menubar.rectangle", title: "Menu Bar Display", gradient: [.purple, .pink])
                        }

                        Section {
                            travelTimeAlertsToggle
                            if tempShowTravelTimeAlerts {
                                travelModePicker
                            }
                        } header: {
                            sectionHeader(icon: "location.circle.fill", title: "Travel & Location", gradient: [.green, .mint])
                        }

                        Section {
                            soundsToggle
                        } header: {
                            sectionHeader(icon: "speaker.wave.2.fill", title: "Sounds", gradient: [.orange, .yellow])
                        }

                        Section {
                            launchAtLoginToggle
                        } header: {
                            sectionHeader(icon: "power.circle.fill", title: "Startup", gradient: [.indigo, .blue])
                        }

                        Section {
                            keyboardShortcutsInfo
                        } header: {
                            sectionHeader(icon: "command.circle.fill", title: "Keyboard Shortcuts", gradient: [.red, .orange])
                        }

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

            Divider()

            footerBar
        }
        .background(.ultraThinMaterial)
        .fileImporter(
            isPresented: $showingAppPicker,
            allowedContentTypes: [.application],
            allowsMultipleSelection: false
        ) { result in
            handleAppSelection(result)
        }
    }

    private var headerBar: some View {
        HStack {
            Text("Configuration")
                .font(.headline)

            Spacer()
        }
        .padding()
        .background(.regularMaterial)
    }

    private var footerBar: some View {
        HStack(spacing: 12) {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            .controlSize(.large)

            Spacer()

            Button("Save") {
                saveSettings()
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .background(.clear)
    }

    private func saveSettings() {
        settings.defaultMeetApp = tempDefaultMeetApp
        settings.showInMenuBar = tempShowInMenuBar
        settings.onlyShowMeetingsWithAttendees = tempOnlyShowMeetingsWithAttendees
        settings.muteSounds = tempMuteSounds
        settings.launchAtLogin = tempLaunchAtLogin
        settings.menuBarShowIcon = tempMenuBarShowIcon
        settings.menuBarShowTitle = tempMenuBarShowTitle
        settings.menuBarShowTime = tempMenuBarShowTime
        settings.menuBarShowCountdown = tempMenuBarShowCountdown
        settings.menuBarThresholdMinutes = tempMenuBarThresholdMinutes
        settings.showAllDayInMenuBar = tempShowAllDayInMenuBar
        settings.showMeetingCountBadge = tempShowMeetingCountBadge
        settings.showTravelTimeAlerts = tempShowTravelTimeAlerts
        settings.defaultTravelMode = tempDefaultTravelMode
    }

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

    private var meetAppPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Open Google Meet with:")
                .font(.body)

            Picker("", selection: $tempDefaultMeetApp) {
                ForEach(MeetAppType.availableApps) { app in
                    Text(app.rawValue).tag(app)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: tempDefaultMeetApp) { _, newValue in
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

    private var menuBarToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Display next meeting in Menu Bar", isOn: $tempShowInMenuBar)

            Text("Shows meeting title (truncated to 30 characters) with platform icon 15 minutes before it starts")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var attendeesToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Only show meetings with attendees", isOn: $tempOnlyShowMeetingsWithAttendees)
                .disabled(!tempShowInMenuBar)

            Text("When enabled, only meetings with other attendees will be shown in the menu bar")
                .font(.caption)
                .foregroundColor(tempShowInMenuBar ? .secondary : Color.secondary.opacity(0.5))
        }
    }

    private var soundsToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Mute sounds", isOn: $tempMuteSounds)

            Text("When enabled, notification sounds will not play")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var launchAtLoginToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Launch at login", isOn: $tempLaunchAtLogin)

            Text("Automatically start MeetingNotifier when you log in")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var displayModePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Display Style:")
                .font(.body)

            VStack(alignment: .leading, spacing: 8) {
                Toggle("Icon", isOn: Binding(
                    get: { tempMenuBarShowIcon },
                    set: { newValue in
                        tempMenuBarShowIcon = newValue
                        settings.menuBarShowIcon = newValue
                    }
                ))

                Toggle("Title", isOn: Binding(
                    get: { tempMenuBarShowTitle },
                    set: { newValue in
                        tempMenuBarShowTitle = newValue
                        settings.menuBarShowTitle = newValue
                    }
                ))

                Toggle("Time", isOn: Binding(
                    get: { tempMenuBarShowTime },
                    set: { newValue in
                        tempMenuBarShowTime = newValue
                        settings.menuBarShowTime = newValue
                    }
                ))

                Toggle("Countdown", isOn: Binding(
                    get: { tempMenuBarShowCountdown },
                    set: { newValue in
                        tempMenuBarShowCountdown = newValue
                        settings.menuBarShowCountdown = newValue
                    }
                ))
            }

            Text("Select which elements to show in the menu bar. If no Icon is selected, the default calendar icon will be shown.")
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
                Text("\(tempMenuBarThresholdMinutes) min")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            Slider(value: Binding(
                get: { Double(tempMenuBarThresholdMinutes) },
                set: { tempMenuBarThresholdMinutes = Int($0) }
            ), in: 5...60, step: 5)
            .disabled(tempShowAllDayInMenuBar)

            Text("Controls how far in advance to display upcoming meetings")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var showAllDayToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Always show next meeting", isOn: $tempShowAllDayInMenuBar)

            Text("When enabled, always shows the next meeting regardless of time")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var meetingCountBadgeToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Show meeting count badge", isOn: $tempShowMeetingCountBadge)

            Text("Display number of remaining meetings today")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var travelTimeAlertsToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Enable travel time alerts", isOn: $tempShowTravelTimeAlerts)

            Text("Get notifications when it's time to leave for meetings with physical locations")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var travelModePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Default travel mode:")
                .font(.body)

            Picker("", selection: $tempDefaultTravelMode) {
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

    private func handleAppSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                customAppURL = url
                // Store the custom app URL path in UserDefaults
                UserDefaults.standard.set(url.path, forKey: "customMeetAppPath")
            }
        case .failure(let error):
            print("Error selecting app: \(error.localizedDescription)")
            // Revert to default browser if selection failed
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
