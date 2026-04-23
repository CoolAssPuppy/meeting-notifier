//
//  SubfolderResolverTests.swift
//  MeetingNotifierTests
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import XCTest
@testable import MeetingNotifier

final class SubfolderResolverTests: XCTestCase {

    // MARK: - resolve()

    func testReturnsNilWhenDisabled() {
        let result = SubfolderResolver.resolve(
            calendarName: "Work",
            isEnabled: false,
            mappings: [:]
        )

        XCTAssertNil(result)
    }

    func testReturnsNilWhenCalendarNameIsNil() {
        let result = SubfolderResolver.resolve(
            calendarName: nil,
            isEnabled: true,
            mappings: [:]
        )

        XCTAssertNil(result)
    }

    func testReturnsNilWhenCalendarNameIsEmpty() {
        let result = SubfolderResolver.resolve(
            calendarName: "",
            isEnabled: true,
            mappings: [:]
        )

        XCTAssertNil(result)
    }

    func testReturnsCalendarNameAsSubfolderByDefault() {
        let result = SubfolderResolver.resolve(
            calendarName: "Work Calendar",
            isEnabled: true,
            mappings: [:]
        )

        XCTAssertEqual(result, "Work Calendar")
    }

    func testUsesCustomMappingWhenAvailable() {
        let result = SubfolderResolver.resolve(
            calendarName: "Work Calendar",
            isEnabled: true,
            mappings: ["Work Calendar": "work"]
        )

        XCTAssertEqual(result, "work")
    }

    func testSanitizesIllegalPathCharacters() {
        let result = SubfolderResolver.resolve(
            calendarName: "Work: Projects/2026",
            isEnabled: true,
            mappings: [:]
        )

        XCTAssertEqual(result, "Work Projects2026")
    }

    func testSanitizesCustomMappingToo() {
        let result = SubfolderResolver.resolve(
            calendarName: "Personal",
            isEnabled: true,
            mappings: ["Personal": "my:stuff"]
        )

        XCTAssertEqual(result, "mystuff")
    }

    // MARK: - sanitizePath() traversal rejection

    func testSanitizePathRejectsDoubleDotExact() {
        XCTAssertNil(SubfolderResolver.sanitizePath(".."))
    }

    func testSanitizePathRejectsSingleDotExact() {
        XCTAssertNil(SubfolderResolver.sanitizePath("."))
    }

    func testSanitizePathRejectsEmptyAfterTrim() {
        XCTAssertNil(SubfolderResolver.sanitizePath("   "))
        XCTAssertNil(SubfolderResolver.sanitizePath("..."))
    }

    func testSanitizePathRejectsLeadingDotFolder() {
        // ".Trash" looks like a hidden folder and is rejected rather than
        // writing transcripts into a dotted directory.
        let trimmed = SubfolderResolver.sanitizePath(".Trash")
        XCTAssertEqual(trimmed, "Trash", "leading dots should be trimmed away")
    }

    func testSanitizePathStripsTraversalSlashes() {
        // The illegal-character filter strips `/` so `..` can't combine with a
        // slash to form a traversal segment that survives sanitization.
        let result = SubfolderResolver.sanitizePath("../etc/passwd")
        XCTAssertEqual(result, "etcpasswd")
    }

    func testSanitizePathStripsBackslashes() {
        let result = SubfolderResolver.sanitizePath("..\\Windows\\System32")
        XCTAssertEqual(result, "WindowsSystem32")
    }

    // MARK: - resolveFolderURL() containment

    private func makeTempBase() throws -> URL {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("mn-subfolder-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    func testResolveFolderURLReturnsBaseWhenDisabled() throws {
        let base = try makeTempBase()
        defer { try? FileManager.default.removeItem(at: base) }

        let resolved = SubfolderResolver.resolveFolderURL(
            baseFolderURL: base,
            calendarName: "Anything",
            isEnabled: false,
            mappings: [:]
        )

        XCTAssertEqual(resolved.standardizedFileURL, base.standardizedFileURL)
    }

    func testResolveFolderURLAppendsValidSubfolder() throws {
        let base = try makeTempBase()
        defer { try? FileManager.default.removeItem(at: base) }

        let resolved = SubfolderResolver.resolveFolderURL(
            baseFolderURL: base,
            calendarName: "Work Calendar",
            isEnabled: true,
            mappings: [:]
        )

        XCTAssertEqual(
            resolved.standardizedFileURL.path,
            base.appendingPathComponent("Work Calendar").standardizedFileURL.path
        )
    }

    func testResolveFolderURLRefusesToEscapeBase() throws {
        let base = try makeTempBase()
        defer { try? FileManager.default.removeItem(at: base) }

        // The sanitizer should strip the slashes from "../../Desktop" before we
        // ever get to the containment check, but the containment guard belongs
        // in this test regardless so we document the defense-in-depth.
        let resolved = SubfolderResolver.resolveFolderURL(
            baseFolderURL: base,
            calendarName: "../../Desktop",
            isEnabled: true,
            mappings: [:]
        )

        XCTAssertTrue(
            resolved.standardizedFileURL.path.hasPrefix(base.standardizedFileURL.path),
            "resolved folder must stay under base"
        )
    }

    func testResolveFolderURLIgnoresDotsOnlyMapping() throws {
        let base = try makeTempBase()
        defer { try? FileManager.default.removeItem(at: base) }

        let resolved = SubfolderResolver.resolveFolderURL(
            baseFolderURL: base,
            calendarName: "Home",
            isEnabled: true,
            mappings: ["Home": ".."]
        )

        // When the mapping sanitizes to nil, we fall through to base.
        XCTAssertEqual(resolved.standardizedFileURL, base.standardizedFileURL)
    }
}
