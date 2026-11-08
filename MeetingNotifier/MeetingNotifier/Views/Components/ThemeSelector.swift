//
//  ThemeSelector.swift
//  Meeting Notifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import SwiftUI

/// Compact theme control for Settings. Choices expand toward the row label.
struct ThemeSelector: View {
    @ObservedObject private var store = ThemeStore.shared
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isTriggerFocused: Bool
    @FocusState private var focusedOption: AppTheme?
    @Namespace private var circleTransition
    @State private var isExpanded = false
    @State private var isPinned = false

    var body: some View {
        HStack(spacing: 8) {
            Text(store.current.label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.foreground)
                .frame(minWidth: 72, alignment: .trailing)

            if isExpanded {
                HStack(spacing: 2) {
                    ForEach(availableThemes) { option in
                        Button {
                            select(option)
                        } label: {
                            themeCircle(option, diameter: 18)
                                .matchedGeometryEffect(id: option, in: circleTransition)
                                .overlay(focusRing(isFocused: focusedOption == option))
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                        .focused($focusedOption, equals: option)
                        .help(option.label)
                        .accessibilityLabel("\(option.label) theme")
                        .accessibilityHint("Select theme")
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            Button {
                isPinned = !isPinned
                setExpanded(isPinned)
                if isPinned {
                    Task { @MainActor in
                        guard isExpanded && isPinned else { return }
                        focusedOption = availableThemes.first
                    }
                } else {
                    focusedOption = nil
                }
            } label: {
                themeCircle(store.current, diameter: 20)
                    .matchedGeometryEffect(id: store.current, in: circleTransition)
                    .overlay(focusRing(isFocused: isTriggerFocused))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .focused($isTriggerFocused)
            .help(isExpanded ? "Hide themes" : "Show themes")
            .accessibilityLabel("Theme, \(store.current.label)")
            .accessibilityHint(isExpanded ? "Hide theme choices" : "Show theme choices")
        }
        .onHover { isHovering in
            if isHovering {
                setExpanded(true)
            } else if !isPinned && focusedOption == nil {
                setExpanded(false)
            }
        }
        .onChange(of: focusedOption) { _, option in
            if option != nil { isPinned = true }
        }
        .onKeyPress(.escape) {
            guard isExpanded else { return .ignored }
            isPinned = false
            focusedOption = nil
            setExpanded(false)
            isTriggerFocused = true
            return .handled
        }
    }

    private var availableThemes: [AppTheme] {
        AppTheme.allCases.filter { $0 != store.current }
    }

    private func themeCircle(_ option: AppTheme, diameter: CGFloat) -> some View {
        Circle()
            .fill(swatch(for: option))
            .frame(width: diameter, height: diameter)
            .overlay(Circle().strokeBorder(theme.borderStrong, lineWidth: 1))
    }

    private func swatch(for option: AppTheme) -> AnyShapeStyle {
        if option == .system {
            return AnyShapeStyle(LinearGradient(stops: [
                .init(color: ThemePalette.systemLight.background, location: 0),
                .init(color: ThemePalette.systemLight.background, location: 0.5),
                .init(color: ThemePalette.systemDark.background, location: 0.5),
                .init(color: ThemePalette.systemDark.background, location: 1)
            ], startPoint: .leading, endPoint: .trailing))
        }
        return AnyShapeStyle(option.palette.primary)
    }

    private func focusRing(isFocused: Bool) -> some View {
        Circle()
            .strokeBorder(isFocused ? theme.foreground : .clear, lineWidth: 2)
            .padding(-4)
    }

    private func setExpanded(_ expanded: Bool) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82)) {
            isExpanded = expanded
        }
    }

    private func select(_ option: AppTheme) {
        isPinned = false
        focusedOption = nil
        withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.82)) {
            store.current = option
            isExpanded = false
        }
        isTriggerFocused = true
    }
}
