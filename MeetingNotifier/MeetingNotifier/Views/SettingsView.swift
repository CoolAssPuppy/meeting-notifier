import SwiftUI

struct SettingsView: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            tabBar

            Divider()

            TabView(selection: $selectedTab) {
                AccountsTab()
                    .tabItem {
                        Label("Accounts", systemImage: "person.crop.circle")
                    }
                    .tag(0)

                CalendarsTab()
                    .tabItem {
                        Label("Calendars", systemImage: "calendar")
                    }
                    .tag(1)

                NotificationsTab()
                    .tabItem {
                        Label("Notifications", systemImage: "bell")
                    }
                    .tag(2)
            }
        }
        .frame(width: 500, height: 600)
    }

    private var tabBar: some View {
        HStack {
            Text("MeetingNotifier Settings")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
