# App Store Submission Guide

## Current Status

**Binary Upload: SUCCESS**

Your app binary (version 1.0, build 2026) has been successfully uploaded to App Store Connect.

The build will be available in App Store Connect within 10 minutes after processing.

## What You Need To Do Next

Since automated metadata and screenshot uploads are problematic, you need to complete the submission manually via the App Store Connect web interface.

### 1. Verify Binary Upload

1. Go to https://appstoreconnect.apple.com
2. Select "My Apps"
3. Find "MeetingNotifier"
4. Go to "TestFlight" tab
5. Wait for build 2026 to appear (processing takes ~10 minutes)

### 2. Upload Screenshots

Screenshots must be specific dimensions for macOS App Store. Apple requires at least one of these sizes:

- **1280 x 800** (Standard)
- **1440 x 900** (Standard)
- **2560 x 1600** (Retina)
- **2880 x 1800** (Retina)

#### How to Resize Your Screenshots

You mentioned you pixelated your screenshots with Skitch. Here's how to resize them:

**Option 1: Use Preview (Built-in macOS)**
1. Open your screenshot in Preview
2. Tools > Adjust Size
3. Set width to 2880 and height to 1800 (or other valid size)
4. Make sure "Scale proportionally" is UNCHECKED
5. Save

**Option 2: Use sips command**
```bash
# Resize to 2880x1800 (most common Retina size)
sips -z 1800 2880 your-screenshot.png --out resized-screenshot.png
```

**Option 3: Use the resize script** (see below)

#### Upload Screenshots to App Store Connect

1. Go to https://appstoreconnect.apple.com
2. Select "My Apps" > "MeetingNotifier"
3. Go to "App Store" tab
4. Select version 1.0 (or create new version)
5. Scroll to "App Preview and Screenshots"
6. Upload your resized screenshots
7. You need at least 1 screenshot, recommended 4-5

### 3. Upload Metadata

All your metadata is ready in `fastlane/metadata/en-US/`. You need to manually copy this to App Store Connect:

1. Go to https://appstoreconnect.apple.com
2. Select "My Apps" > "MeetingNotifier"
3. Go to "App Store" tab

**Copy these fields:**

- **Name**: MeetingNotifier
- **Subtitle**: Never miss a meeting
- **Privacy Policy URL**: https://www.strategicnerds.com/privacy
- **Support URL**: https://github.com/coolasspuppy/meeting-notifier/issues
- **Marketing URL**: (leave blank)

- **Promotional Text** (from `fastlane/metadata/en-US/promotional_text.txt`):
```
MeetingNotifier keeps your upcoming meetings visible in the menu bar, so you always know what's next without switching apps.
```

- **Description** (from `fastlane/metadata/en-US/description.txt`):
```
MeetingNotifier keeps your upcoming meetings visible in the menu bar, so you always know what's next without switching apps.

FEATURES

Menu Bar Display
• See your next meeting time and countdown in the menu bar
• Customize what information appears: time, title, countdown, or icon
• Works across multiple monitors

Meeting List
• View all upcoming meetings in a dropdown
• Shows today and tomorrow's schedule after 5 PM
• Displays meeting platform icons (Zoom, Google Meet, Microsoft Teams)
• Quick access to join meeting links

Notifications
• Get alerts before meetings start (customizable timing)
• Choose from multiple notification sounds
• Configure different alert times for different situations

Calendar Integration
• Supports Google Calendar and Microsoft Calendar
• Select which calendars to monitor
• Secure OAuth authentication
• Works with multiple accounts simultaneously
• iCloud sync keeps settings consistent across devices

Travel Time
• Calculates drive time to meeting locations
• Shows when you need to leave
• Uses real-time traffic data

Meeting Management
• Join video calls with one click
• Open meeting locations in Maps
• Quick access to meeting details

Customization
• Choose which meeting information displays in the menu bar
• Select notification timing (1-60 minutes before)
• Pick custom notification sounds
• Configure for work and personal calendars

Privacy
• All calendar data stays on your device
• Secure OAuth login (no password storage)
• No data collection or tracking

MeetingNotifier is designed for professionals who manage multiple meetings and need reliable reminders without cluttering their workflow. The app runs quietly in the background, surfacing information only when you need it.
```

- **Keywords** (from `fastlane/metadata/en-US/keywords.txt`):
```
meeting,calendar,reminder,notification,zoom,google meet,teams,menu bar,productivity,schedule
```

- **What's New** (from `fastlane/metadata/en-US/release_notes.txt`):
```
Initial release of MeetingNotifier.

Features:
• Menu bar integration with customizable display
• Multi-calendar support (Google, Microsoft)
• iCloud sync across devices
• Customizable notifications
• Travel time calculations
• One-click join for video meetings
```

### 4. Additional App Store Connect Settings

**Category**: Productivity (already set in Info.plist)

**Age Rating**: Select "4+" (unless you have specific content concerns)

**Price**: Select "Free" or set your price

**Availability**: Select countries where you want to distribute

### 5. Submit for Review

Once you've uploaded screenshots and metadata:

1. Click "Save" at the top
2. Click "Add for Review"
3. Answer the Export Compliance questions (usually "No" for most apps)
4. Click "Submit for Review"

## Screenshot Resize Script

If you need to batch resize multiple screenshots, save this script as `resize_screenshots.sh`:

```bash
#!/bin/bash

# Resize screenshots to macOS App Store dimensions
# Usage: ./resize_screenshots.sh

TARGET_WIDTH=2880
TARGET_HEIGHT=1800

echo "Resizing screenshots to ${TARGET_WIDTH}x${TARGET_HEIGHT}..."

# Create output directory
mkdir -p screenshots_resized

# Resize all PNG files in current directory
for file in *.png; do
    if [ -f "$file" ]; then
        output="screenshots_resized/${file}"
        echo "Resizing $file..."
        sips -z $TARGET_HEIGHT $TARGET_WIDTH "$file" --out "$output"
    fi
done

echo "Done! Resized screenshots are in screenshots_resized/"
echo "Upload these to App Store Connect."
```

Make it executable and run:
```bash
chmod +x resize_screenshots.sh
./resize_screenshots.sh
```

## Troubleshooting

**If build doesn't appear in App Store Connect:**
- Wait 15-20 minutes for processing
- Check for email from Apple about build issues
- Verify code signing is correct

**If you need to upload a new build:**
```bash
bundle exec fastlane release
```

**If screenshots are rejected:**
- Ensure dimensions exactly match required sizes
- Make sure no personal information is visible
- Ensure app UI is clearly visible (no blank screens)

## Future Uploads

For future versions:

1. Bump version: `bundle exec fastlane bump_patch` (or bump_minor, bump_major)
2. Upload binary: `bundle exec fastlane release`
3. Update metadata manually in App Store Connect
4. Submit for review

## Summary

**What worked automatically:**
- Binary upload

**What needs manual steps:**
- Screenshot upload (wrong dimensions)
- Metadata upload (API issues)
- App Store Connect configuration

This is a common workflow for App Store submissions - many developers handle metadata and screenshots manually for better control.
