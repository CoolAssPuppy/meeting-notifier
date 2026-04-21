//
//  SharedComponents.swift
//  Meeting Notifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import SwiftUI

// MARK: - Card

struct AppCard<Trailing: View, Content: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: AppSpacing.md) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(theme.tertiary)
                Spacer(minLength: 0)
                trailing()
            }
            .padding(.bottom, AppSpacing.lg)

            content()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                .fill(theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                .strokeBorder(theme.border, lineWidth: 1)
        )
    }
}

extension AppCard where Trailing == EmptyView {
    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.init(title: title, trailing: { EmptyView() }, content: content)
    }
}

extension AppCard {
    init(_ title: String,
         @ViewBuilder trailing: @escaping () -> Trailing,
         @ViewBuilder content: @escaping () -> Content) {
        self.init(title: title, trailing: trailing, content: content)
    }
}

// MARK: - Row with label + description + trailing control

struct AppSettingRow<Trailing: View>: View {
    let title: String
    let description: String?
    @ViewBuilder var trailing: () -> Trailing

    @Environment(\.theme) private var theme

    init(_ title: String,
         description: String? = nil,
         @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.description = description
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.lg) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.foreground)
                if let description {
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: AppSpacing.md)
            trailing()
        }
    }
}

// MARK: - Row divider

struct AppRowDivider: View {
    @Environment(\.theme) private var theme
    var body: some View {
        Rectangle()
            .fill(theme.dividerSubtle)
            .frame(height: 1)
    }
}

// MARK: - Button tints

enum AppButtonTint {
    case foreground, primary, destructive
}

// MARK: - Secondary (bordered) button

struct AppSecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    var tint: AppButtonTint = .foreground
    let action: () -> Void

    @Environment(\.theme) private var theme
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .medium))
                }
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(tintColor)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .fill(isHovered ? theme.cardElevated : theme.cardInset)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var tintColor: Color {
        switch tint {
        case .foreground:  return theme.foreground
        case .primary:     return theme.primary
        case .destructive: return theme.destructive
        }
    }

    private var borderColor: Color {
        switch tint {
        case .destructive: return theme.destructive.opacity(0.35)
        default:           return theme.borderStrong
        }
    }
}

// MARK: - Primary (filled) button

struct AppPrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    @Environment(\.theme) private var theme
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(theme.primaryForeground)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(theme.primaryGradient)
                    .opacity(isHovered ? 0.92 : 1.0)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Icon-only button

struct AppIconButton: View {
    let systemName: String
    var help: String = ""
    var tint: AppButtonTint = .foreground
    var isActive: Bool = false
    var spinOnTap: Bool = false
    let action: () -> Void

    @Environment(\.theme) private var theme
    @State private var isHovered = false
    @State private var isSpinning = false

    var body: some View {
        Button(action: handleTap) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(resolvedColor)
                .rotationEffect(.degrees(isSpinning ? 360 : 0))
                .animation(isSpinning ? .easeInOut(duration: 0.6) : .default, value: isSpinning)
                .frame(width: 28, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                        .fill(backgroundFill)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(help)
    }

    private var resolvedColor: Color {
        if isActive { return theme.foreground }
        if isHovered { return theme.foreground }
        switch tint {
        case .foreground:  return theme.muted
        case .primary:     return theme.primary
        case .destructive: return theme.destructive
        }
    }

    private var backgroundFill: Color {
        if isActive { return theme.cardElevated }
        return isHovered ? theme.cardElevated : Color.clear
    }

    private func handleTap() {
        if spinOnTap {
            isSpinning = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isSpinning = false
            }
        }
        action()
    }
}

// MARK: - Brand mark (calendar glyph on gradient)

struct BrandMark: View {
    var size: CGFloat = 26
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(theme.primaryGradient)
            Image(systemName: "calendar")
                .font(.system(size: size * 0.54, weight: .semibold))
                .foregroundStyle(theme.primaryForeground)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Provider badge (Google / Microsoft icon in a chip)

struct ProviderBadge: View {
    let provider: CalendarProvider
    var size: CGFloat = 24
    var dimmed: Bool = false

    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: max(4, size * 0.22), style: .continuous)
                .fill(theme.cardElevated)
            RoundedRectangle(cornerRadius: max(4, size * 0.22), style: .continuous)
                .strokeBorder(theme.borderStrong, lineWidth: 1)
            if let image = provider.icon {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size * 0.6, height: size * 0.6)
                    .opacity(dimmed ? 0.45 : 1.0)
            } else {
                Image(systemName: "calendar")
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(theme.muted)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Status pill (LIVE / IN 7 MIN / UP TO DATE / KEYCHAIN / OFF / etc.)

/// Ambient style used when the pill is informational rather than semantic.
enum AppStatusPillStyle {
    case tinted(Color)
    case neutral
}

struct AppStatusPill: View {
    let text: String
    var systemImage: String? = nil
    var style: AppStatusPillStyle = .neutral
    var pulse: Bool = false

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 5) {
            if pulse, case .tinted(let color) = style {
                PulsingDot(color: color, active: true)
            } else if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .bold))
            }
            Text(text)
                .font(.system(size: 9, weight: .bold))
                .tracking(0.5)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(fill))
        .overlay(Capsule().strokeBorder(border, lineWidth: 1))
    }

    private var foreground: Color {
        switch style {
        case .tinted(let c): return c
        case .neutral:        return theme.tertiary
        }
    }

    private var fill: Color {
        switch style {
        case .tinted(let c): return c.opacity(0.12)
        case .neutral:        return theme.cardInset
        }
    }

    private var border: Color {
        switch style {
        case .tinted(let c): return c.opacity(0.35)
        case .neutral:        return theme.border
        }
    }
}

/// A pulsing colored dot used inside recording / LIVE badges. `active:false`
/// skips the `repeatForever` animation so idle rows don't spin it on every
/// render pass.
struct PulsingDot: View {
    let color: Color
    var active: Bool = true
    @State private var phase: Double = 0

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .overlay(
                Circle()
                    .stroke(color.opacity(active ? 0.5 * (1 - phase) : 0), lineWidth: 2)
                    .scaleEffect(1 + phase * 1.2)
                    .opacity(active ? 1 : 0)
            )
            .onAppear {
                guard active else { return }
                withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

// MARK: - Drawer icon square

struct DrawerIcon: View {
    let systemName: String
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.md)
                .fill(theme.card)
            RoundedRectangle(cornerRadius: AppRadius.md)
                .strokeBorder(theme.borderStrong, lineWidth: 1)
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.primary)
        }
        .frame(width: 34, height: 34)
    }
}

// MARK: - Close button (top-right on drawers)

struct CloseButton: View {
    let onClose: () -> Void
    @Environment(\.theme) private var theme
    @State private var isHovered = false

    var body: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(theme.foreground)
                .frame(width: 28, height: 28)
                .background(Circle().fill(isHovered ? theme.cardElevated : theme.card))
                .overlay(Circle().strokeBorder(theme.borderStrong, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Inset input field chrome

extension View {
    /// Applies the standard inset field background used for TextField/SecureField
    /// and read-only monospace display rows.
    func appInsetField() -> some View {
        modifier(AppInsetField())
    }
}

private struct AppInsetField: ViewModifier {
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: AppRadius.md).fill(theme.cardInset))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.md).strokeBorder(theme.border, lineWidth: 1))
    }
}

// MARK: - Primary gradient helper

extension ThemePalette {
    /// Canonical primary → primaryDeep gradient used by brand marks, primary
    /// buttons, and theme swatches. Keeps the angle consistent across surfaces.
    var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [primary, primaryDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Small uppercase section label

struct AppSectionLabel: View {
    let text: String
    @Environment(\.theme) private var theme

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(theme.tertiary)
    }
}

// MARK: - Picker styling helper

extension View {
    func appBoxedPicker(width: CGFloat = 180) -> some View {
        self
            .labelsHidden()
            .frame(width: width, alignment: .trailing)
    }
}
