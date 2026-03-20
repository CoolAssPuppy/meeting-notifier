//
//  SubfolderResolverTests.swift
//  MeetingNotifierTests
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import XCTest
@testable import MeetingNotifier

final class SubfolderResolverTests: XCTestCase {

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
}
