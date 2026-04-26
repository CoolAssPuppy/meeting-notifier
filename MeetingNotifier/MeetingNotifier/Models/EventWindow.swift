//
//  EventWindow.swift
//  MeetingNotifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import Foundation

/// The time range used for fetching and filtering calendar events.
/// After 5 PM local time we look forward into tomorrow so the menu bar
/// answers the "what's left today, then what's next" question; before 5 PM
/// the window stays today-only so users see "nothing happening today" as a
/// glanceable signal during the work day.
struct EventWindow {
    let start: Date
    let end: Date
    let includesTomorrow: Bool

    static let tomorrowCutoffHour = 17

    static func current(now: Date = Date(), calendar: Calendar = .current) -> EventWindow {
        let endOfToday = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now
        let hour = calendar.component(.hour, from: now)
        let includesTomorrow = hour >= tomorrowCutoffHour

        let end: Date
        if includesTomorrow,
           let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)),
           let endOfTomorrow = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: startOfTomorrow) {
            end = endOfTomorrow
        } else {
            end = endOfToday
        }

        return EventWindow(start: now, end: end, includesTomorrow: includesTomorrow)
    }

    /// Filters events into the current window: anything currently happening,
    /// anything starting today before midnight, and (after 5 PM) anything in
    /// tomorrow's calendar day.
    ///
    /// `now` is overridable for tests. Production uses `start` (which is
    /// the now passed to `current(now:)`), so the window's notion of "now"
    /// matches the events it accepts as currently-happening.
    func filter<S: Sequence>(_ events: S, now overrideNow: Date? = nil) -> [S.Element] where S.Element == CalendarEvent {
        let now = overrideNow ?? start
        let calendar = Calendar.current
        let endOfToday = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: start) ?? start
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: start)) ?? start
        let endOfTomorrow = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: startOfTomorrow) ?? startOfTomorrow

        return events.filter { event in
            if event.startDate <= now && event.endDate > now { return true }
            if event.startDate >= start && event.startDate <= endOfToday { return true }
            if includesTomorrow && event.startDate >= startOfTomorrow && event.startDate <= endOfTomorrow { return true }
            return false
        }
    }
}
