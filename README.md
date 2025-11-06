# MeetingNotifier

A native macOS menu bar app that keeps you on top of your calendar meetings with smart notifications and quick access to join video calls.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/license-Custom-green)

## Features

- **Multi-Account Support**: Connect multiple Google and Microsoft accounts
- **Smart Menu Bar**: Shows upcoming meetings with customizable display options
- **Quick Join**: One-click access to Zoom, Google Meet, Teams, and WebEx calls
- **Keyboard Shortcuts**:
  - `⌘⇧M` - Join next meeting
  - `⌘⇧O` - Open dropdown menu
  - `⌘⇧R` - Refresh meetings
- **Intelligent Notifications**: Customizable meeting reminders with 1-minute warnings
- **Travel Time Alerts**: Notifications when it's time to leave for physical meetings
- **Double-Booking Detection**: Smart handling of overlapping meetings
- **iCloud Sync**: Settings sync across your devices
- **Native macOS**: Built with SwiftUI, follows Apple HIG

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/coolasspuppy/meeting-notifier.git
cd meeting-notifier
```

### 2. Get OAuth credentials

#### Google Calendar

1. Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Create a new project or select an existing one
3. Enable **Google Calendar API**
4. Create **OAuth 2.0 Client ID** credentials:
   - Application type: **Desktop app**
   - Name: MeetingNotifier (or your preferred name)
5. Copy your **Client ID** and **Client Secret**

#### Microsoft Calendar

1. Go to [Azure Portal - App Registrations](https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps)
2. Click **New registration**
3. Fill in the details:
   - **Name**: MeetingNotifier
   - **Supported account types**: Accounts in any organizational directory and personal Microsoft accounts
   - **Redirect URI**: Select **Public client/native** and enter `msauth.com.strategicnerds.meetingnotifier://auth`
4. After creation, go to **API permissions** and add:
   - `Calendars.Read`
   - `User.Read`
5. Copy your **Application (client) ID** and create a **Client Secret** under Certificates & secrets

### 3. Configure credentials

1. Copy the template files:
   ```bash
   cd MeetingNotifier/MeetingNotifier/Managers
   cp GoogleOAuthSecret.swift.template GoogleOAuthSecret.swift
   cp MicrosoftOAuthSecret.swift.template MicrosoftOAuthSecret.swift
   ```

2. Edit the files with your credentials:
   ```swift
   // GoogleOAuthSecret.swift
   static let secret = "YOUR_GOOGLE_CLIENT_SECRET"

   // MicrosoftOAuthSecret.swift
   static let secret = "YOUR_MICROSOFT_CLIENT_SECRET"
   ```

3. Update the Client IDs in the managers:
   ```swift
   // GoogleOAuthManager.swift (line 9)
   static let clientID = "YOUR_GOOGLE_CLIENT_ID"

   // MicrosoftOAuthManager.swift (line 9)
   static let clientID = "YOUR_MICROSOFT_CLIENT_ID"
   ```

4. These files are gitignored, so your secrets are safe

### 4. Build and run

1. Open `MeetingNotifier.xcodeproj` in Xcode
2. Select your development team in **Signing & Capabilities**
3. Press **Cmd+R** to build and run
4. Click the menu bar icon and add your calendar accounts

## Development

### Prerequisites

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- Swift 5.9 or later
- Google/Microsoft developer accounts for OAuth

### Building

```bash
# Clone and open
git clone https://github.com/coolasspuppy/meeting-notifier.git
cd meeting-notifier/MeetingNotifier
open MeetingNotifier.xcodeproj

# Or build from command line
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

## Architecture

MeetingNotifier follows MVVM architecture with clean separation of concerns:

### Key Components

**CalendarDataManager**: Centralized manager for fetching events from multiple calendar providers. Handles caching, refresh logic, and event aggregation.

**GoogleCalendarManager / MicrosoftCalendarManager**: Provider-specific API clients for fetching calendar events. Handle OAuth refresh, pagination, and error handling.

**AuthManager**: Coordinates OAuth flows for both Google and Microsoft. Manages authentication state and token refresh.

**KeychainManager**: Stores OAuth tokens securely in macOS Keychain. Tokens never touch disk or iCloud.

**AppSettings**: User preferences with iCloud Key-Value Store sync. Handles notification settings, display preferences, and multi-device synchronization.

**NotificationManager**: Manages meeting reminders, 1-minute warnings, and travel time alerts using UserNotifications framework.

## Usage

### Adding Calendar Accounts

1. Click the MeetingNotifier icon in your menu bar
2. Click **+ Add Account** in the footer
3. Select Google or Microsoft
4. Sign in through the OAuth flow
5. Grant calendar access permissions
6. Your meetings will appear automatically

### Managing Meetings

- Click any meeting card with a video link to join the call
- Use keyboard shortcuts for quick access:
  - `⌘⇧M` - Join next meeting instantly
  - `⌘⇧O` - Toggle dropdown
  - `⌘⇧R` - Refresh calendar data

### Settings

Access settings via the gear icon:

1. **Accounts**: Manage connected calendars, re-authenticate accounts
2. **Calendars**: Select which calendars to display from each account
3. **Setup**:
   - Notification preferences
   - Menu bar display options
   - Meeting link preferences (choose browser/app)
   - Travel time alerts
   - Launch at login

## Security & Privacy

- **OAuth tokens**: Stored in macOS Keychain (never in code or iCloud)
- **App Sandbox**: Runs sandboxed with minimal permissions
- **No analytics**: Zero tracking or data collection
- **No third parties**: Only communicates with Google/Microsoft APIs
- **iCloud**: Only settings sync (not credentials)
- **Open source**: Complete transparency - review the code yourself

### Multi-Device Behavior

When you install the app on a new device:
1. Account configurations sync from iCloud
2. App detects missing local OAuth tokens
3. Account is marked as `needsAuth`
4. You'll see a prompt to "Sign in on this device"
5. After signing in, calendar data syncs normally

This ensures OAuth tokens never leave your device while keeping your account setup synchronized.

## Troubleshooting

**Authentication fails**: Check that redirect URIs match exactly in Google/Microsoft developer consoles. For Google, ensure redirect URI includes your bundle identifier.

**No meetings showing**: Verify authentication in Settings → Accounts. Check that calendars are selected in Settings → Calendars.

**Notifications not working**: Check System Settings → Notifications → MeetingNotifier. Ensure notifications are enabled in app Settings → Setup.

**Build errors**: Ensure you've configured both `GoogleOAuthSecret.swift` and `MicrosoftOAuthSecret.swift` with valid credentials.

## TestFlight Distribution

The app uses Fastlane for TestFlight builds:

```bash
cd MeetingNotifier/fastlane
fastlane release
```

## Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Test thoroughly on macOS 14.0+
4. Submit a PR with clear description of changes
5. Follow existing code style and architecture patterns

For major changes, please open an issue first to discuss what you'd like to change.

## License

Custom Open Source License - see [LICENSE](LICENSE) file for details.

**TL;DR**: You can fork and customize for personal use, but you cannot distribute through the App Store without permission. This protects the official MeetingNotifier while keeping the code open for learning and personal projects.

## Credits

Built with:
- Swift & SwiftUI
- [Google Calendar API](https://developers.google.com/calendar)
- [Microsoft Graph API](https://docs.microsoft.com/en-us/graph/api/resources/calendar)
- macOS Keychain Services
- iCloud Key-Value Store
- [AppAuth-iOS](https://github.com/openid/AppAuth-iOS) for OAuth flows

Made with love by Strategic Nerds, Inc.

## Support

- Open an [issue](https://github.com/coolasspuppy/meeting-notifier/issues) for bugs or feature requests
- Check existing issues before creating new ones
- Provide reproduction steps for bugs
- Include macOS version and app version in bug reports

---

**Copyright © 2025 Strategic Nerds, Inc. All rights reserved.**
