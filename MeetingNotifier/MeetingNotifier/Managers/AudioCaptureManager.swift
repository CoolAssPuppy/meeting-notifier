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
    /// As a side effect, every Nth buffer also writes a normalized RMS level
    /// to `MicLevelBridge.current` so the UI can render a live waveform.
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

        // Local counter on the audio thread — no actor hops, no allocations.
        let levelState = AudioLevelState()

        Logger.audio.info("Installing mic tap (sampleRate: \(format.sampleRate)Hz, channels: \(format.channelCount))")
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            bufferHandler(buffer)

            // Compute RMS roughly every 4th buffer (~10 Hz at default
            // 1024-frame buffers / 48 kHz) — frequent enough to feel reactive,
            // sparse enough to be free.
            levelState.count &+= 1
            guard levelState.count % 4 == 0 else { return }
            MicLevelBridge.current = AudioCaptureManager.computeRMS(buffer)
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
        MicLevelBridge.current = 0
        Logger.audio.info("Mic capture stopped")
    }

    // MARK: - RMS computation

    /// Normalized RMS of the first channel, scaled so quiet conversation
    /// reads ~0.4 and loud speech saturates at 1.0. The 8x scalar was tuned
    /// empirically against built-in MacBook mics.
    nonisolated static func computeRMS(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        let samples = channelData[0]
        var sumOfSquares: Float = 0
        for i in 0..<frameLength {
            let sample = samples[i]
            sumOfSquares += sample * sample
        }
        let rms = sqrtf(sumOfSquares / Float(frameLength))
        return min(rms * 8.0, 1.0)
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

// MARK: - Audio thread state

/// Counter that lives entirely on the audio thread so the tap can throttle
/// level computation without crossing into actor-isolated code.
private final class AudioLevelState: @unchecked Sendable {
    var count: Int = 0
}

/// Shared mic level. The audio thread writes here on every Nth buffer; the
/// UI reads it from a SwiftUI `TimelineView` re-render. Float reads/writes
/// are atomic on ARM64, so no lock is needed and we deliberately avoid
/// Combine/Task/GCD on the audio path.
enum MicLevelBridge {
    nonisolated(unsafe) static var current: Float = 0
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
