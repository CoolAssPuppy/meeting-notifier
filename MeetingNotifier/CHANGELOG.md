# Changelog

All notable changes to MeetingNotifier will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release preparation
- Automated deployment pipeline with Fastlane
- TestFlight and App Store deployment automation
- OAuth token refresh with automatic retry on 401 errors
- User notifications for authentication failures
- Menu bar warning indicators for auth issues
- Account reconnection UI in Settings

### Changed
- N/A

### Fixed
- N/A

### Security
- Added OAuth token expiration handling
- Implemented auth status tracking for all accounts

## [1.0.0] - TBD

### Added
- Calendar integration with Google Calendar and Microsoft Calendar
- Meeting notifications with customizable timing
- Menu bar integration showing upcoming meetings
- Support for multiple calendar accounts
- Meeting link detection for Google Meet, Zoom, Teams, and Webex
- Launch at login functionality
- In-app purchases (Buy Me Coffee support)
- Sound notifications with mute option
- Attendee filtering for meeting display

### Features
- **Calendar Sync**: Automatic refresh every 5 minutes
- **Notifications**: 1-minute warning and custom reminders
- **Menu Bar**: Shows next meeting 15 minutes before start
- **Multi-Account**: Support for multiple Google and Microsoft accounts
- **Calendar Selection**: Choose which calendars to sync per account
- **OAuth Authentication**: Secure token-based authentication
- **Auto Token Refresh**: Transparent token refresh on expiration

---

## How to Update This Changelog

When preparing a release:

1. Move items from **[Unreleased]** to a new version section
2. Add the release date
3. Create a new **[Unreleased]** section for future changes
4. Categorize changes under:
   - **Added** for new features
   - **Changed** for changes in existing functionality
   - **Deprecated** for soon-to-be removed features
   - **Removed** for now removed features
   - **Fixed** for any bug fixes
   - **Security** for vulnerability fixes

Example entry:
```markdown
## [1.1.0] - 2025-11-15

### Added
- Push notifications for meeting reminders
- Support for iCloud calendar

### Fixed
- Fixed crash when removing calendar account
```
