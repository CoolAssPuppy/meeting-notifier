//
//  TranscriptFormatter.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation

struct TranscriptFormatter {

    let speakerNameMe: String
    let speakerNameOthers: String

    init(speakerNameMe: String = "Me", speakerNameOthers: String = "Others") {
        self.speakerNameMe = speakerNameMe
        self.speakerNameOthers = speakerNameOthers
    }

    // MARK: - Public API

    func formatMarkdown(
        document: TranscriptDocument,
        summary: MeetingSummary?,
        frontMatterTemplate: String? = nil
    ) -> String {
        var output = ""
        output += formatFrontMatter(document: document, template: frontMatterTemplate)
        output += "\n\n"
        output += formatSummarySection(document: document, summary: summary)
        output += "\n\n"
        output += formatActionItems(summary: summary)
        output += "\n\n"
        output += formatTranscript(segments: document.segments)
        return output
    }

    func generateFilename(document: TranscriptDocument, schema: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy"
        let yyyy = dateFormatter.string(from: document.startDate)
        dateFormatter.dateFormat = "MM"
        let mm = dateFormatter.string(from: document.startDate)
        dateFormatter.dateFormat = "dd"
        let dd = dateFormatter.string(from: document.startDate)

        let sanitizedTitle = sanitizeFilename(document.meetingTitle)

        return schema
            .replacingOccurrences(of: "{yyyy}", with: yyyy)
            .replacingOccurrences(of: "{MM}", with: mm)
            .replacingOccurrences(of: "{dd}", with: dd)
            .replacingOccurrences(of: "{title}", with: sanitizedTitle)
            + ".md"
    }

    // MARK: - Front matter

    private func formatFrontMatter(document: TranscriptDocument, template: String?) -> String {
        let dateFormatter = ISO8601DateFormatter()

        var lines = ["---"]
        lines.append("title: \(document.meetingTitle)")
        lines.append("date: \(dateFormatter.string(from: document.startDate))")

        if let endDate = document.endDate {
            lines.append("end_date: \(dateFormatter.string(from: endDate))")
        }
        if let duration = document.formattedDuration {
            lines.append("duration: \(duration)")
        }

        lines.append("engine: \(document.engine.displayName)")
        lines.append("locale: \(document.locale)")
        lines.append("word_count: \(document.wordCount)")

        let speakers = document.speakerNames.map { speakerDisplayName($0) }
        lines.append("speakers: [\(speakers.joined(separator: ", "))]")

        if let attendeeCount = document.attendeeCount {
            lines.append("attendees: \(attendeeCount)")
        }
        if let names = document.attendeeNames, !names.isEmpty {
            lines.append("attendee_names: [\(names.joined(separator: ", "))]")
        }
        if let link = document.conferenceLink {
            lines.append("conference_link: \(link)")
        }
        if let eventId = document.calendarEventId {
            lines.append("calendar_event_id: \(eventId)")
        }

        if let template, !template.isEmpty {
            lines.append(expandTemplate(template, document: document))
        }

        lines.append("---")
        return lines.joined(separator: "\n")
    }

    // MARK: - Summary

    private func formatSummarySection(document: TranscriptDocument, summary: MeetingSummary?) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d, yyyy 'at' h:mm a"
        let dateString = dateFormatter.string(from: document.startDate)

        // Use real attendee names from calendar if available, fall back to speaker labels
        let attendeeList: String
        if let names = document.attendeeNames, !names.isEmpty {
            attendeeList = names.joined(separator: ", ")
        } else {
            attendeeList = document.speakerNames.map { speakerDisplayName($0) }.joined(separator: ", ")
        }

        var lines = ["## Summary for \(document.meetingTitle) with \(attendeeList) on \(dateString)"]
        lines.append("")

        if let summary {
            lines.append(summary.summary)
        } else {
            lines.append("*Summary unavailable. Configure an OpenAI API key in Settings > Notes to enable meeting summaries.*")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Action items

    private func formatActionItems(summary: MeetingSummary?) -> String {
        var lines = ["## Action Items", ""]

        guard let summary, !summary.actionItems.isEmpty else {
            lines.append("*No action items identified.*")
            return lines.joined(separator: "\n")
        }

        for item in summary.actionItems {
            lines.append(item.markdown)
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Transcript body

    private func formatTranscript(segments: [TranscriptSegment]) -> String {
        guard !segments.isEmpty else { return "## Full Transcript\n\n*No transcript segments recorded.*\n" }

        var lines = ["## Full Transcript", ""]
        var currentSpeaker: SpeakerLabel?

        for segment in segments {
            if segment.speaker != currentSpeaker {
                if currentSpeaker != nil {
                    lines.append("")
                }
                let name = speakerDisplayName(segment.speaker)
                lines.append("**\(name)** [\(segment.formattedStartTime)]")
                currentSpeaker = segment.speaker
            }
            lines.append(segment.text)
        }

        lines.append("")
        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    func speakerDisplayName(_ label: SpeakerLabel) -> String {
        switch label {
        case .me: return speakerNameMe
        case .others: return speakerNameOthers
        case .unknown: return "Unknown"
        }
    }

    // MARK: - Plain transcript (for sending to OpenAI)

    func plainTranscript(segments: [TranscriptSegment]) -> String {
        var lines: [String] = []
        var currentSpeaker: SpeakerLabel?

        for segment in segments {
            if segment.speaker != currentSpeaker {
                let name = speakerDisplayName(segment.speaker)
                lines.append("\(name): \(segment.text)")
                currentSpeaker = segment.speaker
            } else {
                lines.append(segment.text)
            }
        }

        return lines.joined(separator: "\n")
    }

    private func expandTemplate(_ template: String, document: TranscriptDocument) -> String {
        let dateFormatter = DateFormatter()

        dateFormatter.dateFormat = "yyyy"
        var result = template.replacingOccurrences(of: "{yyyy}", with: dateFormatter.string(from: document.startDate))

        dateFormatter.dateFormat = "MM"
        result = result.replacingOccurrences(of: "{MM}", with: dateFormatter.string(from: document.startDate))

        dateFormatter.dateFormat = "dd"
        result = result.replacingOccurrences(of: "{dd}", with: dateFormatter.string(from: document.startDate))

        dateFormatter.dateFormat = "HH"
        result = result.replacingOccurrences(of: "{HH}", with: dateFormatter.string(from: document.startDate))

        dateFormatter.dateFormat = "h"
        result = result.replacingOccurrences(of: "{hh}", with: dateFormatter.string(from: document.startDate))

        dateFormatter.dateFormat = "mm"
        result = result.replacingOccurrences(of: "{mm}", with: dateFormatter.string(from: document.startDate))

        result = result.replacingOccurrences(of: "{title}", with: document.meetingTitle)

        let speakers = document.speakerNames.map { speakerDisplayName($0) }
        result = result.replacingOccurrences(of: "{speakers}", with: speakers.joined(separator: ", "))

        result = result.replacingOccurrences(of: "{attendees}", with: "\(document.attendeeCount ?? 0)")

        result = result.replacingOccurrences(of: "{engine}", with: document.engine.displayName)
        result = result.replacingOccurrences(of: "{locale}", with: document.locale)
        result = result.replacingOccurrences(of: "{duration}", with: document.formattedDuration ?? "")
        result = result.replacingOccurrences(of: "{words}", with: "\(document.wordCount)")
        result = result.replacingOccurrences(of: "{link}", with: document.conferenceLink ?? "")
        result = result.replacingOccurrences(of: "{event_id}", with: document.calendarEventId ?? "")

        return result
    }

    private func sanitizeFilename(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let sanitized = name.unicodeScalars.filter { allowed.contains($0) }
        return String(String.UnicodeScalarView(sanitized))
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()
    }
}
