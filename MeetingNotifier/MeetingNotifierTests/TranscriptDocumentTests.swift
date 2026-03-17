//
//  TranscriptDocumentTests.swift
//  MeetingNotifierTests
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import XCTest
@testable import MeetingNotifier

final class TranscriptDocumentTests: XCTestCase {

    // MARK: - Duration

    func testDurationCalculatesFromStartAndEndDates() {
        let doc = TranscriptionTestFactories.makeDocument(
            startDate: Date(timeIntervalSince1970: 1_000),
            endDate: Date(timeIntervalSince1970: 2_800)
        )
        XCTAssertEqual(doc.duration, 1800)
    }

    func testDurationIsNilWhenEndDateIsNil() {
        let doc = TranscriptionTestFactories.makeDocument(endDate: nil)
        XCTAssertNil(doc.duration)
    }

    // MARK: - Formatted duration

    func testFormattedDurationShowsMinutesOnly() {
        let doc = TranscriptionTestFactories.makeDocument(
            startDate: Date(timeIntervalSince1970: 0),
            endDate: Date(timeIntervalSince1970: 2700)
        )
        XCTAssertEqual(doc.formattedDuration, "45m")
    }

    func testFormattedDurationShowsHoursAndMinutes() {
        let doc = TranscriptionTestFactories.makeDocument(
            startDate: Date(timeIntervalSince1970: 0),
            endDate: Date(timeIntervalSince1970: 5400)
        )
        XCTAssertEqual(doc.formattedDuration, "1h 30m")
    }

    func testFormattedDurationIsNilWhenNoEndDate() {
        let doc = TranscriptionTestFactories.makeDocument(endDate: nil)
        XCTAssertNil(doc.formattedDuration)
    }

    // MARK: - Word count

    func testWordCountSumsAllSegments() {
        let segments = [
            TranscriptionTestFactories.makeSegment(text: "Hello world"),
            TranscriptionTestFactories.makeSegment(text: "One two three four"),
        ]
        let doc = TranscriptionTestFactories.makeDocument(segments: segments)
        XCTAssertEqual(doc.wordCount, 6)
    }

    func testWordCountIsZeroWithNoSegments() {
        let doc = TranscriptionTestFactories.makeDocument(segments: [])
        XCTAssertEqual(doc.wordCount, 0)
    }

    // MARK: - Speaker names

    func testSpeakerNamesReturnsUniqueSpeakers() {
        let segments = [
            TranscriptionTestFactories.makeSegment(speaker: .me),
            TranscriptionTestFactories.makeSegment(speaker: .others),
            TranscriptionTestFactories.makeSegment(speaker: .me),
        ]
        let doc = TranscriptionTestFactories.makeDocument(segments: segments)
        XCTAssertEqual(doc.speakerNames.count, 2)
        XCTAssertTrue(doc.speakerNames.contains(.me))
        XCTAssertTrue(doc.speakerNames.contains(.others))
    }

    // MARK: - Segments by speaker

    func testSegmentsBySpeakerGroupsCorrectly() {
        let segments = [
            TranscriptionTestFactories.makeSegment(speaker: .me, text: "First"),
            TranscriptionTestFactories.makeSegment(speaker: .others, text: "Second"),
            TranscriptionTestFactories.makeSegment(speaker: .me, text: "Third"),
        ]
        let doc = TranscriptionTestFactories.makeDocument(segments: segments)
        let grouped = doc.segmentsBySpeaker

        XCTAssertEqual(grouped[.me]?.count, 2)
        XCTAssertEqual(grouped[.others]?.count, 1)
    }

    // MARK: - Codable round-trip

    func testDocumentEncodesAndDecodesCorrectly() throws {
        let original = TranscriptionTestFactories.makeDocument()

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TranscriptDocument.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.meetingTitle, original.meetingTitle)
        XCTAssertEqual(decoded.engine, original.engine)
        XCTAssertEqual(decoded.segments.count, original.segments.count)
    }
}
