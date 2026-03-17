//
//  WisprEngine.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import AVFoundation
import Foundation
import os

@MainActor
final class WisprEngine: TranscriptionEngine {
    let engineType: TranscriptionEngineType = .wispr

    var isAvailable: Bool {
        KeychainManager.shared.retrieve(forAccount: "wispr_api_key") != nil
    }

    private var segmentHandler: (@Sendable (TranscriptSegment) -> Void)?
    private var webSocketTask: URLSessionWebSocketTask?
    private var sessionStartTime: Date?

    // MARK: - TranscriptionEngine

    func start(locale: String) async throws {
        guard let apiKey = await MainActor.run(body: { KeychainManager.shared.retrieve(forAccount: "wispr_api_key") }) else {
            throw TranscriptionError.apiKeyMissing
        }

        sessionStartTime = Date()

        // Wispr Flow WebSocket connection
        // This is a placeholder implementation -- Wispr's actual API endpoint
        // and protocol will need to be configured based on their documentation
        Logger.transcription.info("Wispr engine started (API key present, locale: \(locale))")
        _ = apiKey // Will be used for WebSocket auth header
    }

    func stop() async {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        sessionStartTime = nil
        Logger.transcription.info("Wispr engine stopped")
    }

    nonisolated func processAudioBuffer(_ buffer: AVAudioPCMBuffer, speaker: SpeakerLabel) {
        // Convert buffer to data and send via WebSocket
        // Placeholder: actual implementation depends on Wispr API format
        guard let data = bufferToData(buffer) else { return }
        _ = data // Will be sent via WebSocket
    }

    func setSegmentHandler(_ handler: @escaping @Sendable (TranscriptSegment) -> Void) {
        segmentHandler = handler
    }

    nonisolated func makeBufferProcessor(speaker: SpeakerLabel) -> @Sendable (AVAudioPCMBuffer) -> Void {
        return { [weak self] buffer in
            self?.processAudioBuffer(buffer, speaker: speaker)
        }
    }

    // MARK: - Helpers

    nonisolated private func bufferToData(_ buffer: AVAudioPCMBuffer) -> Data? {
        guard let channelData = buffer.floatChannelData?[0] else { return nil }
        let frameLength = Int(buffer.frameLength)
        return Data(bytes: channelData, count: frameLength * MemoryLayout<Float>.size)
    }
}
