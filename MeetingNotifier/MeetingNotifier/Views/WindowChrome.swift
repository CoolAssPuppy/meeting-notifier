//
//  WindowChrome.swift
//  MeetingNotifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import SwiftUI
import AppKit

/// Paints the hosting NSWindow with the active palette. Re-applies on every
/// palette change via `updateNSView`.
struct WindowChrome: NSViewRepresentable {
    let palette: ThemePalette

    func makeNSView(context: Context) -> ChromeView {
        ChromeView(palette: palette)
    }

    func updateNSView(_ nsView: ChromeView, context: Context) {
        nsView.palette = palette
        nsView.applyChrome()
    }

    final class ChromeView: NSView {
        var palette: ThemePalette
        init(palette: ThemePalette) {
            self.palette = palette
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            applyChrome()
        }

        func applyChrome() {
            guard let window else { return }
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            window.appearance = palette.nsAppearance
            window.backgroundColor = palette.nsBackground
            window.isMovableByWindowBackground = true
        }
    }
}
