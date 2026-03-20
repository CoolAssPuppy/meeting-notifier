//
//  NotetakerEnums.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation

// MARK: - Transcription engine type

enum TranscriptionEngineType: String, CaseIterable, Codable, Identifiable {
    case apple = "Apple"
    case wispr = "Wispr"
    case deepgram = "Deepgram"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .apple: return "Apple SpeechAnalyzer"
        case .wispr: return "Wispr Flow"
        case .deepgram: return "Deepgram"
        }
    }

    var requiresApiKey: Bool {
        switch self {
        case .apple: return false
        case .wispr, .deepgram: return true
        }
    }

    var icon: String {
        switch self {
        case .apple: return "apple.logo"
        case .wispr: return "waveform"
        case .deepgram: return "network"
        }
    }
}

// MARK: - Transcription state

enum TranscriptionState: String, Codable {
    case idle
    case waitingForPermission
    case recording
    case transcribing
    case paused
    case saving
    case error

    var isActive: Bool {
        switch self {
        case .recording, .transcribing, .paused:
            return true
        case .idle, .waitingForPermission, .saving, .error:
            return false
        }
    }

    var statusText: String {
        switch self {
        case .idle: return "Ready"
        case .waitingForPermission: return "Waiting for permission"
        case .recording: return "Recording"
        case .transcribing: return "Transcribing"
        case .paused: return "Paused"
        case .saving: return "Saving"
        case .error: return "Error"
        }
    }

    var icon: String {
        switch self {
        case .idle: return "mic.slash"
        case .waitingForPermission: return "lock.shield"
        case .recording: return "mic.fill"
        case .transcribing: return "waveform"
        case .paused: return "pause.circle"
        case .saving: return "square.and.arrow.down"
        case .error: return "exclamationmark.triangle"
        }
    }
}

// MARK: - Summarization platform

enum SummarizationPlatform: String, CaseIterable, Codable, Identifiable {
    case openai = "OpenAI"
    case anthropic = "Anthropic"
    case gemini = "Gemini"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .gemini: return "Google Gemini"
        }
    }

    var keychainAccount: String {
        switch self {
        case .openai: return "openai_api_key"
        case .anthropic: return "anthropic_api_key"
        case .gemini: return "gemini_api_key"
        }
    }

    var apiKeyPlaceholder: String {
        switch self {
        case .openai: return "sk-..."
        case .anthropic: return "sk-ant-..."
        case .gemini: return "AIza..."
        }
    }

    var icon: String {
        switch self {
        case .openai: return "brain"
        case .anthropic: return "brain.head.profile"
        case .gemini: return "sparkles"
        }
    }
}

// MARK: - Transcription indicator mode

enum TranscriptionIndicatorMode: String, CaseIterable, Codable, Identifiable {
    case none = "None"
    case menuBarDropdown = "MenuBarDropdown"
    case changeIconColor = "ChangeIconColor"
    case both = "Both"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "None"
        case .menuBarDropdown: return "Menu Bar Dropdown"
        case .changeIconColor: return "Change Icon Color"
        case .both: return "Both Menu and Icon"
        }
    }
}

// MARK: - Speaker label

enum SpeakerLabel: String, Codable, Hashable {
    case me = "Me"
    case others = "Others"
    case unknown = "Unknown"
}
