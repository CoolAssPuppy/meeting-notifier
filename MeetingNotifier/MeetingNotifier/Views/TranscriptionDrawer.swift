//
//  TranscriptionDrawer.swift
//  MeetingNotifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import SwiftUI

struct TranscriptionDrawer: View {
    let onClose: () -> Void

    @ObservedObject private var appSettings = AppSettings.shared
    @ObservedObject private var coordinator = TranscriptionCoordinator.shared
    @Environment(\.theme) private var theme

    @State private var engineApiKeyDraft: String = ""
    @State private var summarizationKeyDraft: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 14) {
                        recordingCard
                        engineCard
                    }.frame(maxWidth: .infinity)

                    VStack(spacing: 14) {
                        outputCard
                        summarizationCard
                        speakersCard
                    }.frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
        }
        .background(theme.background)
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: AppRadius.xxl, bottomTrailingRadius: AppRadius.xxl, style: .continuous))
        .shadow(color: Color.black.opacity(0.45), radius: 18, y: 8)
        .onAppear { loadKeysForEngine() }
        .onChange(of: appSettings.transcriptionEngine) { _, _ in loadKeysForEngine() }
        .onChange(of: appSettings.summarizationPlatform) { _, _ in loadKeysForEngine() }
    }

    private var header: some View {
        HStack(spacing: AppSpacing.lg) {
            drawerIcon
            VStack(alignment: .leading, spacing: 3) {
                Text("Transcription")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(theme.foreground)
                Text("Capture meetings, transcribe them, save markdown notes")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.muted)
            }
            Spacer(minLength: 0)
            recordingPill
            CloseButton(onClose: onClose)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.divider).frame(height: 1)
        }
    }

    private var drawerIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.md)
                .fill(theme.card)
            RoundedRectangle(cornerRadius: AppRadius.md)
                .strokeBorder(theme.borderStrong, lineWidth: 1)
            Image(systemName: "waveform")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.primary)
        }
        .frame(width: 34, height: 34)
    }

    @ViewBuilder
    private var recordingPill: some View {
        let state = coordinator.state
        let active = state == .recording || state == .transcribing
        let paused = state == .paused
        let color = paused ? theme.warning : (active ? theme.destructive : theme.tertiary)
        let text: String = {
            switch state {
            case .recording:   return "● RECORDING"
            case .transcribing: return "● TRANSCRIBING"
            case .paused:      return "● PAUSED"
            case .saving:      return "SAVING"
            case .error:       return "ERROR"
            default:           return "IDLE"
            }
        }()

        HStack(spacing: 5) {
            PulsingDot(color: color, active: active || paused)
            Text(text)
                .font(.system(size: 10, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(color.opacity(0.12)))
        .overlay(Capsule().strokeBorder(color.opacity(0.35), lineWidth: 1))
    }

    // MARK: - Cards

    private var recordingCard: some View {
        AppCard("Recording") {
            VStack(spacing: AppSpacing.md) {
                AppSettingRow("Enable transcription",
                              description: "Capture system audio while in a meeting") {
                    Toggle("", isOn: $appSettings.notetakerEnabled).toggleStyle(.switch).labelsHidden().tint(theme.primary)
                }
                AppRowDivider()
                AppSettingRow("Auto-offer on join",
                              description: "Prompt to record each meeting when you join") {
                    Toggle("", isOn: $appSettings.autoOfferTranscription).toggleStyle(.switch).labelsHidden().tint(theme.primary)
                }
                AppRowDivider()
                AppSettingRow("Status indicator",
                              description: "Where to show the live recording cue") {
                    Picker("", selection: $appSettings.transcriptionIndicatorMode) {
                        ForEach(TranscriptionIndicatorMode.allCases) { m in
                            Text(m.displayName).tag(m)
                        }
                    }.appBoxedPicker(width: 200)
                }
            }
        }
    }

    private var engineCard: some View {
        AppCard("Engine") {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                ForEach(TranscriptionEngineType.allCases) { engine in
                    EngineOptionRow(
                        engine: engine,
                        isSelected: appSettings.transcriptionEngine == engine,
                        onTap: { appSettings.transcriptionEngine = engine }
                    )
                }

                if appSettings.transcriptionEngine.requiresApiKey {
                    AppRowDivider()
                    apiKeyField(
                        label: "\(appSettings.transcriptionEngine.displayName) API key",
                        placeholder: apiKeyPlaceholder(for: appSettings.transcriptionEngine),
                        keychainAccount: keychainAccount(for: appSettings.transcriptionEngine),
                        draft: $engineApiKeyDraft
                    )
                }

                AppRowDivider()
                AppSettingRow("Locale",
                              description: "Language / region for transcription") {
                    Picker("", selection: $appSettings.transcriptionLocale) {
                        Text("English (US)").tag("en_US")
                        Text("English (UK)").tag("en_GB")
                        Text("Español").tag("es_ES")
                        Text("Français").tag("fr_FR")
                        Text("Deutsch").tag("de_DE")
                        Text("日本語").tag("ja_JP")
                    }.appBoxedPicker(width: 160)
                }
            }
        }
    }

    private var outputCard: some View {
        AppCard("Output") {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes folder")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(theme.muted)
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(theme.primary)
                        Text(appSettings.notesFolderPath)
                            .font(.system(size: 12, design: .monospaced).weight(.medium))
                            .foregroundStyle(theme.foreground)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        AppSecondaryButton(title: "Change") {
                            chooseNotesFolder()
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: AppRadius.md).fill(theme.cardInset))
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.md).strokeBorder(theme.border, lineWidth: 1))
                }

                AppSettingRow("Subfolder per calendar",
                              description: "Groups notes by Work / Personal / etc.") {
                    Toggle("", isOn: $appSettings.calendarSubfoldersEnabled).toggleStyle(.switch).labelsHidden().tint(theme.primary)
                }
                AppRowDivider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("File name template")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(theme.muted)
                    TextField("{yyyy}{MM}{dd}-{title}", text: $appSettings.fileNamingSchema)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(theme.foreground)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: AppRadius.md).fill(theme.cardInset))
                        .overlay(RoundedRectangle(cornerRadius: AppRadius.md).strokeBorder(theme.border, lineWidth: 1))
                }
            }
        }
    }

    private var summarizationCard: some View {
        AppCard("Summarization") {
            VStack(spacing: AppSpacing.md) {
                AppSettingRow("Provider",
                              description: "Which AI writes the summary") {
                    Picker("", selection: $appSettings.summarizationPlatform) {
                        ForEach(SummarizationPlatform.allCases) { p in
                            Text(p.displayName).tag(p)
                        }
                    }.appBoxedPicker(width: 180)
                }
                AppRowDivider()
                apiKeyField(
                    label: "\(appSettings.summarizationPlatform.displayName) API key",
                    placeholder: appSettings.summarizationPlatform.apiKeyPlaceholder,
                    keychainAccount: appSettings.summarizationPlatform.keychainAccount,
                    draft: $summarizationKeyDraft
                )
            }
        }
    }

    private var speakersCard: some View {
        AppCard("Speakers") {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                AppSettingRow("My label",
                              description: "Used in transcripts for your voice") {
                    TextField("Me", text: $appSettings.speakerDisplayName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.foreground)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(width: 150)
                        .background(RoundedRectangle(cornerRadius: AppRadius.md).fill(theme.cardInset))
                        .overlay(RoundedRectangle(cornerRadius: AppRadius.md).strokeBorder(theme.border, lineWidth: 1))
                }
                AppRowDivider()
                AppSettingRow("Everyone else",
                              description: "Default label for other speakers") {
                    TextField("Speaker", text: $appSettings.othersDisplayName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.foreground)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(width: 150)
                        .background(RoundedRectangle(cornerRadius: AppRadius.md).fill(theme.cardInset))
                        .overlay(RoundedRectangle(cornerRadius: AppRadius.md).strokeBorder(theme.border, lineWidth: 1))
                }
            }
        }
    }

    // MARK: - Helpers

    private func apiKeyField(label: String,
                             placeholder: String,
                             keychainAccount: String,
                             draft: Binding<String>) -> some View {
        let stored = !draft.wrappedValue.isEmpty
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.muted)
                if stored {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                        Text("KEYCHAIN")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.4)
                    }
                    .foregroundStyle(theme.success)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(theme.success.opacity(0.12)))
                    .overlay(Capsule().strokeBorder(theme.success.opacity(0.3), lineWidth: 1))
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: AppSpacing.md) {
                SecureField(placeholder, text: draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced).weight(.medium))
                    .foregroundStyle(theme.foreground)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: AppRadius.md).fill(theme.cardInset))
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.md).strokeBorder(theme.border, lineWidth: 1))
                AppSecondaryButton(title: "Save", tint: .primary) {
                    _ = KeychainManager.shared.save(token: draft.wrappedValue, forAccount: keychainAccount)
                }
            }
        }
    }

    private func keychainAccount(for engine: TranscriptionEngineType) -> String {
        switch engine {
        case .apple: return ""
        case .wispr: return "wispr_api_key"
        case .deepgram: return "deepgram_api_key"
        }
    }

    private func apiKeyPlaceholder(for engine: TranscriptionEngineType) -> String {
        switch engine {
        case .apple: return ""
        case .wispr: return "wispr_..."
        case .deepgram: return "••••••••"
        }
    }

    private func loadKeysForEngine() {
        if appSettings.transcriptionEngine.requiresApiKey {
            engineApiKeyDraft = KeychainManager.shared.retrieve(forAccount: keychainAccount(for: appSettings.transcriptionEngine)) ?? ""
        } else {
            engineApiKeyDraft = ""
        }
        summarizationKeyDraft = KeychainManager.shared.retrieve(forAccount: appSettings.summarizationPlatform.keychainAccount) ?? ""
    }

    private func chooseNotesFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            appSettings.saveNotesFolderBookmark(for: url)
        }
    }
}

// MARK: - Engine option row

private struct EngineOptionRow: View {
    let engine: TranscriptionEngineType
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.theme) private var theme
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: AppSpacing.lg) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? theme.primary : theme.borderStrong, lineWidth: 1.5)
                        .frame(width: 16, height: 16)
                    if isSelected {
                        Circle().fill(theme.primary).frame(width: 7, height: 7)
                    }
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(engine.displayName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isSelected ? theme.foreground : theme.foregroundSoft)
                        capabilityBadge
                    }
                    Text(engineSubtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.muted)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: AppRadius.lg).fill(backgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var backgroundColor: Color {
        isSelected ? theme.primary.opacity(0.08) : (isHovered ? theme.cardElevated : theme.card)
    }

    private var borderColor: Color {
        isSelected ? theme.primary.opacity(0.35) : theme.border
    }

    private var engineSubtitle: String {
        switch engine {
        case .apple:    return "On-device. No API key. Free. macOS 14+."
        case .wispr:    return "Cloud, low-latency, best diarization."
        case .deepgram: return "Cloud, Nova-3 model, good pricing."
        }
    }

    @ViewBuilder
    private var capabilityBadge: some View {
        if engine.requiresApiKey {
            Text("API KEY")
                .font(.system(size: 9, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(theme.warning)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(theme.warning.opacity(0.12)))
                .overlay(Capsule().strokeBorder(theme.warning.opacity(0.3), lineWidth: 1))
        } else {
            Text("BUILT-IN")
                .font(.system(size: 9, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(theme.success)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(theme.success.opacity(0.12)))
                .overlay(Capsule().strokeBorder(theme.success.opacity(0.3), lineWidth: 1))
        }
    }
}
