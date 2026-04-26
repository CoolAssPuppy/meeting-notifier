//
//  URLRequiredTests.swift
//  MeetingNotifierTests
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import XCTest
@testable import MeetingNotifier

final class URLRequiredTests: XCTestCase {

    func testReturnsURLForValidString() {
        let url = URL.required("https://example.com/path?q=1")
        XCTAssertEqual(url.absoluteString, "https://example.com/path?q=1")
    }

    func testHandlesCustomScheme() {
        let url = URL.required("com.strategicnerds.meetingnotifier://oauthredirect")
        XCTAssertEqual(url.scheme, "com.strategicnerds.meetingnotifier")
    }

    // We don't test the precondition-failure path here — it's a guarded crash
    // by design, and exercising it via XCTest would crash the test runner.
    // The contract is: passing a malformed string preconditions with the
    // offending value in the message; that's exactly what we want.
}
