//
//  AppDelegate+TranscriptionBanner.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import AppKit

// MARK: - Transcription banner management

extension AppDelegate {
    @objc func showTranscriptionBanner() {
        guard transcriptionBannerPanel == nil else { return }

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
    }

    @objc func hideTranscriptionBanner() {
        transcriptionBannerPanel?.close()
        transcriptionBannerPanel = nil
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
}
