//
//  TranscriptSegmentTests.swift
//  MeetingNotifierTests
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import XCTest
@testable import MeetingNotifier

final class TranscriptSegmentTests: XCTestCase {

    // MARK: - Duration

    func testDurationCalculatesCorrectly() {
        let segment = TranscriptionTestFactories.makeSegment(startTime: 10, endTime: 25)
        XCTAssertEqual(segment.duration, 15)
    }

    func testDurationIsZeroWhenStartAndEndAreEqual() {
        let segment = TranscriptionTestFactories.makeSegment(startTime: 5, endTime: 5)
        XCTAssertEqual(segment.duration, 0)
    }

    // MARK: - Timestamp formatting

    func testFormattedStartTimeUnderOneHour() {
        let segment = TranscriptionTestFactories.makeSegment(startTime: 125)
        XCTAssertEqual(segment.formattedStartTime, "2:05")
    }

    func testFormattedStartTimeOverOneHour() {
        let segment = TranscriptionTestFactories.makeSegment(startTime: 3725)
        XCTAssertEqual(segment.formattedStartTime, "1:02:05")
    }

    func testFormattedStartTimeAtZero() {
        let segment = TranscriptionTestFactories.makeSegment(startTime: 0)
        XCTAssertEqual(segment.formattedStartTime, "0:00")
    }

    func testFormattedEndTime() {
        let segment = TranscriptionTestFactories.makeSegment(endTime: 90)
        XCTAssertEqual(segment.formattedEndTime, "1:30")
    }

    // MARK: - Static format helper

    func testFormatTimestampMinutesAndSeconds() {
        XCTAssertEqual(TranscriptSegment.formatTimestamp(65), "1:05")
    }

    func testFormatTimestampHoursMinutesSeconds() {
        XCTAssertEqual(TranscriptSegment.formatTimestamp(7265), "2:01:05")
    }

    // MARK: - Identity

    func testSegmentsWithDifferentIdsAreNotEqual() {
        let segment1 = TranscriptionTestFactories.makeSegment(id: UUID())
        let segment2 = TranscriptionTestFactories.makeSegment(id: UUID())
        XCTAssertNotEqual(segment1.id, segment2.id)
    }

    // MARK: - Codable round-trip

    func testSegmentEncodesAndDecodesCorrectly() throws {
        let original = TranscriptionTestFactories.makeSegment(
            speaker: .others,
            text: "Test encoding",
            startTime: 10,
            endTime: 20
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TranscriptSegment.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.speaker, original.speaker)
        XCTAssertEqual(decoded.text, original.text)
        XCTAssertEqual(decoded.startTime, original.startTime)
        XCTAssertEqual(decoded.endTime, original.endTime)
    }
}
