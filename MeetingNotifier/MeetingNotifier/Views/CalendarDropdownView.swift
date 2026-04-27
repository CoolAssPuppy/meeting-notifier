//
//  CalendarDropdownView.swift
//  MeetingNotifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import AppKit
import SwiftUI

/// Menu-bar popover. One unified theme-driven design.
struct CalendarDropdownView: View {
    @ObservedObject private var themeStore = ThemeStore.shared
    @State private var isDatePickerOpen = false

    var body: some View {
        let theme = themeStore.palette
        return VStack(spacing: 0) {
            PopoverHeader()

            AppRowDivider()

            ZStack(alignment: .bottom) {
                PopoverBody()

                if isDatePickerOpen {
                    MiniCalendarDrawer(onClose: closeDatePicker)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(1)
                }
            }
            .frame(maxHeight: .infinity)
            .clipped()

            AppRowDivider()

            PopoverFooter(isDatePickerOpen: $isDatePickerOpen)
        }
        .frame(width: 380, height: 620)
        .background(theme.background)
        .environment(\.theme, theme)
        .environment(\.colorScheme, theme.isDark ? .dark : .light)
    }

    private func closeDatePicker() {
        withAnimation(.easeOut(duration: 0.22)) {
            isDatePickerOpen = false
        }
    }
}

// MARK: - Header

private struct PopoverHeader: View {
    @ObservedObject private var dataManager = CalendarDataManager.shared
    @ObservedObject private var appSettings = AppSettings.shared
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: AppSpacing.lg) {
            BrandMark(size: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text("Meeting Notifier")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.foreground)
                HStack(spacing: 6) {
                    Circle()
                        .fill(appSettings.accounts.isEmpty ? theme.warning : theme.success)
                        .frame(width: 6, height: 6)
                    Text(statusLine)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(theme.muted)
                }
            }

            Spacer(minLength: AppSpacing.md)

            nextMeetingPill
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(theme.surface)
    }

    private var statusLine: String {
        let active = appSettings.accounts.filter(\.isEnabled).count
        if active == 0 { return "No accounts connected" }
        let totalCalendars = appSettings.accounts.reduce(0) { $0 + $1.selectedCalendarIds.count }
        return "\(active) account\(active == 1 ? "" : "s") · \(totalCalendars) calendar\(totalCalendars == 1 ? "" : "s")"
    }

    @ViewBuilder
    private var nextMeetingPill: some View {
        if let next = dataManager.events.first(where: { $0.startDate > Date() }) {
            AppStatusPill(
                text: countdownText(until: next.startDate),
                systemImage: "clock",
                style: .tinted(theme.warning)
            )
        }
    }

    private func countdownText(until date: Date) -> String {
        let minutes = max(0, Int(date.timeIntervalSinceNow / 60))
        return minutes < 60 ? "IN \(minutes) MIN" : "IN \(minutes / 60) H"
    }
}

// MARK: - Body

private struct PopoverBody: View {
    @ObservedObject private var dataManager = CalendarDataManager.shared
    @ObservedObject private var appSettings = AppSettings.shared
    @Environment(\.theme) private var theme

    var body: some View {
        if appSettings.accounts.isEmpty {
            EmptyPopoverState()
        } else if dataManager.isLoading && dataManager.events.isEmpty {
            LoadingPopoverState()
        } else if dataManager.events.isEmpty {
            NoMeetingsState()
        } else {
            meetingList
        }
    }

    private var meetingList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: AppSpacing.md) {
                let today = dataManager.todayEvents()
                let tomorrow = dataManager.tomorrowEvents()

                if !today.isEmpty {
                    MeetingSectionLabel(title: "Today · \(Date().headerDateString)",
                                        trailing: lastUpdatedText)
                    ForEach(today) { event in
                        MeetingRow(event: event, onTap: { handleTap(event) })
                    }
                }

                if !tomorrow.isEmpty {
                    MeetingSectionLabel(title: "Tomorrow · \(Date().addingTimeInterval(86_400).headerDateString)",
                                        trailing: nil)
                    ForEach(tomorrow) { event in
                        MeetingRow(event: event, onTap: { handleTap(event) })
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
        }
        .background(theme.background)
    }

    private var lastUpdatedText: String? {
        guard let last = dataManager.lastRefreshDate else { return nil }
        return "Updated \(last.shortTimeString)"
    }

    private func handleTap(_ event: CalendarEvent) {
        guard let link = event.conferenceLink, let url = URL(string: link) else { return }
        TranscriptionCoordinator.shared.registerUserSelectedMeeting(event)
        AppSettings.shared.openURL(url, accountEmail: event.accountEmail)
    }
}

private struct MeetingSectionLabel: View {
    let title: String
    let trailing: String?
    @Environment(\.theme) private var theme

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(theme.tertiary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.muted)
            }
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 2)
    }
}

// MARK: - Meeting row

private struct MeetingRow: View {
    let event: CalendarEvent
    let onTap: () -> Void

    @Environment(\.theme) private var theme
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(calendarColor)
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 7) {
                    topRow
                    Text(event.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.foreground)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    metaRow
                    if event.hasPhysicalLocation, let loc = event.location {
                        LocationChip(location: loc)
                    }
                }
                .padding(.vertical, 11)
                .padding(.horizontal, 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.card)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var borderColor: Color {
        if event.isHappening { return theme.destructive.opacity(0.5) }
        if isHovered { return theme.borderStrong }
        return theme.border
    }

    private var calendarColor: Color {
        Color(hex: event.calendarColorHex) ?? theme.primary
    }

    private var topRow: some View {
        HStack(spacing: AppSpacing.md) {
            statusBadge
            Text(timeRange)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(theme.muted)
            Spacer(minLength: 0)
            if event.hasVideoLink {
                PlatformChip(platform: event.videoPlatform)
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if event.isHappening {
            AppStatusPill(text: "LIVE", style: .tinted(theme.destructive), pulse: true)
        } else if let minutes = minutesUntil, minutes <= 15 {
            AppStatusPill(text: "IN \(minutes) MIN", style: .tinted(theme.warning))
        }
    }

    private var metaRow: some View {
        HStack(spacing: AppSpacing.md) {
            Circle().fill(calendarColor).frame(width: 6, height: 6)
            Text(metaText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.muted)
                .lineLimit(1)
        }
    }

    private var metaText: String {
        var parts: [String] = [event.calendarName]
        if event.attendeeCount > 0 {
            parts.append("\(event.attendeeCount) attendee\(event.attendeeCount == 1 ? "" : "s")")
        }
        return parts.joined(separator: " · ")
    }

    private var timeRange: String {
        "\(event.startDate.shortTimeString) – \(event.endDate.shortTimeString)"
    }

    private var minutesUntil: Int? {
        event.minutesUntilStart
    }
}

// MARK: - Platform chip

private struct PlatformChip: View {
    let platform: VideoPlatform?
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: iconName)
                .font(.system(size: 10, weight: .semibold))
            Text("Join")
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(theme.foreground)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(theme.cardElevated))
        .overlay(Capsule().strokeBorder(theme.borderStrong, lineWidth: 1))
    }

    private var iconName: String {
        switch platform {
        case .meet: return "video.fill"
        case .zoom: return "video.circle.fill"
        case .teams: return "person.2.fill"
        case .webex: return "video.fill"
        case nil: return "link"
        }
    }
}

// MARK: - Location chip

private struct LocationChip: View {
    let location: String
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(theme.primary)
            Text(location)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.foregroundSoft)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: AppRadius.md).fill(theme.cardInset))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.md).strokeBorder(theme.border, lineWidth: 1))
    }
}

// MARK: - Empty states

private struct EmptyPopoverState: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [theme.primary.opacity(0.15), theme.primary.opacity(0.05)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(theme.primary)
            }
            .frame(width: 56, height: 56)

            VStack(spacing: 4) {
                Text("No accounts connected")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.foreground)
                Text("Add a Google or Microsoft calendar to see your meetings here.")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.muted)
                    .multilineTextAlignment(.center)
            }

            AppPrimaryButton(title: "Open settings") {
                AppDelegate.shared?.openSettings()
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct LoadingPopoverState: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            ProgressView()
                .controlSize(.small)
                .tint(theme.primary)
            Text("Loading meetings…")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct NoMeetingsState: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "calendar")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(theme.tertiary)
            Text("Clear calendar")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.foreground)
            Text("Nothing scheduled for today or tomorrow.")
                .font(.system(size: 11))
                .foregroundStyle(theme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Footer

private struct PopoverFooter: View {
    @Binding var isDatePickerOpen: Bool

    @ObservedObject private var dataManager = CalendarDataManager.shared
    @ObservedObject private var transcription = TranscriptionCoordinator.shared
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            AppIconButton(systemName: "arrow.clockwise", help: "Refresh", spinOnTap: true) {
                Task { await dataManager.refreshEvents() }
            }
            AppIconButton(systemName: "macwindow", help: "Open window",
                          isActive: AppDelegate.shared?.settingsWindow?.isVisible == true) {
                AppDelegate.shared?.openMainWindow()
            }
            AppIconButton(systemName: "gearshape", help: "Settings") {
                AppDelegate.shared?.openSettings()
            }
            AppIconButton(systemName: "waveform",
                          help: "Transcription",
                          tint: transcription.state == .recording ? .destructive : .foreground) {
                AppDelegate.shared?.openTranscriptionDrawer()
            }
            AppIconButton(systemName: "calendar",
                          help: "Jump to date",
                          isActive: isDatePickerOpen) {
                withAnimation(.easeOut(duration: 0.26)) {
                    isDatePickerOpen.toggle()
                }
            }
            Spacer(minLength: 0)
            ThemeStrip()
            Spacer(minLength: 0)
            AppIconButton(systemName: "power", help: "Quit", tint: .destructive) {
                NSApp.terminate(nil)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(theme.surface)
    }
}

// (MiniCalendarDrawer + CalendarChip + DayCell live in Views/MiniCalendarDrawer.swift)
// (ThemeStrip lives in Views/ThemeStrip.swift)
// (Color(hex:) lives in Views/Components/ColorHex.swift)
