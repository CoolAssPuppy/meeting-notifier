//
//  TranscriptionBannerView.swift
//  MeetingNotifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import SwiftUI

/// High-level banner states. Pause is a first-class state, distinct from
/// recording, and drives the yellow pulsing outline in the view.
enum BannerState: Equatable {
    case recording
    case paused
    case ended
    case analyzing
    case saved
    case error(String)
}

struct TranscriptionBannerView: View {
    @ObservedObject var viewModel: BannerViewModel
    @ObservedObject private var themeStore = ThemeStore.shared

    var body: some View {
        let theme = themeStore.palette
        return content(theme: theme)
            .environment(\.theme, theme)
            .environment(\.colorScheme, theme.isDark ? .dark : .light)
    }

    @ViewBuilder
    private func content(theme: ThemePalette) -> some View {
        HStack(spacing: 12) {
            leadingIndicator(theme: theme)

            VStack(alignment: .leading, spacing: 1) {
                Text(headlineText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.foreground)
                    .lineLimit(1)
                if let sub = subtitleText {
                    Text(sub)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(theme.muted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 6)

            actionButtons(theme: theme)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.surface.opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(outlineColor(theme: theme), lineWidth: 1.5)
                .opacity(outlineOpacity)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                           value: viewModel.state == .paused)
        )
        .shadow(color: Color.black.opacity(0.45), radius: 14, y: 6)
        .overlay(
            // Soft color glow that matches the outline state
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(outlineColor(theme: theme).opacity(0.10), lineWidth: 6)
                .blur(radius: 4)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
        )
    }

    // MARK: - Leading indicator

    @ViewBuilder
    private func leadingIndicator(theme: ThemePalette) -> some View {
        switch viewModel.state {
        case .recording:
            recordingDot(color: theme.destructive)
        case .paused:
            pausedDot(color: theme.warning)
        case .analyzing:
            ProgressView().controlSize(.small).tint(theme.primary).frame(width: 22, height: 22)
        case .ended, .saved:
            badge(color: theme.success, icon: "checkmark")
        case .error:
            badge(color: theme.destructive, icon: "exclamationmark")
        }
    }

    private func recordingDot(color: Color) -> some View {
        ZStack {
            Circle().fill(color.opacity(0.18))
            Circle().strokeBorder(color.opacity(0.5), lineWidth: 1)
            Circle().fill(color).frame(width: 8, height: 8)
        }
        .frame(width: 22, height: 22)
    }

    private func pausedDot(color: Color) -> some View {
        ZStack {
            Circle().fill(color.opacity(0.18))
            Circle().strokeBorder(color.opacity(0.5), lineWidth: 1)
            Image(systemName: "pause.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(width: 22, height: 22)
    }

    private func badge(color: Color, icon: String) -> some View {
        ZStack {
            Circle().fill(color.opacity(0.18))
            Circle().strokeBorder(color.opacity(0.5), lineWidth: 1)
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(width: 22, height: 22)
    }

    // MARK: - Text

    private var headlineText: String {
        switch viewModel.state {
        case .recording: return viewModel.meetingTitle ?? "Recording meeting"
        case .paused:    return "Paused — \(viewModel.meetingTitle ?? "meeting")"
        case .analyzing: return "Analyzing transcript…"
        case .ended:     return "Recording ended"
        case .saved:     return "Transcript saved"
        case .error(let msg): return msg
        }
    }

    private var subtitleText: String? {
        switch viewModel.state {
        case .recording, .paused:
            var parts: [String] = []
            if let elapsed = viewModel.elapsed { parts.append("● \(elapsed)") }
            parts.append(viewModel.engineLabel)
            return parts.joined(separator: " · ")
        case .ended, .saved:
            return viewModel.meetingTitle
        default:
            return nil
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private func actionButtons(theme: ThemePalette) -> some View {
        switch viewModel.state {
        case .recording:
            BannerIconButton(systemName: "pause.fill", tint: theme.foreground) { viewModel.onPause() }
            BannerIconButton(systemName: "stop.fill",
                             tint: theme.destructive,
                             background: theme.destructive.opacity(0.14),
                             borderColor: theme.destructive.opacity(0.4)) { viewModel.onStop() }
        case .paused:
            BannerIconButton(systemName: "play.fill",
                             tint: theme.primaryForeground,
                             background: theme.warning,
                             borderColor: theme.warning) { viewModel.onResume() }
            BannerIconButton(systemName: "stop.fill",
                             tint: theme.destructive,
                             background: theme.destructive.opacity(0.14),
                             borderColor: theme.destructive.opacity(0.4)) { viewModel.onStop() }
        case .error:
            BannerIconButton(systemName: "doc.on.clipboard", tint: theme.muted) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(viewModel.lastError, forType: .string)
            }
        default:
            EmptyView()
        }
    }

    // MARK: - Outline color (red recording / pulsing yellow on pause)

    private func outlineColor(theme: ThemePalette) -> Color {
        switch viewModel.state {
        case .recording:
            return theme.destructive
        case .paused:
            return theme.warning
        case .analyzing:
            return theme.primary
        case .ended, .saved:
            return theme.success
        case .error:
            return theme.destructive
        }
    }

    private var outlineOpacity: Double {
        // Pulse is the whole mechanism — animate via the .animation modifier above
        viewModel.state == .paused ? (viewModel.pulsePhase ? 1.0 : 0.35) : 1.0
    }
}

// MARK: - Banner icon button

private struct BannerIconButton: View {
    let systemName: String
    let tint: Color
    var background: Color = .clear
    var borderColor: Color? = nil
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isHovered ? background.opacity(0.85) : background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(borderColor ?? tint.opacity(0.0), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
