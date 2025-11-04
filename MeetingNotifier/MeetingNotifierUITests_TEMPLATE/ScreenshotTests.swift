import XCTest

class ScreenshotTests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()

        continueAfterFailure = false

        app = XCUIApplication()

        // Set up snapshot for Fastlane
        setupSnapshot(app)

        app.launch()

        // Wait for app to be ready
        sleep(2)
    }

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    func testScreenshots() {
        // Screenshot 1: Main Window / Calendar View
        snapshot("01MainWindow")

        // Screenshot 2: Settings Window
        // Navigate to settings if needed
        if app.menuBars.menuBarItems["MeetingNotifier"].exists {
            app.menuBars.menuBarItems["MeetingNotifier"].click()
            if app.menuItems["Settings..."].exists {
                app.menuItems["Settings..."].click()
                sleep(1)
                snapshot("02Settings")

                // Close settings
                if app.buttons[XCUIIdentifierCloseWindow].exists {
                    app.buttons[XCUIIdentifierCloseWindow].click()
                }
            }
        }

        // Screenshot 3: Notifications Tab
        // You can navigate to different tabs/views in your app
        // For example, if you have a tab bar or buttons:
        // app.buttons["Notifications"].click()
        // sleep(1)
        // snapshot("03Notifications")

        // Screenshot 4: Accounts Tab
        // app.buttons["Accounts"].click()
        // sleep(1)
        // snapshot("04Accounts")

        // Screenshot 5: Calendar Configuration
        // app.buttons["Calendars"].click()
        // sleep(1)
        // snapshot("05Calendars")

        // Add more screenshots as needed for your app
        // Each snapshot should represent a key feature or screen
    }

    // You can add more test methods for different scenarios
    func testDarkModeScreenshots() {
        // If you want dark mode screenshots, you can toggle the appearance
        // and take additional screenshots

        // Note: You might need to implement dark mode switching in your app
        // or use system preferences to toggle it

        snapshot("06MainWindow_Dark")
    }
}
