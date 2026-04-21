//
//  Sidebar.swift
//  MeetingNotifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import SwiftUI

struct Sidebar: View {
    @Binding var selectedEmail: String?

    @ObservedObject private var appSettings = AppSettings.shared
    @ObservedObject private var drawerState = DrawerState.shared
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.top, 2)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)

            sectionLabel
                .padding(.horizontal, 18)
                .padding(.bottom, 8)

            accountList

            footer
        }
        .frame(maxHeight: .infinity)
        .background(theme.surface)
        .overlay(alignment: .trailing) {
            Rectangle().fill(theme.divider).frame(width: 1)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            BrandMark(size: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text("Meeting Notifier")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.foreground)
                Text(appVersionLine)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.tertiary)
            }
            Spacer(minLength: 0)
        }
    }

    private var appVersionLine: String {
        "v\(Bundle.main.appVersionString)"
    }

    private var sectionLabel: some View {
        HStack {
            AppSectionLabel(text: "Accounts")
            Spacer()
        }
    }

    private var accountList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(appSettings.accounts) { account in
                    SidebarAccountRow(
                        account: account,
                        isSelected: selectedEmail == account.email,
                        onTap: { selectedEmail = account.email }
                    )
                }
            }
            .padding(.horizontal, 10)
        }
        .frame(maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: AppSpacing.sm) {
            AppSecondaryButton(title: "Add account", systemImage: "plus", tint: .foreground) {
                showAddAccountMenu()
            }
            .frame(maxWidth: .infinity)

            AppIconButton(systemName: "gearshape", help: "Settings",
                          isActive: drawerState.openDrawer == .settings) {
                drawerState.open(.settings)
            }
            AppIconButton(systemName: "waveform", help: "Transcription",
                          isActive: drawerState.openDrawer == .transcription) {
                drawerState.open(.transcription)
            }
        }
        .padding(12)
        .overlay(alignment: .top) {
            Rectangle().fill(theme.divider).frame(height: 1)
        }
    }

    private func showAddAccountMenu() {
        let menu = NSMenu()
        let googleItem = NSMenuItem(title: "Add Google account", action: nil, keyEquivalent: "")
        googleItem.target = nil
        googleItem.action = #selector(AppDelegate.addGoogleAccount)
        let msItem = NSMenuItem(title: "Add Microsoft account", action: nil, keyEquivalent: "")
        msItem.target = nil
        msItem.action = #selector(AppDelegate.addMicrosoftAccount)
        menu.items = [googleItem, msItem]
        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: NSApp.keyWindow?.contentView ?? NSView())
        }
    }
}

// MARK: - Sidebar row

private struct SidebarAccountRow: View {
    let account: CalendarAccount
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.theme) private var theme
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                ProviderBadge(provider: account.provider, size: 22, dimmed: !account.isEnabled)

                VStack(alignment: .leading, spacing: 1) {
                    Text(account.displayName)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? theme.foreground : theme.foregroundSoft)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(theme.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                trailing
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .strokeBorder(borderColor, lineWidth: isSelected ? 1 : 0)
            )
            .opacity(account.isEnabled ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var subtitle: String {
        let count = account.selectedCalendarIds.count
        return "\(account.providerName) · \(count) calendar\(count == 1 ? "" : "s")"
    }

    @ViewBuilder
    private var trailing: some View {
        if !account.isEnabled {
            AppStatusPill(text: "OFF", style: .neutral)
        } else if account.authStatus != .valid {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(theme.destructive)
        }
    }

    private var backgroundColor: Color {
        if isSelected { return theme.primary.opacity(0.10) }
        if isHovered { return theme.foreground.opacity(0.02) }
        return .clear
    }

    private var borderColor: Color {
        isSelected ? theme.primary.opacity(0.25) : .clear
    }
}
