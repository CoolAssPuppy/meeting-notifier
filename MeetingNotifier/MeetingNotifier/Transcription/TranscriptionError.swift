//
//  TranscriptionError.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation

enum TranscriptionError: LocalizedError {
    case permissionDenied
    case engineUnavailable
    case apiKeyMissing
    case connectionFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Speech recognition permission was denied"
        case .engineUnavailable:
            return "Transcription engine is not available"
        case .apiKeyMissing:
            return "An API key is required for this transcription engine"
        case .connectionFailed:
            return "Unable to connect to the transcription service"
        }
    }
}
