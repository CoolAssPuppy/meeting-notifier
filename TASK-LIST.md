# MeetingNotifier - Task List

A comprehensive checklist for building MeetingNotifier, a macOS menu bar app for calendar notifications.

## Phase 1: Project scaffolding and data models

**Objective**: Set up Xcode project structure and define core data models

- [ ] Create Xcode project
  - [ ] Configure as macOS app targeting macOS 14.0+
  - [ ] Set up proper bundle identifier
  - [ ] Configure Info.plist (LSUIElement = true for menu bar app)
  - [ ] Add URL schemes for OAuth redirects
  - [ ] Add required capabilities
- [ ] Create folder structure
  - [ ] Models/
  - [ ] Managers/
  - [ ] Views/
  - [ ] Resources/
  - [ ] Services/
- [ ] Define data models
  - [ ] CalendarAccount.swift (email, type, tokens, enabled calendars)
  - [ ] CalendarInfo.swift (id, name, color, provider)
  - [ ] CalendarEvent.swift (id, title, start, end, location, description, conferenceData)
  - [ ] NotificationTracking.swift (track sent notifications)
- [ ] Add KeychainManager.swift for secure token storage
- [ ] Create AppSettings.swift for UserDefaults management
- [ ] Build successful with no warnings

## Phase 2: OAuth authentication

**Objective**: Implement Google and Microsoft OAuth flows

- [ ] Add AppAuth dependency via Swift Package Manager
- [ ] Create GoogleOAuthManager.swift
  - [ ] Use mail-notifier client credentials
  - [ ] Request calendar.readonly scope
  - [ ] Implement authorization flow with ASWebAuthenticationSession
  - [ ] Handle token refresh
  - [ ] Store tokens in Keychain
- [ ] Create MicrosoftOAuthManager.swift
  - [ ] Use mail-notifier client credentials
  - [ ] Request Calendars.Read and offline_access scopes
  - [ ] Implement authorization flow
  - [ ] Handle token refresh
  - [ ] Store tokens in Keychain
- [ ] Create AuthManager.swift
  - [ ] Unified interface for both providers
  - [ ] Account addition/removal
  - [ ] Token validation and refresh
- [ ] Test OAuth flows
  - [ ] Can add Google account
  - [ ] Can add Microsoft account
  - [ ] Can add multiple accounts
  - [ ] Tokens refresh automatically
- [ ] Build successful with no warnings

## Phase 3: Calendar API integration

**Objective**: Fetch calendar data from Google and Microsoft

- [ ] Create GoogleCalendarManager.swift
  - [ ] Fetch calendar list
  - [ ] Fetch events for date range
  - [ ] Parse event data (title, time, location, conference links)
  - [ ] Handle pagination
  - [ ] Error handling
- [ ] Create MicrosoftCalendarManager.swift
  - [ ] Fetch calendar list
  - [ ] Fetch events for date range
  - [ ] Parse event data
  - [ ] Handle pagination
  - [ ] Error handling
- [ ] Create CalendarDataManager.swift
  - [ ] Coordinate between providers
  - [ ] Aggregate events from all selected calendars
  - [ ] Sort events by start time
  - [ ] Filter events (today + tomorrow after 5 PM)
  - [ ] Automatic refresh every 5 minutes
  - [ ] Manual refresh capability
- [ ] Implement meeting link detection
  - [ ] Check conferenceData/onlineMeeting fields
  - [ ] Parse description for URLs
  - [ ] Parse location for URLs
  - [ ] Support Google Meet, Zoom, Teams, Webex
- [ ] Test API integration
  - [ ] Calendar list fetches correctly
  - [ ] Events fetch correctly
  - [ ] Multiple accounts work
  - [ ] Refresh works
  - [ ] Meeting links detected
- [ ] Build successful with no warnings

## Phase 4: Menu bar UI and dropdown

**Objective**: Create menu bar item and dropdown interface

- [ ] Create MeetingNotifierApp.swift
  - [ ] Main app entry point
  - [ ] URL handling for OAuth
  - [ ] No dock icon (accessory app)
- [ ] Create AppDelegate.swift
  - [ ] Menu bar status item setup
  - [ ] Default state: 📅 emoji
  - [ ] Active state: show next meeting within 15 minutes
  - [ ] Click handler for dropdown
- [ ] Create CalendarDropdownView.swift
  - [ ] Header with "Upcoming meetings" title
  - [ ] Refresh button with loading indicator
  - [ ] Scrollable meeting list
  - [ ] Section headers (Today/Tomorrow)
  - [ ] Empty state view
  - [ ] Footer with buttons
- [ ] Create MeetingRowView.swift
  - [ ] Time display (h:mm a format)
  - [ ] Time until meeting (in Xm, in Xh)
  - [ ] Meeting title (max 2 lines)
  - [ ] Location (if present)
  - [ ] Video icon for conference links
  - [ ] Calendar color indicator
  - [ ] Click to open video link
  - [ ] Hover effects
- [ ] Create EmptyStateView.swift
  - [ ] Calendar icon
  - [ ] "No upcoming meetings" text
- [ ] Style to match mail-notifier aesthetic
  - [ ] Same fonts and spacing
  - [ ] Same colors
  - [ ] Same button styles
  - [ ] Clean, minimal design
- [ ] Test dropdown functionality
  - [ ] Opens on click
  - [ ] Shows meetings correctly
  - [ ] Refresh works
  - [ ] Click on meeting opens link
  - [ ] Menu bar text updates
- [ ] Build successful with no warnings

## Phase 5: Settings window

**Objective**: Create settings interface for account and calendar management

- [ ] Create SettingsView.swift
  - [ ] Tab interface (Accounts, Calendars, Notifications)
  - [ ] Window size: 500x600
  - [ ] Proper window management
- [ ] Create AccountsTab.swift
  - [ ] List all connected accounts
  - [ ] Show provider icon, email, status
  - [ ] "Add Google Account" button
  - [ ] "Add Microsoft Account" button
  - [ ] "Remove" button for each account
  - [ ] Confirm removal dialog
- [ ] Create CalendarsTab.swift
  - [ ] List all calendars grouped by account
  - [ ] Show calendar name and color
  - [ ] Toggle switch for each calendar
  - [ ] Auto-save changes
  - [ ] Refresh calendar list
- [ ] Create NotificationsTab.swift
  - [ ] "Enable notifications" master toggle
  - [ ] "One minute warning" toggle
  - [ ] Info text explaining notification types
- [ ] Add settings button to dropdown footer
- [ ] Test settings window
  - [ ] Can add/remove accounts
  - [ ] Can toggle calendars
  - [ ] Settings persist
  - [ ] Window appears/disappears correctly
- [ ] Build successful with no warnings

## Phase 6: Notifications and reminders

**Objective**: Implement notification system

- [ ] Create NotificationManager.swift
  - [ ] Request notification permissions
  - [ ] Schedule one minute warnings
  - [ ] Schedule custom reminders from event
  - [ ] Play custom chime for one minute warning
  - [ ] Track sent notifications (prevent duplicates)
  - [ ] Clean up old tracking data
- [ ] Add chime sound to Resources/
  - [ ] Include .aiff file
  - [ ] Add to bundle
- [ ] Implement notification checking
  - [ ] Check every minute for upcoming notifications
  - [ ] Send notification at correct time
  - [ ] Don't duplicate notifications
- [ ] Handle notification actions
  - [ ] Click notification to open meeting link
- [ ] Test notifications
  - [ ] One minute warning works
  - [ ] Custom reminders work
  - [ ] Sound plays
  - [ ] No duplicates
  - [ ] Tracking cleaned up
- [ ] Build successful with no warnings

## Phase 7: Polish, testing, and documentation

**Objective**: Final polish and comprehensive testing

- [ ] Code quality
  - [ ] All files under 500 lines
  - [ ] Functions under 40 lines
  - [ ] Proper error handling everywhere
  - [ ] No force unwraps
  - [ ] All optionals handled safely
  - [ ] No console.log in production
- [ ] Refactoring
  - [ ] Extract repeated code
  - [ ] Improve naming
  - [ ] Add inline documentation
  - [ ] Organize imports
- [ ] Testing checklist (from spec)
  - [ ] Can add Google account
  - [ ] Can add Microsoft account
  - [ ] Can add multiple accounts
  - [ ] Can remove accounts
  - [ ] Token refresh works
  - [ ] All calendars appear in settings
  - [ ] Can toggle calendars on/off
  - [ ] Only selected calendars show events
  - [ ] Today's meetings appear
  - [ ] Tomorrow's meetings appear after 5 PM
  - [ ] Meetings sorted by time
  - [ ] Time-until updates every minute
  - [ ] Video icon shows for meetings with links
  - [ ] Menu bar shows next meeting within 15 minutes
  - [ ] Menu bar text truncates appropriately
  - [ ] Google Meet links work
  - [ ] Zoom links work
  - [ ] Teams links work
  - [ ] Webex links work
  - [ ] Links in description detected
  - [ ] Links in location detected
  - [ ] One minute warning fires correctly
  - [ ] Custom reminders fire correctly
  - [ ] Chime sound plays
  - [ ] No duplicate notifications
  - [ ] Network errors handled gracefully
  - [ ] Auth errors handled gracefully
- [ ] Update README.md
  - [ ] Add setup instructions
  - [ ] Document OAuth setup
  - [ ] Add architecture overview
  - [ ] Include screenshots
- [ ] Create .gitignore
  - [ ] Xcode files
  - [ ] User data
  - [ ] OAuth secrets
- [ ] Final build
  - [ ] Clean build folder
  - [ ] Build with no warnings
  - [ ] Build with no errors
  - [ ] Test on fresh macOS installation (if possible)
- [ ] Final commit
  - [ ] Review all changes
  - [ ] Write comprehensive commit message
  - [ ] Commit to git

## Progress Tracking

- **Phase 1**: ⬜ Not started
- **Phase 2**: ⬜ Not started
- **Phase 3**: ⬜ Not started
- **Phase 4**: ⬜ Not started
- **Phase 5**: ⬜ Not started
- **Phase 6**: ⬜ Not started
- **Phase 7**: ⬜ Not started

## Notes

- Each phase must build successfully with NO WARNINGS and NO ERRORS before moving to the next phase
- Commit to git after each phase is complete
- Follow the code style and patterns from mail-notifier and link-opener
- Prioritize code readability and maintainability
- Keep the UI clean and minimal like the reference apps
- Test thoroughly at each phase
