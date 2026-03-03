//
//  CalendarDropdownView+GlassStyle.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import SwiftUI

// MARK: - Glass style views

extension CalendarDropdownView {
    var glassAuthErrorBanner: some View {
        let needsAuthAccounts = appSettings.accounts.filter { $0.authStatus == .needsAuth }
        let expiredAccounts = appSettings.accounts.filter { $0.authStatus == .expired || $0.authStatus == .revoked }

        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Authentication Required")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)

                    if !needsAuthAccounts.isEmpty {
                        Text("Sign in on this device:")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)

                        ForEach(needsAuthAccounts, id: \.email) { account in
                            Text("\u{2022} \(account.email)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }

                    if !expiredAccounts.isEmpty {
                        Text(needsAuthAccounts.isEmpty ? "Calendar access has expired:" : "Access also expired:")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.top, needsAuthAccounts.isEmpty ? 0 : 4)

                        ForEach(expiredAccounts, id: \.email) { account in
                            Text("\u{2022} \(account.email)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()
            }

            Button(action: {
                NotificationCenter.default.post(name: .settingsRequested, object: nil)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Open Settings to Reconnect")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    var glassHeaderView: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(0.2),
                                Color.purple.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .blur(radius: 8)

                Circle()
                    .fill(.regularMaterial)
                    .frame(width: 32, height: 32)

                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Upcoming Meetings")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text(currentDateString)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Spacer()

            glassRefreshButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 0)
        )
    }

    var glassRefreshButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                isRefreshing = true
            }
            Task {
                await dataManager.refreshEvents()
                try? await Task.sleep(nanoseconds: 500_000_000)
                withAnimation {
                    isRefreshing = false
                }
            }
        }) {
            ZStack {
                Circle()
                    .fill(.regularMaterial)
                    .frame(width: 32, height: 32)

                if dataManager.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                }
            }
            .overlay(
                Circle()
                    .strokeBorder(Color.blue.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(dataManager.isLoading)
    }

    var currentDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }

    func glassSectionHeader(title: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: title == "Today" ? "sun.max.fill" : "moon.stars.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: title == "Today" ? [.orange, .yellow] : [.indigo, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .textCase(.uppercase)
                .tracking(1)

            Text("\(count)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: title == "Today" ? [.orange, .red] : [.indigo, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            .thinMaterial,
            in: RoundedRectangle(cornerRadius: 0)
        )
    }

    var glassLoadingView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.accentColor.opacity(0.2), lineWidth: 3)
                    .frame(width: 40, height: 40)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))
                    .animation(
                        .linear(duration: 1).repeatForever(autoreverses: false),
                        value: dataManager.isLoading
                    )
            }

            VStack(spacing: 4) {
                Text("Loading meetings")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)

                Text("Fetching your calendar events...")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var glassFooterView: some View {
        HStack(spacing: 10) {
            Menu {
                Button(action: {
                    addGoogleAccount()
                }) {
                    Label("Google Calendar", systemImage: "g.circle.fill")
                }

                Button(action: {
                    addMicrosoftAccount()
                }) {
                    Label("Microsoft Calendar", systemImage: "m.circle.fill")
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text("Add Account")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.regularMaterial)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)

            Spacer()

            glassFooterButton(
                icon: "gearshape.fill",
                title: "Settings",
                gradient: [.blue, .cyan]
            ) {
                NotificationCenter.default.post(name: .settingsRequested, object: nil)
            }
            .accessibilityIdentifier("settingsButton")

            glassFooterButton(
                icon: "power",
                title: "Quit",
                gradient: [.red, .orange]
            ) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            .thinMaterial,
            in: RoundedRectangle(cornerRadius: 0)
        )
    }

    func glassFooterButton(icon: String, title: String, gradient: [Color], action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    func addGoogleAccount() {
        NotificationCenter.default.post(
            name: .addAccountRequested,
            object: nil,
            userInfo: ["provider": "google"]
        )
    }

    func addMicrosoftAccount() {
        NotificationCenter.default.post(
            name: .addAccountRequested,
            object: nil,
            userInfo: ["provider": "microsoft"]
        )
    }
}
