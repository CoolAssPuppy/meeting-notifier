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
                Text("Front matter:")
                    .font(.body)

                Spacer()

                Button("Reset") {
                    settings.frontMatterTemplate = AppSettings.defaultFrontMatterTemplate
                }
                .font(.caption)

                Text("?")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(Color.secondary))
                    .help("""
                    Available tags:

                    {title}          - Meeting title
                    {date}           - Start date (ISO8601)
                    {end_date}       - End date (ISO8601)
                    {yyyy}           - Year (2026)
                    {MM}             - Month (03)
                    {dd}             - Day (17)
                    {HH}             - Hour, 24h (14)
                    {hh}             - Hour, 12h (2)
                    {mm}             - Minutes (30)
                    {speakers}       - Speaker names
                    {attendees}      - Attendee count
                    {attendee_names} - Attendee names
                    {duration}       - Duration (1h 30m)
                    {engine}         - Transcription engine
                    {locale}         - Language
                    {words}          - Word count
                    {link}           - Conference link
                    {event_id}       - Calendar event ID
                    """)
            }

            TextEditor(text: $settings.frontMatterTemplate)
                .font(.system(.caption, design: .monospaced))
                .frame(minHeight: 120, maxHeight: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )

            Text("This template defines the complete YAML front matter block at the top of every note. The --- delimiters are added automatically.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    var calendarSubfoldersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Organize by calendar", isOn: $settings.calendarSubfoldersEnabled)

            Text("Save transcripts in subfolders named after the meeting's calendar. Add custom mappings below to use different folder names.")
                .font(.caption)
                .foregroundColor(.secondary)

            if settings.calendarSubfoldersEnabled {
                calendarMappingsList
                calendarMappingAddRow
            }
        }
    }

    private var calendarMappingsList: some View {
        let sortedKeys = settings.calendarSubfolderMappings.keys.sorted()
        return Group {
            if !sortedKeys.isEmpty {
                VStack(spacing: 0) {
                    ForEach(sortedKeys, id: \.self) { key in
                        calendarMappingRow(key: key, isLast: key == sortedKeys.last)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                )
            }
        }
    }

    private func calendarMappingRow(key: String, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Label(key, systemImage: "calendar")
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Text(settings.calendarSubfolderMappings[key] ?? "")
                    .font(.system(size: 12, design: .monospaced))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    settings.calendarSubfolderMappings.removeValue(forKey: key)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)

            if !isLast {
                Divider()
                    .padding(.horizontal, 8)
            }
        }
    }

    private var calendarMappingAddRow: some View {
        HStack(spacing: 8) {
            Picker("", selection: $newMappingCalendar) {
                Text("Select calendar")
                    .tag("")
                ForEach(availableCalendarNames, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)

            TextField("Subfolder name", text: $newMappingFolder)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .frame(maxWidth: .infinity)

            Button {
                guard !newMappingCalendar.isEmpty, !newMappingFolder.isEmpty else { return }
                settings.calendarSubfolderMappings[newMappingCalendar] = newMappingFolder
                newMappingCalendar = ""
                newMappingFolder = ""
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .disabled(newMappingCalendar.isEmpty || newMappingFolder.isEmpty)
        }
    }

    private var availableCalendarNames: [String] {
        let allNames = Set(CalendarDataManager.shared.events.map(\.calendarName))
        let alreadyMapped = Set(settings.calendarSubfolderMappings.keys)
        return allNames.subtracting(alreadyMapped).sorted()
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
            settings.saveNotesFolderBookmark(for: url)
        }
    }
}
