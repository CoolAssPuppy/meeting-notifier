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
    @Published private(set) var micLevel: Float = 0

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

        // State lives outside the actor so the audio thread can freely mutate it.
        let levelState = AudioLevelState()

        Logger.audio.info("Installing mic tap (sampleRate: \(format.sampleRate)Hz, channels: \(format.channelCount))")
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            bufferHandler(buffer)

            levelState.count += 1
            guard levelState.count % 4 == 0 else { return }
            guard !levelState.dispatchPending else { return }

            let rms = AudioCaptureManager.computeRMS(buffer)
            levelState.dispatchPending = true
            DispatchQueue.main.async {
                levelState.dispatchPending = false
                self?.micLevel = rms
            }
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
        micLevel = 0
        Logger.audio.info("Mic capture stopped")
    }

    // MARK: - RMS computation

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
        return min(rms * 3.0, 1.0)
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

// MARK: - Audio level state (lives on the audio thread, not main actor)

private final class AudioLevelState: @unchecked Sendable {
    var count: Int = 0
    var dispatchPending: Bool = false
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
