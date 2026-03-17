//
//  NotetakerTab+OutputSettings.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Output and file settings

extension NotetakerTab {
    var notesFolderPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes folder:")
                .font(.body)

            HStack {
                Text(settings.notesFolderPath)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Button("Choose...") {
                    selectNotesFolder()
                }
            }

            Text("Where meeting transcripts will be saved as Markdown files")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    var fileNamingField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("File naming:")
                .font(.body)

            TextField("{yyyy}{MM}{dd}-{title}", text: $settings.fileNamingSchema)
                .textFieldStyle(.roundedBorder)

            Text("Available tokens: {yyyy}, {MM}, {dd}, {title}")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    var frontMatterField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Extra front matter:")
                    .font(.body)

                Spacer()

                Text("?")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(Color.secondary))
                    .help("""
                    Available tags:

                    {yyyy}     - Year (2026)
                    {MM}       - Month (03)
                    {dd}       - Day (17)
                    {HH}       - Hour, 24h (14)
                    {hh}       - Hour, 12h (2)
                    {mm}       - Minutes (30)
                    {title}    - Meeting title
                    {speakers} - Speaker names
                    {attendees}- Attendee count
                    {duration} - Duration (1h 30m)
                    {engine}   - Transcription engine
                    {locale}   - Language
                    {words}    - Word count
                    {link}     - Conference link
                    {event_id} - Calendar event ID
                    """)
            }

            TextEditor(text: $settings.frontMatterTemplate)
                .font(.system(.caption, design: .monospaced))
                .frame(minHeight: 60, maxHeight: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )

            Text("Added to the top of every note")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Helpers

    private func selectNotesFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.message = "Choose a folder for meeting transcripts"

        if panel.runModal() == .OK, let url = panel.url {
            settings.notesFolderPath = url.path
        }
    }
}
