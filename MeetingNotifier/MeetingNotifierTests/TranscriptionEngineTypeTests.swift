//
//  TranscriptionEngineTypeTests.swift
//  MeetingNotifierTests
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import XCTest
@testable import MeetingNotifier

final class TranscriptionEngineTypeTests: XCTestCase {

    func testAppleIsImplemented() {
        XCTAssertTrue(TranscriptionEngineType.apple.isImplemented)
    }

    func testDeepgramIsImplemented() {
        XCTAssertTrue(TranscriptionEngineType.deepgram.isImplemented)
    }

    func testWisprIsNotImplemented() {
        XCTAssertFalse(TranscriptionEngineType.wispr.isImplemented,
                       "Wispr is a placeholder engine and must not appear implemented")
    }

    func testSelectableCasesExcludesWispr() {
        let selectable = TranscriptionEngineType.selectableCases
        XCTAssertFalse(selectable.contains(.wispr),
                       "WisprEngine is unimplemented; UI pickers must not show it")
    }

    func testSelectableCasesIncludesImplementedEngines() {
        let selectable = TranscriptionEngineType.selectableCases
        XCTAssertTrue(selectable.contains(.apple))
        XCTAssertTrue(selectable.contains(.deepgram))
    }

    func testSelectableCasesMatchesIsImplementedFilter() {
        // Contract: selectableCases == allCases filtered by isImplemented.
        let expected = TranscriptionEngineType.allCases.filter { $0.isImplemented }
        XCTAssertEqual(TranscriptionEngineType.selectableCases, expected)
    }
}
