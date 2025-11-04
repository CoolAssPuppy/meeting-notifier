# Screenshot Automation Setup Guide

This guide explains how to set up and use Fastlane's screenshot automation for MeetingNotifier.

## Initial Setup

### 1. Create UI Tests Target (One-time setup)

1. Open MeetingNotifier.xcodeproj in Xcode
2. File → New → Target
3. Select "UI Testing Bundle" under macOS
4. Name it "MeetingNotifierUITests"
5. Click Finish
6. Make sure the target is added to your scheme

### 2. Add SnapshotHelper to UI Tests

Run this command to add Fastlane's snapshot helper to your UI tests:

```bash
cd /Users/prashant/Developer/meeting-notifier/MeetingNotifier
fastlane snapshot init
```

This will create:
- A Snapfile configuration (already created)
- SnapshotHelper files in your UI tests

Then, add the SnapshotHelper to your UI Tests target:

```bash
fastlane snapshot setup_for_swift
```

This will add the necessary Swift files to your UI Tests target.

### 3. Add Screenshot Test File

1. In Xcode, open the MeetingNotifierUITests target
2. Create a new Swift file called `ScreenshotTests.swift`
3. Copy the contents from `MeetingNotifierUITests_TEMPLATE/ScreenshotTests.swift`
4. Customize the test methods to navigate through your app

### 4. Update UI Test Scheme Settings

1. In Xcode, go to Product → Scheme → Edit Scheme
2. Select "Test" in the left sidebar
3. Ensure "MeetingNotifierUITests" is checked
4. Under "Info" tab, make sure the test target has the host application set to MeetingNotifier

## Configuration Files

### Snapfile

Located at `fastlane/Snapfile`, this file configures:
- Which scheme to use
- Languages to generate screenshots for
- Output directory
- Screenshot options

You can add more languages by editing:
```ruby
languages([
  "en-US",
  "es-ES",  # Spanish
  "fr-FR",  # French
  "de-DE",  # German
  "ja-JP"   # Japanese
])
```

### ScreenshotTests.swift

This is your UI test file that captures screenshots. Key points:

1. Use `snapshot("ScreenshotName")` to capture a screenshot
2. Name screenshots with numbers to control order: "01MainWindow", "02Settings"
3. Add navigation code between snapshots to show different screens
4. Use `sleep()` to wait for animations to complete

Example:
```swift
func testScreenshots() {
    // Main window
    snapshot("01MainWindow")

    // Navigate to settings
    app.menuBars.menuBarItems["MeetingNotifier"].click()
    app.menuItems["Settings..."].click()
    sleep(1)

    // Capture settings
    snapshot("02Settings")
}
```

## Usage

### Generate Screenshots

To generate screenshots for your app:

```bash
cd /Users/prashant/Developer/meeting-notifier/MeetingNotifier
bundle exec fastlane screenshots
```

This will:
1. Build your app
2. Run the UI tests
3. Capture screenshots at each `snapshot()` call
4. Save them to `fastlane/screenshots/`

### Upload Screenshots to App Store Connect

To generate and upload screenshots in one command:

```bash
bundle exec fastlane update_screenshots
```

This will:
1. Generate screenshots
2. Upload them to App Store Connect
3. Overwrite any existing screenshots

### Generate Screenshots with Frames (Optional)

If you want to add device frames to your screenshots:

```bash
# Install imagemagick first
brew install imagemagick

# Generate screenshots
bundle exec fastlane screenshots

# Add frames
bundle exec fastlane frame_screenshots
```

## Available Fastlane Lanes

- `fastlane screenshots` - Generate screenshots only
- `fastlane frame_screenshots` - Add frames to existing screenshots (requires imagemagick)
- `fastlane update_screenshots` - Generate and upload screenshots to App Store Connect

## Customization Tips

### 1. Capture Different App States

In your ScreenshotTests.swift, you can capture different states:

```swift
// Light mode
snapshot("01MainWindow_Light")

// With meetings
// Add code to populate test data
snapshot("02WithMeetings")

// Settings
snapshot("03Settings")
```

### 2. Test Data Setup

Add test data in your `setUp()` method:

```swift
override func setUp() {
    super.setUp()
    app = XCUIApplication()
    app.launchArguments.append("--uitesting")
    setupSnapshot(app)
    app.launch()
}
```

Then in your app code, check for the testing flag:

```swift
if CommandLine.arguments.contains("--uitesting") {
    // Load test data
    setupTestMeetings()
}
```

### 3. Dark Mode Screenshots

To capture dark mode screenshots:

```swift
func testDarkModeScreenshots() {
    // Toggle dark mode
    // (You may need to implement this in your app)

    snapshot("01MainWindow_Dark")
    snapshot("02Settings_Dark")
}
```

## Troubleshooting

### Screenshots are blank or wrong
- Add `sleep(2)` after navigation to let UI settle
- Check that your app is properly launching
- Verify the UI elements exist with `app.buttons["ButtonName"].exists`

### UI Tests can't find elements
- Use Xcode's Accessibility Inspector to find element identifiers
- Use `app.debugDescription` in tests to see available elements
- Ensure your UI elements have proper accessibility labels

### Build fails
- Make sure UI Tests target is added to your scheme
- Verify SnapshotHelper is properly integrated
- Check that the scheme is set to "Debug" configuration for testing

## Integration with Release Process

To include screenshots in your release process, update the `release` lane in your Fastfile:

1. Change `skip_screenshots: true` to `skip_screenshots: false` at line 256
2. Run `fastlane screenshots` before `fastlane release`
3. Or use `fastlane update_screenshots` separately to update screenshots without releasing

## macOS Screenshot Requirements

For macOS App Store, screenshots should be:
- 1280x800, 1440x900, 2560x1600, or 2880x1800 pixels
- PNG or JPEG format
- At least 1 screenshot required
- Up to 10 screenshots per app version
- Screenshots should show actual app functionality

## Resources

- [Fastlane Snapshot Docs](https://docs.fastlane.tools/getting-started/ios/screenshots/)
- [XCUITest Documentation](https://developer.apple.com/documentation/xctest/user_interface_tests)
- [App Store Screenshot Guidelines](https://developer.apple.com/app-store/product-page/)
