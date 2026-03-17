//
//  AudioCaptureManager.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import AVFoundation
import Combine
import Foundation
import os

@MainActor
final class AudioCaptureManager: ObservableObject {
    @Published private(set) var isCapturing = false

    private var micEngine: AVAudioEngine?

    init() {}

    // MARK: - Mic capture via AVAudioEngine

    /// Start capturing mic audio.
    /// The `bufferHandler` is called on the real-time audio render thread.
    /// It receives the original AVAudioPCMBuffer -- no copies, no actor hops.
    func startMicCapture(bufferHandler: @escaping @Sendable (AVAudioPCMBuffer) -> Void) throws {
        guard !isCapturing else {
            Logger.audio.warning("startMicCapture() called while capture is already running")
            return
        }

        let engine = AVAudioEngine()
        micEngine = engine

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        guard format.sampleRate > 0 else {
            Logger.audio.error("Invalid audio format: sample rate is 0")
            throw AudioCaptureError.invalidFormat
        }

        Logger.audio.info("Installing mic tap (sampleRate: \(format.sampleRate)Hz, channels: \(format.channelCount))")
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            bufferHandler(buffer)
        }

        do {
            try engine.start()
            isCapturing = true
            Logger.audio.info("Mic capture started")
        } catch {
            inputNode.removeTap(onBus: 0)
            micEngine = nil
            Logger.audio.error("AVAudioEngine failed to start: \(error.localizedDescription)")
            throw AudioCaptureError.failedToStart(error.localizedDescription)
        }
    }

    func stopMicCapture() {
        micEngine?.inputNode.removeTap(onBus: 0)
        micEngine?.stop()
        micEngine = nil
        isCapturing = false
        Logger.audio.info("Mic capture stopped")
    }

    // MARK: - Permission

    nonisolated static func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

// MARK: - Errors

enum AudioCaptureError: LocalizedError {
    case invalidFormat
    case permissionDenied
    case failedToStart(String)

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Audio input format is invalid"
        case .permissionDenied:
            return "Microphone access was denied"
        case .failedToStart(let reason):
            return "Audio engine failed to start: \(reason)"
        }
    }
}
