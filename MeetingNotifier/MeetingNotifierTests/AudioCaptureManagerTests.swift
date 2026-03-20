//
//  AudioCaptureManagerTests.swift
//  MeetingNotifierTests
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import AVFoundation
import XCTest
@testable import MeetingNotifier

final class AudioCaptureManagerTests: XCTestCase {

    func testComputeRMSReturnsZeroForSilentBuffer() {
        let buffer = makePCMBuffer(samples: [0, 0, 0, 0])

        let rms = AudioCaptureManager.computeRMS(buffer)

        XCTAssertEqual(rms, 0, accuracy: 1e-6)
    }

    func testComputeRMSReturnsPositiveForNonSilentBuffer() {
        let buffer = makePCMBuffer(samples: [0.5, -0.5, 0.5, -0.5])

        let rms = AudioCaptureManager.computeRMS(buffer)

        XCTAssertGreaterThan(rms, 0)
    }

    func testComputeRMSClampsToOne() {
        let buffer = makePCMBuffer(samples: [1.0, 1.0, 1.0, 1.0])

        let rms = AudioCaptureManager.computeRMS(buffer)

        XCTAssertLessThanOrEqual(rms, 1.0)
    }

    // MARK: - Factory

    private func makePCMBuffer(samples: [Float]) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = AVAudioFrameCount(samples.count)

        guard let channelData = buffer.floatChannelData else {
            fatalError("Expected float channel data")
        }

        for (i, sample) in samples.enumerated() {
            channelData[0][i] = sample
        }

        return buffer
    }
}
