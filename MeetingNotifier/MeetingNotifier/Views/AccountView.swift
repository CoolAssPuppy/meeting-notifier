//
//  AccountView.swift
//  MeetingNotifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import SwiftUI

struct AccountView: View {
    let account: CalendarAccount

    @ObservedObject private var appSettings = AppSettings.shared
    @Environment(\.theme) private var theme

    @State private var calendars: [CalendarInfo] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 28)
                .padding(.top, 8)
                .padding(.bottom, 20)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(theme.divider).frame(height: 1)
                }

            ScrollView(showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 14) {
                        identityCard
                        calendarsCard
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 14) {
                        notificationsCard
                        managementCard
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 28)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            Task { await loadCalendars() }
        }
        .onChange(of: account.email) { _, _ in
            Task { await loadCalendars() }
        }
    }

    /// Binding that writes straight through to the account's friendlyName
    /// without an intermediate @State draft.
    private var friendlyNameBinding: Binding<String> {
        Binding(
            get: { account.friendlyName ?? "" },
            set: { newValue in
                var updated = account
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                updated.friendlyName = trimmed.isEmpty ? nil : trimmed
                appSettings.updateAccount(updated)
            }
        )
    }

    private func loadCalendars() async {
        let fetched = await CalendarDataManager.shared.fetchCalendarsForAccount(account)
        await MainActor.run { self.calendars = fetched }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: AppSpacing.xl) {
            ProviderBadge(provider: account.provider, size: 44, dimmed: !account.isEnabled)

            VStack(alignment: .leading, spacing: 4) {
                Text(account.displayName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.foreground)
                metaRow
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                AppIconButton(systemName: "arrow.clockwise", help: "Refresh", spinOnTap: true) {
                    Task { await CalendarDataManager.shared.refreshEvents() }
                }
                AppIconButton(systemName: "arrow.up.right.square", help: "Open provider") {
                    let url = account.provider == .google
                        ? URL(string: "https://calendar.google.com")!
                        : URL(string: "https://outlook.office.com/calendar")!
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    private var metaRow: some View {
        HStack(spacing: 8) {
            Text(account.providerName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.muted)
            dot
            HStack(spacing: 4) {
                Circle().fill(statusColor).frame(width: 6, height: 6)
                Text(statusText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(statusColor)
            }
            if let last = CalendarDataManager.shared.lastRefreshDate {
                dot
                Text("Synced \(last.shortTimeString)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.tertiary)
            }
        }
    }

    private var dot: some View {
        Circle().fill(theme.tertiary).frame(width: 3, height: 3)
    }

    private var statusColor: Color {
        switch account.authStatus {
        case .valid: return theme.success
        case .expired, .needsAuth: return theme.warning
        case .revoked: return theme.destructive
        }
    }

    private var statusText: String {
        switch account.authStatus {
        case .valid: return "Connected"
        case .expired: return "Expired"
        case .needsAuth: return "Needs authentication"
        case .revoked: return "Access revoked"
        }
    }

    // MARK: - Identity card

    private var identityCard: some View {
        AppCard("Identity") {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Display name")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(theme.muted)
                    TextField("e.g. Work", text: friendlyNameBinding)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(theme.foreground)
                        .appInsetField()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("\(account.providerName) account")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(theme.muted)
                    Text(account.email)
                        .font(.system(size: 12, design: .monospaced).weight(.medium))
                        .foregroundStyle(theme.foregroundSoft)
                        .textSelection(.enabled)
                }
            }
        }
    }

    // MARK: - Calendars card

    private var calendarsCard: some View {
        let selected = account.selectedCalendarIds

        return AppCard("Calendars", trailing: {
            Text("\(selected.count) of \(calendars.count) enabled")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(theme.tertiary)
        }, content: {
            LazyVStack(alignment: .leading, spacing: 0) {
                if calendars.isEmpty {
                    Text("No calendars available yet. Refresh to load them.")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.muted)
                        .padding(.vertical, 8)
                } else {
                    ForEach(Array(calendars.enumerated()), id: \.element.id) { index, calendar in
                        CalendarToggleRow(
                            calendar: calendar,
                            isEnabled: selected.contains(calendar.id),
                            onToggle: { toggle(calendar: calendar) }
                        )
                        if index < calendars.count - 1 {
                            AppRowDivider()
                                .padding(.vertical, 8)
                        }
                    }
                }
            }
        })
    }

    private func toggle(calendar: CalendarInfo) {
        var updated = account
        if updated.selectedCalendarIds.contains(calendar.id) {
            updated.selectedCalendarIds.remove(calendar.id)
        } else {
            updated.selectedCalendarIds.insert(calendar.id)
        }
        appSettings.updateAccount(updated)
    }

    // MARK: - Notifications card

    private var notificationsCard: some View {
        AppCard("Notifications") {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                AppSettingRow("Notifications enabled",
                              description: "Ping before meetings start") {
                    Toggle("", isOn: bindingForNotifications).toggleStyle(.switch).labelsHidden().tint(theme.primary)
                }
                AppRowDivider()
                AppSettingRow("One-minute warning",
                              description: "Also ping 60 seconds before start") {
                    Toggle("", isOn: $appSettings.oneMinuteWarningEnabled).toggleStyle(.switch).labelsHidden().tint(theme.primary)
                }
                AppRowDivider()
                AppSettingRow("Only meetings with attendees",
                              description: "Skip solo holds and focus blocks") {
                    Toggle("", isOn: $appSettings.onlyShowMeetingsWithAttendees).toggleStyle(.switch).labelsHidden().tint(theme.primary)
                }
            }
        }
    }

    private var bindingForNotifications: Binding<Bool> {
        Binding(
            get: { appSettings.notificationsEnabled },
            set: { appSettings.notificationsEnabled = $0 }
        )
    }

    // MARK: - Management card

    private var managementCard: some View {
        AppCard("Account management") {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                AppSettingRow("Sync this account",
                              description: "Fetch new events every 5 minutes") {
                    Toggle("", isOn: bindingForEnabled).toggleStyle(.switch).labelsHidden().tint(theme.primary)
                }
                AppRowDivider()
                AppSettingRow("Reauthorize",
                              description: "Refresh the provider's permission grant") {
                    AppSecondaryButton(title: "Reauthorize", systemImage: "arrow.clockwise") {
                        AppDelegate.shared?.reauthorizeAccount(account)
                    }
                }
                AppRowDivider()
                HStack(alignment: .center, spacing: AppSpacing.lg) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Remove account")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(theme.destructive)
                        Text("Disconnects the provider and deletes local tokens")
                            .font(.system(size: 11))
                            .foregroundStyle(theme.muted)
                    }
                    Spacer(minLength: AppSpacing.md)
                    AppSecondaryButton(title: "Remove",
                                       systemImage: "trash",
                                       tint: .destructive) {
                        appSettings.removeAccount(account)
                    }
                }
            }
        }
    }

    private var bindingForEnabled: Binding<Bool> {
        Binding(
            get: { account.isEnabled },
            set: { newValue in
                var updated = account
                updated.isEnabled = newValue
                appSettings.updateAccount(updated)
            }
        )
    }
}

// MARK: - Calendar toggle row

private struct CalendarToggleRow: View {
    let calendar: CalendarInfo
    let isEnabled: Bool
    let onToggle: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(nsColor: calendar.color))
                .frame(width: 14, height: 14)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(calendar.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.foreground)
                    .lineLimit(1)
                if calendar.isPrimary {
                    Text("Primary")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(theme.tertiary)
                }
            }

            Spacer(minLength: AppSpacing.md)

            Toggle("", isOn: Binding(get: { isEnabled }, set: { _ in onToggle() }))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
                .tint(theme.primary)
        }
        .padding(.vertical, 2)
    }
}
