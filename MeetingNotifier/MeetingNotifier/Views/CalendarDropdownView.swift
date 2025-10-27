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
    }

    private var headerView: some View {
        HStack {
            Text("Upcoming meetings")
                .font(.headline)

            Spacer()

            Button(action: {
                Task {
                    await dataManager.refreshEvents()
                }
            }) {
                if dataManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(dataManager.isLoading)
        }
        .padding(12)
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
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
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
            Button("Add Account") {
                NotificationCenter.default.post(name: .addAccountRequested, object: nil)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.blue)

            Spacer()

            Button("Settings") {
                NotificationCenter.default.post(name: .settingsRequested, object: nil)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.blue)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.blue)
        }
        .font(.system(size: 12))
        .padding(12)
    }

    private func handleEventTap(_ event: CalendarEvent) {
        guard let conferenceLink = event.conferenceLink,
              let url = URL(string: conferenceLink) else {
            return
        }

        NSWorkspace.shared.open(url)
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
