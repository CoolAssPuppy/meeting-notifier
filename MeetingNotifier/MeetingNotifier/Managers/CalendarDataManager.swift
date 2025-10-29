import Foundation
import Combine

@MainActor
class CalendarDataManager: ObservableObject {
    static let shared = CalendarDataManager()

    @Published var events: [CalendarEvent] = []
    @Published var isLoading = false
    @Published var lastRefreshDate: Date?
    @Published var errorMessage: String?

    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        startAutoRefresh()
        observeAccountChanges()
    }

    func startAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshEvents()
            }
        }

        Task {
            await refreshEvents()
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func observeAccountChanges() {
        AppSettings.shared.$accounts
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.refreshEvents()
                }
            }
            .store(in: &cancellables)
    }

    func refreshEvents() async {
        isLoading = true
        errorMessage = nil

        do {
            let accounts = AppSettings.shared.accounts.filter { $0.isEnabled }
            var allEvents: [CalendarEvent] = []

            for account in accounts {
                let calendars = await fetchCalendarsForAccount(account)
                let selectedCalendars = calendars.filter { account.selectedCalendarIds.contains($0.id) }

                for calendar in selectedCalendars {
                    let events = try await fetchEventsForCalendar(calendar, account: account)
                    allEvents.append(contentsOf: events)
                }
            }

            let now = Date()
            let calendar = Calendar.current
            let endOfToday = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now

            let hour = calendar.component(.hour, from: now)
            let shouldIncludeTomorrow = hour >= 17

            let filteredEvents = allEvents.filter { event in
                if event.startDate >= now && event.startDate <= endOfToday {
                    return true
                }

                if shouldIncludeTomorrow {
                    let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
                    let endOfTomorrow = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: startOfTomorrow) ?? now
                    return event.startDate >= startOfTomorrow && event.startDate <= endOfTomorrow
                }

                return false
            }

            events = filteredEvents.sorted { $0.startDate < $1.startDate }
            lastRefreshDate = Date()

        } catch {
            errorMessage = error.localizedDescription
            print("Error refreshing events: \(error)")
        }

        isLoading = false
    }

    func fetchCalendarsForAccount(_ account: CalendarAccount) async -> [CalendarInfo] {
        do {
            var calendars: [CalendarInfo]
            switch account.provider {
            case .google:
                calendars = try await GoogleCalendarManager.shared.fetchCalendarList(forAccount: account)
            case .microsoft:
                calendars = try await MicrosoftCalendarManager.shared.fetchCalendarList(forAccount: account)
            }

            // Apply custom colors if available
            return calendars.map { calendar in
                if let customColor = AppSettings.shared.getCustomColor(forCalendar: calendar.id, account: account.email) {
                    var updatedCalendar = calendar
                    updatedCalendar.colorHex = customColor
                    return updatedCalendar
                }
                return calendar
            }
        } catch {
            print("Error fetching calendars for \(account.email): \(error)")
            return []
        }
    }

    private func fetchEventsForCalendar(_ calendarInfo: CalendarInfo, account: CalendarAccount) async throws -> [CalendarEvent] {
        let now = Date()
        let calendar = Calendar.current

        let endOfToday = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now

        let hour = calendar.component(.hour, from: now)
        let shouldIncludeTomorrow = hour >= 17

        let endDate: Date
        if shouldIncludeTomorrow {
            let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
            endDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: startOfTomorrow) ?? now
        } else {
            endDate = endOfToday
        }

        switch account.provider {
        case .google:
            return try await GoogleCalendarManager.shared.fetchEvents(
                forCalendar: calendarInfo.id,
                account: account,
                startDate: now,
                endDate: endDate
            )
        case .microsoft:
            return try await MicrosoftCalendarManager.shared.fetchEvents(
                forCalendar: calendarInfo.id,
                account: account,
                startDate: now,
                endDate: endDate
            )
        }
    }

    func nextMeetingWithin(minutes: Int) -> CalendarEvent? {
        let now = Date()
        let threshold = now.addingTimeInterval(TimeInterval(minutes * 60))

        return events.first { event in
            event.startDate >= now && event.startDate <= threshold
        }
    }

    func todayEvents() -> [CalendarEvent] {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let endOfToday = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now

        return events.filter { event in
            event.startDate >= startOfToday && event.startDate <= endOfToday
        }
    }

    func tomorrowEvents() -> [CalendarEvent] {
        let calendar = Calendar.current
        let now = Date()
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let endOfTomorrow = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: startOfTomorrow) ?? now

        return events.filter { event in
            event.startDate >= startOfTomorrow && event.startDate <= endOfTomorrow
        }
    }
}
