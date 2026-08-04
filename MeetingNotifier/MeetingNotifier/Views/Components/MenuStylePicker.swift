//
//  MenuStylePicker.swift
//  Meeting Notifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import SwiftUI

// MARK: - Picker

/// Two selectable tiles, each showing a miniature of the dropdown it picks.
/// Lives in the main window, so it keeps the app theme even when it is
/// selecting the untinted classic menu.
struct MenuStylePicker: View {
    @ObservedObject private var store = MenuStyleStore.shared

    var body: some View {
        HStack(spacing: 12) {
            ForEach(MenuStyle.allCases) { style in
                MenuStyleTile(style: style, isSelected: store.current == style) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        store.current = style
                    }
                }
            }
        }
    }
}

// MARK: - Tile

private struct MenuStyleTile: View {
    let style: MenuStyle
    let isSelected: Bool
    let onSelect: () -> Void

    @Environment(\.theme) private var theme
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 10) {
                preview
                    .frame(height: 76)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                            .fill(theme.cardInset)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                            .strokeBorder(theme.border, lineWidth: 1)
                    )

                HStack(spacing: 6) {
                    Text(style.label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.foreground)
                    Spacer(minLength: 0)
                    selectionDot
                }

                Text(style.summary)
                    .font(.system(size: 10))
                    .foregroundStyle(theme.muted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                    .fill(isSelected ? theme.primary.opacity(0.07) : theme.cardElevated.opacity(isHovered ? 1 : 0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                    .strokeBorder(isSelected ? theme.primary.opacity(0.65) : theme.border,
                                  lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(Text(style.label))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var selectionDot: some View {
        ZStack {
            Circle()
                .strokeBorder(isSelected ? theme.primary : theme.borderStrong, lineWidth: 1.5)
            if isSelected {
                Circle()
                    .fill(theme.primary)
                    .padding(3.5)
            }
        }
        .frame(width: 14, height: 14)
    }

    @ViewBuilder
    private var preview: some View {
        switch style {
        case .classic: ClassicPreview()
        case .pretty:  PrettyPreview()
        }
    }
}

// MARK: - Miniatures

/// A section heading, flat time-and-title rows with flyout arrows, and the
/// icon strip.
private struct ClassicPreview: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 3) {
            sectionHeading
            row(titleWidth: 0.7, isHighlighted: false)
            row(titleWidth: 0.85, isHighlighted: true)

            Rectangle()
                .fill(theme.dividerSubtle)
                .frame(height: 1)
                .padding(.top, 2)

            HStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { _ in dot }
                Spacer(minLength: 0)
                dot
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
    }

    private var sectionHeading: some View {
        RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(theme.dim.opacity(0.7))
            .frame(width: 18, height: 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
            .padding(.bottom, 1)
    }

    private func row(titleWidth: CGFloat, isHighlighted: Bool) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isHighlighted ? theme.primaryForeground.opacity(0.9) : theme.muted.opacity(0.55))
                .frame(width: 5, height: 5)
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(isHighlighted ? theme.primaryForeground.opacity(0.9) : theme.muted.opacity(0.75))
                .frame(width: 12, height: 4)
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(isHighlighted ? theme.primaryForeground.opacity(0.9) : theme.muted.opacity(0.55))
                .frame(height: 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .scaleEffect(x: titleWidth, anchor: .leading)
            Image(systemName: "chevron.right")
                .font(.system(size: 5, weight: .bold))
                .foregroundStyle(isHighlighted ? theme.primaryForeground.opacity(0.9) : theme.dim)
                .opacity(isHighlighted ? 1 : 0.6)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(isHighlighted ? theme.primary : Color.clear)
        )
    }

    private var dot: some View {
        Circle()
            .fill(theme.muted.opacity(0.5))
            .frame(width: 4, height: 4)
    }
}

/// Rounded meeting cards with a calendar stripe, a live pill, and a join chip.
private struct PrettyPreview: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 4) {
            header
            card(isLive: true)
            card(isLive: false)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
    }

    private var header: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(
                    LinearGradient(colors: [theme.primary, theme.primaryDeep],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                )
                .frame(width: 8, height: 8)
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(theme.muted.opacity(0.55))
                .frame(width: 26, height: 4)
            Spacer(minLength: 0)
            Capsule()
                .fill(theme.warning.opacity(0.35))
                .frame(width: 16, height: 6)
        }
        .padding(.bottom, 1)
    }

    private func card(isLive: Bool) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(theme.primary.opacity(0.7))
                .frame(width: 2)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    if isLive {
                        Capsule()
                            .fill(theme.destructive.opacity(0.45))
                            .frame(width: 12, height: 5)
                    }
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(theme.muted.opacity(0.4))
                        .frame(width: 16, height: 3)
                    Spacer(minLength: 0)
                    Capsule()
                        .strokeBorder(theme.borderStrong, lineWidth: 0.8)
                        .frame(width: 14, height: 6)
                }
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(theme.muted.opacity(0.7))
                    .frame(width: 34, height: 3.5)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(isLive ? theme.destructive.opacity(0.4) : theme.border, lineWidth: 1)
        )
    }
}
