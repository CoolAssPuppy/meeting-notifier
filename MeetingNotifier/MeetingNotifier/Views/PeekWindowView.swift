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
                    .background(Circle().fill(theme.primaryGradient))
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
        if meeting.isHappening {
            AppStatusPill(text: "LIVE",
                          systemImage: "dot.radiowaves.left.and.right",
                          style: .tinted(theme.destructive))
        } else {
            let minutes = meeting.minutesUntilStart ?? 0
            let label = minutes < 60 ? "\(minutes) MIN" : "\(minutes / 60) H"
            AppStatusPill(text: label,
                          systemImage: "clock",
                          style: .tinted(theme.warning))
        }
    }
}
