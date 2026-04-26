//
//  MiniCalendarDrawer.swift
//  MeetingNotifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import AppKit
import SwiftUI

/// Bottom drawer in the menu-bar popover that lets the user pick a calendar
/// and jump to a specific day in the provider's web calendar UI.
struct MiniCalendarDrawer: View {
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
        let calendar = Calendar.current
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
        let calendar = Calendar.current

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

// MARK: - Calendar chip

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

// MARK: - Day cell

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

// MARK: - Calendar helper

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? date
    }
}
