//
//  MicLevelBars.swift
//  MeetingNotifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import SwiftUI

/// Tiny live waveform reading directly from `MicLevelBridge.current`.
/// The audio thread writes the level on every Nth tap buffer; this view
/// re-renders at 30 Hz via `TimelineView(.animation)` and reads it
/// atomically. No Combine, no Task, no Timer — the data path is the
/// nonisolated bridge the user explicitly preferred for audio→UI.
struct MicLevelBars: View {
    var color: Color
    var barCount: Int = 5
    var barWidth: CGFloat = 2.5
    var spacing: CGFloat = 2.5
    var maxHeight: CGFloat = 16
    var minHeight: CGFloat = 3

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { _ in
            let level = max(0, min(1, MicLevelBridge.current))
            HStack(alignment: .center, spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { i in
                    Capsule(style: .continuous)
                        .fill(color)
                        .frame(width: barWidth, height: barHeight(at: i, level: level))
                }
            }
            .frame(height: maxHeight)
            .accessibilityHidden(true)
        }
    }

    /// Vary each bar's height by index so the row reads as a wave instead of
    /// a single block. Center bars track the level most directly; outer bars
    /// trail off so the visual stays coherent at low levels.
    private func barHeight(at index: Int, level: Float) -> CGFloat {
        let center = Double(barCount - 1) / 2.0
        let distance = abs(Double(index) - center)
        let falloff = max(0.45, 1.0 - distance * 0.18)
        let scaled = Double(level) * falloff
        let h = minHeight + (maxHeight - minHeight) * CGFloat(scaled)
        return max(minHeight, min(maxHeight, h))
    }
}
