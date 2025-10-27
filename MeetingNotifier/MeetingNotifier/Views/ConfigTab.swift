import SwiftUI
import AppKit

struct ConfigTab: View {
    @ObservedObject var settings = AppSettings.shared
    @Environment(\.dismiss) var dismiss

    @State private var tempDefaultMeetApp: MeetAppType
    @State private var tempShowInMenuBar: Bool
    @State private var tempOnlyShowMeetingsWithAttendees: Bool
    @State private var tempMuteSounds: Bool
    @State private var showingAppPicker = false
    @State private var customAppURL: URL?

    init() {
        let settings = AppSettings.shared
        _tempDefaultMeetApp = State(initialValue: settings.defaultMeetApp)
        _tempShowInMenuBar = State(initialValue: settings.showInMenuBar)
        _tempOnlyShowMeetingsWithAttendees = State(initialValue: settings.onlyShowMeetingsWithAttendees)
        _tempMuteSounds = State(initialValue: settings.muteSounds)
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
                            Text("Meeting Links")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }

                        Section {
                            menuBarToggle
                            attendeesToggle
                        } header: {
                            Text("Menu Bar Display")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }

                        Section {
                            soundsToggle
                        } header: {
                            Text("Sounds")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                    .formStyle(.grouped)
                }
                .padding(20)
            }

            Divider()

            footerBar
        }
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
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button("Save") {
                saveSettings()
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.regularMaterial)
    }

    private func saveSettings() {
        settings.defaultMeetApp = tempDefaultMeetApp
        settings.showInMenuBar = tempShowInMenuBar
        settings.onlyShowMeetingsWithAttendees = tempOnlyShowMeetingsWithAttendees
        settings.muteSounds = tempMuteSounds
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
