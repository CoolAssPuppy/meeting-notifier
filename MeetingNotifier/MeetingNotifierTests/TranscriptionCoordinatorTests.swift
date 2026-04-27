//
//  TranscriptionCoordinatorTests.swift
//  MeetingNotifierTests
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import XCTest
@testable import MeetingNotifier

final class TranscriptionCoordinatorTests: XCTestCase {
    private let timeout: TimeInterval = 90

    // Silence at the start of a meeting (people still joining) should not tear
    // down a live transcription. The fix: while the microphone is still being
    // used by some app, inactivity auto-stop must stay its hand.
    func test_shouldAutoStopForInactivity_whenMicIsActive_returnsFalseEvenPastTimeout() {
        let now = Date()
        let wayPastTimeout = now.addingTimeInterval(-10_000)

        let result = TranscriptionCoordinator.shouldAutoStopForInactivity(
            lastSegmentTimestamp: wayPastTimeout,
            now: now,
            isMicActive: true,
            timeout: timeout,
            hardTimeout: timeout * 10
        )

        XCTAssertFalse(result)
    }

    // Safety net: the mic has been released and no segments have arrived for
    // longer than the timeout — the meeting is over, stop the session.
    func test_shouldAutoStopForInactivity_whenMicInactiveAndElapsedExceedsTimeout_returnsTrue() {
        let now = Date()
        let pastTimeout = now.addingTimeInterval(-(timeout + 1))

        let result = TranscriptionCoordinator.shouldAutoStopForInactivity(
            lastSegmentTimestamp: pastTimeout,
            now: now,
            isMicActive: false,
            timeout: timeout,
            hardTimeout: timeout * 10
        )

        XCTAssertTrue(result)
    }

    // Mic released but still within the grace window — don't stop yet.
    func test_shouldAutoStopForInactivity_whenMicInactiveButWithinTimeout_returnsFalse() {
        let now = Date()
        let recent = now.addingTimeInterval(-(timeout - 5))

        let result = TranscriptionCoordinator.shouldAutoStopForInactivity(
            lastSegmentTimestamp: recent,
            now: now,
            isMicActive: false,
            timeout: timeout,
            hardTimeout: timeout * 10
        )

        XCTAssertFalse(result)
    }

    // If the microphone signal never flips inactive (for example due to CoreAudio
    // false positives), we still need a deterministic teardown after prolonged silence.
    func test_shouldAutoStopForInactivity_whenMicActiveAndHardTimeoutExceeded_returnsTrue() {
        let now = Date()
        let hardTimeout: TimeInterval = 120
        let pastHardTimeout = now.addingTimeInterval(-(hardTimeout + 1))

        let result = TranscriptionCoordinator.shouldAutoStopForInactivity(
            lastSegmentTimestamp: pastHardTimeout,
            now: now,
            isMicActive: true,
            timeout: timeout,
            hardTimeout: hardTimeout
        )

        XCTAssertTrue(result)
    }
}
