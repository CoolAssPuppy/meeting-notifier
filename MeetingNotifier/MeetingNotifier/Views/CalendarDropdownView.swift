import SwiftUI

struct CalendarDropdownView: View {
    @ObservedObject var dataManager = CalendarDataManager.shared
    @ObservedObject var appSettings = AppSettings.shared
    @State private var isRefreshing = false

    var body: some View {
        ZStack {
            // Background with depth
            backgroundGradient

            VStack(spacing: 0) {
                if appSettings.dropDownStyle == .simple {
                    simpleHeaderView
                } else {
                    headerView

                    // Subtle separator
                    LinearGradient(
                        colors: [
                            Color.primary.opacity(0.1),
                            Color.primary.opacity(0.05)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 1)
                }

                // Auth error banner
                if hasAuthErrors {
                    if appSettings.dropDownStyle == .simple {
                        simpleAuthErrorBanner
                    } else {
                        authErrorBanner
                    }
                }

                if dataManager.isLoading && dataManager.events.isEmpty {
                    if appSettings.dropDownStyle == .simple {
                        simpleLoadingView
                    } else {
                        loadingView
                    }
                } else if dataManager.events.isEmpty {
                    EmptyStateView()
                } else {
                    meetingListView
                }

                if appSettings.dropDownStyle == .simple {
                    Divider()
                    simpleFooterView
                } else {
                    // Bottom separator
                    LinearGradient(
                        colors: [
                            Color.primary.opacity(0.05),
                            Color.primary.opacity(0.1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 1)

                    footerView
                }
            }
        }
        .frame(width: appSettings.dropDownStyle == .simple ? 320 : 380, height: appSettings.dropDownStyle == .simple ? 400 : 500)
        .clipShape(RoundedRectangle(cornerRadius: appSettings.dropDownStyle == .simple ? 10 : 16))
        .shadow(color: Color.black.opacity(appSettings.dropDownStyle == .simple ? 0.15 : 0.2), radius: appSettings.dropDownStyle == .simple ? 10 : 20, x: 0, y: appSettings.dropDownStyle == .simple ? 4 : 10)
        .overlay(
            Group {
                if appSettings.dropDownStyle == .simple {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
            }
        )
    }

    private var hasAuthErrors: Bool {
        appSettings.accounts.contains { $0.authStatus != .valid }
    }

    private var authErrorAccountEmails: [String] {
        appSettings.accounts.filter { $0.authStatus != .valid }.map { $0.email }
    }

    private var authErrorBanner: some View {
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
                            Text("• \(account.email)")
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
                            Text("• \(account.email)")
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

    private var backgroundGradient: some View {
        ZStack {
            if appSettings.dropDownStyle == .simple {
                // Simple style: native macOS menu background
                Rectangle()
                    .fill(.regularMaterial)
            } else {
                // Glass style: glassmorphic effect
                Rectangle()
                    .fill(.ultraThinMaterial)

                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.03),
                        Color.clear,
                        Color.purple.opacity(0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private var headerView: some View {
        HStack(spacing: 12) {
            // App icon with glow
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

            // Refresh button with animation
            refreshButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 0)
        )
    }

    private var refreshButton: some View {
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

    private var currentDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }

    private var meetingListView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                let todayEvents = dataManager.todayEvents()
                let tomorrowEvents = dataManager.tomorrowEvents()

                if !todayEvents.isEmpty {
                    if appSettings.dropDownStyle == .simple {
                        simpleSectionHeader(title: "Today")
                    } else {
                        sectionHeader(title: "Today", count: todayEvents.count)
                    }
                    ForEach(todayEvents) { event in
                        meetingRow(for: event)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.95).combined(with: .opacity),
                                removal: .scale(scale: 0.95).combined(with: .opacity)
                            ))
                    }
                }

                if !tomorrowEvents.isEmpty {
                    if !todayEvents.isEmpty {
                        Spacer()
                            .frame(height: appSettings.dropDownStyle == .simple ? 8 : 16)
                    }
                    if appSettings.dropDownStyle == .simple {
                        simpleSectionHeader(title: "Tomorrow")
                    } else {
                        sectionHeader(title: "Tomorrow", count: tomorrowEvents.count)
                    }
                    ForEach(tomorrowEvents) { event in
                        meetingRow(for: event)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.95).combined(with: .opacity),
                                removal: .scale(scale: 0.95).combined(with: .opacity)
                            ))
                    }
                }
            }
            .padding(.vertical, appSettings.dropDownStyle == .simple ? 8 : 12)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: dataManager.events.count)
        }
    }

    @ViewBuilder
    private func meetingRow(for event: CalendarEvent) -> some View {
        if appSettings.dropDownStyle == .simple {
            SimpleMeetingRowView(event: event) {
                handleEventTap(event)
            }
        } else {
            MeetingRowView(event: event) {
                handleEventTap(event)
            }
        }
    }

    private func simpleSectionHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // MARK: - Simple Style Views

    private var simpleHeaderView: some View {
        EmptyView()
    }

    private var simpleAuthErrorBanner: some View {
        Button(action: {
            NotificationCenter.default.post(name: .settingsRequested, object: nil)
        }) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)

                Text("Authentication required")
                    .font(.system(size: 13))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.1))
        }
        .buttonStyle(.plain)
    }

    private var simpleLoadingView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)

            Text("Loading...")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var simpleFooterView: some View {
        VStack(spacing: 0) {
            // Settings
            simpleMenuButton(title: "Settings", icon: "gearshape") {
                NotificationCenter.default.post(name: .settingsRequested, object: nil)
            }

            Divider()

            // Quit
            simpleMenuButton(title: "Quit", icon: "power") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func simpleMenuButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        SimpleMenuButton(title: title, icon: icon, action: action)
    }

    private func sectionHeader(title: String, count: Int) -> some View {
        HStack(spacing: 8) {
            // Section icon
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

            // Count badge
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

    private var loadingView: some View {
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

    private var footerView: some View {
        HStack(spacing: 10) {
            // Add Account button with icon
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

            // Settings button
            footerButton(
                icon: "gearshape.fill",
                title: "Settings",
                gradient: [.blue, .cyan]
            ) {
                NotificationCenter.default.post(name: .settingsRequested, object: nil)
            }
            .accessibilityIdentifier("settingsButton")

            // Quit button
            footerButton(
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

    private func footerButton(icon: String, title: String, gradient: [Color], action: @escaping () -> Void) -> some View {
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

    private func addGoogleAccount() {
        NotificationCenter.default.post(
            name: .addAccountRequested,
            object: nil,
            userInfo: ["provider": "google"]
        )
    }

    private func addMicrosoftAccount() {
        NotificationCenter.default.post(
            name: .addAccountRequested,
            object: nil,
            userInfo: ["provider": "microsoft"]
        )
    }

    private func handleEventTap(_ event: CalendarEvent) {
        guard let conferenceLink = event.conferenceLink,
              let url = URL(string: conferenceLink) else {
            return
        }

        AppSettings.shared.openURL(url, accountEmail: event.accountEmail)
    }
}

extension Notification.Name {
    static let addAccountRequested = Notification.Name("addAccountRequested")
    static let settingsRequested = Notification.Name("settingsRequested")
    static let accountsDidUpdate = Notification.Name("accountsDidUpdate")
}

struct SimpleMenuButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(isHovered ? .white.opacity(0.7) : .secondary)
                    .frame(width: 16)

                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(isHovered ? .white : .primary)

                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? Color.accentColor : Color.clear)
            )
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct CalendarDropdownView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarDropdownView()
    }
}
