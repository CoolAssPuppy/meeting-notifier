# MeetingNotifier

A macOS menu bar app that keeps you on top of your calendar meetings with smart notifications and quick access to join video calls.

## Features

- **Multi-Account Support**: Connect multiple Google and Microsoft accounts
- **Smart Menu Bar**: Shows upcoming meetings with customizable display options
- **Quick Join**: One-click access to Zoom, Google Meet, Teams, and WebEx calls
- **Keyboard Shortcuts**:
  - `⌘⇧M` - Join next meeting
  - `⌘⇧O` - Open dropdown menu
  - `⌘⇧R` - Refresh meetings
- **Intelligent Notifications**: Customizable meeting reminders with 1-minute warnings
- **iCloud Sync**: Settings sync across your devices

## Development Setup

### Prerequisites
- Xcode 15 or later
- macOS 14.0 or later
- Swift 5.9 or later

### Building the App

```bash
cd MeetingNotifier
xcodebuild -scheme MeetingNotifier -configuration Debug build
```

### Running Tests

```bash
xcodebuild -scheme MeetingNotifier -destination 'platform=macOS' test
```

## Project Structure

```
MeetingNotifier/
├── MeetingNotifier/
│   ├── Services/
│   │   ├── AppSettings.swift           # Settings & iCloud sync
│   │   └── KeychainManager.swift       # OAuth token storage
│   ├── Managers/
│   │   ├── AuthManager.swift           # Authentication
│   │   ├── GoogleCalendarManager.swift
│   │   ├── MicrosoftCalendarManager.swift
│   │   ├── CalendarDataManager.swift
│   │   ├── NotificationManager.swift
│   │   └── KeyboardShortcutManager.swift
│   ├── Views/
│   │   ├── CalendarDropdownView.swift
│   │   ├── SettingsView.swift
│   │   └── ...
│   └── Models/
│       ├── CalendarAccount.swift
│       ├── CalendarEvent.swift
│       └── ...
└── fastlane/                           # TestFlight deployment
```

## OAuth Credentials & iCloud Sync

### How It Works

- **OAuth Tokens**: Stored locally in macOS Keychain (device-specific)
- **Account Info**: Synced via iCloud (email, provider, selected calendars)
- **Settings**: Synced via iCloud across all your devices

### Multi-Device Behavior

When you install the app on a new device:
1. Account configurations sync from iCloud
2. App detects missing local OAuth tokens
3. Account is marked as `needsAuth`
4. You'll see a prompt to "Sign in on this device"
5. After signing in, calendar data syncs normally

This ensures OAuth tokens never leave your device while keeping your account setup synchronized.

## TestFlight Distribution

The app uses Fastlane for TestFlight builds:

```bash
cd fastlane
fastlane release
```

## License

Proprietary - All Rights Reserved

## Contact

For issues or questions, please contact the development team.
