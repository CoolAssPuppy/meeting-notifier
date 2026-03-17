//
//  TranscriptionBannerPanel.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import AppKit
import SwiftUI

class TranscriptionBannerPanel: NSPanel {
    private var hostingView: NSHostingView<TranscriptionBannerView>?

    init(onStop: @escaping () -> Void) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 270, height: 36),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isFloatingPanel = true
        self.hidesOnDeactivate = false
        self.isMovableByWindowBackground = false
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.ignoresMouseEvents = false

        let bannerView = TranscriptionBannerView(onStop: onStop)
        let hosting = NSHostingView(rootView: bannerView)
        hosting.frame = self.contentView?.bounds ?? .zero
        hosting.autoresizingMask = [.width, .height]

        self.contentView = hosting
        self.hostingView = hosting
    }

    func positionBelowStatusItem(_ statusItem: NSStatusItem, animated: Bool = false) {
        guard let button = statusItem.button,
              let window = button.window else { return }

        let buttonFrame = button.convert(button.bounds, to: nil)
        let screenFrame = window.convertToScreen(buttonFrame)

        let panelWidth: CGFloat = 270
        let panelHeight: CGFloat = 30

        var panelFrame = NSRect(
            x: screenFrame.midX - panelWidth / 2,
            y: screenFrame.minY - panelHeight - 4,
            width: panelWidth,
            height: panelHeight
        )

        // Keep on screen
        if let screen = NSScreen.main {
            let screenBounds = screen.visibleFrame
            if panelFrame.maxX > screenBounds.maxX {
                panelFrame.origin.x = screenBounds.maxX - panelFrame.width - 10
            }
            if panelFrame.minX < screenBounds.minX {
                panelFrame.origin.x = screenBounds.minX + 10
            }
        }

        if animated {
            var startFrame = panelFrame
            startFrame.origin.y = screenFrame.minY - 2
            self.setFrame(startFrame, display: false)
            self.alphaValue = 0

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.34, 1.56, 0.64, 1)
                self.animator().alphaValue = 1
                self.animator().setFrame(panelFrame, display: true)
            })
        } else {
            self.setFrame(panelFrame, display: true)
        }
    }
}
