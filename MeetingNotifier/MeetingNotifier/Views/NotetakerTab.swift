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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
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
            }
            .padding(20)
        }
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.02),
                    Color.clear,
                    Color.purple.opacity(0.01)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
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
