import XCTest

@MainActor
class ScreenshotTests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()

        continueAfterFailure = false

        app = XCUIApplication()

        // Add UI testing launch argument to enable test data
        app.launchArguments.append("--uitesting")

        // Set up snapshot for Fastlane
        setupSnapshot(app)

        app.launch()

        // Wait for app to be ready
        sleep(3)
    }

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    func testScreenshots() {
        print("Starting screenshot tests...")

        // For macOS menu bar apps, we need to interact with the menu bar
        // First, try to find and click the menu bar item
        clickMenuBarItem()

        // Wait for dropdown to appear
        sleep(2)

        // Screenshot 1: Main dropdown with meetings
        snapshot("01DropdownWithMeetings")

        // Find and click the Settings button
        if app.buttons.matching(identifier: "settingsButton").firstMatch.exists {
            print("Found settings button by identifier")
            app.buttons["settingsButton"].click()
        } else {
            // Fallback: try to find by label
            print("Settings button not found by identifier, trying label...")
            let settingsButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Settings'"))
            if settingsButtons.count > 0 {
                settingsButtons.firstMatch.click()
            }
        }

        // Wait for settings window to open
        sleep(2)

        // Screenshot 2: Settings - Accounts tab (default)
        snapshot("02SettingsAccounts")

        // Navigate to Calendars tab
        navigateToTab(named: "Calendars")
        sleep(1)

        // Screenshot 3: Settings - Calendars tab
        snapshot("03SettingsCalendars")

        // Navigate to Setup tab
        navigateToTab(named: "Setup")
        sleep(1)

        // Screenshot 4: Settings - Setup tab
        snapshot("04SettingsSetup")

        // Take a few extra screenshots from different angles
        // You can navigate back and take dark mode screenshots if needed
        print("Screenshots completed successfully!")
    }

    // MARK: - Helper Methods

    private func clickMenuBarItem() {
        // Try to find the menu bar extra item
        // For menu bar apps, the status item may not be directly accessible
        // We'll try different approaches

        // Approach 1: Try to find by accessibility
        let menuBars = XCUIApplication(bundleIdentifier: "com.apple.systemuiserver").menuBars
        if menuBars.count > 0 {
            // Look for our app's menu bar item
            let menuBarItems = menuBars.firstMatch.statusItems
            print("Found \(menuBarItems.count) menu bar items")

            // Try to find our specific item (may need to adjust based on your icon/title)
            for i in 0..<menuBarItems.count {
                let item = menuBarItems.element(boundBy: i)
                if item.exists {
                    print("Menu bar item \(i): \(item.debugDescription)")
                    // Click the first one that might be ours
                    // You may need to adjust this logic
                    if item.label.contains("calendar") ||
                       item.label.contains("meeting") ||
                       item.value as? String == "MeetingNotifier" {
                        item.click()
                        return
                    }
                }
            }

            // If we couldn't find it specifically, click the last few items
            // (new apps usually appear near the right side)
            if menuBarItems.count > 0 {
                let lastItem = menuBarItems.element(boundBy: menuBarItems.count - 1)
                if lastItem.exists {
                    print("Clicking last menu bar item as fallback")
                    lastItem.click()
                }
            }
        }

        // Approach 2: Try keyboard shortcut if configured
        // (You may need to add a keyboard shortcut for opening the dropdown)

        // Approach 3: Manual wait - for testing, you might manually click
        // the menu bar item and let the test continue
        print("Waiting for popover to appear...")
    }

    private func navigateToTab(named tabName: String) {
        // Try to find the tab by name
        print("Looking for tab: \(tabName)")

        // Method 1: Try radio buttons (tabs are often represented as radio buttons)
        let tabButtons = app.radioButtons.matching(NSPredicate(format: "label CONTAINS[c] %@", tabName))
        if tabButtons.count > 0 {
            print("Found tab as radio button")
            tabButtons.firstMatch.click()
            return
        }

        // Method 2: Try regular buttons
        let buttons = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", tabName))
        if buttons.count > 0 {
            print("Found tab as button")
            buttons.firstMatch.click()
            return
        }

        // Method 3: Try by accessibility identifier
        let identifierMap: [String: String] = [
            "Accounts": "accountsTab",
            "Calendars": "calendarsTab",
            "Setup": "setupTab"
        ]

        if let identifier = identifierMap[tabName] {
            if app.radioButtons[identifier].exists {
                print("Found tab by identifier: \(identifier)")
                app.radioButtons[identifier].click()
                return
            }
        }

        // Method 4: Try static text (sometimes tabs are just text)
        let staticTexts = app.staticTexts.matching(NSPredicate(format: "label == %@", tabName))
        if staticTexts.count > 0 {
            print("Found tab as static text")
            staticTexts.firstMatch.click()
            return
        }

        print("Warning: Could not find tab named: \(tabName)")
    }

    // Alternative test method that doesn't rely on clicking the menu bar
    func testSettingsWindowScreenshots() {
        print("Starting settings window screenshots...")

        // This test assumes the settings window can be opened directly
        // You may need to trigger it programmatically or manually

        // Wait for any window to appear
        let windows = app.windows
        print("Number of windows: \(windows.count)")

        if windows.count > 0 {
            // Screenshot the first window
            snapshot("05AnyWindow")

            // Try to find settings-related elements
            if app.buttons["setupTab"].exists {
                app.buttons["setupTab"].click()
                sleep(1)
                snapshot("06SetupTab")
            }

            if app.buttons["calendarsTab"].exists {
                app.buttons["calendarsTab"].click()
                sleep(1)
                snapshot("07CalendarsTab")
            }
        }
    }

    // Debug helper to print all accessible elements
    func testPrintAccessibleElements() {
        print("=== ALL WINDOWS ===")
        print(app.windows.debugDescription)

        print("\n=== ALL BUTTONS ===")
        print(app.buttons.debugDescription)

        print("\n=== ALL RADIO BUTTONS ===")
        print(app.radioButtons.debugDescription)

        print("\n=== ALL STATIC TEXTS ===")
        print(app.staticTexts.debugDescription)

        print("\n=== MENU BARS ===")
        print(app.menuBars.debugDescription)

        // This will help you identify the correct selectors
        sleep(10) // Keep the app open so you can inspect it
    }
}
