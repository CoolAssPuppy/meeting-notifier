//
//  URL+Required.swift
//  MeetingNotifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import Foundation

extension URL {
    /// Build a URL from a literal that is known-good at compile time.
    /// Crashes with the offending string in the message instead of a bare
    /// `unexpectedly found nil`. Use only for hardcoded API endpoints and
    /// redirect URIs — never for user input.
    static func required(_ string: String, file: StaticString = #file, line: UInt = #line) -> URL {
        guard let url = URL(string: string) else {
            preconditionFailure("Invalid hardcoded URL: \(string)", file: file, line: line)
        }
        return url
    }
}
