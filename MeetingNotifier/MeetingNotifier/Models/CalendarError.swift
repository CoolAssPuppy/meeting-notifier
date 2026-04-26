//
//  CalendarError.swift
//  MeetingNotifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import Foundation

enum CalendarError: LocalizedError {
    case apiError(String)
    case parseError(String)
    case authError(String)

    var errorDescription: String? {
        switch self {
        case .apiError(let message):
            return "API Error: \(message)"
        case .parseError(let message):
            return "Parse Error: \(message)"
        case .authError(let message):
            return "Auth Error: \(message)"
        }
    }
}
