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

// MARK: - Mini calendar drawer

private struct MiniCalendarDrawer: View {
    let onClose: () -> Void

    @ObservedObject private var appSettings = AppSettings.shared
    @Environment(\.theme) private var theme
    @State private var visibleMonth: Date = Calendar.current.startOfMonth(for: Date())
    @State private var calendars: [CalendarInfo] = []
    @State private var selectedCalendarKey: String?

    private static let monthYear: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMMM yyyy"
        return df
    }()

    private static func key(for calendar: CalendarInfo) -> String {
        "\(calendar.accountEmail)|\(calendar.id)"
    }

    private var selectedCalendar: CalendarInfo? {
        if let key = selectedCalendarKey,
           let match = calendars.first(where: { Self.key(for: $0) == key }) {
            return match
        }
        return calendars.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            header
            if !calendars.isEmpty {
                calendarPicker
            }
            weekdayHeader
            daysGrid
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background(theme.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(theme.divider).frame(height: 1)
        }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: AppRadius.lg, topTrailingRadius: AppRadius.lg, style: .continuous))
        .shadow(color: Color.black.opacity(0.18), radius: 10, y: -4)
        .onAppear { loadCalendars() }
    }

    private var calendarPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(calendars, id: \.self) { calendar in
                    let key = Self.key(for: calendar)
                    CalendarChip(
                        calendar: calendar,
                        isSelected: (selectedCalendar.map(Self.key(for:)) ?? "") == key,
                        onTap: { selectedCalendarKey = key }
                    )
                }
            }
            .padding(.horizontal, 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadCalendars() {
        Task { @MainActor in
            var collected: [CalendarInfo] = []
            for account in appSettings.accounts where account.isEnabled {
                let all = await CalendarDataManager.shared.fetchCalendarsForAccount(account)
                let selected = all.filter { account.selectedCalendarIds.contains($0.id) }
                collected.append(contentsOf: selected)
            }
            calendars = collected
            if selectedCalendarKey == nil, let first = collected.first {
                selectedCalendarKey = Self.key(for: first)
            }
        }
    }

    private var header: some View {
        HStack(spacing: AppSpacing.sm) {
            Text(Self.monthYear.string(from: visibleMonth))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.foreground)

            Spacer(minLength: 0)

            AppIconButton(systemName: "chevron.left", help: "Previous month") {
                shiftMonth(by: -1)
            }
            AppIconButton(systemName: "chevron.right", help: "Next month") {
                shiftMonth(by: 1)
            }
            AppIconButton(systemName: "xmark", help: "Close") {
                onClose()
            }
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(theme.tertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var daysGrid: some View {
        let cells = monthCells(for: visibleMonth)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(cells) { cell in
                DayCell(cell: cell) {
                    handleSelect(cell.date)
                }
            }
        }
    }

    private var weekdaySymbols: [String] {
        var calendar = Calendar.current
        calendar.firstWeekday = 1 // Sunday
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    private func shiftMonth(by amount: Int) {
        guard let next = Calendar.current.date(byAdding: .month, value: amount, to: visibleMonth) else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            visibleMonth = Calendar.current.startOfMonth(for: next)
        }
    }

    private func monthCells(for month: Date) -> [DayCellModel] {
        var calendar = Calendar.current
        calendar.firstWeekday = 1

        guard let monthRange = calendar.range(of: .day, in: .month, for: month),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7

        let totalDays = monthRange.count
        let totalSlots = ((leading + totalDays + 6) / 7) * 7

        let today = calendar.startOfDay(for: Date())

        return (0..<totalSlots).compactMap { offset -> DayCellModel? in
            guard let date = calendar.date(byAdding: .day, value: offset - leading, to: firstOfMonth) else {
                return nil
            }
            let inMonth = calendar.isDate(date, equalTo: month, toGranularity: .month)
            let isToday = calendar.isDate(date, inSameDayAs: today)
            return DayCellModel(date: date, isInCurrentMonth: inMonth, isToday: isToday)
        }
    }

    private func handleSelect(_ date: Date) {
        guard let url = calendarURL(for: date) else {
            onClose()
            return
        }
        AppDelegate.shared?.closePopover()
        NSWorkspace.shared.open(url)
        onClose()
    }

    private func calendarURL(for date: Date) -> URL? {
        let cal = Calendar.current
        let year = cal.component(.year, from: date)
        let month = cal.component(.month, from: date)
        let day = cal.component(.day, from: date)

        guard let calendar = selectedCalendar else {
            return URL(string: "https://calendar.google.com/calendar/u/0/r/day/\(year)/\(month)/\(day)")
        }

        switch calendar.provider {
        case .microsoft:
            let iso = String(format: "%04d-%02d-%02d", year, month, day)
            return URL(string: "https://outlook.live.com/calendar/0/view/day/\(iso)")
        case .google:
            var components = URLComponents(string: "https://calendar.google.com/calendar/u/0/r/day/\(year)/\(month)/\(day)")
            components?.queryItems = [URLQueryItem(name: "authuser", value: calendar.accountEmail)]
            return components?.url
        }
    }
}

private struct CalendarChip: View {
    let calendar: CalendarInfo
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.theme) private var theme
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
                Text(calendar.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(backgroundFill))
            .overlay(Capsule().strokeBorder(borderColor, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("\(calendar.name) · \(calendar.accountEmail)")
    }

    private var dotColor: Color {
        Color(hex: calendar.colorHex) ?? theme.primary
    }

    private var textColor: Color {
        isSelected ? theme.foreground : theme.muted
    }

    private var backgroundFill: Color {
        if isSelected { return theme.primary.opacity(0.14) }
        return isHovered ? theme.cardElevated : theme.card
    }

    private var borderColor: Color {
        isSelected ? theme.primary.opacity(0.5) : theme.border
    }
}

private struct DayCellModel: Identifiable {
    let date: Date
    let isInCurrentMonth: Bool
    let isToday: Bool
    var id: TimeInterval { date.timeIntervalSince1970 }
}

private struct DayCell: View {
    let cell: DayCellModel
    let onTap: () -> Void

    @Environment(\.theme) private var theme
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            Text("\(Calendar.current.component(.day, from: cell.date))")
                .font(.system(size: 12, weight: cell.isToday ? .semibold : .medium))
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                        .fill(backgroundFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: cell.isToday ? 1 : 0)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var textColor: Color {
        if cell.isToday { return theme.primary }
        if !cell.isInCurrentMonth { return theme.tertiary.opacity(0.6) }
        return theme.foreground
    }

    private var backgroundFill: Color {
        if cell.isToday { return theme.primary.opacity(0.12) }
        if isHovered { return theme.cardElevated }
        return Color.clear
    }

    private var borderColor: Color {
        cell.isToday ? theme.primary.opacity(0.5) : Color.clear
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? date
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
            Circle().fill(option.palette.primaryGradient)
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
