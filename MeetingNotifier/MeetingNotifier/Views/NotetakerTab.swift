//
//  NotetakerTab.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import SwiftUI
import os

struct NotetakerTab: View {
    @ObservedObject var settings = AppSettings.shared

    // API key fields backed by @State so SecureField keeps focus.
    // Synced to Keychain via .onChange.
    @State var wisprKey = KeychainManager.shared.retrieve(forAccount: "wispr_api_key") ?? ""
    @State var deepgramKey = KeychainManager.shared.retrieve(forAccount: "deepgram_api_key") ?? ""
    @State var aiKey = ""
    @State private var lastAiPlatform: SummarizationPlatform?

    var body: some View {
        Form {
            Section {
                notetakerToggle
                autoOfferToggle
            } header: {
                sectionHeader(icon: "waveform.circle.fill", title: "Transcription", gradient: [.blue, .purple])
            }

            Section {
                enginePicker
                localePicker

                switch settings.transcriptionEngine {
                case .wispr:
                    wisprApiKeyField
                case .deepgram:
                    deepgramApiKeyField
                case .apple:
                    EmptyView()
                }
            } header: {
                sectionHeader(icon: "cpu.fill", title: "Engine", gradient: [.orange, .red])
            }

            Section {
                aiPlatformPicker
                aiApiKeyField
            } header: {
                sectionHeader(icon: "brain", title: "Summarization", gradient: [.teal, .cyan])
            }

            Section {
                notesFolderPicker
                fileNamingField
                frontMatterField
            } header: {
                sectionHeader(icon: "doc.text.fill", title: "Output", gradient: [.green, .mint])
            }

            Section {
                speakerNameField
                othersNameField
            } header: {
                sectionHeader(icon: "person.2.fill", title: "Speakers", gradient: [.purple, .pink])
            }
        }
        .formStyle(.grouped)
        .onAppear { loadAiKey() }
        .onChange(of: settings.summarizationPlatform) { loadAiKey() }
        .onChange(of: wisprKey) { saveKey(wisprKey, account: "wispr_api_key") }
        .onChange(of: deepgramKey) { saveKey(deepgramKey, account: "deepgram_api_key") }
        .onChange(of: aiKey) { saveKey(aiKey, account: settings.summarizationPlatform.keychainAccount) }
    }

    private func loadAiKey() {
        let account = settings.summarizationPlatform.keychainAccount
        aiKey = KeychainManager.shared.retrieve(forAccount: account) ?? ""
        lastAiPlatform = settings.summarizationPlatform
    }

    private func saveKey(_ value: String, account: String) {
        if value.isEmpty {
            _ = KeychainManager.shared.delete(forAccount: account)
        } else {
            _ = KeychainManager.shared.save(token: value, forAccount: account)
        }
    }

    // MARK: - Section header (matches ConfigTab pattern)

    func sectionHeader(icon: String, title: String, gradient: [Color]) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.primary)
        }
    }
}

struct NotetakerTab_Previews: PreviewProvider {
    static var previews: some View {
        NotetakerTab()
            .frame(width: 500, height: 600)
    }
}
