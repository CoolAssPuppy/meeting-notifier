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

    // MARK: - TranscriptionEngine

    func start(locale: String) async throws {
        guard let apiKey = KeychainManager.shared.retrieve(forAccount: "deepgram_api_key") else {
            throw TranscriptionError.apiKeyMissing
        }

        sessionStartTime = Date()

        let languageCode = locale.replacingOccurrences(of: "_", with: "-").lowercased()
        let urlString = "wss://api.deepgram.com/v1/listen?model=nova-2&language=\(languageCode)&punctuate=true&smart_format=true"

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
            try? await self.webSocketTask?.send(.data(data))
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

        let segment = TranscriptSegment(
            speaker: currentSpeaker,
            text: transcript,
            startTime: start,
            endTime: start + duration
        )

        segmentHandler?(segment)
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
