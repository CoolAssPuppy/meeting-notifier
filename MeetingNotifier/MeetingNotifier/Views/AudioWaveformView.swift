//
//  AudioWaveformView.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import SwiftUI

struct AudioWaveformView: View {
    @State private var barHeights: [CGFloat] = [2, 2, 2, 2]

    private static let barWidth: CGFloat = 3
    private static let barSpacing: CGFloat = 1.5
    private static let maxHeight: CGFloat = 16
    private static let minHeight: CGFloat = 2
    private static let multipliers: [CGFloat] = [0.6, 1.0, 0.8, 0.5]

    private let timer = Timer.publish(every: 0.08, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .center, spacing: Self.barSpacing) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.green)
                    .frame(width: Self.barWidth, height: barHeights[index])
            }
        }
        .frame(height: Self.maxHeight)
        .onReceive(timer) { _ in
            let raw = CGFloat(MicLevelBridge.current)
            let level = min(pow(raw, 0.4), 1.0)
            withAnimation(.easeOut(duration: 0.08)) {
                for i in 0..<4 {
                    let jitter = CGFloat.random(in: 0.6...1.4)
                    let scaled = level * Self.multipliers[i] * jitter
                    barHeights[i] = Self.minHeight + scaled * (Self.maxHeight - Self.minHeight)
                }
            }
        }
    }
}
