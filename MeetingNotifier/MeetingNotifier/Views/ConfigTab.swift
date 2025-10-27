import SwiftUI
import AppKit

struct ConfigTab: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var showingAppPicker = false
    @State private var customAppURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Configuration")
                .font(.headline)

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

            Spacer()
        }
        .padding(20)
        .fileImporter(
            isPresented: $showingAppPicker,
            allowedContentTypes: [.application],
            allowsMultipleSelection: false
        ) { result in
            handleAppSelection(result)
        }
    }

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

    private var menuBarToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Display next meeting in Menu Bar", isOn: $settings.showInMenuBar)

            Text("Shows meeting title (truncated to 30 characters) with platform icon 15 minutes before it starts")
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

    private var soundsToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Mute sounds", isOn: $settings.muteSounds)

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
