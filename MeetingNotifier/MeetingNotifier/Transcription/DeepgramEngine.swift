//
//  DeepgramEngine.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import AVFoundation
import Foundation
import os

@MainActor
final class DeepgramEngine: TranscriptionEngine {
    let engineType: TranscriptionEngineType = .deepgram

    var isAvailable: Bool {
        KeychainManager.shared.retrieve(forAccount: "deepgram_api_key") != nil
    }

    private var segmentHandler: (@Sendable (TranscriptSegment) -> Void)?
    private var webSocketTask: URLSessionWebSocketTask?
    private var sessionStartTime: Date?
    private var currentSpeaker: SpeakerLabel = .me
    private var sendCount = 0
    private var receiveCount = 0

    // MARK: - TranscriptionEngine

    func start(locale: String) async throws {
        guard let apiKey = KeychainManager.shared.retrieve(forAccount: "deepgram_api_key") else {
            throw TranscriptionError.apiKeyMissing
        }

        sessionStartTime = Date()

        let languageCode = locale.replacingOccurrences(of: "_", with: "-").lowercased()
        let urlString = "wss://api.deepgram.com/v1/listen?model=nova-2&language=\(languageCode)&punctuate=true&smart_format=true&diarize=true"

        guard let url = URL(string: urlString) else {
            throw TranscriptionError.connectionFailed
        }

        var request = URLRequest(url: url)
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()

        scheduleReceive()
        Logger.transcription.info("Deepgram engine started (locale: \(languageCode))")
    }

    func stop() async {
        let closeMessage = "{\"type\": \"CloseStream\"}"
        try? await webSocketTask?.send(.string(closeMessage))
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        sessionStartTime = nil
        Logger.transcription.info("Deepgram engine stopped")
    }

    nonisolated func processAudioBuffer(_ buffer: AVAudioPCMBuffer, speaker: SpeakerLabel) {
        guard let data = bufferToData(buffer) else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.currentSpeaker = speaker
            self.sendCount += 1
            if self.sendCount == 1 || self.sendCount % 100 == 0 {
                Logger.transcription.info("[\(speaker.rawValue) engine] sent \(self.sendCount) buffers to Deepgram (\(data.count) bytes)")
            }
            do {
                try await self.webSocketTask?.send(.data(data))
            } catch {
                Logger.transcription.error("[\(speaker.rawValue) engine] WebSocket send failed: \(error.localizedDescription)")
            }
        }
    }

    func setSegmentHandler(_ handler: @escaping @Sendable (TranscriptSegment) -> Void) {
        segmentHandler = handler
    }

    nonisolated func makeBufferProcessor(speaker: SpeakerLabel) -> @Sendable (AVAudioPCMBuffer) -> Void {
        return { [weak self] buffer in
            self?.processAudioBuffer(buffer, speaker: speaker)
        }
    }

    // MARK: - WebSocket message handling

    private func scheduleReceive() {
        webSocketTask?.receive { [weak self] result in
            // Runs on URLSession background thread -- hop to MainActor
            Task { @MainActor [weak self] in
                guard let self else { return }

                switch result {
                case .success(let message):
                    self.handleMessage(message)
                    self.scheduleReceive()
                case .failure(let error):
                    Logger.transcription.error("Deepgram WebSocket error: \(error.localizedDescription)")
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        receiveCount += 1
        if receiveCount == 1 {
            Logger.transcription.info("[\(self.currentSpeaker.rawValue) engine] first WebSocket message received")
        }

        guard case .string(let text) = message,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let channel = (json["channel"] as? [String: Any]),
              let alternatives = (channel["alternatives"] as? [[String: Any]])?.first,
              let transcript = alternatives["transcript"] as? String,
              !transcript.isEmpty else {
            return
        }

        let sessionStart = sessionStartTime ?? Date()
        let elapsed = Date().timeIntervalSince(sessionStart)

        let start = (json["start"] as? Double) ?? max(0, elapsed - 3)
        let duration = (json["duration"] as? Double) ?? 3.0

        // When diarize=true, Deepgram returns words with speaker indices.
        // Group consecutive words by speaker and emit separate segments.
        // For the system audio stream (currentSpeaker == .others), always
        // label as .others since Deepgram's indices are per-stream and
        // speaker 0 does NOT mean "the local user" on that stream.
        if let words = alternatives["words"] as? [[String: Any]],
           !words.isEmpty,
           words.first?["speaker"] != nil {
            let grouped = groupWordsBySpeaker(words)
            for group in grouped {
                let speaker = currentSpeaker == .others
                    ? SpeakerLabel.others
                    : speakerLabel(for: group.speakerIndex)
                let segment = TranscriptSegment(
                    speaker: speaker,
                    text: group.text,
                    startTime: group.start,
                    endTime: group.end
                )
                segmentHandler?(segment)
            }
        } else {
            let segment = TranscriptSegment(
                speaker: currentSpeaker,
                text: transcript,
                startTime: start,
                endTime: start + duration
            )
            segmentHandler?(segment)
        }
    }

    // MARK: - Diarization helpers

    private struct SpeakerGroup {
        let speakerIndex: Int
        let text: String
        let start: Double
        let end: Double
    }

    private func groupWordsBySpeaker(_ words: [[String: Any]]) -> [SpeakerGroup] {
        var groups: [SpeakerGroup] = []
        var currentWords: [String] = []
        var currentSpeakerIdx = -1
        var groupStart: Double = 0
        var groupEnd: Double = 0

        for word in words {
            let speaker = word["speaker"] as? Int ?? 0
            let wordText = word["punctuated_word"] as? String ?? word["word"] as? String ?? ""
            let wordStart = word["start"] as? Double ?? groupEnd
            let wordEnd = word["end"] as? Double ?? wordStart

            if speaker != currentSpeakerIdx && !currentWords.isEmpty {
                groups.append(SpeakerGroup(
                    speakerIndex: currentSpeakerIdx,
                    text: currentWords.joined(separator: " "),
                    start: groupStart,
                    end: groupEnd
                ))
                currentWords = []
            }

            if currentWords.isEmpty {
                groupStart = wordStart
            }
            currentSpeakerIdx = speaker
            currentWords.append(wordText)
            groupEnd = wordEnd
        }

        if !currentWords.isEmpty {
            groups.append(SpeakerGroup(
                speakerIndex: currentSpeakerIdx,
                text: currentWords.joined(separator: " "),
                start: groupStart,
                end: groupEnd
            ))
        }

        return groups
    }

    /// Map Deepgram speaker index to SpeakerLabel.
    /// Speaker 0 is assumed to be "me" (the local user), all others are "others".
    private func speakerLabel(for index: Int) -> SpeakerLabel {
        index == 0 ? .me : .others
    }

    // MARK: - Helpers

    nonisolated private func bufferToData(_ buffer: AVAudioPCMBuffer) -> Data? {
        guard let channelData = buffer.floatChannelData?[0] else { return nil }
        let frameLength = Int(buffer.frameLength)

        var int16Data = [Int16](repeating: 0, count: frameLength)
        for i in 0..<frameLength {
            let sample = max(-1.0, min(1.0, channelData[i]))
            int16Data[i] = Int16(sample * Float(Int16.max))
        }

        return int16Data.withUnsafeBufferPointer { Data(buffer: $0) }
    }
}
