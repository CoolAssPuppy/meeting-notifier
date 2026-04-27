//
//  AppDelegate+PeekWindow.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import AppKit

// MARK: - Peek window management

extension AppDelegate {
    func updatePeekWindow() {
        let meeting = getNextMeetingForMenuBar()
        let settings = AppSettings.shared

        if meeting == nil {
            hidePeekWindow()
            return
        }

        if let existingPanel = peekWindowPanel {
            existingPanel.updateMeeting(
                meeting,
                settings: settings,
                onTap: { [weak self] in
                    self?.handlePeekMeetingTap()
                },
                onClose: { [weak self] in
                    self?.hidePeekWindow()
                }
            )
            if let statusItem {
                existingPanel.positionBelowStatusItem(statusItem, animated: false)
            }
        } else {
            let panel = PeekWindowPanel(
                meeting: meeting,
                settings: settings,
                onTap: { [weak self] in
                    self?.handlePeekMeetingTap()
                },
                onClose: { [weak self] in
                    self?.hidePeekWindow()
                }
            )

            panel.orderFrontRegardless()
            peekWindowPanel = panel

            if let statusItem {
                panel.positionBelowStatusItem(statusItem, animated: true)
            }
        }
    }

    func hidePeekWindow() {
        peekWindowPanel?.close()
        peekWindowPanel = nil
    }

    private func handlePeekMeetingTap() {
        guard let meeting = getNextMeetingForMenuBar(),
              let conferenceLink = meeting.conferenceLink,
              let url = URL(string: conferenceLink) else {
            return
        }
        TranscriptionCoordinator.shared.registerUserSelectedMeeting(meeting)
        AppSettings.shared.openURL(url, accountEmail: meeting.accountEmail)
    }
}
