//
//  TranscriptionTestFactories.swift
//  MeetingNotifierTests
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation
@testable import MeetingNotifier

enum TranscriptionTestFactories {

    static func makeSegment(
        id: UUID = UUID(),
        speaker: SpeakerLabel = .me,
        text: String = "Hello, this is a test segment.",
        startTime: TimeInterval = 0,
        endTime: TimeInterval = 5,
        timestamp: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> TranscriptSegment {
        TranscriptSegment(
            id: id,
            speaker: speaker,
            text: text,
            startTime: startTime,
            endTime: endTime,
            timestamp: timestamp
        )
    }

    static func makeDocument(
        id: UUID = UUID(),
        meetingTitle: String = "Team Standup",
        startDate: Date = Date(timeIntervalSince1970: 1_700_000_000),
        endDate: Date? = Date(timeIntervalSince1970: 1_700_001_800),
        engine: TranscriptionEngineType = .apple,
        locale: String = "en_US",
        segments: [TranscriptSegment]? = nil,
        calendarEventId: String? = "event_123",
        attendeeCount: Int? = 5,
        attendeeNames: [String]? = ["Prashant Sridharan", "Jane Smith", "Bob Lee"],
        conferenceLink: String? = "https://meet.google.com/abc-def-ghi"
    ) -> TranscriptDocument {
        let defaultSegments = segments ?? [
            makeSegment(speaker: .me, text: "Good morning everyone.", startTime: 0, endTime: 3),
            makeSegment(speaker: .others, text: "Good morning!", startTime: 3, endTime: 5),
            makeSegment(speaker: .me, text: "Let's review the sprint progress.", startTime: 5, endTime: 10),
            makeSegment(speaker: .others, text: "Sure, I finished the API integration yesterday.", startTime: 10, endTime: 16),
        ]

        return TranscriptDocument(
            id: id,
            meetingTitle: meetingTitle,
            startDate: startDate,
            endDate: endDate,
            engine: engine,
            locale: locale,
            segments: defaultSegments,
            calendarEventId: calendarEventId,
            attendeeCount: attendeeCount,
            attendeeNames: attendeeNames,
            conferenceLink: conferenceLink
        )
    }
}
