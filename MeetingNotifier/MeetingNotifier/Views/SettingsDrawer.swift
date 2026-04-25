//
//  SettingsDrawer.swift
//  MeetingNotifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import SwiftUI

struct SettingsDrawer: View {
    let onClose: () -> Void

    @ObservedObject private var appSettings = AppSettings.shared
    @State private var telemetryOptIn: Bool = Telemetry.isOptedIn
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 14) {
                        generalCard
                        menuBarCard
                    }.frame(maxWidth: .infinity)

                    VStack(spacing: 14) {
                        meetingLinkCard
                        privacyCard
                        updatesCard
                        supportCard
                        contactCard
                    }.frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
        }
        .background(theme.background)
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: AppRadius.xxl, bottomTrailingRadius: AppRadius.xxl, style: .continuous))
        .shadow(color: Color.black.opacity(0.45), radius: 18, y: 8)
    }

    private var header: some View {
        HStack(spacing: AppSpacing.lg) {
            DrawerIcon(systemName: "gearshape")
            VStack(alignment: .leading, spacing: 3) {
                Text("Settings")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(theme.foreground)
                Text("General preferences · menu bar · updates")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.muted)
            }
            Spacer(minLength: 0)
            CloseButton(onClose: onClose)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.divider).frame(height: 1)
        }
    }

    // MARK: - Cards

    private var generalCard: some View {
        AppCard("General") {
            VStack(spacing: AppSpacing.md) {
                AppSettingRow("Launch at login",
                              description: "Start Meeting Notifier when you sign in") {
                    Toggle("", isOn: $appSettings.launchAtLogin).toggleStyle(.switch).labelsHidden().tint(theme.primary)
                }
                AppRowDivider()
                AppSettingRow("Double-booking preference",
                              description: "How to rank overlapping meetings") {
                    Picker("", selection: $appSettings.doubleBookingPreference) {
                        ForEach(DoubleBookingPreference.allCases) { pref in
                            Text(pref.rawValue).tag(pref)
                        }
                    }
                    .appBoxedPicker(width: 220)
                }
                AppRowDivider()
                AppSettingRow("Mute sounds",
                              description: "Silence notification chimes") {
                    Toggle("", isOn: $appSettings.muteSounds).toggleStyle(.switch).labelsHidden().tint(theme.primary)
                }
                AppRowDivider()
                AppSettingRow("Send anonymous usage data",
                              description: "Help improve Meeting Notifier.") {
                    Toggle("", isOn: Binding(
                        get: { telemetryOptIn },
                        set: { newValue in
                            telemetryOptIn = newValue
                            Telemetry.setOptedIn(newValue)
                        }
                    )).toggleStyle(.switch).labelsHidden().tint(theme.primary)
                }
            }
        }
    }

    private var menuBarCard: some View {
        AppCard("Menu bar") {
            VStack(spacing: AppSpacing.md) {
                AppSettingRow("Display mode",
                              description: "How the next meeting shows in the menu bar") {
                    Picker("", selection: $appSettings.menuBarDisplayMode) {
                        ForEach(MenuBarDisplayMode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }.appBoxedPicker(width: 180)
                }
                AppRowDivider()
                AppSettingRow("Show icon",
                              description: nil) {
                    Toggle("", isOn: $appSettings.menuBarShowIcon).toggleStyle(.switch).labelsHidden().tint(theme.primary)
                }
                AppRowDivider()
                AppSettingRow("Show title",
                              description: nil) {
                    Toggle("", isOn: $appSettings.menuBarShowTitle).toggleStyle(.switch).labelsHidden().tint(theme.primary)
                }
                AppRowDivider()
                AppSettingRow("Show countdown",
                              description: "Replace time with minutes-until") {
                    Toggle("", isOn: $appSettings.menuBarShowCountdown).toggleStyle(.switch).labelsHidden().tint(theme.primary)
                }
                AppRowDivider()
                AppSettingRow("Urgent threshold",
                              description: "Tint the title when this close") {
                    HStack(spacing: 4) {
                        Stepper(value: $appSettings.menuBarThresholdMinutes, in: 1...60) {
                            Text("\(appSettings.menuBarThresholdMinutes) min")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(theme.foreground)
                        }
                        .labelsHidden()
                    }
                }
            }
        }
    }

    private var privacyCard: some View {
        AppCard("Privacy") {
            VStack(spacing: AppSpacing.md) {
                AppSettingRow("Sync settings to iCloud",
                              description: "Mirror your preferences across your Macs") {
                    Toggle("", isOn: $appSettings.settingsSyncEnabled).toggleStyle(.switch).labelsHidden().tint(theme.primary)
                }
            }
        }
    }

    private var meetingLinkCard: some View {
        AppCard("Meeting links") {
            VStack(spacing: AppSpacing.md) {
                AppSettingRow("Open links in",
                              description: "Browser or native app for video calls") {
                    Picker("", selection: $appSettings.defaultMeetApp) {
                        ForEach(MeetAppType.availableApps) { app in
                            Text(app.rawValue).tag(app)
                        }
                    }.appBoxedPicker(width: 200)
                }
                AppRowDivider()
                AppSettingRow("Map provider",
                              description: "For physical locations") {
                    Picker("", selection: $appSettings.preferredMapProvider) {
                        ForEach(MapProvider.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }.appBoxedPicker(width: 160)
                }
                AppRowDivider()
                AppSettingRow("Travel time alerts",
                              description: "Warn if you need to leave soon") {
                    Toggle("", isOn: $appSettings.showTravelTimeAlerts).toggleStyle(.switch).labelsHidden().tint(theme.primary)
                }
            }
        }
    }

    private var updatesCard: some View {
        AppCard("Updates") {
            VStack(spacing: AppSpacing.md) {
                AppSettingRow("Automatically check for updates", description: nil) {
                    Toggle("", isOn: Binding(
                        get: { UpdaterManager.shared.automaticallyChecksForUpdates },
                        set: { UpdaterManager.shared.automaticallyChecksForUpdates = $0 }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(theme.primary)
                }

                AppRowDivider()

                AppSettingRow("Current version", description: nil) {
                    Text(Bundle.main.appVersionString)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(theme.foreground)
                }

                AppRowDivider()

                Button { UpdaterManager.shared.checkForUpdates() } label: {
                    Text("Check for updates…")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.foreground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                                .strokeBorder(theme.borderStrong, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var supportCard: some View {
        AppCard("Support") {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("If Meeting Notifier keeps you on time, a small tip keeps me coding.")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.foregroundSoft)
                HStack(spacing: AppSpacing.md) {
                    AppPrimaryButton(title: "Buy me a coffee", systemImage: "cup.and.saucer.fill") {
                        NSWorkspace.shared.open(URL(string: "https://www.buymeacoffee.com/coolasspuppy")!)
                    }
                    AppSecondaryButton(title: "GitHub", systemImage: "star") {
                        NSWorkspace.shared.open(URL(string: "https://github.com/coolasspuppy/meeting-notifier")!)
                    }
                }
            }
        }
    }

    private var contactCard: some View {
        AppCard("Contact") {
            VStack(alignment: .leading, spacing: 10) {
                contactRow(icon: "ladybug.fill",
                           title: "bugs@strategicnerds.dev",
                           url: "mailto:bugs@strategicnerds.dev")
                contactRow(icon: "chevron.left.forwardslash.chevron.right",
                           title: "coolasspuppy/meeting-notifier",
                           url: "https://github.com/coolasspuppy/meeting-notifier")
                contactRow(icon: "cup.and.saucer.fill",
                           title: "Buy me coffee",
                           url: "https://venmo.com/u/coolasspuppy")
                contactRow(icon: "book.closed.fill",
                           title: "Buy my book",
                           url: "https://www.strategicnerds.com/picksandshovels")
            }
        }
    }

    private func contactRow(icon: String, title: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.muted)
                    .frame(width: 16, alignment: .center)
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

