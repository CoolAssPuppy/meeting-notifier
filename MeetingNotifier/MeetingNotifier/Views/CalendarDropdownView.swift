import SwiftUI

struct CalendarDropdownView: View {
    @ObservedObject var dataManager = CalendarDataManager.shared
    @State private var isRefreshing = false

    var body: some View {
        ZStack {
            // Background with depth
            backgroundGradient

            VStack(spacing: 0) {
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

                if dataManager.isLoading && dataManager.events.isEmpty {
                    loadingView
                } else if dataManager.events.isEmpty {
                    EmptyStateView()
                } else {
                    meetingListView
                }

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
        .frame(width: 380, height: 500)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        .overlay(
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
        )
    }

    private var backgroundGradient: some View {
        ZStack {
            // Base material
            Rectangle()
                .fill(.ultraThinMaterial)

            // Subtle gradient overlay
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
                        .scaleEffect(0.8)
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
                    sectionHeader(title: "Today", count: todayEvents.count)
                    ForEach(todayEvents) { event in
                        MeetingRowView(event: event) {
                            handleEventTap(event)
                        }
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .opacity),
                            removal: .scale(scale: 0.95).combined(with: .opacity)
                        ))
                    }
                }

                if !tomorrowEvents.isEmpty {
                    if !todayEvents.isEmpty {
                        Spacer()
                            .frame(height: 16)
                    }
                    sectionHeader(title: "Tomorrow", count: tomorrowEvents.count)
                    ForEach(tomorrowEvents) { event in
                        MeetingRowView(event: event) {
                            handleEventTap(event)
                        }
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .opacity),
                            removal: .scale(scale: 0.95).combined(with: .opacity)
                        ))
                    }
                }
            }
            .padding(.vertical, 12)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: dataManager.events.count)
        }
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
            .regularMaterial,
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
}

struct CalendarDropdownView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarDropdownView()
    }
}
