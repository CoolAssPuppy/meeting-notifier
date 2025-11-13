import AppKit
import SwiftUI

class PeekWindowPanel: NSPanel {
    private var hostingView: NSHostingView<PeekWindowView>?

    init(
        meeting: CalendarEvent?,
        settings: AppSettings,
        onTap: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 32),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        // Panel configuration
        self.level = .floating
        self.isFloatingPanel = true
        self.hidesOnDeactivate = false
        self.isMovableByWindowBackground = false
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Create SwiftUI view
        let peekView = PeekWindowView(
            meeting: meeting,
            settings: settings,
            onTap: onTap,
            onClose: onClose
        )

        // Create hosting view
        let hosting = NSHostingView(rootView: peekView)
        hosting.frame = self.contentView?.bounds ?? .zero
        hosting.autoresizingMask = [.width, .height]

        self.contentView = hosting
        self.hostingView = hosting
    }

    func updateMeeting(
        _ meeting: CalendarEvent?,
        settings: AppSettings,
        onTap: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        let peekView = PeekWindowView(
            meeting: meeting,
            settings: settings,
            onTap: onTap,
            onClose: onClose
        )

        hostingView?.rootView = peekView
    }

    func positionBelowStatusItem(_ statusItem: NSStatusItem, animated: Bool = false) {
        guard let button = statusItem.button,
              let window = button.window else { return }

        let buttonFrame = button.convert(button.bounds, to: nil)
        let screenFrame = window.convertToScreen(buttonFrame)

        // Calculate panel width based on content
        let panelWidth: CGFloat = 300
        let panelHeight: CGFloat = 32

        var panelFrame = NSRect(
            x: screenFrame.midX - panelWidth / 2,
            y: screenFrame.minY - panelHeight - 4,
            width: panelWidth,
            height: panelHeight
        )

        // Ensure panel stays on screen
        if let screen = NSScreen.main {
            let screenBounds = screen.visibleFrame
            if panelFrame.maxX > screenBounds.maxX {
                panelFrame.origin.x = screenBounds.maxX - panelFrame.width - 10
            }
            if panelFrame.minX < screenBounds.minX {
                panelFrame.origin.x = screenBounds.minX + 10
            }
            if panelFrame.minY < screenBounds.minY {
                panelFrame.origin.y = screenBounds.minY + 10
            }
        }

        if animated {
            // Start from menu bar position
            var startFrame = panelFrame
            startFrame.origin.y = screenFrame.minY - 2
            self.setFrame(startFrame, display: false)
            self.alphaValue = 0

            // Animate down with bounce
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.35
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.34, 1.56, 0.64, 1)
                self.animator().alphaValue = 1
                self.animator().setFrame(panelFrame, display: true)
            })
        } else {
            self.setFrame(panelFrame, display: true)
        }
    }
}
