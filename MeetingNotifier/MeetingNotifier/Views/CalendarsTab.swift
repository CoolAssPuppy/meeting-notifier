import SwiftUI

struct CalendarsTab: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var calendars: [String: [CalendarInfo]] = [:]
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select Calendars")
                .font(.headline)

            if settings.accounts.isEmpty {
                emptyStateView
            } else if isLoading {
                loadingView
            } else {
                calendarListView
            }

            Spacer()
        }
        .padding(20)
        .onAppear {
            loadCalendars()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No accounts connected")
                .font(.headline)

            Text("Add an account to see your calendars")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading calendars...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var calendarListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(settings.accounts) { account in
                    accountSection(account)
                }
            }
        }
    }

    private func accountSection(_ account: CalendarAccount) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let icon = account.provider.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: account.provider == .google ? "g.circle.fill" : "cloud.fill")
                        .font(.system(size: 16))
                        .foregroundColor(account.provider == .google ? .red : .blue)
                }

                Text(account.email)
                    .font(.system(size: 13, weight: .medium))
            }

            if let accountCalendars = calendars[account.email] {
                ForEach(accountCalendars) { calendar in
                    calendarRow(calendar, account: account)
                }
            }

            Divider()
        }
    }

    private func calendarRow(_ calendar: CalendarInfo, account: CalendarAccount) -> some View {
        Toggle(isOn: binding(for: calendar.id, account: account)) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: calendar.colorHex))
                    .frame(width: 12, height: 12)

                Text(calendar.name)
                    .font(.body)
            }
        }
        .padding(.leading, 8)
    }

    private func binding(for calendarId: String, account: CalendarAccount) -> Binding<Bool> {
        Binding(
            get: {
                if let acc = settings.accounts.first(where: { $0.id == account.id }) {
                    return acc.selectedCalendarIds.contains(calendarId)
                }
                return false
            },
            set: { isSelected in
                if let index = settings.accounts.firstIndex(where: { $0.id == account.id }) {
                    var updatedAccount = settings.accounts[index]
                    if isSelected {
                        updatedAccount.selectedCalendarIds.insert(calendarId)
                    } else {
                        updatedAccount.selectedCalendarIds.remove(calendarId)
                    }
                    settings.updateAccount(updatedAccount)
                }
            }
        )
    }

    private func loadCalendars() {
        isLoading = true

        Task {
            var loadedCalendars: [String: [CalendarInfo]] = [:]

            for account in settings.accounts {
                let accountCalendars = await CalendarDataManager.shared.fetchCalendarsForAccount(account)
                loadedCalendars[account.email] = accountCalendars
            }

            await MainActor.run {
                calendars = loadedCalendars
                isLoading = false
            }
        }
    }
}

struct CalendarsTab_Previews: PreviewProvider {
    static var previews: some View {
        CalendarsTab()
            .frame(width: 500, height: 600)
    }
}
