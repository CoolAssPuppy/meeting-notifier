import XCTest

/// Simple screenshot tests without fastlane dependency
/// Uses native XCTest screenshot attachment API
@MainActor
class BasicScreenshotTests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        app.launch()

        // Give the app time to load test data and show menu bar icon
        print("⏱️ Waiting 5 seconds for app to initialize...")
        sleep(5)

        print("✅ App should be ready now")
        print("📍 Check your menu bar for the MeetingNotifier icon")
    }

    // Helper to take and attach screenshot
    private func takeScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()

        // Save to Xcode test results (for viewing in Xcode)
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        // Save to project screenshots folder (for easy access)
        let projectPath = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let screenshotsDir = projectPath.appendingPathComponent("screenshots")

        // Create screenshots directory if it doesn't exist
        try? FileManager.default.createDirectory(at: screenshotsDir, withIntermediateDirectories: true)

        // Save PNG file
        let fileName = "\(name).png"
        let filePath = screenshotsDir.appendingPathComponent(fileName)

        do {
            try screenshot.pngRepresentation.write(to: filePath)
            print("✅ Saved screenshot: \(filePath.path)")
        } catch {
            print("❌ Failed to save screenshot to \(filePath.path): \(error)")
        }
    }

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    /// Main screenshot capture test
    /// INSTRUCTIONS:
    /// 1. Run this test in Xcode (Cmd+U or click the diamond icon next to the test)
    /// 2. When the app launches, MANUALLY click the menu bar icon to open the dropdown
    /// 3. The test will automatically navigate and capture screenshots
    func testCaptureScreenshots() {
        print("🎬 Starting MeetingNotifier screenshot capture...")
        print("📌 Please click the MeetingNotifier menu bar icon now!")
        print("⏱️ You have 10 seconds to click the icon...")

        // Wait for user to manually open the dropdown
        sleep(10)

        // Debug: Check what windows are visible
        print("🔍 Debug: Checking visible windows...")
        print("   App windows count: \(app.windows.count)")
        for i in 0..<app.windows.count {
            let window = app.windows.element(boundBy: i)
            print("   Window \(i): exists=\(window.exists), frame=\(window.frame)")
        }

        // Screenshot 1: Dropdown with meetings
        print("📸 Capturing dropdown...")
        takeScreenshot(named: "01-DropdownWithMeetings")
        sleep(1)

        // Look for and click Settings button
        print("🔍 Looking for Settings button...")
        if clickSettingsButton() {
            print("✅ Clicked Settings button")
            sleep(2)
        } else {
            print("⚠️  Could not find Settings button")
            print("📌 Please click the Settings button now! (5 seconds)")
            sleep(5)
        }

        // Wait for settings window
        sleep(2)

        // Debug: Check windows again
        print("🔍 Debug: Checking windows after settings opened...")
        print("   App windows count: \(app.windows.count)")

        // Screenshot 2: Settings - Accounts tab
        print("📸 Capturing Accounts tab...")
        takeScreenshot(named: "02-SettingsAccounts")
        sleep(1)

        // Navigate to Calendars tab
        print("🔍 Clicking Calendars tab...")
        if clickTab(named: "Calendars") {
            sleep(1)
            print("📸 Capturing Calendars tab...")
            takeScreenshot(named: "03-SettingsCalendars")
        } else {
            print("⚠️  Please manually click Calendars tab (5 seconds)")
            sleep(5)
            takeScreenshot(named: "03-SettingsCalendars")
        }

        // Navigate to Setup tab
        print("🔍 Clicking Setup tab...")
        if clickTab(named: "Setup") {
            sleep(1)
            print("📸 Capturing Setup tab...")
            takeScreenshot(named: "04-SettingsSetup")
        } else {
            print("⚠️  Please manually click Setup tab (5 seconds)")
            sleep(5)
            takeScreenshot(named: "04-SettingsSetup")
        }

        print("✅ Screenshot capture complete!")
        print("📂 Screenshots attached to test results - view in Xcode")
    }

    // MARK: - Helper Methods

    private func clickSettingsButton() -> Bool {
        // Try different ways to find the Settings button

        // Method 1: By accessibility identifier
        if app.buttons["settingsButton"].exists {
            app.buttons["settingsButton"].click()
            return true
        }

        // Method 2: By label containing "Settings"
        let buttons = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Settings'"))
        if buttons.count > 0 {
            buttons.firstMatch.click()
            return true
        }

        // Method 3: By exact label
        if app.buttons["Settings"].exists {
            app.buttons["Settings"].click()
            return true
        }

        // Method 4: Try static texts that might be clickable
        let staticTexts = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Settings'"))
        if staticTexts.count > 0 {
            staticTexts.firstMatch.click()
            return true
        }

        return false
    }

    private func clickTab(named tabName: String) -> Bool {
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

    // MARK: - Debug Helper

    /// Run this test to see all UI elements available
    /// This helps debug why elements can't be found
    func testDebugPrintAllElements() {
        print("🎬 Debug mode - will print all UI elements")
        print("📌 Please click the menu bar icon now!")
        sleep(8)

        print("\n=== WINDOWS ===")
        for i in 0..<app.windows.count {
            let window = app.windows.element(boundBy: i)
            print("Window \(i): exists=\(window.exists)")
        }

        print("\n=== BUTTONS ===")
        for i in 0..<min(app.buttons.count, 20) {
            let button = app.buttons.element(boundBy: i)
            if button.exists {
                print("Button \(i): label='\(button.label)' identifier='\(button.identifier)'")
            }
        }

        print("\n=== RADIO BUTTONS ===")
        for i in 0..<app.radioButtons.count {
            let radio = app.radioButtons.element(boundBy: i)
            if radio.exists {
                print("Radio \(i): label='\(radio.label)' identifier='\(radio.identifier)'")
            }
        }

        print("\n=== STATIC TEXTS ===")
        for i in 0..<min(app.staticTexts.count, 20) {
            let text = app.staticTexts.element(boundBy: i)
            if text.exists {
                print("Text \(i): label='\(text.label)'")
            }
        }

        sleep(10) // Keep app open to review output
    }
}
