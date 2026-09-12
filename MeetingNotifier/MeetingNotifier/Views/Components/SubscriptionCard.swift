//
//  SubscriptionCard.swift
//  MeetingNotifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//
//  The Settings home for the paid multi-account plan: what state the
//  subscription is in, how to start one, how to manage it, and how to move a
//  license between Macs. Its own file because `SettingsDrawer` is already long
//  and this is a self-contained concern.
//
//  Copy comes from `PaywallCopy`, same as the paywall sheet.
//

import SwiftUI
import AppKit

struct SubscriptionCard: View {
    @ObservedObject private var entitlement = EntitlementManager.shared
    @Environment(\.theme) private var theme

    @State private var removing = false
    @State private var showingKeyField = false

    var body: some View {
        AppCard(PaywallCopy.settingsCardTitle) {
            VStack(spacing: 0) {
                statusRow

                if entitlement.state != .unavailable {
                    AppRowDivider().padding(.vertical, 10)
                    actionRow
                }

                if showingKeyField {
                    AppRowDivider().padding(.vertical, 10)
                    LicenseKeyField(layout: .inline) {
                        withAnimation { showingKeyField = false }
                    }
                }

                if entitlement.hasStoredKey {
                    AppRowDivider().padding(.vertical, 10)
                    removeRow
                }
            }
        }
    }

    // MARK: Status

    private var statusRow: some View {
        HStack(spacing: 10) {
            Image(systemName: statusIcon)
                .font(.system(size: 13))
                .foregroundStyle(statusColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.foreground)
                Text(statusDescription)
                    .font(.system(size: 10))
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private var statusIcon: String {
        switch entitlement.state {
        case .active:      return "checkmark.seal.fill"
        case .lapsed:      return "exclamationmark.triangle.fill"
        case .none:        return "person.fill"
        case .unavailable: return "wrench.and.screwdriver.fill"
        }
    }

    private var statusColor: Color {
        switch entitlement.state {
        case .active:      return theme.success
        case .lapsed:      return theme.warning
        case .none:        return theme.muted
        case .unavailable: return theme.muted
        }
    }

    private var statusTitle: String {
        switch entitlement.state {
        case .active:      return PaywallCopy.settingsActiveState
        case .lapsed:      return PaywallCopy.settingsLapsedState
        case .none:        return PaywallCopy.settingsFreeState
        case .unavailable: return PaywallCopy.settingsFreeState
        }
    }

    private var statusDescription: String {
        switch entitlement.state {
        case .active:
            // A key with no expiry is the normal case for this product, so
            // "renews" only appears when Polar actually gave us a date.
            if let expiry = entitlement.expiresAt {
                return "Renews \(AppDateFormatters.longDate.string(from: expiry))."
            }
            return PaywallCopy.activeNote
        case .lapsed:      return PaywallCopy.settingsLapsedDescription
        case .none:        return PaywallCopy.settingsFreeDescription
        case .unavailable: return PaywallCopy.notConfiguredNote
        }
    }

    // MARK: Actions

    private var actionRow: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)

            if !entitlement.isEntitled {
                AppSecondaryButton(title: PaywallCopy.hasKeyPrompt) {
                    withAnimation(.easeInOut(duration: 0.15)) { showingKeyField.toggle() }
                }
                AppPrimaryButton(title: PaywallCopy.subscribeButton,
                                 systemImage: "arrow.up.forward.app",
                                 isDisabled: PolarConfig.checkoutURL == nil) {
                    subscribe()
                }
            } else if let portal = PolarConfig.portalURL {
                AppSecondaryButton(title: PaywallCopy.manageButton,
                                   systemImage: "arrow.up.forward.app") {
                    NSWorkspace.shared.open(portal)
                }
            }
        }
    }

    private var removeRow: some View {
        AppSettingRow(
            PaywallCopy.removeLicenseButton,
            description: PaywallCopy.removeLicenseDescription
        ) {
            AppSecondaryButton(title: removing ? "Removing…" : "Remove",
                               systemImage: "trash",
                               tint: .destructive) {
                remove()
            }
        }
    }

    // MARK: Behavior

    private func subscribe() {
        guard let url = PolarConfig.checkoutURL else { return }
        Telemetry.capture(.subscribeClicked, properties: ["trigger": PaywallTrigger.settings.rawValue])
        NSWorkspace.shared.open(url)
        // The key arrives by email, so open the paste field now rather than
        // making them find it again on their return.
        withAnimation { showingKeyField = true }
    }

    private func remove() {
        guard !removing else { return }
        removing = true
        Task {
            await entitlement.removeLicense()
            removing = false
            Telemetry.capture(.licenseRemoved)
        }
    }
}

#Preview {
    SubscriptionCard()
        .frame(width: 420)
        .padding()
        .environment(\.theme, ThemeStore.shared.palette)
}
