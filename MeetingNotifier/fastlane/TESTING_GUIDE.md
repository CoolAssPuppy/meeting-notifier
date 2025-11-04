## Screenshot Testing Guide for MeetingNotifier

This guide will help you capture screenshots of your menu bar app for App Store submission.

### Quick Start

1. **Open the project in Xcode:**
   ```bash
   open MeetingNotifier.xcodeproj
   ```

2. **Make sure SnapshotHelper is added to your UI Tests target:**
   - Select the project in the navigator
   - Select the `MeetingNotifierUITests` target
   - Go to the "Build Phases" tab
   - Verify `SnapshotHelper.swift` is under "Compile Sources"
   - If not, click the `+` button and add it

3. **Run the screenshot test:**
   - In Xcode: Product → Test (Cmd+U)
   - OR from terminal:
     ```bash
     bundle exec fastlane screenshots
     ```

### Testing Workflow

#### Option 1: Automated (Recommended)

Run the full automated test:

```bash
cd /Users/prashant/Developer/meeting-notifier/MeetingNotifier
bundle exec fastlane screenshots
```

This will:
- Build the app in UI testing mode
- Launch the app with test data
- Attempt to capture screenshots automatically
- Save screenshots to `fastlane/screenshots/`

#### Option 2: Manual Assistance (If automation fails)

If the automated test has trouble clicking the menu bar icon:

1. **Run the simple test in Xcode:**
   - Open `SimpleScreenshotTests.swift`
   - Click the diamond icon next to `testCaptureAllScreenshots`
   - OR: Product → Test

2. **Follow the console instructions:**
   - The test will pause and ask you to click the menu bar icon
   - Click the MeetingNotifier icon in your menu bar
   - The test will automatically navigate and capture screenshots

3. **What gets captured:**
   - Dropdown with test meetings (Today and Tomorrow)
   - Settings → Accounts tab
   - Settings → Calendars tab
   - Settings → Setup tab

### Test Data

When running with `--uitesting` flag, the app automatically creates:

- **3 meetings today:**
  - Team Standup (15 min from now) - Zoom
  - Client Meeting - Q4 Review (2 hours from now) - Google Meet
  - 1:1 with Manager (4 hours from now) - Teams

- **2 meetings tomorrow:**
  - Design Review - Zoom
  - Sprint Planning - Google Meet

This ensures your dropdown looks populated and realistic.

### Customizing Screenshots

#### Add More Screenshots

Edit `SimpleScreenshotTests.swift` or `ScreenshotTests.swift`:

```swift
// Add after existing screenshots
snapshot("05CustomView")
```

#### Change Test Data

Edit `TestDataManager.swift` to customize the meetings shown:

```swift
// Add or modify test events
createTestEvent(
    title: "Your Meeting Title",
    startDate: someDate,
    duration: 60,
    conferenceType: "zoom" // or "meet", "teams"
)
```

#### Add More Languages

Edit `fastlane/Snapfile`:

```ruby
languages([
  "en-US",
  "es-ES",  # Spanish
  "fr-FR",  # French
  "de-DE",  # German
  "ja-JP"   # Japanese
])
```

### Troubleshooting

#### Problem: SnapshotHelper not found

**Solution:**
```bash
cd /Users/prashant/Developer/meeting-notifier/MeetingNotifier
curl -o MeetingNotifierUITests/SnapshotHelper.swift \
  https://raw.githubusercontent.com/fastlane/fastlane/master/snapshot/lib/assets/SnapshotHelper.swift
```

Then add it to your target in Xcode.

#### Problem: Menu bar icon not clickable

**Reason:** macOS security restrictions may prevent UI tests from clicking menu bar items.

**Solutions:**
1. **Grant permissions:**
   - System Settings → Privacy & Security → Accessibility
   - Add Xcode and Terminal

2. **Use manual assistance mode:**
   - Run `SimpleScreenshotTests` in Xcode
   - Manually click the menu bar icon when prompted
   - The test continues automatically

3. **Use keyboard shortcut:**
   - Add a global keyboard shortcut to open your dropdown
   - Modify the test to use that shortcut instead

#### Problem: Can't find Settings button or tabs

**Solution:** Run the debug test to see all elements:

```swift
// In ScreenshotTests.swift
func testPrintAccessibleElements()
```

This prints all accessible UI elements to help you find the right selectors.

#### Problem: Screenshots are blank

**Causes:**
- Window/popover not visible
- Timing issues (need longer sleep)
- Permissions not granted

**Solutions:**
- Increase `sleep()` durations
- Manually verify the UI is visible during tests
- Check System Settings → Privacy & Security → Screen Recording

#### Problem: Test Data Not Showing

**Check:**
1. Is `--uitesting` flag being passed? (Check setUp method)
2. Is TestDataManager.swift compiled into the main app target?
3. Check console for any errors during test data setup

### File Locations

```
MeetingNotifier/
├── fastlane/
│   ├── Snapfile                 # Screenshot configuration
│   ├── screenshots/             # Generated screenshots (gitignored)
│   │   └── en-US/              # Screenshots by language
│   └── Fastfile                # Fastlane lanes
├── MeetingNotifierUITests/
│   ├── SnapshotHelper.swift    # Fastlane helper (don't modify)
│   ├── ScreenshotTests.swift   # Full automated tests
│   └── SimpleScreenshotTests.swift  # Manual-assisted tests
└── MeetingNotifier/
    └── Managers/
        └── TestDataManager.swift  # Test data generation
```

### View Generated Screenshots

```bash
# View in Finder
open fastlane/screenshots/en-US/

# Or list them
ls -la fastlane/screenshots/en-US/
```

### Upload to App Store Connect

```bash
# Generate and upload in one command
bundle exec fastlane update_screenshots
```

Or separately:

```bash
# 1. Generate
bundle exec fastlane screenshots

# 2. Upload
bundle exec fastlane update_screenshots
```

### Tips for Best Screenshots

1. **Use realistic data:** The test data includes varied meeting types and times
2. **Show key features:** Make sure screenshots highlight:
   - Meeting list with countdown timers
   - Different meeting types (Zoom, Meet, Teams)
   - Settings and customization options
3. **Clean state:** Test data ensures a clean, professional look
4. **Timing:** Screenshots show upcoming meetings, not past ones
5. **Consistency:** All screenshots use the same test data for consistency

### Integration with Release Process

To include screenshots in your release:

1. **Edit `fastlane/Fastfile` line 256:**
   ```ruby
   skip_screenshots: false  # Change from true
   ```

2. **Or run separately before release:**
   ```bash
   bundle exec fastlane update_screenshots
   bundle exec fastlane release
   ```

### Next Steps

1. ✅ Run the tests to generate screenshots
2. ✅ Review screenshots in `fastlane/screenshots/en-US/`
3. ✅ Adjust test data or add more screenshots if needed
4. ✅ Upload to App Store Connect
5. ✅ Submit for review

Need help? Check the main README or Fastlane documentation.
