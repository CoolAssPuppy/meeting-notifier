//
//  TranscriptionBannerPanel.swift
//  MeetingNotifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import AppKit
import SwiftUI
import Combine

@MainActor
final class BannerViewModel: ObservableObject {
    @Published var state: BannerState = .recording
    @Published var meetingTitle: String?
    @Published var engineLabel: String = "Apple Speech"
    @Published var elapsed: String?
    @Published var pulsePhase: Bool = false

    var lastError: String = ""

    var onStop: () -> Void = {}
    var onPause: () -> Void = {}
    var onResume: () -> Void = {}

    /// Drives the yellow-on-pause pulsing outline. Toggles every ~1 second
    /// while paused, animating via SwiftUI's repeatForever(autoreverses:) binding.
    private var pulseTimer: Timer?

    func startPausePulse() {
        pulseTimer?.invalidate()
        pulsePhase = true
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.9, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pulsePhase.toggle()
            }
        }
    }

    func stopPausePulse() {
        pulseTimer?.invalidate()
        pulseTimer = nil
        pulsePhase = false
    }

    /// Start counting wall-clock seconds and publish them as "mm:ss".
    private var elapsedTimer: Timer?
    private var elapsedStart: Date?

    func startElapsed() {
        elapsedStart = Date()
        updateElapsed()
        elapsedTimer?.invalidate()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateElapsed()
            }
        }
    }

    func stopElapsed() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        elapsed = nil
    }

    private func updateElapsed() {
        guard let start = elapsedStart else { return }
        let secs = Int(Date().timeIntervalSince(start))
        let m = secs / 60
        let s = secs % 60
        elapsed = String(format: "%d:%02d", m, s)
    }

}

final class TranscriptionBannerPanel: NSPanel {
    private var hostingView: NSHostingView<TranscriptionBannerView>?
    let viewModel = BannerViewModel()

    override func close() {
        // Invalidate timers before teardown so they don't keep firing on the
        // main RunLoop while the panel deallocates.
        viewModel.stopPausePulse()
        viewModel.stopElapsed()
        super.close()
    }

    override var canBecomeKey: Bool { true }

    init(onPause: @escaping () -> Void,
         onResume: @escaping () -> Void,
         onStop: @escaping () -> Void) {
        viewModel.onPause = onPause
        viewModel.onResume = onResume
        viewModel.onStop = onStop

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 52),
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
        viewModel.startElapsed()
    }

    func updateState(_ newState: BannerState) {
        viewModel.state = newState
        switch newState {
        case .paused:
            viewModel.startPausePulse()
        case .recording, .analyzing:
            viewModel.stopPausePulse()
        default:
            viewModel.stopPausePulse()
            viewModel.stopElapsed()
        }
        if case .error(let msg) = newState {
            viewModel.lastError = msg
        }
    }

    func configure(meetingTitle: String?, engineLabel: String) {
        viewModel.meetingTitle = meetingTitle
        viewModel.engineLabel = engineLabel
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

        let panelWidth: CGFloat = 420
        let panelHeight: CGFloat = 52

        var panelFrame = NSRect(
            x: screenFrame.midX - panelWidth / 2,
            y: screenFrame.minY - panelHeight - 4,
            width: panelWidth,
            height: panelHeight
        )

        if let screen = NSScreen.main {
            let bounds = screen.visibleFrame
            if panelFrame.maxX > bounds.maxX {
                panelFrame.origin.x = bounds.maxX - panelFrame.width - 10
            }
            if panelFrame.minX < bounds.minX {
                panelFrame.origin.x = bounds.minX + 10
            }
        }

        if animated {
            var startFrame = panelFrame
            startFrame.origin.y = screenFrame.minY - 2
            setFrame(startFrame, display: false)
            alphaValue = 0
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.3
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.34, 1.56, 0.64, 1)
                animator().alphaValue = 1
                animator().setFrame(panelFrame, display: true)
            })
        } else {
            setFrame(panelFrame, display: true)
        }
    }
}
