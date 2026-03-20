//
//  NotetakerTab+EngineSettings.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import SwiftUI

// MARK: - Supported locales for transcription

private struct TranscriptionLocale: Identifiable, Hashable {
    let code: String
    let flag: String
    let name: String

    var id: String { code }

    static let supported: [TranscriptionLocale] = [
        TranscriptionLocale(code: "en_US", flag: "\u{1F1FA}\u{1F1F8}", name: "English (US)"),
        TranscriptionLocale(code: "en_GB", flag: "\u{1F1EC}\u{1F1E7}", name: "English (UK)"),
        TranscriptionLocale(code: "en_AU", flag: "\u{1F1E6}\u{1F1FA}", name: "English (Australia)"),
        TranscriptionLocale(code: "en_IN", flag: "\u{1F1EE}\u{1F1F3}", name: "English (India)"),
        TranscriptionLocale(code: "es_ES", flag: "\u{1F1EA}\u{1F1F8}", name: "Spanish (Spain)"),
        TranscriptionLocale(code: "es_MX", flag: "\u{1F1F2}\u{1F1FD}", name: "Spanish (Mexico)"),
        TranscriptionLocale(code: "fr_FR", flag: "\u{1F1EB}\u{1F1F7}", name: "French"),
        TranscriptionLocale(code: "de_DE", flag: "\u{1F1E9}\u{1F1EA}", name: "German"),
        TranscriptionLocale(code: "it_IT", flag: "\u{1F1EE}\u{1F1F9}", name: "Italian"),
        TranscriptionLocale(code: "pt_BR", flag: "\u{1F1E7}\u{1F1F7}", name: "Portuguese (Brazil)"),
        TranscriptionLocale(code: "ja_JP", flag: "\u{1F1EF}\u{1F1F5}", name: "Japanese"),
        TranscriptionLocale(code: "ko_KR", flag: "\u{1F1F0}\u{1F1F7}", name: "Korean"),
        TranscriptionLocale(code: "zh_CN", flag: "\u{1F1E8}\u{1F1F3}", name: "Chinese (Simplified)"),
        TranscriptionLocale(code: "zh_TW", flag: "\u{1F1F9}\u{1F1FC}", name: "Chinese (Traditional)"),
        TranscriptionLocale(code: "hi_IN", flag: "\u{1F1EE}\u{1F1F3}", name: "Hindi"),
        TranscriptionLocale(code: "ar_SA", flag: "\u{1F1F8}\u{1F1E6}", name: "Arabic"),
        TranscriptionLocale(code: "nl_NL", flag: "\u{1F1F3}\u{1F1F1}", name: "Dutch"),
        TranscriptionLocale(code: "pl_PL", flag: "\u{1F1F5}\u{1F1F1}", name: "Polish"),
        TranscriptionLocale(code: "ru_RU", flag: "\u{1F1F7}\u{1F1FA}", name: "Russian"),
        TranscriptionLocale(code: "tr_TR", flag: "\u{1F1F9}\u{1F1F7}", name: "Turkish"),
    ]
}

// MARK: - Engine and transcription settings

extension NotetakerTab {
    var notetakerToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Enable meeting notes", isOn: $settings.notetakerEnabled)

            Text("Automatically transcribe meetings and save notes")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    var indicatorModePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Active indicator", selection: $settings.transcriptionIndicatorMode) {
                ForEach(TranscriptionIndicatorMode.allCases) { mode in
                    Text(mode.displayName)
                        .tag(mode)
                }
            }

            Text("How to show that transcription is active")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    var autoOfferToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Auto-offer transcription", isOn: $settings.autoOfferTranscription)

            Text("Start transcription automatically when a meeting begins")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    var enginePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Transcription engine", selection: $settings.transcriptionEngine) {
                ForEach(TranscriptionEngineType.allCases) { engine in
                    HStack(spacing: 6) {
                        Image(systemName: engine.icon)
                        Text(engine.displayName)
                    }
                    .tag(engine)
                }
            }

            Text(engineDescription)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    var localePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Language", selection: $settings.transcriptionLocale) {
                ForEach(TranscriptionLocale.supported) { locale in
                    Text("\(locale.flag)  \(locale.name)")
                        .tag(locale.code)
                }
            }
        }
    }

    var wisprApiKeyField: some View {
        VStack(alignment: .leading, spacing: 8) {
            SecureField("Wispr Flow API key", text: $wisprKey)
                .textFieldStyle(.roundedBorder)

            Text("Stored securely in Keychain and synced via iCloud")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    var deepgramApiKeyField: some View {
        VStack(alignment: .leading, spacing: 8) {
            SecureField("Deepgram API key", text: $deepgramKey)
                .textFieldStyle(.roundedBorder)

            Text("Stored securely in Keychain and synced via iCloud")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    var aiPlatformPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("AI platform", selection: $settings.summarizationPlatform) {
                ForEach(SummarizationPlatform.allCases) { platform in
                    HStack(spacing: 6) {
                        Image(systemName: platform.icon)
                        Text(platform.displayName)
                    }
                    .tag(platform)
                }
            }

            Text("Used to generate meeting summaries and extract action items after transcription")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    var aiApiKeyField: some View {
        VStack(alignment: .leading, spacing: 8) {
            SecureField(
                "\(settings.summarizationPlatform.displayName) API key (\(settings.summarizationPlatform.apiKeyPlaceholder))",
                text: $aiKey
            )
            .textFieldStyle(.roundedBorder)

            Text("Stored securely in Keychain and synced via iCloud")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Helpers

    private var engineDescription: String {
        switch settings.transcriptionEngine {
        case .apple:
            return "On-device transcription using Apple SpeechAnalyzer. Free, private, no API key required."
        case .wispr:
            return "High-quality transcription via Wispr Flow. Requires API key."
        case .deepgram:
            return "Cloud transcription via Deepgram. Requires API key (BYOK)."
        }
    }
}
