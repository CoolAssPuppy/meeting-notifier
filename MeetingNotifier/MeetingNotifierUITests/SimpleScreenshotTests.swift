import XCTest

/// Simplified screenshot tests for manual execution
/// Since MeetingNotifier is a menu bar app, some interactions may need to be manual
@MainActor
class SimpleScreenshotTests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments.append("--uitesting")

        setupSnapshot(app)
        app.launch()

        // Give the app time to load test data
        sleep(3)
    }

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    /// Main screenshot capture test
    /// INSTRUCTIONS:
    /// 1. Run this test (Cmd+U or Product > Test)
    /// 2. When the app launches, MANUALLY click the menu bar icon to open the dropdown
    /// 3. The test will automatically capture screenshots as it navigates
    func testCaptureAllScreenshots() {
        print("🎬 Starting screenshot capture...")
        print("📌 Please click the MeetingNotifier menu bar icon now!")

        // Wait for user to manually open the dropdown
        sleep(5)

        // Debug: Check what windows are visible
        print("🔍 Debug: Checking visible windows...")
        print("   App windows count: \(app.windows.count)")
        for i in 0..<app.windows.count {
            let window = app.windows.element(boundBy: i)
            print("   Window \(i): exists=\(window.exists), frame=\(window.frame)")
        }

        // Screenshot 1: Dropdown with meetings
        print("📸 Capturing dropdown...")
        snapshot("01DropdownWithMeetings")

        // Look for the Settings button and click it
        print("🔍 Looking for Settings button...")
        if let settingsButton = findSettingsButton() {
            print("✅ Found Settings button, clicking...")
            settingsButton.click()
            sleep(2)
        } else {
            print("⚠️  Could not find Settings button automatically")
            print("📌 Please click the Settings button now!")
            sleep(5)
        }

        // Wait for settings window
        sleep(2)

        // Debug: Check windows again
        print("🔍 Debug: Checking windows after settings opened...")
        print("   App windows count: \(app.windows.count)")

        // Screenshot 2: Settings - Accounts tab (default)
        print("📸 Capturing Accounts tab...")
        snapshot("02SettingsAccounts")

        // Navigate to Calendars tab
        print("🔍 Navigating to Calendars tab...")
        if clickTab(named: "Calendars") {
            sleep(1)
            print("📸 Capturing Calendars tab...")
            snapshot("03SettingsCalendars")
        } else {
            print("⚠️  Please manually click the Calendars tab")
            sleep(5)
            snapshot("03SettingsCalendars")
        }

        // Navigate to Setup tab
        print("🔍 Navigating to Setup tab...")
        if clickTab(named: "Setup") {
            sleep(1)
            print("📸 Capturing Setup tab...")
            snapshot("04SettingsSetup")
        } else {
            print("⚠️  Please manually click the Setup tab")
            sleep(5)
            snapshot("04SettingsSetup")
        }

        print("✅ Screenshot capture complete!")
    }

    // MARK: - Helper Methods

    private func findSettingsButton() -> XCUIElement? {
        // Try different ways to find the Settings button

        // Method 1: By accessibility identifier
        if app.buttons["settingsButton"].exists {
            return app.buttons["settingsButton"]
        }

        // Method 2: By label containing "Settings"
        let buttons = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Settings'"))
        if buttons.count > 0 {
            return buttons.firstMatch
        }

        // Method 3: By label exactly matching "Settings"
        if app.buttons["Settings"].exists {
            return app.buttons["Settings"]
        }

        return nil
    }

    private func clickTab(named tabName: String) -> Bool {
        // Try to find and click a tab

        // Method 1: Radio buttons (tabs in TabView appear as radio buttons)
        let radioButtons = app.radioButtons.matching(NSPredicate(format: "label CONTAINS[c] %@", tabName))
        if radioButtons.count > 0 {
            radioButtons.firstMatch.click()
            return true
        }

        // Method 2: Regular buttons
        let buttons = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", tabName))
        if buttons.count > 0 {
            buttons.firstMatch.click()
            return true
        }

        // Method 3: By accessibility identifier
        let identifierMap: [String: String] = [
            "Accounts": "accountsTab",
            "Calendars": "calendarsTab",
            "Setup": "setupTab"
        ]

        if let identifier = identifierMap[tabName] {
            if app.radioButtons[identifier].exists {
                app.radioButtons[identifier].click()
                return true
            }
            if app.buttons[identifier].exists {
                app.buttons[identifier].click()
                return true
            }
        }

        return false
    }
}
