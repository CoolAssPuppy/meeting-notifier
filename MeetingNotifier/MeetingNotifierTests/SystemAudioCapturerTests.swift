//
//  SystemAudioCapturerTests.swift
//  MeetingNotifierTests
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import AVFoundation
import CoreMedia
import XCTest
@testable import MeetingNotifier

final class SystemAudioCapturerTests: XCTestCase {

    // MARK: - CMSampleBuffer -> AVAudioPCMBuffer conversion

    func testConvertValidSampleBufferProducesCorrectFrameCount() {
        let frameCount = 1024
        let sampleBuffer = makeCMSampleBuffer(frameCount: frameCount)

        let pcmBuffer = SystemAudioCapturer.pcmBuffer(from: sampleBuffer)

        XCTAssertNotNil(pcmBuffer)
        XCTAssertEqual(Int(pcmBuffer!.frameLength), frameCount)
    }

    func testConvertValidSampleBufferPreservesSampleRate() {
        let sampleRate: Float64 = 48000
        let sampleBuffer = makeCMSampleBuffer(sampleRate: sampleRate)

        let pcmBuffer = SystemAudioCapturer.pcmBuffer(from: sampleBuffer)

        XCTAssertNotNil(pcmBuffer)
        XCTAssertEqual(pcmBuffer!.format.sampleRate, sampleRate)
    }

    func testConvertValidSampleBufferPreservesChannelCount() {
        let sampleBuffer = makeCMSampleBuffer(channelCount: 1)

        let pcmBuffer = SystemAudioCapturer.pcmBuffer(from: sampleBuffer)

        XCTAssertNotNil(pcmBuffer)
        XCTAssertEqual(pcmBuffer!.format.channelCount, 1)
    }

    func testConvertPreservesAudioData() {
        let frameCount = 4
        let floats: [Float] = [0.1, 0.2, 0.3, 0.4]
        let sampleBuffer = makeCMSampleBuffer(frameCount: frameCount, samples: floats)

        let pcmBuffer = SystemAudioCapturer.pcmBuffer(from: sampleBuffer)

        XCTAssertNotNil(pcmBuffer)
        guard let channelData = pcmBuffer?.floatChannelData?[0] else {
            XCTFail("Expected float channel data")
            return
        }
        for i in 0..<frameCount {
            XCTAssertEqual(channelData[i], floats[i], accuracy: 1e-6)
        }
    }

    func testConvertDifferentSampleRatePreservesFormat() {
        let sampleBuffer = makeCMSampleBuffer(sampleRate: 16000, frameCount: 512)

        let pcmBuffer = SystemAudioCapturer.pcmBuffer(from: sampleBuffer)

        XCTAssertNotNil(pcmBuffer)
        XCTAssertEqual(pcmBuffer!.format.sampleRate, 16000)
        XCTAssertEqual(Int(pcmBuffer!.frameLength), 512)
    }

    // MARK: - Factory helpers

    private func makeCMSampleBuffer(
        sampleRate: Float64 = 48000,
        channelCount: UInt32 = 1,
        frameCount: Int = 1024,
        samples: [Float]? = nil
    ) -> CMSampleBuffer {
        var asbd = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 4 * channelCount,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4 * channelCount,
            mChannelsPerFrame: channelCount,
            mBitsPerChannel: 32,
            mReserved: 0
        )

        var formatDescription: CMAudioFormatDescription!
        let formatStatus = CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: &asbd,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &formatDescription
        )
        precondition(formatStatus == noErr, "Failed to create format description")

        let dataSize = frameCount * Int(asbd.mBytesPerFrame)

        // Allocate a persistent block buffer that owns its own memory copy
        var blockBuffer: CMBlockBuffer!
        CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: dataSize,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: dataSize,
            flags: kCMBlockBufferAssureMemoryNowFlag,
            blockBufferOut: &blockBuffer
        )

        // If sample data is provided, copy it into the block buffer
        if let samples {
            samples.withUnsafeBytes { rawBuffer in
                let bytesToCopy = min(rawBuffer.count, dataSize)
                CMBlockBufferReplaceDataBytes(
                    with: rawBuffer.baseAddress!,
                    blockBuffer: blockBuffer,
                    offsetIntoDestination: 0,
                    dataLength: bytesToCopy
                )
            }
        }

        var sampleBuffer: CMSampleBuffer!
        let sampleStatus = CMAudioSampleBufferCreateReadyWithPacketDescriptions(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            formatDescription: formatDescription,
            sampleCount: frameCount,
            presentationTimeStamp: .zero,
            packetDescriptions: nil,
            sampleBufferOut: &sampleBuffer
        )
        precondition(sampleStatus == noErr, "Failed to create sample buffer: \(sampleStatus)")

        return sampleBuffer
    }
}
