//
//  PaywallSheet.swift
//  MeetingNotifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//
//  The subscription gate, shown when someone tries to connect a second calendar
//  account or opens an account the subscription has paused.
//
//  Title, two paragraphs, one button. The X in the corner is the only way out,
//  because a second dismiss button is one more thing to read. The license paste
//  field stays folded away: it exists for the few people who already paid.
//
//  No copy lives in this file. Every string comes from `PaywallCopy`.
//

import SwiftUI
import AppKit

struct PaywallSheet: View {
    let trigger: PaywallTrigger
    let onClose: () -> Void

    @ObservedObject private var entitlement = EntitlementManager.shared
    @Environment(\.theme) private var theme

    @State private var showingKeyField = false

    private var isEntitled: Bool { entitlement.isEntitled }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    section(PaywallCopy.whyPayTitle, PaywallCopy.whyPayBody)
                    section(PaywallCopy.namePriceTitle, PaywallCopy.namePriceBody)

                    if isEntitled {
                        activeNote
                    } else {
                        subscribeSection
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .frame(width: 420, height: 460)
        .background(theme.background)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous)
                .strokeBorder(theme.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.45), radius: 24, y: 10)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(PaywallCopy.sheetTitle)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(theme.foreground)
                Text(PaywallCopy.sheetSubtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            AppIconButton(systemName: "xmark", help: "Close", action: onClose)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 22)
    }

    // MARK: Sections

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.foreground)
            Text(body)
                .font(.system(size: 12))
                .foregroundStyle(theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var activeNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 13))
                .foregroundStyle(theme.success)
            Text(PaywallCopy.activeNote)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.foregroundSoft)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var subscribeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppPrimaryButton(title: PaywallCopy.subscribeButton,
                             systemImage: "arrow.up.forward.app",
                             isDisabled: PolarConfig.checkoutURL == nil,
                             fillsWidth: true) {
                subscribe()
            }

            if PolarConfig.checkoutURL == nil {
                Text(PaywallCopy.notConfiguredNote)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.warning)
            }

            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { showingKeyField.toggle() } }) {
                HStack(spacing: 4) {
                    Text(PaywallCopy.hasKeyPrompt)
                        .font(.system(size: 11, weight: .medium))
                    Image(systemName: showingKeyField ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                }
                .foregroundStyle(theme.primary)
            }
            .buttonStyle(.plain)

            if showingKeyField {
                LicenseKeyField(layout: .stacked)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: Actions

    private func subscribe() {
        guard PolarConfig.openCheckout(trigger: trigger) else { return }
        // Checkout finishes in the browser and the key arrives by email, so open
        // the paste field now rather than making them find it on their return.
        withAnimation { showingKeyField = true }
    }
}

#Preview {
    PaywallSheet(trigger: .addAccount, onClose: {})
        .environment(\.theme, ThemeStore.shared.palette)
}
