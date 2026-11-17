//
//  CalendarDayDots.swift
//  MeetingNotifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import Foundation

/// One colored dot under a day in the mini calendar: this calendar has at
/// least one event on that day.
struct CalendarDayDot: Equatable, Hashable {
    let calendarKey: String
    let colorHex: String
    /// The day is in the past, or it is today and every event this calendar
    /// has on it has already ended.
    let isMuted: Bool
}

/// Works out which dots a day in the mini calendar shows. Pure, so the date
/// rules (midnight crossings, all-day events, "today but already over") are
/// tested without the UI.
enum CalendarDayDots {
    /// Calendar ids are only unique per account, so the key pairs them.
    static func key(calendarId: String, accountEmail: String?) -> String {
        "\(accountEmail ?? "")|\(calendarId)"
    }

    static func key(for calendar: CalendarInfo) -> String {
        key(calendarId: calendar.id, accountEmail: calendar.accountEmail)
    }

    /// - Parameters:
    ///   - calendars: the selected calendars, in the order their dots appear.
    ///   - calendar: supplies the day boundaries and time zone.
    static func dots(for day: Date, events: [CalendarEvent], calendars: [CalendarInfo],
                     now: Date, calendar: Calendar) -> [CalendarDayDot] {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }

        let todayStart = calendar.startOfDay(for: now)
        let isPastDay = dayStart < todayStart
        let isToday = dayStart == todayStart

        let eventsOnDay = events.filter { overlaps($0, start: dayStart, end: dayEnd) }
        let byCalendar = Dictionary(grouping: eventsOnDay) {
            key(calendarId: $0.calendarId, accountEmail: $0.accountEmail)
        }

        return calendars.compactMap { info in
            let calendarKey = key(for: info)
            guard let matches = byCalendar[calendarKey], !matches.isEmpty else { return nil }
            let allEnded = matches.allSatisfy { $0.endDate <= now }
            let isMuted = isPastDay || (isToday && allEnded)
            return CalendarDayDot(calendarKey: calendarKey, colorHex: info.colorHex, isMuted: isMuted)
        }
    }

    /// Half-open overlap, so an event ending at midnight stays on its own day.
    /// A zero-length event counts for the day its start falls in.
    private static func overlaps(_ event: CalendarEvent, start: Date, end: Date) -> Bool {
        if event.endDate <= event.startDate {
            return event.startDate >= start && event.startDate < end
        }
        return event.startDate < end && event.endDate > start
    }
}
