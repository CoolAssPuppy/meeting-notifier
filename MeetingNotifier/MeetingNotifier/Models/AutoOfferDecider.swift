//
//  AutoOfferDecider.swift
//  MeetingNotifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import Foundation

/// Pure decision logic for whether to auto-start transcription when the
/// microphone activates (or while it remains active during the safety-net
/// poll). Pulled out of TranscriptionCoordinator so the guard matrix and the
/// double-booking tie-breaker are testable without touching audio, settings,
/// or notification plumbing.
enum AutoOfferDecider {
    enum Decision: Equatable {
        case skip
        case start(CalendarEvent?)
    }

    /// Window for matching a calendar event to the active mic session.
    /// Anything starting in the next 5 minutes (or already in progress and
    /// not yet ended) counts as the "current" meeting.
    static let matchLookahead: TimeInterval = 300

    static func decide(
        state: TranscriptionState,
        suppressAutoStart: Bool,
        notetakerEnabled: Bool,
        autoOfferEnabled: Bool,
        isMicActive: Bool,
        candidates: [CalendarEvent],
        doubleBookingPreference: DoubleBookingPreference,
        now: Date = Date()
    ) -> Decision {
        guard state == .idle,
              !suppressAutoStart,
              notetakerEnabled,
              autoOfferEnabled,
              isMicActive else {
            return .skip
        }
        return .start(selectMeeting(from: candidates, now: now, preference: doubleBookingPreference))
    }

    /// The meeting (if any) that best matches an auto-offer trigger. When
    /// double-booked, the user's preference picks the larger or smaller
    /// gathering.
    static func selectMeeting(
        from candidates: [CalendarEvent],
        now: Date = Date(),
        preference: DoubleBookingPreference
    ) -> CalendarEvent? {
        let active = candidates.filter { event in
            event.startDate <= now.addingTimeInterval(matchLookahead) && event.endDate > now
        }

        guard !active.isEmpty else { return nil }
        if active.count == 1 { return active.first }

        switch preference {
        case .fewerAttendees:
            return active.min(by: { $0.attendeeCount < $1.attendeeCount })
        case .moreAttendees:
            return active.max(by: { $0.attendeeCount < $1.attendeeCount })
        }
    }
}
