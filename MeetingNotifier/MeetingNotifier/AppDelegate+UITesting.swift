//
//  AppDelegate+UITesting.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation

#if DEBUG

extension AppDelegate {
    func setupTestDataForUITesting() {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)

        components.hour = 9
        components.minute = 0
        let meeting1Start = calendar.date(from: components)!

        components.hour = 10
        components.minute = 30
        let meeting2Start = calendar.date(from: components)!

        components.hour = 14
        components.minute = 0
        let meeting3Start = calendar.date(from: components)!

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        var tomorrowComponents = calendar.dateComponents([.year, .month, .day], from: tomorrow)

        tomorrowComponents.hour = 9
        tomorrowComponents.minute = 0
        let meeting4Start = calendar.date(from: tomorrowComponents)!

        tomorrowComponents.hour = 11
        tomorrowComponents.minute = 0
        let meeting5Start = calendar.date(from: tomorrowComponents)!

        let testEvents = [
            createTestEvent(title: "Team Standup", startDate: meeting1Start, duration: 15, conferenceType: "zoom"),
            createTestEvent(title: "Client Meeting - Q4 Review", startDate: meeting2Start, duration: 60, conferenceType: "meet"),
            createTestEvent(title: "1:1 with Manager", startDate: meeting3Start, duration: 30, conferenceType: "teams"),
            createTestEvent(title: "Design Review", startDate: meeting4Start, duration: 45, conferenceType: "zoom"),
            createTestEvent(title: "Sprint Planning", startDate: meeting5Start, duration: 90, conferenceType: "meet"),
        ]

        CalendarDataManager.shared.setTestEvents(testEvents)
    }

    private func createTestEvent(
        title: String,
        startDate: Date,
        duration: Int,
        conferenceType: String
    ) -> CalendarEvent {
        let endDate = Calendar.current.date(byAdding: .minute, value: duration, to: startDate)!

        let conferenceLink: String
        switch conferenceType {
        case "zoom": conferenceLink = "https://zoom.us/j/1234567890"
        case "meet": conferenceLink = "https://meet.google.com/abc-defg-hij"
        case "teams": conferenceLink = "https://teams.microsoft.com/l/meetup-join/123"
        default: conferenceLink = ""
        }

        return CalendarEvent(
            id: UUID().uuidString,
            title: title,
            startDate: startDate,
            endDate: endDate,
            location: nil,
            description: "Test meeting for screenshots",
            conferenceLink: conferenceLink,
            calendarId: "test-calendar",
            calendarName: "Test Calendar",
            calendarColorHex: "#4285F4",
            provider: .google,
            reminders: [],
            attendeeCount: 3,
            accountEmail: "test@example.com"
        )
    }
}

#endif
