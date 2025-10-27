import SwiftUI

struct CalendarDropdownView: View {
    @ObservedObject var dataManager = CalendarDataManager.shared

    var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider()

            if dataManager.isLoading && dataManager.events.isEmpty {
                loadingView
            } else if dataManager.events.isEmpty {
                EmptyStateView()
            } else {
                meetingListView
            }

            Divider()

            footerView
        }
        .frame(width: 350, height: 400)
        .background(.ultraThinMaterial)
    }

    private var headerView: some View {
        HStack {
            Text("Upcoming Meetings")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)

            Spacer()

            Button(action: {
                Task {
                    await dataManager.refreshEvents()
                }
            }) {
                if dataManager.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.borderless)
            .disabled(dataManager.isLoading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    private var meetingListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                let todayEvents = dataManager.todayEvents()
                let tomorrowEvents = dataManager.tomorrowEvents()

                if !todayEvents.isEmpty {
                    sectionHeader(title: "Today")
                    ForEach(todayEvents) { event in
                        MeetingRowView(event: event) {
                            handleEventTap(event)
                        }
                    }
                }

                if !tomorrowEvents.isEmpty {
                    if !todayEvents.isEmpty {
                        Divider()
                            .padding(.vertical, 8)
                    }
                    sectionHeader(title: "Tomorrow")
                    ForEach(tomorrowEvents) { event in
                        MeetingRowView(event: event) {
                            handleEventTap(event)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func sectionHeader(title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 6)
    }

    private var loadingView: some View {
        VStack {
            ProgressView()
            Text("Loading meetings...")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footerView: some View {
        HStack(spacing: 12) {
            Menu {
                Button(action: {
                    addGoogleAccount()
                }) {
                    Text("Google Calendar")
                }

                Button(action: {
                    addMicrosoftAccount()
                }) {
                    Text("Microsoft Calendar")
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Add Account")
                        .font(.system(size: 12))
                }
            }
            .menuStyle(.borderlessButton)
            .foregroundColor(.secondary)

            Spacer()

            Button(action: {
                NotificationCenter.default.post(name: .settingsRequested, object: nil)
            }) {
                Text("Settings")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .foregroundColor(.secondary)

            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Text("Quit")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial)
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

        AppSettings.shared.openURL(url)
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
