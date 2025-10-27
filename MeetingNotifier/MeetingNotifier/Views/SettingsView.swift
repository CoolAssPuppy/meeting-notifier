import SwiftUI

struct SettingsView: View {
    @State private var selectedTab = 0
    @State private var showingConfig = false

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
        .sheet(isPresented: $showingConfig) {
            ConfigTab()
                .frame(width: 500, height: 400)
        }
    }

    private var headerBar: some View {
        HStack {
            Text("MeetingNotifier Settings")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            Button(action: {
                showingConfig = true
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Configuration")
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
