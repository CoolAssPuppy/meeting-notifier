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
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 4096,
            "system": systemPrompt,
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

    private static let systemPrompt = "You are a professional meeting assistant. You produce concise, accurate meeting summaries and extract action items with assignees. Respond only in the exact JSON format requested."

    private static func buildPrompt(transcript: String, meetingTitle: String) -> String {
        """
        Summarize the following meeting transcript. The meeting is titled "\(meetingTitle)".

        Produce a JSON response with exactly this structure:
        {
          "summary": "A concise 2-4 paragraph summary of the meeting.",
          "action_items": [
            {"description": "What needs to be done", "assignee": "Person responsible or empty string if unknown"}
          ]
        }

        Rules:
        - The summary should capture key decisions, discussion topics, and outcomes.
        - Extract every action item mentioned or implied.
        - If you cannot determine the assignee, use an empty string.
        - Do not invent information not present in the transcript.

        Transcript:
        \(transcript)
        """
    }

    private static func parseJSON(_ content: String) throws -> MeetingSummary {
        guard let contentData = content.data(using: .utf8),
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
            let responseBody = String(data: data, encoding: .utf8) ?? "no body"
            Logger.transcription.error("AI API error \(httpResponse.statusCode): \(responseBody, privacy: .public)")
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
