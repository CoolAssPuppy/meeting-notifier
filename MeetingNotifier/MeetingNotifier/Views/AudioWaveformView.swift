//
//  AudioWaveformView.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import SwiftUI

struct AudioWaveformView: View {
    let audioLevel: Float

    private static let barCount = 4
    private static let barWidth: CGFloat = 2.5
    private static let barSpacing: CGFloat = 1.5
    private static let maxHeight: CGFloat = 12
    private static let minHeight: CGFloat = 3
    private static let multipliers: [Float] = [0.6, 1.0, 0.8, 0.5]

    var body: some View {
        HStack(spacing: Self.barSpacing) {
            ForEach(0..<Self.barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.green)
                    .frame(width: Self.barWidth, height: barHeight(for: index))
            }
        }
        .frame(height: Self.maxHeight)
        .animation(.easeOut(duration: 0.1), value: audioLevel)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let multiplier = Self.multipliers[index]
        let level = CGFloat(audioLevel * multiplier)
        let height = Self.minHeight + level * (Self.maxHeight - Self.minHeight)
        return min(max(height, Self.minHeight), Self.maxHeight)
    }
}
