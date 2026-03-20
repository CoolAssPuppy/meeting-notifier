//
//  TranscriptionBannerPanel.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import AppKit
import SwiftUI

@MainActor
final class BannerViewModel: ObservableObject {
    @Published var state: BannerState = .recording
    var lastError: String = ""
    var onStop: () -> Void = {}
}

class TranscriptionBannerPanel: NSPanel {
    private var hostingView: NSHostingView<TranscriptionBannerView>?
    let viewModel = BannerViewModel()

    override var canBecomeKey: Bool { true }

    init(onStop: @escaping () -> Void) {
        viewModel.onStop = onStop
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 40),
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

        setupView()
    }

    func updateState(_ newState: BannerState) {
        viewModel.state = newState
        if case .error(let msg) = newState {
            viewModel.lastError = msg
        }
    }

    private func setupView() {
        let bannerView = TranscriptionBannerView(viewModel: viewModel)

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

        let panelWidth: CGFloat = 300
        let panelHeight: CGFloat = 40

        var panelFrame = NSRect(
            x: screenFrame.midX - panelWidth / 2,
            y: screenFrame.minY - panelHeight - 4,
            width: panelWidth,
            height: panelHeight
        )

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
