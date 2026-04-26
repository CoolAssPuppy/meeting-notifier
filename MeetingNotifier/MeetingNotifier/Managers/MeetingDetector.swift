//
//  MeetingDetector.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Combine
import CoreAudio
import Foundation
import os

/// Watches CoreAudio for input-device activity (mic in use). Drives the
/// auto-offer transcription flow.
///
/// The previous implementation polled every 2 seconds. That's up to a
/// 2-second delay before transcription starts after a meeting begins, plus
/// a constant background CoreAudio call. This version installs a property
/// listener on `kAudioDevicePropertyDeviceIsRunningSomewhere` for each
/// input-capable device, so state changes fire immediately. A 5-second
/// safety-net poll is retained as a fallback in case a listener misses an
/// edge case (device hot-plug during a transition, etc.) — losing a state
/// change for ~5s is far better than 2s of constant polling.
@MainActor
final class MeetingDetector: ObservableObject {
    static let shared = MeetingDetector()

    @Published private(set) var isMicrophoneActive = false

    private var deviceListenerTokens: [AudioObjectID: AudioObjectPropertyListenerBlock] = [:]
    private var deviceListListenerBlock: AudioObjectPropertyListenerBlock?
    private var safetyNetTimer: Timer?

    private static let listenerQueue = DispatchQueue(
        label: "com.strategicnerds.meetingnotifier.meetingdetector",
        qos: .userInitiated
    )

    private init() {
        startMonitoring()
    }

    deinit {
        // Best-effort teardown. We can't await main-actor methods from deinit;
        // the listeners hold weak references to a queue, so the OS cleans them
        // up when the app exits.
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        installDeviceListListener()
        refreshDeviceListeners()
        startSafetyNetTimer()
        checkMicrophoneStatus()
    }

    /// Re-evaluate which input devices we should be listening to. Called on
    /// init and whenever the system advertises a device-list change.
    private func refreshDeviceListeners() {
        let inputs = inputDevices()
        let current = Set(deviceListenerTokens.keys)
        let next = Set(inputs)

        // Remove listeners on devices that disappeared.
        for removed in current.subtracting(next) {
            removeDeviceListener(for: removed)
        }
        // Add listeners on new devices.
        for added in next.subtracting(current) {
            installDeviceListener(for: added)
        }
    }

    /// Re-check the running state of all input devices and publish.
    private func checkMicrophoneStatus() {
        let wasActive = isMicrophoneActive
        let nowActive = inputDevices().contains { isDeviceRunning($0) }
        guard nowActive != wasActive else { return }

        isMicrophoneActive = nowActive
        if nowActive {
            Logger.transcription.info("Microphone became active")
            NotificationCenter.default.post(name: .microphoneDidActivate, object: nil)
        } else {
            Logger.transcription.info("Microphone became inactive")
            NotificationCenter.default.post(name: .microphoneDidDeactivate, object: nil)
        }
    }

    // MARK: - Listener wiring

    private func installDeviceListListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            // CoreAudio invokes this on its own thread; hop to MainActor before
            // touching `@MainActor` state. Sendable-safe because we capture
            // only `self` (a class).
            Task { @MainActor in
                self?.refreshDeviceListeners()
                self?.checkMicrophoneStatus()
            }
        }

        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            Self.listenerQueue,
            block
        )
        if status == noErr {
            deviceListListenerBlock = block
        } else {
            Logger.transcription.warning("Failed to install device-list listener: \(status)")
        }
    }

    private func installDeviceListener(for deviceId: AudioObjectID) {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in
                self?.checkMicrophoneStatus()
            }
        }

        let status = AudioObjectAddPropertyListenerBlock(
            deviceId,
            &address,
            Self.listenerQueue,
            block
        )
        if status == noErr {
            deviceListenerTokens[deviceId] = block
        } else {
            Logger.transcription.warning("Failed to install device listener for \(deviceId): \(status)")
        }
    }

    private func removeDeviceListener(for deviceId: AudioObjectID) {
        guard let block = deviceListenerTokens.removeValue(forKey: deviceId) else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        _ = AudioObjectRemovePropertyListenerBlock(deviceId, &address, Self.listenerQueue, block)
    }

    /// Coarse safety-net poll. Listeners cover the immediate-response path;
    /// this is here only to recover from edge cases where a listener missed
    /// a transition (rare but observed historically with audio-device churn).
    private func startSafetyNetTimer() {
        safetyNetTimer?.invalidate()
        safetyNetTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkMicrophoneStatus()
            }
        }
    }

    // MARK: - Device enumeration

    private func inputDevices() -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0, nil,
            &dataSize
        )
        guard status == noErr, dataSize > 0 else { return [] }

        let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var devices = [AudioObjectID](repeating: 0, count: count)

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0, nil,
            &dataSize, &devices
        )
        guard status == noErr else { return [] }

        return devices.filter { hasInputChannels($0) }
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
}
