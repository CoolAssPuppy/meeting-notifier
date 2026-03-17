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
            self?.hideTranscriptionBanner()
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
}
