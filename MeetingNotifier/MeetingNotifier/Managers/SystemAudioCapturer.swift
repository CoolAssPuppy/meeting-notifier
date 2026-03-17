//
//  SystemAudioCapturer.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import AVFoundation
import CoreMedia
import Foundation
import ScreenCaptureKit
import os

@MainActor
final class SystemAudioCapturer: ObservableObject {
    @Published private(set) var isCapturing = false

    private var stream: SCStream?
    private let streamOutput = SystemAudioStreamOutput()

    init() {}

    // MARK: - Capture lifecycle

    func startCapture(bufferHandler: @escaping @Sendable (AVAudioPCMBuffer) -> Void) async throws {
        guard !isCapturing else {
            Logger.audio.warning("startCapture() called while system audio capture is already running")
            return
        }

        streamOutput.bufferHandler = bufferHandler

        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            Logger.audio.error("Screen recording permission denied or unavailable: \(error.localizedDescription)")
            throw SystemAudioCaptureError.permissionDenied
        }

        guard let display = content.displays.first else {
            Logger.audio.error("No display available for system audio capture")
            throw SystemAudioCaptureError.noDisplay
        }

        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 48000
        config.channelCount = 1

        // Minimize mandatory video capture: 1x1 pixel at lowest frame rate
        config.width = 1
        config.height = 1
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let stream = SCStream(filter: filter, configuration: config, delegate: streamOutput)
        try stream.addStreamOutput(streamOutput, type: .audio, sampleHandlerQueue: streamOutput.queue)
        try stream.addStreamOutput(streamOutput, type: .screen, sampleHandlerQueue: streamOutput.queue)

        self.stream = stream

        do {
            try await stream.startCapture()
            isCapturing = true
            Logger.audio.info("System audio capture started")
        } catch {
            self.stream = nil
            streamOutput.bufferHandler = nil
            Logger.audio.error("SCStream failed to start: \(error.localizedDescription)")
            throw SystemAudioCaptureError.failedToStart(error.localizedDescription)
        }
    }

    func stopCapture() async {
        guard let stream else { return }
        do {
            try await stream.stopCapture()
        } catch {
            Logger.audio.warning("SCStream stop error (non-fatal): \(error.localizedDescription)")
        }
        self.stream = nil
        streamOutput.bufferHandler = nil
        isCapturing = false
        Logger.audio.info("System audio capture stopped")
    }

    // MARK: - CMSampleBuffer -> AVAudioPCMBuffer conversion

    nonisolated static func pcmBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
        else {
            return nil
        }

        guard let audioFormat = AVAudioFormat(streamDescription: asbd) else {
            return nil
        }

        let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
        guard frameCount > 0 else { return nil }

        guard let pcmBuffer = AVAudioPCMBuffer(
            pcmFormat: audioFormat,
            frameCapacity: AVAudioFrameCount(frameCount)
        ) else {
            return nil
        }
        pcmBuffer.frameLength = AVAudioFrameCount(frameCount)

        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return nil
        }

        var dataLength = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        let status = CMBlockBufferGetDataPointer(
            blockBuffer,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &dataLength,
            dataPointerOut: &dataPointer
        )

        guard status == noErr, let sourceData = dataPointer else {
            return nil
        }

        guard let destination = pcmBuffer.floatChannelData else {
            return nil
        }

        let bytesToCopy = min(dataLength, Int(frameCount) * Int(audioFormat.streamDescription.pointee.mBytesPerFrame))
        memcpy(destination[0], sourceData, bytesToCopy)

        return pcmBuffer
    }
}

// MARK: - SCStream output and delegate

private final class SystemAudioStreamOutput: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    let queue = DispatchQueue(label: "com.strategicnerds.meetingnotifier.systemaudio", qos: .userInitiated)
    var bufferHandler: (@Sendable (AVAudioPCMBuffer) -> Void)?

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        guard let pcmBuffer = SystemAudioCapturer.pcmBuffer(from: sampleBuffer) else { return }
        bufferHandler?(pcmBuffer)
    }

    func stream(_ stream: SCStream, didStopWithError error: any Error) {
        Logger.audio.error("SCStream stopped with error: \(error.localizedDescription)")
    }
}

// MARK: - Errors

enum SystemAudioCaptureError: LocalizedError {
    case permissionDenied
    case noDisplay
    case failedToStart(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen recording permission is required to capture system audio"
        case .noDisplay:
            return "No display available for audio capture"
        case .failedToStart(let reason):
            return "System audio capture failed to start: \(reason)"
        }
    }
}
