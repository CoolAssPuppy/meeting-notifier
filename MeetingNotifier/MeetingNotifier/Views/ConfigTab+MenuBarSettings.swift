//
//  ConfigTab+MenuBarSettings.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import SwiftUI

// MARK: - Meeting links and menu bar display settings

extension ConfigTab {
    var meetAppPicker: some View {
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

    var menuBarToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Display next meeting:")
                .font(.body)

            Picker("", selection: $settings.menuBarDisplayMode) {
                ForEach(MenuBarDisplayMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.menu)

            Text(menuBarDisplayModeDescription)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    var menuBarDisplayModeDescription: String {
        switch settings.menuBarDisplayMode {
        case .none:
            return "Meeting information will not be displayed in the menu bar"
        case .inMenuBar:
            return "Shows meeting title (truncated to 30 characters) with platform icon before it starts"
        case .peekWindow:
            return "Shows the next meeting in a floating window below the menu bar, matching your display preferences"
        }
    }

    var displayModePicker: some View {
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

    var thresholdSlider: some View {
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

    var peekWindowThresholdSlider: some View {
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

            Text("Controls how far in advance to show meetings in the peek window")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    var showAllDayToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Always show next meeting", isOn: $settings.showAllDayInMenuBar)

            Text("When enabled, always shows the next meeting regardless of time")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    var attendeesToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Only show meetings with attendees", isOn: $settings.onlyShowMeetingsWithAttendees)
                .disabled(settings.menuBarDisplayMode == .none)

            Text("When enabled, only meetings with other attendees will be shown")
                .font(.caption)
                .foregroundColor(settings.menuBarDisplayMode != .none ? .secondary : Color.secondary.opacity(0.5))
        }
    }

    var doubleBookingPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("When double-booked, show:")
                .font(.body)

            Picker("", selection: $settings.doubleBookingPreference) {
                ForEach(DoubleBookingPreference.allCases) { preference in
                    Text(preference.rawValue).tag(preference)
                }
            }
            .pickerStyle(.menu)
            .disabled(settings.menuBarDisplayMode == .none)

            Text("Choose which meeting to display when you have overlapping meetings")
                .font(.caption)
                .foregroundColor(settings.menuBarDisplayMode != .none ? .secondary : Color.secondary.opacity(0.5))
        }
    }

    var meetingCountBadgeToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Show meeting count badge", isOn: $settings.showMeetingCountBadge)

            Text("Display number of remaining meetings today")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    var dropDownStylePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ForEach(DropDownStyle.allCases) { style in
                    Button(action: {
                        settings.dropDownStyle = style
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: style == .simple ? "list.bullet" : "sparkles.rectangle.stack")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(
                                    settings.dropDownStyle == style
                                        ? LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        : LinearGradient(colors: [.secondary, .secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )

                            Text(style.rawValue)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(settings.dropDownStyle == style ? .primary : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(settings.dropDownStyle == style ? Color.accentColor.opacity(0.1) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(
                                    settings.dropDownStyle == style ? Color.accentColor : Color.secondary.opacity(0.3),
                                    lineWidth: settings.dropDownStyle == style ? 2 : 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(settings.dropDownStyle.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
