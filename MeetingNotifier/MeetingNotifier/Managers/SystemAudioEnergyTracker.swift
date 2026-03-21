//
//  SystemAudioEnergyTracker.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import AVFoundation
import Foundation
import os

/// Tracks system audio energy to determine when remote participants are
/// speaking. Apple's SpeechAnalyzer does not support concurrent instances,
/// so the Apple-engine path uses energy detection instead of a second
/// speech recognizer for speaker labeling.
///
/// The coordinator feeds system audio buffers into this tracker and checks
/// `isActive` when a mic-engine segment arrives. If system audio is active,
/// the segment is relabeled as "Others" (the mic picked up speaker bleed).
final class SystemAudioEnergyTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var smoothedEnergy: Float = 0

    /// Exponential moving average decay (0-1). Higher = slower decay.
    private let smoothingFactor: Float = 0.85

    /// RMS threshold above which system audio is considered active.
    private let activeThreshold: Float = 0.005

    private var bufferCount = 0

    var isActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return smoothedEnergy > activeThreshold
    }

    func processBuffer(_ buffer: AVAudioPCMBuffer) {
        let rms = computeRMS(buffer)
        lock.lock()
        smoothedEnergy = smoothedEnergy * smoothingFactor + rms * (1 - smoothingFactor)
        bufferCount += 1
        let count = bufferCount
        let energy = smoothedEnergy
        let active = energy > activeThreshold
        lock.unlock()

        if count == 1 {
            Logger.transcription.info("System audio energy tracker: first buffer received")
        }
        if count == 1 || count % 200 == 0 {
            Logger.transcription.debug("System audio energy: \(String(format: "%.4f", energy)), active=\(active), buffers=\(count)")
        }
    }

    func reset() {
        lock.lock()
        smoothedEnergy = 0
        bufferCount = 0
        lock.unlock()
    }

    func makeBufferProcessor() -> @Sendable (AVAudioPCMBuffer) -> Void {
        return { [weak self] buffer in
            self?.processBuffer(buffer)
        }
    }

    private func computeRMS(_ buffer: AVAudioPCMBuffer) -> Float {
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
}
