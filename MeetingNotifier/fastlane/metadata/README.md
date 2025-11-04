# App Store Metadata

This directory contains all the App Store copy and metadata for MeetingNotifier.

## Current Status

**Binary Upload:** Successfully uploaded via Fastlane
**Metadata:** Must be uploaded manually via App Store Connect
**Screenshots:** Must be uploaded manually via App Store Connect

Due to App Store Connect API limitations and screenshot dimension requirements, metadata and screenshots need to be uploaded manually through the web interface.

## Files Created

All metadata is stored in `en-US/` (add more language folders as needed):

- **name.txt** - App name (30 chars max for macOS)
- **subtitle.txt** - Short tagline (30 chars max for macOS)
- **promotional_text.txt** - Featured text at top of listing (170 chars max)
- **description.txt** - Full app description (4000 chars max)
- **keywords.txt** - Search keywords, comma-separated (100 chars total max)
- **release_notes.txt** - What's new in this version (4000 chars max)
- **privacy_url.txt** - Privacy policy URL
- **support_url.txt** - Support URL

## Uploading to App Store

### Step 1: Upload Binary (Automated)

```bash
cd /Users/prashant/Developer/meeting-notifier/MeetingNotifier
bundle exec fastlane release
```

This builds and uploads the app binary to App Store Connect. The build will be available after processing (~10 minutes).

### Step 2: Upload Metadata (Manual)

Go to https://appstoreconnect.apple.com and copy the content from these files:

1. **App Store tab** > **App Information**:
   - Name: Copy from `en-US/name.txt`
   - Subtitle: Copy from `en-US/subtitle.txt`
   - Privacy Policy URL: Copy from `en-US/privacy_url.txt`

2. **App Store tab** > **Version 1.0**:
   - Promotional Text: Copy from `en-US/promotional_text.txt`
   - Description: Copy from `en-US/description.txt`
   - Keywords: Copy from `en-US/keywords.txt`
   - What's New: Copy from `en-US/release_notes.txt`
   - Support URL: Copy from `en-US/support_url.txt`

### Step 3: Upload Screenshots (Manual)

Screenshots must be resized to specific dimensions for macOS App Store:
- **2880 x 1800** (Recommended - Retina)
- **2560 x 1600** (Retina)
- **1440 x 900** (Standard)
- **1280 x 800** (Standard)

**Resize your screenshots:**
```bash
# Run the resize script from the directory containing your screenshots
cd /path/to/your/screenshots
/Users/prashant/Developer/meeting-notifier/MeetingNotifier/resize_screenshots.sh
```

This creates a `screenshots_resized/` directory with properly sized screenshots.

**Upload to App Store Connect:**
1. Go to https://appstoreconnect.apple.com
2. My Apps > MeetingNotifier > App Store tab
3. Scroll to "App Preview and Screenshots"
4. Drag and drop your resized screenshots

### Step 4: Submit for Review

Once metadata and screenshots are uploaded:
1. Click "Save"
2. Click "Add for Review"
3. Answer Export Compliance questions
4. Click "Submit for Review"

## Complete Instructions

See `../APP_STORE_SUBMISSION.md` for detailed step-by-step instructions.

## What Gets Uploaded

### `bundle exec fastlane release`

Uploads:
- ✅ App binary (.pkg file)
- ✅ App name and subtitle
- ✅ Description and promotional text
- ✅ Keywords
- ✅ Release notes (What's New)
- ✅ Privacy and support URLs
- ✅ Screenshots from `screenshots/en-US/`
- ✅ Creates git tag for this version

Does NOT upload:
- ❌ App icon (set in Xcode project)
- ❌ Category (set in Info.plist: Productivity)
- ❌ Price/availability (configure in App Store Connect)
- ❌ Doesn't auto-submit for review (you must do this manually)

### `bundle exec fastlane upload_metadata`

Uploads:
- ✅ App name and subtitle
- ✅ Description and promotional text
- ✅ Keywords
- ✅ Release notes
- ✅ Privacy and support URLs
- ✅ Screenshots from `screenshots/en-US/`

Does NOT upload:
- ❌ App binary (no .pkg uploaded)
- ❌ App icon
- ❌ Doesn't submit for review

### `bundle exec fastlane update_screenshots`

Uploads:
- ✅ Only screenshots from `screenshots/en-US/`

Does NOT upload:
- ❌ Any metadata text
- ❌ App binary
- ❌ URLs

## Adding More Languages

To add another language (e.g., Spanish):

```bash
mkdir -p fastlane/metadata/es-ES
cp fastlane/metadata/en-US/*.txt fastlane/metadata/es-ES/
# Then translate all the .txt files
```

## Editing Copy

Edit any `.txt` file directly:

```bash
# Edit description
nano fastlane/metadata/en-US/description.txt

# Or open in your editor
open fastlane/metadata/en-US/description.txt

# After editing, upload changes
bundle exec fastlane upload_metadata
```

## Character Limits

- **App Name:** 30 characters
- **Subtitle:** 30 characters
- **Promotional Text:** 170 characters
- **Keywords:** 100 characters total (comma-separated)
- **Description:** 4,000 characters
- **Release Notes:** 4,000 characters

## Tips

1. **Keywords:** Use singular forms, no spaces after commas
2. **Description:** Use line breaks and bullets for readability
3. **Screenshots:** App Store requires at least 1 screenshot
4. **Privacy URL:** Required for App Store submission
5. **Support URL:** Recommended but optional

## Current Copy Summary

**Name:** MeetingNotifier
**Subtitle:** Never miss a meeting
**Category:** Productivity (set in Info.plist)
**URLs:**
- Privacy: https://www.strategicnerds.com/privacy
- Support: https://github.com/coolasspuppy/meeting-notifier/issues

**Keywords:** meeting, calendar, reminder, notification, zoom, google meet, teams, menu bar, productivity, schedule

**Description highlights:**
- Menu bar integration with customizable display
- Multi-calendar support (Google, Microsoft)
- iCloud sync across devices
- Customizable notification system
- Travel time calculations
- Privacy-focused (no data collection)
- One-click join for video meetings
- Multi-account support

**Tone:** Professional, matter-of-fact, feature-focused. No marketing fluff.
