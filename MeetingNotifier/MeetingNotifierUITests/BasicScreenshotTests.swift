import XCTest

@MainActor
class BasicScreenshotTests: XCTestCase {

    var app: XCUIApplication!

    private let screenshotDir = "/tmp/MeetingNotifier-Screenshots"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()

        // Create output directory via shell (no sandbox restrictions on /tmp)
        let _ = try? FileManager.default.createDirectory(
            atPath: screenshotDir,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    /// Captures all 5 App Store screenshots:
    ///   1. Calendar dropdown
    ///   2. Accounts tab
    ///   3. Calendars tab
    ///   4. Notes tab
    ///   5. Setup tab
    ///
    /// Screenshots saved to /tmp/MeetingNotifier-Screenshots/
    /// Copy to Desktop:  cp /tmp/MeetingNotifier-Screenshots/*.png ~/Desktop/
    func testCaptureScreenshots() {
        // -- Screenshot 1: Dropdown --
        app.launchArguments = ["--uitesting", "--show-dropdown"]
        app.launch()
        sleep(3)
        captureMainScreen(named: "01-CalendarDropdown")
        app.terminate()

        // -- Screenshots 2-5: Settings tabs --
        app.launchArguments = ["--uitesting", "--open-settings"]
        app.launch()

        let settingsWindow = app.windows.firstMatch
        guard settingsWindow.waitForExistence(timeout: 10) else {
            XCTFail("Settings window did not appear")
            return
        }
        sleep(1)

        captureMainScreen(named: "02-SettingsAccounts")

        clickTab("Calendars")
        sleep(1)
        captureMainScreen(named: "03-SettingsCalendars")

        clickTab("Notes")
        sleep(1)
        captureMainScreen(named: "04-SettingsNotes")

        clickTab("Setup")
        sleep(1)
        captureMainScreen(named: "05-SettingsSetup")
    }

    // MARK: - Helpers

    private func clickTab(_ name: String) {
        let identifier = "tab-\(name)"
        if app.buttons[identifier].exists {
            app.buttons[identifier].click()
            return
        }
        let byLabel = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", name))
        if byLabel.count > 0 {
            byLabel.firstMatch.click()
        }
    }

    /// Captures the main display using macOS screencapture and also attaches to test results.
    private func captureMainScreen(named name: String) {
        let path = "\(screenshotDir)/\(name).png"

        // Use macOS screencapture to capture the main display (Display 1)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-D", "1", "-x", path]
        try? process.run()
        process.waitUntilExit()

        // Also attach to xcresult for Xcode viewing
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Debug

    func testDebugPrintAllElements() {
        app.launchArguments = ["--uitesting", "--open-settings"]
        app.launch()
        sleep(5)

        print("\n=== BUTTONS ===")
        for i in 0..<min(app.buttons.count, 30) {
            let button = app.buttons.element(boundBy: i)
            if button.exists {
                print("Button \(i): label='\(button.label)' id='\(button.identifier)'")
            }
        }
        sleep(5)
    }
}
