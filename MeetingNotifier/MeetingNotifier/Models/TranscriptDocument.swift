//
//  TranscriptDocument.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation

struct TranscriptDocument: Identifiable, Codable {
    let id: UUID
    let meetingTitle: String
    let startDate: Date
    var endDate: Date?
    let engine: TranscriptionEngineType
    let locale: String
    var segments: [TranscriptSegment]
    var calendarEventId: String?
    var attendeeCount: Int?
    var conferenceLink: String?

    init(
        id: UUID = UUID(),
        meetingTitle: String,
        startDate: Date = Date(),
        endDate: Date? = nil,
        engine: TranscriptionEngineType = .apple,
        locale: String = "en_US",
        segments: [TranscriptSegment] = [],
        calendarEventId: String? = nil,
        attendeeCount: Int? = nil,
        conferenceLink: String? = nil
    ) {
        self.id = id
        self.meetingTitle = meetingTitle
        self.startDate = startDate
        self.endDate = endDate
        self.engine = engine
        self.locale = locale
        self.segments = segments
        self.calendarEventId = calendarEventId
        self.attendeeCount = attendeeCount
        self.conferenceLink = conferenceLink
    }

    var duration: TimeInterval? {
        guard let endDate else { return nil }
        return endDate.timeIntervalSince(startDate)
    }

    var formattedDuration: String? {
        guard let duration else { return nil }
        let minutes = Int(duration) / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        }
        return "\(remainingMinutes)m"
    }

    var wordCount: Int {
        segments.reduce(0) { count, segment in
            count + segment.text.split(separator: " ").count
        }
    }

    var speakerNames: [SpeakerLabel] {
        Array(Set(segments.map(\.speaker))).sorted { $0.rawValue < $1.rawValue }
    }

    var segmentsBySpeaker: [SpeakerLabel: [TranscriptSegment]] {
        Dictionary(grouping: segments, by: \.speaker)
    }
}
