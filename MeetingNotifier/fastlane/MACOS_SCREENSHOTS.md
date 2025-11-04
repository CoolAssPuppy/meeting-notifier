# macOS Screenshot Guide

Since MeetingNotifier is a macOS menu bar app, the screenshot process is simpler than iOS but requires some manual steps.

## Quick Method (Recommended)

### Step 1: Run Tests in Xcode

1. **Open the project:**
   ```bash
   open MeetingNotifier.xcodeproj
   ```

2. **Open the test file:**
   - Navigate to `MeetingNotifierUITests/SimpleScreenshotTests.swift`

3. **Run the test:**
   - Click the diamond icon (▷) next to `testCaptureAllScreenshots`
   - OR: Product → Test (Cmd+U)

4. **During the test:**
   - When the app launches, **manually click your menu bar icon**
   - The test will wait 5 seconds for you to do this
   - Then it automatically navigates and captures 4 screenshots

5. **Find your screenshots:**
   The screenshots are saved to:
   ```bash
   ~/Library/Caches/tools.fastlane/
   ```

   To copy them to your project:
   ```bash
   mkdir -p fastlane/screenshots/en-US
   cp ~/Library/Caches/tools.fastlane/*.png fastlane/screenshots/en-US/
   ```

### Step 2: View Screenshots

```bash
open fastlane/screenshots/en-US/
```

You should see:
- `01DropdownWithMeetings.png`
- `02SettingsAccounts.png`
- `03SettingsCalendars.png`
- `04SettingsSetup.png`

## Alternative: Manual Screenshots

If UI testing is too complex, you can take manual screenshots:

### 1. Enable Test Mode

Run your app with test data:

1. Edit your scheme in Xcode:
   - Product → Scheme → Edit Scheme
   - Select "Run" in left sidebar
   - Go to "Arguments" tab
   - Under "Arguments Passed On Launch", add: `--uitesting`

2. Run the app (Cmd+R)

3. The app will show test meetings in the dropdown

### 2. Take Screenshots

1. **Dropdown screenshot:**
   - Click your menu bar icon
   - Press Cmd+Shift+4, then Space
   - Click the dropdown window to capture

2. **Settings screenshots:**
   - Click Settings button
   - For each tab (Accounts, Calendars, Setup):
     - Click the tab
     - Press Cmd+Shift+4, then Space
     - Click the settings window

3. **Save screenshots:**
   - Save all to `fastlane/screenshots/en-US/`
   - Name them: `01DropdownWithMeetings.png`, `02SettingsAccounts.png`, etc.

## Using Fastlane (Advanced)

The automated Fastlane command has been updated for macOS:

```bash
cd /Users/prashant/Developer/meeting-notifier/MeetingNotifier
bundle exec fastlane screenshots
```

This will:
1. Run the UI tests with macOS destination
2. Copy screenshots from temp folder to `fastlane/screenshots/en-US/`

**Note:** You'll still need to manually click the menu bar icon during the test.

## Screenshot Locations

Fastlane saves screenshots to a temp location:
```
~/Library/Caches/tools.fastlane/
```

The Fastlane lane copies them to:
```
fastlane/screenshots/en-US/
```

## Upload to App Store Connect

Once you have screenshots in `fastlane/screenshots/en-US/`:

```bash
bundle exec fastlane update_screenshots
```

Or manually upload via App Store Connect web interface.

## Tips

1. **Clean screenshots:** Remove any personal information from test data
2. **Consistent sizing:** macOS will automatically size screenshots correctly
3. **Multiple languages:** Create folders like `screenshots/es-ES/` for Spanish, etc.
4. **Professional look:** The test data shows realistic meetings without clutter

## Troubleshooting

### Menu bar icon not visible
- Check the app is running in test mode
- Look for the calendar icon in your menu bar
- Grant Screen Recording permissions if needed

### Screenshots not saving
- Check permissions: System Settings → Privacy & Security → Screen Recording
- Verify the temp folder exists: `ls ~/Library/Caches/tools.fastlane/`

### Can't find screenshots
After running tests, search for them:
```bash
find ~/Library/Caches -name "*.png" -mtime -1
```

## Summary

**Easiest method:**
1. Open Xcode
2. Run `SimpleScreenshotTests/testCaptureAllScreenshots`
3. Click menu bar icon when app launches
4. Copy screenshots from `~/Library/Caches/tools.fastlane/` to `fastlane/screenshots/en-US/`
5. Upload with `bundle exec fastlane update_screenshots`

**Or take manual screenshots** with Cmd+Shift+4 after enabling `--uitesting` mode.
