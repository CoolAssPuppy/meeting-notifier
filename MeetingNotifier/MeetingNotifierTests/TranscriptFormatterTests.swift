//
//  TranscriptFormatterTests.swift
//  MeetingNotifierTests
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import XCTest
@testable import MeetingNotifier

final class TranscriptFormatterTests: XCTestCase {

    private let formatter = TranscriptFormatter(speakerNameMe: "Prashant", speakerNameOthers: "Others")

    // MARK: - Front matter

    func testMarkdownContainsFrontMatter() {
        let doc = TranscriptionTestFactories.makeDocument()
        let result = formatter.formatMarkdown(document: doc, summary: nil)

        XCTAssertTrue(result.hasPrefix("---\n"))
        XCTAssertTrue(result.contains("title: Team Standup"))
        XCTAssertTrue(result.contains("engine: Apple SpeechAnalyzer"))
        XCTAssertTrue(result.contains("locale: en_US"))
    }

    func testFrontMatterContainsSpeakers() {
        let doc = TranscriptionTestFactories.makeDocument()
        let result = formatter.formatMarkdown(document: doc, summary: nil)

        XCTAssertTrue(result.contains("speakers: [Prashant, Others]"))
    }

    func testFrontMatterContainsAttendeeCount() {
        let doc = TranscriptionTestFactories.makeDocument(attendeeCount: 8)
        let result = formatter.formatMarkdown(document: doc, summary: nil)

        XCTAssertTrue(result.contains("attendees: 8"))
    }

    func testFrontMatterContainsConferenceLink() {
        let doc = TranscriptionTestFactories.makeDocument(conferenceLink: "https://zoom.us/j/123")
        let result = formatter.formatMarkdown(document: doc, summary: nil)

        XCTAssertTrue(result.contains("conference_link: https://zoom.us/j/123"))
    }

    func testFrontMatterUsesCustomTemplate() {
        let doc = TranscriptionTestFactories.makeDocument()
        let template = "tags: [meeting, standup]\ntitle: {title}"
        let result = formatter.formatMarkdown(document: doc, summary: nil, frontMatterTemplate: template)

        XCTAssertTrue(result.contains("tags: [meeting, standup]"))
        XCTAssertTrue(result.contains("title: Team Standup"))
    }

    func testFrontMatterExpandsDateToken() {
        let doc = TranscriptionTestFactories.makeDocument()
        let template = "date: {date}"
        let result = formatter.formatMarkdown(document: doc, summary: nil, frontMatterTemplate: template)

        XCTAssertTrue(result.contains("date: "))
        XCTAssertFalse(result.contains("{date}"))
    }

    func testFrontMatterExpandsAttendeeNamesToken() {
        let doc = TranscriptionTestFactories.makeDocument(
            attendeeNames: ["Alice", "Bob"]
        )
        let template = "attendee_names: [{attendee_names}]"
        let result = formatter.formatMarkdown(document: doc, summary: nil, frontMatterTemplate: template)

        XCTAssertTrue(result.contains("attendee_names: [Alice, Bob]"))
    }

    func testFrontMatterEndDateEmptyWhenNil() {
        let doc = TranscriptionTestFactories.makeDocument(endDate: nil)
        let template = "end_date: {end_date}\nduration: {duration}"
        let result = formatter.formatMarkdown(document: doc, summary: nil, frontMatterTemplate: template)

        XCTAssertTrue(result.contains("end_date: \n"))
        XCTAssertTrue(result.contains("duration: \n"))
    }

    // MARK: - Summary section

    func testSummaryHeaderContainsMeetingInfo() {
        let doc = TranscriptionTestFactories.makeDocument(meetingTitle: "Sprint Review")
        let result = formatter.formatMarkdown(document: doc, summary: nil)

        XCTAssertTrue(result.contains("## Summary for Sprint Review with"))
    }

    func testSummaryWithOpenAIContent() {
        let doc = TranscriptionTestFactories.makeDocument()
        let summary = MeetingSummary(
            summary: "The team discussed sprint progress.",
            actionItems: [
                ActionItem(description: "Update the backlog", assignee: "Prashant"),
                ActionItem(description: "Review PRs", assignee: nil),
            ]
        )
        let result = formatter.formatMarkdown(document: doc, summary: summary)

        XCTAssertTrue(result.contains("The team discussed sprint progress."))
        XCTAssertTrue(result.contains("## Action Items"))
        XCTAssertTrue(result.contains("[ ] Update the backlog (Assigned to: Prashant)"))
        XCTAssertTrue(result.contains("[ ] Review PRs"))
        XCTAssertFalse(result.contains("Assigned to:") && result.contains("Review PRs (Assigned to:"))
    }

    func testNoSummaryShowsPlaceholder() {
        let doc = TranscriptionTestFactories.makeDocument()
        let result = formatter.formatMarkdown(document: doc, summary: nil)

        XCTAssertTrue(result.contains("*Summary unavailable."))
    }

    func testNoActionItemsShowsPlaceholder() {
        let doc = TranscriptionTestFactories.makeDocument()
        let summary = MeetingSummary(summary: "A meeting happened.", actionItems: [])
        let result = formatter.formatMarkdown(document: doc, summary: summary)

        XCTAssertTrue(result.contains("*No action items identified.*"))
    }

    // MARK: - Full transcript section

    func testTranscriptGroupsByConsecutiveSpeaker() {
        let segments = [
            TranscriptionTestFactories.makeSegment(speaker: .me, text: "Hello", startTime: 0, endTime: 2),
            TranscriptionTestFactories.makeSegment(speaker: .me, text: "How are you?", startTime: 2, endTime: 4),
            TranscriptionTestFactories.makeSegment(speaker: .others, text: "Good, thanks!", startTime: 4, endTime: 6),
        ]
        let doc = TranscriptionTestFactories.makeDocument(segments: segments)
        let result = formatter.formatMarkdown(document: doc, summary: nil)

        let prashantCount = result.components(separatedBy: "**Prashant**").count - 1
        let othersCount = result.components(separatedBy: "**Others**").count - 1
        XCTAssertEqual(prashantCount, 1)
        XCTAssertEqual(othersCount, 1)
    }

    func testTranscriptShowsTimestampOnSpeakerChange() {
        let segments = [
            TranscriptionTestFactories.makeSegment(speaker: .me, text: "Hi", startTime: 65, endTime: 67),
        ]
        let doc = TranscriptionTestFactories.makeDocument(segments: segments)
        let result = formatter.formatMarkdown(document: doc, summary: nil)

        XCTAssertTrue(result.contains("**Prashant** [1:05]"))
    }

    func testEmptySegmentsProduceEmptyTranscriptMessage() {
        let doc = TranscriptionTestFactories.makeDocument(segments: [])
        let result = formatter.formatMarkdown(document: doc, summary: nil)

        XCTAssertTrue(result.contains("*No transcript segments recorded.*"))
    }

    func testTranscriptSectionIsLabeledFullTranscript() {
        let doc = TranscriptionTestFactories.makeDocument()
        let result = formatter.formatMarkdown(document: doc, summary: nil)

        XCTAssertTrue(result.contains("## Full Transcript"))
    }

    // MARK: - Filename generation

    func testGenerateFilenameWithDateAndTitle() {
        let doc = TranscriptionTestFactories.makeDocument(
            meetingTitle: "Team Standup",
            startDate: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let filename = formatter.generateFilename(document: doc, schema: "{yyyy}{mm}{dd}-{title}")

        XCTAssertTrue(filename.hasSuffix(".md"))
        XCTAssertTrue(filename.contains("team-standup"))
    }

    func testGenerateFilenameSanitizesSpecialCharacters() {
        let doc = TranscriptionTestFactories.makeDocument(meetingTitle: "Q4 Review: Budget & Plans!")
        let filename = formatter.generateFilename(document: doc, schema: "{yyyy}{mm}{dd}-{title}")

        XCTAssertFalse(filename.contains(":"))
        XCTAssertFalse(filename.contains("&"))
        XCTAssertFalse(filename.contains("!"))
    }

    // MARK: - File deduplication

    func testDeduplicatedFileURLReturnsOriginalWhenNoConflict() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("notes.md")
        let result = TranscriptFormatter.deduplicatedFileURL(for: fileURL)

        XCTAssertEqual(result.lastPathComponent, "notes.md")
    }

    func testDeduplicatedFileURLAppendsSuffixWhenFileExists() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("notes.md")
        FileManager.default.createFile(atPath: fileURL.path, contents: Data("existing".utf8))

        let result = TranscriptFormatter.deduplicatedFileURL(for: fileURL)

        XCTAssertEqual(result.lastPathComponent, "notes-1.md")
    }

    func testDeduplicatedFileURLIncrementsUntilAvailable() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("notes.md")
        FileManager.default.createFile(atPath: fileURL.path, contents: Data("v1".utf8))
        let dash1 = tempDir.appendingPathComponent("notes-1.md")
        FileManager.default.createFile(atPath: dash1.path, contents: Data("v2".utf8))

        let result = TranscriptFormatter.deduplicatedFileURL(for: fileURL)

        XCTAssertEqual(result.lastPathComponent, "notes-2.md")
    }

    // MARK: - Speaker display name

    func testSpeakerDisplayNameMapsCorrectly() {
        XCTAssertEqual(formatter.speakerDisplayName(.me), "Prashant")
        XCTAssertEqual(formatter.speakerDisplayName(.others), "Others")
        XCTAssertEqual(formatter.speakerDisplayName(.unknown), "Unknown")
    }
}
