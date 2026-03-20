//
//  AppDelegate+TranscriptionBanner.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import AppKit
import Combine

// MARK: - Transcription banner management

extension AppDelegate {
    @objc func showTranscriptionBanner() {
        let mode = AppSettings.shared.transcriptionIndicatorMode

        let shouldShowDropdown = mode == .menuBarDropdown || mode == .both
        let shouldTintIcon = mode == .changeIconColor || mode == .both

        if shouldShowDropdown, transcriptionBannerPanel == nil {
            let panel = TranscriptionBannerPanel(onStop: { [weak self] in
                Task { @MainActor in
                    await TranscriptionCoordinator.shared.stopTranscription()
                }
            })

            panel.orderFrontRegardless()
            transcriptionBannerPanel = panel

            if let statusItem {
                panel.positionBelowStatusItem(statusItem, animated: true)
            }

            startAudioLevelUpdates()
        }

        if shouldTintIcon {
            setMenuBarIconRecording(true)
        }
    }

    @objc func hideTranscriptionBanner() {
        stopAudioLevelUpdates()
        transcriptionBannerPanel?.close()
        transcriptionBannerPanel = nil
        setMenuBarIconRecording(false)
    }

    func updateBannerState(_ state: BannerState) {
        transcriptionBannerPanel?.updateState(state)
    }

    func showBannerThenDismiss(_ state: BannerState, after seconds: TimeInterval = 5.0) {
        transcriptionBannerPanel?.updateState(state)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            hideTranscriptionBanner()
        }
    }

    private func startAudioLevelUpdates() {
        audioLevelCancellable = TranscriptionCoordinator.shared.$micLevel
            .receive(on: RunLoop.main)
            .sink { [weak self] level in
                self?.transcriptionBannerPanel?.updateAudioLevel(level)
            }
    }

    private func stopAudioLevelUpdates() {
        audioLevelCancellable?.cancel()
        audioLevelCancellable = nil
    }
}
