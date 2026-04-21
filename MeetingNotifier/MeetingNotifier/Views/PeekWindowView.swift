//
//  PeekWindowView.swift
//  MeetingNotifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import SwiftUI
import AppKit

struct PeekWindowView: View {
    let meeting: CalendarEvent?
    let settings: AppSettings
    let onTap: () -> Void
    let onClose: () -> Void

    @ObservedObject private var themeStore = ThemeStore.shared

    var body: some View {
        let theme = themeStore.palette
        return Group {
            if let meeting = meeting {
                content(meeting: meeting, theme: theme)
            } else {
                EmptyView()
            }
        }
        .environment(\.theme, theme)
        .environment(\.colorScheme, theme.isDark ? .dark : .light)
    }

    @ViewBuilder
    private func content(meeting: CalendarEvent, theme: ThemePalette) -> some View {
        HStack(spacing: 10) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(theme.tertiary)
                    .frame(width: 16, height: 16)
                    .background(
                        Circle().fill(theme.cardInset)
                    )
                    .overlay(Circle().strokeBorder(theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("Dismiss")

            countdownPill(meeting: meeting, theme: theme)

            Button(action: onTap) {
                Text(meeting.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.foreground)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 210, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button(action: onTap) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(theme.primaryForeground)
                    .frame(width: 20, height: 20)
                    .background(
                        Circle().fill(
                            LinearGradient(colors: [theme.primary, theme.primaryDeep],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    )
            }
            .buttonStyle(.plain)
            .help(meeting.hasVideoLink ? "Join meeting" : "Open meeting")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.surface.opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(theme.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 10, y: 4)
    }

    @ViewBuilder
    private func countdownPill(meeting: CalendarEvent, theme: ThemePalette) -> some View {
        let color: Color = meeting.isHappening ? theme.destructive : theme.warning
        let label: String = {
            if meeting.isHappening { return "LIVE" }
            let m = max(0, Int(meeting.startDate.timeIntervalSinceNow / 60))
            if m < 60 { return "\(m) MIN" }
            return "\(m / 60) H"
        }()
        HStack(spacing: 4) {
            Image(systemName: meeting.isHappening ? "dot.radiowaves.left.and.right" : "clock")
                .font(.system(size: 9, weight: .bold))
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(0.3)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.14)))
        .overlay(Capsule().strokeBorder(color.opacity(0.35), lineWidth: 1))
    }
}
