//
//  LicenseKeyField.swift
//  MeetingNotifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//
//  Paste a license key and activate it. Both places that offer this (the paywall
//  sheet and the Settings subscription card) had their own copy of the field,
//  the button, the error line, and the activation call, differing only in
//  layout. One divergent copy of "what happens when activation fails" is one too
//  many, so it lives here.
//
//  Copy comes from `PaywallCopy`.
//

import SwiftUI

struct LicenseKeyField: View {
    /// How the field and its button sit together. The paywall sheet has a full
    /// column to work with; the Settings card has one cramped row.
    enum Layout {
        /// Field on its own line, button below it. The paywall sheet has a
        /// column to spend.
        case stacked
        /// Field and button side by side, for the cramped Settings row.
        case inline
    }

    var layout: Layout = .stacked
    /// Called after a key activates. The Settings card folds the field away
    /// again; the paywall sheet leaves it open so the success note replaces it.
    var onActivated: () -> Void = {}

    @Environment(\.theme) private var theme

    @State private var licenseKey = ""
    @State private var isActivating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(PaywallCopy.keyLocationHint)
                .font(.system(size: 10))
                .foregroundStyle(theme.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            switch layout {
            case .stacked:
                textField
                HStack {
                    errorText
                    Spacer(minLength: 8)
                    activateButton
                }
            case .inline:
                HStack(spacing: 6) {
                    textField
                    activateButton
                }
                errorText
            }
        }
    }

    // MARK: Pieces

    private var textField: some View {
        // `appInsetField()` is the chrome every other text input in the app
        // uses. Hand-rolling it here made this the one field with a heavier
        // border, for no stated reason.
        TextField(PaywallCopy.keyFieldPlaceholder, text: $licenseKey)
            .textFieldStyle(.plain)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(theme.foreground)
            .appInsetField()
            .onSubmit(activate)
    }

    private var activateButton: some View {
        AppPrimaryButton(title: isActivating ? "Activating…" : "Activate",
                         isDisabled: trimmedKey.isEmpty || isActivating,
                         action: activate)
    }

    @ViewBuilder
    private var errorText: some View {
        if let errorMessage {
            Text(errorMessage)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(theme.destructive)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Behavior

    private var trimmedKey: String {
        licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func activate() {
        let key = trimmedKey
        guard !key.isEmpty, !isActivating else { return }
        isActivating = true
        errorMessage = nil
        Task {
            do {
                try await EntitlementManager.shared.activate(key: key)
                isActivating = false
                licenseKey = ""
                Telemetry.capture(.licenseActivated)
                onActivated()
            } catch {
                isActivating = false
                errorMessage = error.userMessage
                Telemetry.capture(.licenseActivationFailed,
                                  properties: ["reason": Self.failureReason(for: error)])
            }
        }
    }

    /// A coarse, non-identifying label for why an activation failed. The key
    /// itself never goes near telemetry.
    static func failureReason(for error: Error) -> String {
        switch error {
        case let licenseError as LicenseError:
            switch licenseError {
            case .notConfigured:           return "not_configured"
            case .invalidKey:              return "invalid_key"
            case .wrongProduct:            return "wrong_product"
            case .activationLimitReached:  return "activation_limit"
            case .requestFailed:           return "request_failed"
            case .invalidResponse:         return "invalid_response"
            }
        case is URLError:
            return "network"
        default:
            return "unknown"
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        LicenseKeyField(layout: .stacked)
        LicenseKeyField(layout: .inline)
    }
    .frame(width: 360)
    .padding()
    .environment(\.theme, ThemeStore.shared.palette)
}
