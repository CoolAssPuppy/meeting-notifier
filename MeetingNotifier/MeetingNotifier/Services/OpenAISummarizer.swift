//
//  OpenAISummarizer.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation
import os

struct MeetingSummary {
    let summary: String
    let actionItems: [ActionItem]
}

struct ActionItem {
    let description: String
    let assignee: String?

    var markdown: String {
        if let assignee, !assignee.isEmpty {
            return "[ ] \(description) (Assigned to: \(assignee))"
        }
        return "[ ] \(description)"
    }
}

@MainActor
final class AISummarizer {

    static func apiKey(for platform: SummarizationPlatform) -> String? {
        KeychainManager.shared.retrieve(forAccount: platform.keychainAccount)
    }

    static func hasApiKey(for platform: SummarizationPlatform) -> Bool {
        apiKey(for: platform) != nil
    }

    static func summarize(
        transcript: String,
        meetingTitle: String,
        platform: SummarizationPlatform
    ) async throws -> MeetingSummary {
        guard let key = apiKey(for: platform) else {
            throw SummarizerError.apiKeyMissing
        }

        let prompt = buildPrompt(transcript: transcript, meetingTitle: meetingTitle)

        switch platform {
        case .openai:
            return try await callOpenAI(prompt: prompt, apiKey: key)
        case .anthropic:
            return try await callAnthropic(prompt: prompt, apiKey: key)
        case .gemini:
            return try await callGemini(prompt: prompt, apiKey: key)
        }
    }

    // MARK: - OpenAI

    private static func callOpenAI(prompt: String, apiKey: String) async throws -> MeetingSummary {
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.3,
            "response_format": ["type": "json_object"]
        ]

        let data = try await post(
            url: "https://api.openai.com/v1/chat/completions",
            headers: ["Authorization": "Bearer \(apiKey)"],
            body: requestBody
        )

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw SummarizerError.invalidResponse
        }

        return try parseJSON(content)
    }

    // MARK: - Anthropic

    private static func callAnthropic(prompt: String, apiKey: String) async throws -> MeetingSummary {
        let requestBody: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 4096,
            "system": systemPrompt + "\n\nRespond with ONLY the JSON object. No markdown, no code fences, no explanation.",
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        let data = try await post(
            url: "https://api.anthropic.com/v1/messages",
            headers: [
                "x-api-key": apiKey,
                "anthropic-version": "2023-06-01",
            ],
            body: requestBody
        )

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let textBlock = content.first(where: { $0["type"] as? String == "text" }),
              let text = textBlock["text"] as? String else {
            throw SummarizerError.invalidResponse
        }

        return try parseJSON(text)
    }

    // MARK: - Gemini

    private static func callGemini(prompt: String, apiKey: String) async throws -> MeetingSummary {
        let requestBody: [String: Any] = [
            "contents": [
                ["parts": [["text": "\(systemPrompt)\n\n\(prompt)"]]]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "responseMimeType": "application/json"
            ]
        ]

        let data = try await post(
            url: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(apiKey)",
            headers: [:],
            body: requestBody
        )

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw SummarizerError.invalidResponse
        }

        return try parseJSON(text)
    }

    // MARK: - Shared

    private static let systemPrompt = """
        You are a professional meeting notes assistant. Your job is to analyze meeting transcripts and produce two things: a clear summary and a list of action items.

        You always respond with valid JSON matching this exact schema:
        {
          "summary": "string",
          "action_items": [{"description": "string", "assignee": "string"}]
        }

        Guidelines for the summary:
        - Write 2-4 concise paragraphs covering the key topics discussed, decisions made, and outcomes reached.
        - Use professional language. Be specific about what was decided, not just what was discussed.
        - Mention participants by name when they made key points or commitments.
        - Do not pad the summary or add filler. Every sentence should convey information.

        Guidelines for action items:
        - Extract every task, commitment, follow-up, or next step mentioned or clearly implied.
        - Each action item should be specific and actionable (not vague like "think about X").
        - Set "assignee" to the person's name if mentioned or clearly implied. Use "" if unknown.
        - Order action items by when they appeared in the meeting.

        Never invent information that is not in the transcript. If the transcript is too short or unclear to summarize, say so honestly in the summary and return an empty action_items array.
        """

    private static func buildPrompt(transcript: String, meetingTitle: String) -> String {
        """
        Meeting title: "\(meetingTitle)"

        Transcript:
        \(transcript)
        """
    }

    private static func parseJSON(_ content: String) throws -> MeetingSummary {
        // Strip markdown code fences if the model wrapped the JSON
        var cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let contentData = cleaned.data(using: .utf8),
              let parsed = try JSONSerialization.jsonObject(with: contentData) as? [String: Any] else {
            throw SummarizerError.invalidResponse
        }

        let summary = parsed["summary"] as? String ?? ""

        var actionItems: [ActionItem] = []
        if let items = parsed["action_items"] as? [[String: Any]] {
            for item in items {
                let description = item["description"] as? String ?? ""
                let assignee = item["assignee"] as? String
                if !description.isEmpty {
                    actionItems.append(ActionItem(
                        description: description,
                        assignee: (assignee?.isEmpty == true) ? nil : assignee
                    ))
                }
            }
        }

        return MeetingSummary(summary: summary, actionItems: actionItems)
    }

    private static func post(url: String, headers: [String: String], body: [String: Any]) async throws -> Data {
        let jsonData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = jsonData
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SummarizerError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let requestId = httpResponse.value(forHTTPHeaderField: "x-request-id")
                ?? httpResponse.value(forHTTPHeaderField: "X-Request-ID")
                ?? ""
            Logger.transcription.error(
                "AI API error status=\(httpResponse.statusCode) requestId=\(requestId, privacy: .public)"
            )
            throw SummarizerError.apiError(statusCode: httpResponse.statusCode)
        }

        return data
    }
}

// MARK: - Errors

enum SummarizerError: LocalizedError {
    case apiKeyMissing
    case invalidResponse
    case apiError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "API key is not configured"
        case .invalidResponse:
            return "Invalid response from AI API"
        case .apiError(let statusCode):
            return "AI API returned status \(statusCode)"
        }
    }
}
