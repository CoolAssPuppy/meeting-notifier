//
//  TranscriptSegment.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation

struct TranscriptSegment: Identifiable, Codable, Hashable {
    let id: UUID
    let speaker: SpeakerLabel
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let timestamp: Date

    init(
        id: UUID = UUID(),
        speaker: SpeakerLabel,
        text: String,
        startTime: TimeInterval,
        endTime: TimeInterval,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.speaker = speaker
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.timestamp = timestamp
    }

    var duration: TimeInterval {
        endTime - startTime
    }

    var formattedStartTime: String {
        TranscriptSegment.formatTimestamp(startTime)
    }

    var formattedEndTime: String {
        TranscriptSegment.formatTimestamp(endTime)
    }

    static func formatTimestamp(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}
