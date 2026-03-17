import SwiftUI

struct SettingsView: View {
    @State private var selectedTab = 0

    private let tabs: [(String, String)] = [
        ("Accounts", "person.crop.circle"),
        ("Calendars", "calendar"),
        ("Notes", "waveform.circle"),
        ("Setup", "gearshape"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar inside the window body
            HStack(spacing: 1) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                    Button(action: { selectedTab = index }) {
                        Label(tab.0, systemImage: tab.1)
                            .font(.system(size: 12))
                            .padding(.vertical, 6)
                            .padding(.horizontal, 14)
                    }
                    .buttonStyle(TabButtonStyle(isSelected: selectedTab == index))
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider()

            // Tab content
            Group {
                switch selectedTab {
                case 0: AccountsTab()
                case 1: CalendarsTab()
                case 2: NotetakerTab()
                case 3: ConfigTab()
                default: AccountsTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 500, height: 600)
    }
}

// MARK: - Native macOS tab button style

private struct TabButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isSelected ? .primary : .secondary)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .shadow(color: .black.opacity(0.1), radius: 1, y: 0.5)
                    }
                }
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
