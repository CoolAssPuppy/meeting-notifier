//
//  ConfigTab+GeneralSettings.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import SwiftUI

// MARK: - Travel, sounds, startup, keyboard, support, and about settings

extension ConfigTab {
    var soundsToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Mute sounds", isOn: $settings.muteSounds)

            Text("When enabled, notification sounds will not play")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    var travelTimeAlertsToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Enable travel time alerts", isOn: $settings.showTravelTimeAlerts)

            Text("Get notifications when it's time to leave for meetings with physical locations")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    var travelModePicker: some View {
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

    var mapProviderPicker: some View {
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

    var launchAtLoginToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Launch at login", isOn: $settings.launchAtLogin)

            Text("Automatically start MeetingNotifier when you log in")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    var keyboardShortcutsInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            shortcutRow(keys: "\u{2318}\u{21E7}M", description: "Join next meeting")
            shortcutRow(keys: "\u{2318}\u{21E7}O", description: "Open/close dropdown")
            shortcutRow(keys: "\u{2318}\u{21E7}R", description: "Refresh meetings")

            Text("Global keyboard shortcuts for quick access")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
    }

    func shortcutRow(keys: String, description: String) -> some View {
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

    var buyMeCoffeeButton: some View {
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

    var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Made with love by Strategic Nerds, Inc.")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("\u{00A9} 2025 Strategic Nerds, Inc.")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("Build \(appBuildNumber)")
                .font(.caption)
                .foregroundColor(.secondary)

            Link("Contribute on GitHub", destination: URL(string: "https://github.com/coolasspuppy/meeting-notifier")!)
                .font(.caption)
        }
    }

    var appBuildNumber: String {
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return build
        }
        return "Unknown"
    }
}
