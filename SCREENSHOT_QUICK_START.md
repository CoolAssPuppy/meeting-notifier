# Quick Start: Generate Screenshots

This guide shows you how to generate App Store screenshots using the **fastlane-free** XCTest approach (based on linear-bar).

## Running the Tests

### Step 1: Open in Xcode

```bash
cd MeetingNotifier
open MeetingNotifier.xcodeproj
```

### Step 2: Run the Test

1. In Xcode, navigate to `MeetingNotifierUITests/BasicScreenshotTests.swift`
2. Click the diamond icon next to `testCaptureScreenshots()` OR press `Cmd+U`

### Step 3: Manual Interaction Required

When the app launches:

1. **Manually click the MeetingNotifier menu bar icon** (you have 10 seconds)
2. The test will automatically capture the dropdown
3. **Manually click the Settings button** when prompted (if auto-click fails)
4. The test will navigate through tabs and capture screenshots automatically

## Where Are the Screenshots?

Screenshots are saved in TWO places:

1. **Project folder** (easy access):
   ```bash
   open MeetingNotifier/screenshots/
   ```

2. **Xcode test results** (attached to test):
   - In Xcode, open the Test Navigator (diamond icon)
   - Click on the test run
   - View attachments

## What Gets Captured

The test captures 4 screenshots:

1. `01-DropdownWithMeetings.png` - Main dropdown with test meetings
2. `02-SettingsAccounts.png` - Settings Accounts tab
3. `03-SettingsCalendars.png` - Settings Calendars tab
4. `04-SettingsSetup.png` - Settings Setup tab

## Test Data

When run with `--uitesting` flag, the app shows mock meetings:
- 3 meetings today (Team Standup, Client Meeting, 1:1 with Manager)
- 2 meetings tomorrow (Design Review, Sprint Planning)
- Different meeting types (Zoom, Google Meet, Teams)

## Troubleshooting

### Test fails to compile
- Make sure `BasicScreenshotTests.swift` is added to the `MeetingNotifierUITests` target
- Check File Inspector → Target Membership

### Can't find Settings button or tabs
- The test will prompt you to click manually
- Just follow the console output

### Blank screenshots
- Make sure you clicked the menu bar icon when prompted
- Check the console for debug output showing window count

### Debug mode
Run the debug test to see all UI elements:
```swift
testDebugPrintAllElements()
```

## No Fastlane Required

This approach uses only native XCTest APIs. No fastlane, no snapshot helper dependencies.
