//
//  CalendarDropdownView.swift
//  MeetingNotifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import SwiftUI

/// Menu-bar popover. One unified theme-driven design.
struct CalendarDropdownView: View {
    @ObservedObject private var dataManager = CalendarDataManager.shared
    @ObservedObject private var appSettings = AppSettings.shared
    @ObservedObject private var themeStore = ThemeStore.shared
    @ObservedObject private var transcription = TranscriptionCoordinator.shared

    var body: some View {
        let theme = themeStore.palette
        return VStack(spacing: 0) {
            PopoverHeader()

            AppRowDivider()

            PopoverBody()
                .frame(maxHeight: .infinity)

            AppRowDivider()

            PopoverFooter()
        }
        .frame(width: 380, height: 620)
        .background(theme.background)
        .environment(\.theme, theme)
        .environment(\.colorScheme, theme.isDark ? .dark : .light)
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
            let minutes = max(0, Int(next.startDate.timeIntervalSinceNow / 60))
            let text = minutes < 60 ? "IN \(minutes) MIN" : "IN \(minutes / 60) H"
            HStack(spacing: 5) {
                Image(systemName: "clock")
                    .font(.system(size: 9, weight: .bold))
                Text(text)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.4)
            }
            .foregroundStyle(theme.warning)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(theme.warning.opacity(0.12))
            )
            .overlay(
                Capsule().strokeBorder(theme.warning.opacity(0.3), lineWidth: 1)
            )
        }
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
                    MeetingSectionLabel(title: "Today · \(shortDate(Date()))",
                                        trailing: lastUpdatedText)
                    ForEach(today) { event in
                        MeetingRow(event: event, onTap: { handleTap(event) })
                    }
                }

                if !tomorrow.isEmpty {
                    MeetingSectionLabel(title: "Tomorrow · \(shortDate(Date().addingTimeInterval(86_400)))",
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
        let df = DateFormatter()
        df.dateFormat = "H:mm"
        return "Updated \(df.string(from: last))"
    }

    private func shortDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "EEE MMM d"
        return df.string(from: date).uppercased()
    }

    private func handleTap(_ event: CalendarEvent) {
        guard let link = event.conferenceLink, let url = URL(string: link) else { return }
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
                    .strokeBorder(borderColor, lineWidth: isHovered ? 1 : 1)
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
            badge(text: "LIVE", color: theme.destructive, pulse: true)
        } else if let minutes = minutesUntil, minutes <= 15 {
            badge(text: "IN \(minutes) MIN", color: theme.warning, pulse: false)
        }
    }

    private func badge(text: String, color: Color, pulse: Bool) -> some View {
        HStack(spacing: 5) {
            PulsingDot(color: color, active: pulse)
            Text(text)
                .font(.system(size: 9, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.15)))
        .overlay(Capsule().strokeBorder(color.opacity(0.4), lineWidth: 1))
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
        let df = DateFormatter()
        df.dateFormat = "H:mm"
        return "\(df.string(from: event.startDate)) – \(df.string(from: event.endDate))"
    }

    private var minutesUntil: Int? {
        let m = Int(event.startDate.timeIntervalSinceNow / 60)
        return m >= 0 ? m : nil
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

// MARK: - Pulsing dot

struct PulsingDot: View {
    let color: Color
    var active: Bool = true
    @State private var phase: Double = 0

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .overlay(
                Circle()
                    .stroke(color.opacity(active ? 0.5 * (1 - phase) : 0), lineWidth: 2)
                    .scaleEffect(1 + phase * 1.2)
                    .opacity(active ? 1 : 0)
            )
            .onAppear {
                guard active else { return }
                withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
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
                AppDelegate.shared?.openSettings()
            }
            AppIconButton(systemName: "waveform",
                          help: "Transcription",
                          tint: transcription.state == .recording ? .destructive : .foreground) {
                AppDelegate.shared?.openTranscriptionDrawer()
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

// MARK: - Theme strip

struct ThemeStrip: View {
    @ObservedObject private var store = ThemeStore.shared
    @Environment(\.theme) private var theme
    @State private var isExpanded = false

    private static let bouncy: Animation = .spring(response: 0.35, dampingFraction: 0.6)
    private static let dotSize: CGFloat = 10

    var body: some View {
        HStack(spacing: isExpanded ? 6 : 0) {
            ForEach(AppTheme.allCases) { option in
                let isActive = store.current == option
                let show = isExpanded || isActive

                Button {
                    withAnimation(Self.bouncy) {
                        store.current = option
                        isExpanded = false
                    }
                } label: {
                    ZStack {
                        dotFill(for: option)
                        if isActive {
                            Circle()
                                .stroke(theme.foreground.opacity(0.9), lineWidth: 1.5)
                                .padding(-2.5)
                        }
                    }
                    .frame(width: Self.dotSize, height: Self.dotSize)
                    .scaleEffect(show ? 1 : 0.01)
                    .opacity(show ? 1 : 0)
                }
                .buttonStyle(.plain)
                .frame(width: show ? Self.dotSize : 0)
                .clipped()
                .help(option.label)
            }
        }
        .padding(.horizontal, isExpanded ? 9 : 6)
        .padding(.vertical, 5)
        .background(Capsule().fill(theme.card))
        .overlay(Capsule().strokeBorder(theme.border, lineWidth: 1))
        .animation(Self.bouncy, value: isExpanded)
        .onHover { hovering in
            withAnimation(Self.bouncy) { isExpanded = hovering }
        }
    }

    @ViewBuilder
    private func dotFill(for option: AppTheme) -> some View {
        if option == .system {
            ZStack {
                Circle().fill(Color.white)
                Circle()
                    .fill(Color.black)
                    .mask(
                        Rectangle()
                            .frame(width: Self.dotSize, height: Self.dotSize)
                            .offset(x: Self.dotSize / 2)
                    )
            }
        } else {
            let palette = option.palette
            Circle()
                .fill(
                    LinearGradient(
                        colors: [palette.primary, palette.primaryDeep],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
        }
    }
}

// MARK: - Color hex helper

extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let rgb = UInt32(h, radix: 16) else { return nil }
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0
        )
    }
}
