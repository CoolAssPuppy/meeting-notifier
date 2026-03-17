//
//  MeetingDetector.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import AVFoundation
import Combine
import CoreAudio
import Foundation
import os

@MainActor
final class MeetingDetector: ObservableObject {
    static let shared = MeetingDetector()

    @Published private(set) var isMicrophoneActive = false
    @Published private(set) var isCameraActive = false

    private var micPropertyListenerBlock: AudioObjectPropertyListenerBlock?
    nonisolated(unsafe) private var pollTimer: Timer?

    private init() {
        startMonitoring()
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        // Poll mic/camera status every 2 seconds
        // CoreAudio property listeners require careful lifecycle management,
        // so polling is more reliable for a menu bar app
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkMicrophoneStatus()
                // Camera check disabled: AVCaptureDevice.DiscoverySession
                // can trigger CMIO framework crashes when camera subsystem
                // is in a bad state (e.g. with virtual cameras or background
                // video apps). Mic detection is sufficient for transcription.
            }
        }

        checkMicrophoneStatus()
    }

    private func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // MARK: - Microphone detection

    private func checkMicrophoneStatus() {
        let wasActive = isMicrophoneActive
        isMicrophoneActive = isAudioInputInUse()

        if isMicrophoneActive && !wasActive {
            Logger.transcription.info("Microphone became active")
            NotificationCenter.default.post(name: .microphoneDidActivate, object: nil)
        } else if !isMicrophoneActive && wasActive {
            Logger.transcription.info("Microphone became inactive")
            NotificationCenter.default.post(name: .microphoneDidDeactivate, object: nil)
        }
    }

    private func isAudioInputInUse() -> Bool {
        // Get all audio devices in the system
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0, nil,
            &dataSize
        )
        guard status == noErr, dataSize > 0 else { return false }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var devices = [AudioObjectID](repeating: 0, count: deviceCount)

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0, nil,
            &dataSize, &devices
        )
        guard status == noErr else { return false }

        // Check each device that has input channels
        for device in devices {
            guard hasInputChannels(device) else { continue }
            if isDeviceRunning(device) { return true }
        }

        return false
    }

    private func hasInputChannels(_ deviceId: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        var size: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(deviceId, &address, 0, nil, &size)
        guard status == noErr, size > 0 else { return false }

        let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(size))
        defer { bufferListPointer.deallocate() }

        let dataStatus = AudioObjectGetPropertyData(deviceId, &address, 0, nil, &size, bufferListPointer)
        guard dataStatus == noErr else { return false }

        let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPointer)
        return bufferList.contains { $0.mNumberChannels > 0 }
    }

    private func isDeviceRunning(_ deviceId: AudioObjectID) -> Bool {
        var isRunning: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<UInt32>.size)

        let status = AudioObjectGetPropertyData(deviceId, &address, 0, nil, &size, &isRunning)
        return status == noErr && isRunning != 0
    }

    // MARK: - Camera detection

    private func checkCameraStatus() {
        let wasActive = isCameraActive
        isCameraActive = isCameraInUse()

        if isCameraActive && !wasActive {
            Logger.transcription.info("Camera became active")
        } else if !isCameraActive && wasActive {
            Logger.transcription.info("Camera became inactive")
        }
    }

    private func isCameraInUse() -> Bool {
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        ).devices

        return devices.contains { $0.isInUseByAnotherApplication }
    }
}
