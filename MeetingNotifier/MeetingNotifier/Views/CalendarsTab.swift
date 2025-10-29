import SwiftUI
import AppKit

struct CalendarsTab: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var calendars: [String: [CalendarInfo]] = [:]
    @State private var isLoading = false
    @State private var selectedCalendarForColor: (calendarId: String, accountEmail: String, defaultColor: String)?
    @State private var showColorPicker = false

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
        .sheet(isPresented: $showColorPicker) {
            if let selected = selectedCalendarForColor {
                CalendarColorPickerView(
                    calendarId: selected.calendarId,
                    accountEmail: selected.accountEmail,
                    defaultColor: selected.defaultColor
                )
            }
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
                Button(action: {
                    selectedCalendarForColor = (calendar.id, account.email, calendar.colorHex)
                    showColorPicker = true
                }) {
                    Circle()
                        .fill(Color(hex: effectiveColor(for: calendar, account: account)))
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help("Click to customize color")

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

    private func effectiveColor(for calendar: CalendarInfo, account: CalendarAccount) -> String {
        return settings.getCustomColor(forCalendar: calendar.id, account: account.email) ?? calendar.colorHex
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

// MARK: - Color Picker View

struct CalendarColorPickerView: View {
    let calendarId: String
    let accountEmail: String
    let defaultColor: String

    @ObservedObject var settings = AppSettings.shared
    @Environment(\.dismiss) var dismiss

    @State private var selectedColor: Color
    @State private var hexInput: String
    @State private var isValidHex: Bool = true
    @State private var isUpdatingFromColorPicker: Bool = false
    @State private var isUpdatingFromHexInput: Bool = false
    @FocusState private var isHexFieldFocused: Bool

    init(calendarId: String, accountEmail: String, defaultColor: String) {
        self.calendarId = calendarId
        self.accountEmail = accountEmail
        self.defaultColor = defaultColor

        let currentColor = AppSettings.shared.getCustomColor(forCalendar: calendarId, account: accountEmail) ?? defaultColor
        _selectedColor = State(initialValue: Color(hex: currentColor))
        _hexInput = State(initialValue: currentColor.uppercased())
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Customize Calendar Color")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(.regularMaterial)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Color preview
                    colorPreviewSection

                    Divider()

                    // Color picker
                    colorPickerSection

                    Divider()

                    // Hex input
                    hexInputSection

                    Divider()

                    // Preset palette
                    presetPaletteSection
                }
                .padding(20)
            }

            Divider()

            // Footer buttons
            HStack(spacing: 12) {
                Button("Reset to Default") {
                    Task {
                        settings.removeCustomColor(forCalendar: calendarId, account: accountEmail)
                        await CalendarDataManager.shared.refreshEvents()
                        dismiss()
                    }
                }
                .help("Reset to the original Google Calendar color")

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    Task {
                        await saveColor()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!isValidHex)
            }
            .padding()
            .background(.regularMaterial)
        }
        .frame(width: 400, height: 500)
        .background(.ultraThinMaterial)
    }

    private var colorPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                Circle()
                    .fill(selectedColor)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: selectedColor.opacity(0.3), radius: 8, x: 0, y: 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Sample Event")
                        .font(.system(size: 14, weight: .medium))

                    HStack(spacing: 4) {
                        Circle()
                            .fill(selectedColor)
                            .frame(width: 8, height: 8)
                        Text("Calendar Name")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
            )
        }
    }

    private var colorPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Color Picker")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                .labelsHidden()
                .onChange(of: selectedColor) { _, newColor in
                    guard !isUpdatingFromHexInput else { return }
                    isUpdatingFromColorPicker = true
                    updateHexFromColor(newColor)
                    isUpdatingFromColorPicker = false
                }
        }
    }

    private var hexInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hex Code")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            TextField("", text: $hexInput)
                .textFieldStyle(.plain)
                .font(.system(size: 14, design: .monospaced))
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(
                                    isValidHex ? Color.primary.opacity(0.2) : Color.red.opacity(0.5),
                                    lineWidth: 1
                                )
                        )
                )
                .focused($isHexFieldFocused)
                .onChange(of: hexInput) { _, newValue in
                    guard !isUpdatingFromColorPicker else { return }
                    validateAndUpdateColor(newValue)
                }

            if !isValidHex {
                Text("Invalid hex color code")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    private var presetPaletteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Colors")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(presetColors, id: \.self) { colorHex in
                    Button(action: {
                        isUpdatingFromHexInput = true
                        hexInput = colorHex
                        selectedColor = Color(hex: colorHex)
                        isValidHex = true
                        isUpdatingFromHexInput = false
                    }) {
                        Circle()
                            .fill(Color(hex: colorHex))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        hexInput.uppercased() == colorHex.uppercased() ?
                                        Color.primary.opacity(0.5) : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(colorHex)
                }
            }
        }
    }

    private let presetColors = [
        "#D50000", "#E67C73", "#F4511E", "#F6BF26", "#33B679", "#0B8043",
        "#039BE5", "#3F51B5", "#7986CB", "#8E24AA", "#616161", "#3F3F3F"
    ]

    private func validateAndUpdateColor(_ hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if !sanitized.hasPrefix("#") {
            sanitized = "#" + sanitized
        }

        let hexPattern = "^#[0-9A-Fa-f]{6}$"
        let regex = try? NSRegularExpression(pattern: hexPattern)
        let range = NSRange(location: 0, length: sanitized.utf16.count)

        if regex?.firstMatch(in: sanitized, range: range) != nil {
            isValidHex = true
            isUpdatingFromHexInput = true
            selectedColor = Color(hex: sanitized)
            isUpdatingFromHexInput = false
        } else {
            isValidHex = false
        }
    }

    private func updateHexFromColor(_ color: Color) {
        // Don't update hex input while user is typing
        guard !isHexFieldFocused else { return }

        if let nsColor = NSColor(color).usingColorSpace(.deviceRGB) {
            let r = Int(nsColor.redComponent * 255)
            let g = Int(nsColor.greenComponent * 255)
            let b = Int(nsColor.blueComponent * 255)
            let newHex = String(format: "#%02X%02X%02X", r, g, b)

            // Only update if different to prevent unnecessary updates
            if hexInput.uppercased() != newHex {
                hexInput = newHex
                isValidHex = true
            }
        }
    }

    private func saveColor() async {
        guard isValidHex else { return }

        var sanitized = hexInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sanitized.hasPrefix("#") {
            sanitized = "#" + sanitized
        }

        settings.setCustomColor(forCalendar: calendarId, account: accountEmail, color: sanitized.uppercased())

        // Wait for events to refresh before dismissing
        await CalendarDataManager.shared.refreshEvents()

        dismiss()
    }
}

// MARK: - Previews

struct CalendarsTab_Previews: PreviewProvider {
    static var previews: some View {
        CalendarsTab()
            .frame(width: 500, height: 600)
    }
}
