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
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let meeting = self.getNextMeetingForMenuBar()
            let settings = AppSettings.shared

            if meeting == nil {
                self.hidePeekWindow()
                return
            }

            if let existingPanel = self.peekWindowPanel {
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
                if let statusItem = self.statusItem {
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
                self.peekWindowPanel = panel

                if let statusItem = self.statusItem {
                    panel.positionBelowStatusItem(statusItem, animated: true)
                }
            }
        }
    }

    func hidePeekWindow() {
        DispatchQueue.main.async { [weak self] in
            self?.peekWindowPanel?.close()
            self?.peekWindowPanel = nil
        }
    }

    private func handlePeekMeetingTap() {
        guard let meeting = getNextMeetingForMenuBar(),
              let conferenceLink = meeting.conferenceLink,
              let url = URL(string: conferenceLink) else {
            return
        }
        AppSettings.shared.openURL(url, accountEmail: meeting.accountEmail)
    }
}
