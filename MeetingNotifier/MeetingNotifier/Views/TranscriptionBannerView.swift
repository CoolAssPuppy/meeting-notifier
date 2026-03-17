//
//  TranscriptionBannerView.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import SwiftUI

struct TranscriptionBannerView: View {
    let onStop: () -> Void

    @State private var dotOpacity: Double = 1.0

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
                .shadow(color: .green.opacity(0.8), radius: 4)
                .opacity(dotOpacity)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        dotOpacity = 0.3
                    }
                }

            Text("Transcription Active")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .fixedSize()

            Button(action: onStop) {
                Text("Stop")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.red)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

struct TranscriptionBannerView_Previews: PreviewProvider {
    static var previews: some View {
        TranscriptionBannerView(onStop: {})
            .padding()
    }
}
