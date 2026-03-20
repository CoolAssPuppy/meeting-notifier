//
//  TranscriptionBannerView.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import SwiftUI

enum BannerState {
    case recording
    case ended
    case analyzing
    case saved
    case error(String)
}

struct TranscriptionBannerView: View {
    @ObservedObject var viewModel: BannerViewModel

    var body: some View {
        HStack(spacing: 10) {
            statusDot
            statusText
            actionButton
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

    @ViewBuilder
    private var statusDot: some View {
        switch viewModel.state {
        case .recording:
            AudioWaveformView()
        case .ended:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.blue)
        case .analyzing:
            ProgressView()
                .controlSize(.small)
        case .saved:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.green)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundColor(.orange)
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch viewModel.state {
        case .recording:
            Text("Transcription Active")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .fixedSize()
        case .ended:
            Text("Transcription ended.")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .fixedSize()
        case .analyzing:
            Text("Analyzing transcript...")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .fixedSize()
        case .saved:
            Text("Transcript saved.")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .fixedSize()
        case .error(let message):
            Text(message)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.red)
                .lineLimit(1)
                .truncationMode(.tail)
                .help(message)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch viewModel.state {
        case .recording:
            Button(action: viewModel.onStop) {
                Text("Stop")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .fixedSize()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.red)
                    )
            }
            .buttonStyle(.plain)
            .fixedSize()
        case .error:
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(viewModel.lastError, forType: .string)
            } label: {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Copy error to clipboard")
        default:
            EmptyView()
        }
    }
}
