# MeetingNotifier

A native macOS menu bar application that displays upcoming meetings from Google Calendar and Microsoft Outlook with intelligent notifications.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-green)

## Overview

MeetingNotifier is a productivity tool that keeps you informed about your upcoming meetings directly from your menu bar. It integrates with Google Calendar and Microsoft Outlook using OAuth authentication, providing a clean and minimal interface inspired by the best macOS menu bar apps.

## Features

### Core functionality
- Display upcoming meetings in your menu bar
- Support for multiple Google and Microsoft accounts
- Show next meeting within 15 minutes in menu bar
- Quick access dropdown with today's and tomorrow's meetings
- One-click to join video meetings (Meet, Zoom, Teams, Webex)
- Automatic refresh every 5 minutes

### Calendar management
- Select which calendars to monitor from each account
- Color-coded calendar indicators
- Smart filtering (today + tomorrow after 5 PM)
- Manual refresh capability

### Notifications
- One minute warning before meetings with custom chime
- Custom reminders based on calendar event settings
- Duplicate prevention
- Smart notification tracking

### Security
- OAuth 2.0 authentication (no passwords stored)
- Refresh tokens stored securely in macOS Keychain
- Read-only calendar access
- Automatic token refresh

## Installation

### Requirements
- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later (for building from source)
- Google account and/or Microsoft account
- Internet connection for calendar sync

### Building from source

1. Clone the repository:
```bash
git clone https://github.com/yourusername/meeting-notifier.git
cd meeting-notifier
```

2. Open the project in Xcode:
```bash
open MeetingNotifier/MeetingNotifier.xcodeproj
```

3. Configure OAuth credentials (see OAuth Setup below)

4. Build and run:
   - Select Product > Run (⌘ + R)
   - The app will appear in your menu bar as a calendar emoji

## OAuth setup

### Google Calendar

To use your own Google OAuth credentials:

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable the Google Calendar API
4. Create OAuth 2.0 credentials (Desktop application type)
5. Configure OAuth consent screen with scope: `https://www.googleapis.com/auth/calendar.readonly`
6. Update `GoogleOAuthManager.swift` with your client ID and secret
7. Add URL scheme to Info.plist: `com.googleusercontent.apps.YOUR_CLIENT_ID`

### Microsoft Outlook

To use your own Microsoft OAuth credentials:

1. Go to [Azure Portal](https://portal.azure.com/)
2. Register a new application
3. Add required Graph API permissions: `Calendars.Read`, `offline_access`
4. Configure redirect URI to match the app
5. Update `MicrosoftOAuthManager.swift` with your client ID and secret
6. Add URL scheme to Info.plist

Note: The app comes with pre-configured OAuth credentials for testing, using the same credentials as Mail Notifier.

## Usage

### Getting started

1. **First Launch**: Click the calendar emoji in your menu bar
2. **Add Account**: Click "Add Account" in the dropdown footer
3. **Authenticate**: Choose Google or Microsoft and sign in
4. **Select Calendars**: Go to Settings > Calendars and toggle which calendars to monitor
5. **Enable Notifications**: Go to Settings > Notifications and enable notification types

### Menu bar states

**Default state**: Shows 📅 when no meetings are within 15 minutes

**Active state**: Shows 📅 Meeting Title at 2:30 PM when a meeting is approaching

### Dropdown interface

Click the menu bar icon to open the dropdown:

- **Header**: Shows "Upcoming meetings" with refresh button
- **Meeting List**:
  - Time and countdown (e.g., "2:30 PM - in 15m")
  - Meeting title (up to 2 lines)
  - Location (if available)
  - Video icon for virtual meetings
  - Calendar color indicator
- **Footer**: Add Account, Settings, Quit buttons

### Managing accounts

**Add an account:**
1. Click menu bar icon
2. Click "Add Account"
3. Choose Google or Microsoft
4. Sign in and authorize

**Remove an account:**
1. Open Settings
2. Go to Accounts tab
3. Click "Remove" next to the account
4. Confirm removal

### Managing calendars

**Select calendars to monitor:**
1. Open Settings
2. Go to Calendars tab
3. Toggle calendars on/off
4. Changes save automatically

### Notifications

**One Minute Warning:**
- Fires exactly 1 minute before any meeting
- Plays custom chime sound
- Shows meeting title and time

**Custom Reminders:**
- Based on reminder settings in your calendar events
- Uses system notification sound
- Shows custom timing (e.g., 15 minutes before)

**Managing notifications:**
1. Open Settings
2. Go to Notifications tab
3. Toggle notification types
4. Grant notification permissions in System Settings if prompted

## Architecture

### Technology stack

- **Language**: Swift 6
- **UI Framework**: SwiftUI + AppKit (for menu bar)
- **Authentication**: AppAuth (OAuth 2.0)
- **Storage**: UserDefaults + Keychain
- **Async**: Swift Concurrency (async/await)
- **Architecture**: MVVM with Manager pattern

### Project structure

```
MeetingNotifier/
├── MeetingNotifierApp.swift          # App entry point, URL handling
├── AppDelegate.swift                 # Menu bar management
├── Models/
│   ├── CalendarAccount.swift         # Account data model
│   ├── CalendarInfo.swift            # Calendar metadata
│   ├── CalendarEvent.swift           # Event data model
│   └── NotificationTracking.swift    # Notification tracking
├── Managers/
│   ├── AuthManager.swift             # Unified auth interface
│   ├── GoogleOAuthManager.swift      # Google OAuth flows
│   ├── MicrosoftOAuthManager.swift   # Microsoft OAuth flows
│   ├── GoogleCalendarManager.swift   # Google Calendar API
│   ├── MicrosoftCalendarManager.swift # Microsoft Graph API
│   ├── CalendarDataManager.swift     # Data coordination
│   ├── NotificationManager.swift     # Notification scheduling
│   └── KeychainManager.swift         # Secure token storage
├── Views/
│   ├── CalendarDropdownView.swift    # Main dropdown UI
│   ├── MeetingRowView.swift          # Meeting list item
│   ├── EmptyStateView.swift          # No meetings state
│   ├── SettingsView.swift            # Settings window
│   ├── AccountsTab.swift             # Account management
│   ├── CalendarsTab.swift            # Calendar selection
│   └── NotificationsTab.swift        # Notification preferences
├── Services/
│   ├── AppSettings.swift             # UserDefaults wrapper
│   └── MeetingLinkDetector.swift     # Video link detection
└── Resources/
    ├── Assets.xcassets               # App icons and images
    ├── chime.aiff                    # One minute warning sound
    └── Info.plist                    # App configuration
```

### Data flow

1. **Authentication**: OAuth managers handle token acquisition and refresh
2. **Calendar Fetching**: Calendar managers fetch data from APIs
3. **Data Aggregation**: CalendarDataManager combines and filters events
4. **UI Updates**: SwiftUI views observe data changes via @Published properties
5. **Notifications**: NotificationManager schedules based on event timing
6. **Persistence**: AppSettings saves preferences, Keychain stores tokens

### Key design decisions

**Why menu bar app?**
- Always visible and accessible
- Minimal screen real estate
- Native macOS experience
- LSUIElement prevents dock icon

**Why OAuth over EventKit?**
- Access to virtual meeting links (not available in EventKit)
- Support for non-Apple calendar services
- More reliable cross-platform sync
- Richer event metadata

**Why both Google and Microsoft?**
- Cover most business and personal use cases
- Many users have both account types
- Different organizations use different providers

**Why 15-minute threshold for menu bar?**
- Balance between usefulness and noise
- Enough time to prepare for meeting
- Avoids constant menu bar changes

**Why 5-minute auto-refresh?**
- Balances freshness with API rate limits
- Most calendar changes don't need instant sync
- Prevents excessive battery drain

### Security and privacy

- OAuth tokens stored in macOS Keychain with secure enclave
- No passwords stored anywhere
- Read-only calendar access (no write permissions)
- No analytics or tracking
- No external services (except Google/Microsoft APIs)
- All API calls use HTTPS
- Tokens automatically refreshed before expiration
- User data never leaves the device except for API calls

### Performance considerations

- Events cached in memory (cleared after they pass)
- Calendar list cached (only refreshed in settings)
- Efficient SwiftUI view updates via @Published
- Background refresh doesn't block UI
- Lazy loading of meeting details
- Efficient date range queries to APIs

## Development

### Code style

- Swift naming conventions (camelCase, PascalCase)
- Files under 500 lines
- Functions under 40 lines
- Comprehensive error handling
- No force unwraps
- Proper optional handling
- Inline documentation for complex logic

### Building for distribution

1. Archive the app:
   - Product > Archive
   - Wait for archive to complete

2. Distribute:
   - Window > Organizer
   - Select your archive
   - Click "Distribute App"
   - Choose distribution method

### Testing

The app includes comprehensive manual testing (see TASK-LIST.md Phase 7):
- OAuth flows for both providers
- Multi-account support
- Calendar selection and filtering
- Meeting display and sorting
- Link detection for all platforms
- Notification timing and sounds
- Error handling

## Troubleshooting

### OAuth errors

If you get authentication errors:
1. Verify your OAuth credentials are correctly configured
2. Check URL schemes in Info.plist match your client IDs
3. Ensure you've enabled the correct API permissions
4. Try removing and re-adding the account

### Meetings not showing

If meetings don't appear:
1. Check that calendars are toggled on in Settings > Calendars
2. Verify your account is connected in Settings > Accounts
3. Try manually refreshing (click refresh button in dropdown)
4. Check internet connectivity
5. Look for expired OAuth tokens (re-authenticate)

### Notifications not working

If notifications don't fire:
1. Check notification settings in Settings > Notifications
2. Grant notification permissions in System Settings > Notifications > MeetingNotifier
3. Verify events have reminder settings in your calendar
4. Check that the app is running (look for menu bar icon)

### Video links not opening

If meeting links don't work:
1. Verify the meeting has a video conferencing link
2. Check that link is in event's conferenceData, location, or description
3. Ensure you have a default browser set
4. Try copying the link and opening manually

## Roadmap

### Planned enhancements
- Menubar icon customization
- Calendar event creation
- Meeting status tracking (accepted, tentative, declined)
- Travel time calculations
- Multiple notification profiles
- Keyboard shortcuts
- Dark mode customization
- Custom notification sounds
- Meeting notes/agenda viewing

### Integration ideas
- Siri Shortcuts support
- Raycast extension
- Alfred workflow
- Focus mode integration

## Contributing

Contributions welcome! This project serves as an educational resource for learning macOS menu bar app development.

### Areas for contribution
- Bug fixes and improvements
- Additional calendar providers
- Enhanced notification options
- UI/UX improvements
- Documentation enhancements
- Test coverage
- Localization

## License

MIT License - See LICENSE file for details

## Acknowledgments

Built with:
- Swift 6 and SwiftUI
- AppAuth for OAuth 2.0
- AppKit for menu bar integration
- Inspired by Mail Notifier and LinkDropdown

Special thanks to:
- James Chen for Mail Notifier OAuth implementation reference
- MeetingBar app for inspiration

---

**Note**: This app requires macOS 14.0 (Sonoma) or later. The app runs as a menu bar application and does not appear in the Dock.
