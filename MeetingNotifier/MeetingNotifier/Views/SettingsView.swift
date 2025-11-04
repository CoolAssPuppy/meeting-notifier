import SwiftUI

struct SettingsView: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            Divider()

            TabView(selection: $selectedTab) {
                AccountsTab()
                    .tabItem {
                        Label("Accounts", systemImage: "person.crop.circle")
                    }
                    .tag(0)
                    .accessibilityIdentifier("accountsTab")

                CalendarsTab()
                    .tabItem {
                        Label("Calendars", systemImage: "calendar")
                    }
                    .tag(1)
                    .accessibilityIdentifier("calendarsTab")

                ConfigTab()
                    .tabItem {
                        Label("Setup", systemImage: "gearshape")
                    }
                    .tag(2)
                    .accessibilityIdentifier("setupTab")
            }
            .accessibilityIdentifier("settingsTabView")
        }
        .background(.ultraThinMaterial)
        .frame(width: 500, height: 600)
    }

    private var headerBar: some View {
        HStack {
            Text("MeetingNotifier Settings")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()
        }
        .padding()
        .background(.regularMaterial)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
