# MeetingNotifier macOS App - Codebase Architecture & Logging Analysis

## Overview
MeetingNotifier is a native macOS menu bar application built with SwiftUI that aggregates calendar meetings from Google and Microsoft Calendar APIs. The app runs as an accessory application (menu bar only) and provides smart notifications, keyboard shortcuts, and travel time alerts.

**Codebase Stats:**
- 30 Swift files
- 7,029 lines of code
- Architecture: MVVM with Manager-based service layer
- Threading: Heavily using Swift structured concurrency (@MainActor)

---

## Architecture & Main Components

### 1. Entry Points

**MeetingNotifierApp.swift** (13 lines)
- Standard SwiftUI @main entry point
- Minimal configuration - delegates to AppDelegate via NSApplicationDelegateAdaptor

**AppDelegate.swift** (615 lines)
- Primary application lifecycle management
- Menu bar setup and UI popover management
- Contains most of the business logic for display and user interaction
- Uses NSStatusItem for menu bar presence
- Manages popover (dropdown menu) behavior with semitransient behavior
- Handles OAuth URL callbacks via NSAppleEventManager
- Monitors global events for popover dismissal
- WARNING: 615 lines is getting large for a single file

### 2. Core Managers (Service Layer)

**CalendarDataManager.swift** (218 lines)
- @MainActor singleton for calendar event aggregation
- Fetches from multiple providers (Google/Microsoft)
- Auto-refresh timer (5-minute interval)
- Observes account changes via Combine
- Error handling: Catches exceptions, stores errorMessage property
- Threading: Proper Task wrapping for async operations
- Issue: Minimal logging (only 2 print statements)

**GoogleCalendarManager.swift** (362 lines)
- Implements Google Calendar API client
- Handles OAuth token refresh with retry logic (1 retry max)
- Parses conference link detection with regex patterns
- Handles attendee counts and reminders
- Auth failure notification via NotificationManager
- Error types: CalendarError enum with apiError, parseError, authError
- Logging: Uses print() statements for token expiration and errors

**MicrosoftCalendarManager.swift** (328 lines)
- Parallel implementation to GoogleCalendarManager for Microsoft Graph API
- Same retry and error handling patterns
- Different JSON parsing structure (value array vs items)
- Logging: Uses print() statements similar to Google manager

**AuthManager.swift** (180 lines)
- Coordinates OAuth flows for both providers
- Manages token storage via KeychainManager
- Validates token presence before proceeding
- Error handling: Creates NSError objects with descriptive messages
- Logging: Print statements for keychain operations and success/failure
- Critical section: Token storage verification with explicit error messages

**NotificationManager.swift** (260 lines)
- Manages meeting reminders and notifications
- 1-minute warning system and custom reminders
- Auth failure notification throttling (1-hour interval)
- Uses UNUserNotificationCenter with categories and actions
- Implements nonisolated delegate methods (proper threading)
- Error handling: Try-catch for notification scheduling
- Logging: Print statements for permission errors, throttling info

**LocationManager.swift** (281 lines)
- Handles travel time calculations using MapKit
- Geocodes addresses and calculates routes
- Caches results (5-minute TTL)
- Uses CLLocationManager for current location
- Error handling: LocationError enum (noRouteFound, geocodingFailed, permissionDenied)
- Logging: Print statements for errors
- Issue: Default fallback location hardcoded (SF coordinates)

**KeyboardShortcutManager.swift** (Not analyzed in depth, but found in codebase)
- Handles keyboard shortcuts (Cmd+Shift+M, etc.)

### 3. Service Layer

**KeychainManager.swift** (162 lines)
- Secure OAuth token storage in macOS Keychain
- Comprehensive error handling with keychainErrorMessage() mapper
- Handles duplicate item errors with cleanup + retry logic
- Detailed logging for all operations
- Uses Security framework APIs (SecItemAdd, SecItemUpdate, SecItemDelete)
- Account-specific tokens with "_access" and "_refresh" suffixes
- Accessibility level: kSecAttrAccessibleAfterFirstUnlock

**AppSettings.swift** (728 lines - largest file)
- @MainActor singleton for user preferences and app state
- iCloud Key-Value Store sync for cross-device settings
- UserDefaults fallback for local storage
- Accounts management with multi-device support
- Error handling: Silent failures with try? in JSON decoding
- Logging: Print statements for load/save operations
- ISSUE: Marked initialization with isUpdatingFromiCloud flag to prevent sync loop
- Threading: Uses defer to ensure flag reset during initialization
- Custom calendar colors management
- Login item management (LaunchAtLogin)

### 4. Models

Located in Models/ directory:
- CalendarEvent.swift - Event data structure with computed properties
- CalendarAccount.swift - Account info with auth status tracking
- CalendarInfo.swift - Calendar metadata
- NotificationTracking.swift - Notification delivery tracking
- Supporting enums: AuthStatus, CalendarProvider, MeetAppType, etc.

### 5. Views

**CalendarDropdownView.swift** (551 lines)
- Main popover UI with tab-based interface
- Tab structure: Accounts, Calendars, Settings

**MeetingRowView.swift** (359 lines)
- Individual meeting card display

**ConfigTab.swift** (520 lines)
- Settings interface for notifications, display, travel time

**CalendarsTab.swift** (479 lines)
- Calendar selection interface

**AccountsTab.swift** (245 lines)
- Account management UI

**LocationCardView.swift** (341 lines)
- Travel time display for meetings with location

**CoffeeView.swift** (210 lines)
- Coffee/tip prompting UI

---

## Existing Logging Infrastructure

### Current Logging Mechanisms

1. **print() statements (Basic Console Logging)**
   - Used throughout codebase for debugging
   - Not persistent - lost on app restart
   - Visible in Xcode console during development
   - Locations:
     - AuthManager: Token save results, auth flow status
     - CalendarDataManager: Event refresh errors
     - GoogleCalendarManager: Token expiration, API errors
     - MicrosoftCalendarManager: Token expiration, API errors
     - KeychainManager: All operations with error codes
     - LocationManager: Travel calculation errors
     - NotificationManager: Permission errors, throttling
     - AppSettings: Account load/sync operations

2. **Error Message Display Properties**
   - CalendarDataManager.errorMessage: User-facing error display
   - Shows in UI when refresh fails
   - Populated by catch blocks

3. **Status Tracking**
   - CalendarAccount.authStatus: Tracks auth state (valid, expired, needsAuth)
   - CalendarAccount.lastAuthError: Timestamp of last auth failure
   - NotificationTracking: Tracks sent notifications to prevent duplicates

4. **Apple System Logging (Not Used)**
   - No os_log or Logger imports found
   - No system unified logging implementation

### Log Output Locations
- **Runtime Logs**: Xcode console (when running under debugger)
- **Persistent Storage**: NONE - logs are not written to disk
- **iCloud**: Settings only (no logs)
- **Crash Reports**: Handled by macOS system (~/Library/Logs/DiagnosticMessages/)

---

## Identified Crash-Prone Areas

### High Priority Issues

1. **iCloud Sync Initialization Loop** (PARTIALLY FIXED)
   - Location: AppSettings.swift, lines 157-160
   - Issue: @Published properties trigger didSet during initialization
   - Mitigation: isUpdatingFromiCloud flag with defer
   - Risk: Race condition if flag not properly reset
   - Severity: MEDIUM - Could cause infinite sync loops

2. **Timer Memory Management**
   - CalendarDataManager.refreshTimer
   - NotificationManager.notificationCheckTimer
   - AppDelegate.menuBarUpdateTimer
   - Risk: Timer holds strong reference to self, preventing dealloc
   - Mitigation: Found 18 weak/unowned self uses in code
   - Usage: menuBarUpdateTimer uses [weak self] properly
   - Severity: LOW - Appears properly handled with weak captures

3. **Global Event Monitor (AppDelegate)**
   - Lines 362-366: NSEvent.addGlobalMonitorForEvents
   - Risk: Global event monitor not properly removed on app quit
   - Cleanup: stopMonitoringForClicksOutsidePopover() exists but verify called
   - Severity: MEDIUM - Could monitor events after deallocation

4. **NSAppleEventManager URL Callback**
   - Lines 31-36: Weak reference to self in handler
   - Missing: No cleanup/unsubscribe visible
   - Risk: Persistent event handlers on global manager
   - Severity: LOW-MEDIUM - Global managers typically persist

### Medium Priority Issues

5. **Keychain Manager Silent Failures**
   - KeychainManager operations return Bool, not Result
   - Callers must check return value (sometimes they don't)
   - Example: Line 26 in GoogleCalendarManager ignores delete status
   - Severity: LOW - Not critical, just poor error visibility

6. **OAuth Token Refresh Race Condition**
   - GoogleCalendarManager/MicrosoftCalendarManager retry logic
   - Multiple concurrent requests could delete token simultaneously
   - Line 119: Deletes access token if 401 received
   - Next request might not have token available
   - Severity: MEDIUM - Could cause auth failures under load

7. **Location Manager Default Fallback**
   - LocationManager.swift line 66: Hardcoded SF coordinates
   - If location unavailable, uses fixed coordinates
   - Risk: Inaccurate travel times for non-SF users
   - Severity: LOW - Functional but not ideal

8. **Notification Scheduling Race Conditions**
   - NotificationManager: 60-second timer + on-demand checks
   - Multiple notifications could be scheduled simultaneously
   - Severity: LOW - UNUserNotificationCenter handles duplicates

9. **Memory Leaks in Closures**
   - Found 18 uses of weak self appropriately
   - AppDelegate openSettings() uses DispatchQueue.main.asyncAfter
   - CoffeeView uses DispatchQueue.main.asyncAfter (5-second delay)
   - Risk: Delayed captures could retain longer than expected
   - Severity: MEDIUM - Closure captures need verification

### Lower Priority Issues

10. **Error String Interpolation**
    - Print statements with error messages in live code
    - Should use structured logging for privacy/security
    - Example: Prints account email in many places
    - Severity: LOW - Privacy concern, not crash risk

11. **Silent JSON Parse Failures**
    - try? JSONSerialization.jsonObject (compiles to nil)
    - No logging when JSON parse fails
    - CalendarDataManager line 143: Returns empty array on parse failure
    - Severity: LOW - Gracefully handles, but hard to debug

12. **DispatchQueue Usage**
    - AppDelegate line 449: asyncAfter with 0.1s delay
    - CoffeeView line ~5: asyncAfter with 5s delay
    - Risk: Weak self captured in delayed closures
    - Severity: LOW-MEDIUM - Need to verify captures

### Threading Issues

13. **MainActor Confinement**
    - Properly used: All managers marked @MainActor
    - Exception: Delegate methods properly marked nonisolated
    - Risk: Callbacks from background (location, notifications) use Task @MainActor
    - Severity: LOW - Appears properly isolated

---

## Potential Crash Scenarios

### 1. Rapid Account Addition/Removal
**Sequence:**
1. Add multiple accounts rapidly
2. CalendarDataManager observes changes via Combine
3. Multiple refreshEvents() calls triggered
4. Could exhaust API rate limits or cause concurrent modification

**Current Mitigation:** Combine sink with Task wrapping
**Risk:** MEDIUM

### 2. iCloud Sync During Initialization
**Sequence:**
1. AppSettings initializing
2. iCloud sync notification arrives
3. isUpdatingFromiCloud flag checked but timing-sensitive
4. Could trigger infinite loop

**Current Mitigation:** defer block ensures flag reset
**Risk:** MEDIUM-LOW (partially fixed)

### 3. OAuth Token Expiration Under Load
**Sequence:**
1. Multiple calendar requests in flight
2. Google/Microsoft returns 401 for all
3. Each request deletes access token
4. Race condition on token deletion
5. Retry fails to find token

**Current Mitigation:** Single retry with token deletion
**Risk:** MEDIUM

### 4. Popover/Settings Window Reference Cycles
**Sequence:**
1. Open settings window
2. Settings window closes but strong reference remains
3. settingsWindow property holds reference
4. Window never deallocated

**Current Mitigation:** isReleasedWhenClosed = false, delegate cleanup
**Risk:** LOW (appears handled)

### 5. Notification Permission Denial + Retry Loop
**Sequence:**
1. User denies notification permission
2. NotificationManager.requestNotificationPermission() retried
3. Line 49: Calls getNotificationSettings in completion
4. Could spam permission requests

**Risk:** LOW (single request per app launch)

---

## Recommendations for Crash Mitigation

### Immediate Actions (High Priority)

1. **Implement Structured Logging**
   ```
   - Replace print() with os.Logger
   - Use subsystem "com.strategicnerds.meetingnotifier"
   - Categories: auth, api, notifications, ui
   - Persist logs to disk with log levels
   ```

2. **Add Crash Reporting**
   ```
   - Integrate Firebase Crashlytics or Sentry
   - Capture stack traces for all crash types
   - Track common error conditions
   ```

3. **Audit Timer Management**
   ```
   - Verify all timers use [weak self]
   - Add invalidation in deinit methods
   - Track timer lifecycle in logging
   ```

4. **Add Synchronization for Token Operations**
   ```
   - Use serial queue for token access
   - Prevent concurrent delete/update
   - Lock around retry logic
   ```

### Medium Priority Actions

5. **Improve Error Handling**
   - Return Result types instead of Bool
   - Log all error conditions
   - Track error frequency

6. **Add Memory Profiling**
   - Monitor for reference cycles
   - Track object allocations
   - Check timer cleanup

7. **Implement Settings Validation**
   - Verify iCloud sync flag transitions
   - Add assertion checks for invalid states
   - Log state transitions

8. **Add Integration Tests**
   - Test rapid account changes
   - Test concurrent API requests
   - Test token refresh under load

### Long-term Actions

9. **Refactor Large Files**
   - AppDelegate: 615 lines (consider splitting)
   - AppSettings: 728 lines (consider splitting)
   - Views: Some exceed 500+ lines

10. **Add Comprehensive Logging**
    - Every API call (request/response)
    - Every token operation
    - Every notification scheduled
    - Every settings change

11. **Implement Telemetry**
    - Track app startup time
    - Monitor API latencies
    - Count notification deliveries
    - Track auth failures

---

## File Structure Summary

```
MeetingNotifier/
├── MeetingNotifier/
│   ├── MeetingNotifierApp.swift          [13 lines] Entry point
│   ├── AppDelegate.swift                 [615 lines] Main lifecycle & UI
│   ├── Managers/
│   │   ├── CalendarDataManager.swift     [218 lines] Event aggregation
│   │   ├── GoogleCalendarManager.swift   [362 lines] Google API
│   │   ├── MicrosoftCalendarManager.swift[328 lines] Microsoft API
│   │   ├── AuthManager.swift             [180 lines] OAuth coordination
│   │   ├── NotificationManager.swift     [260 lines] Reminders & alerts
│   │   ├── LocationManager.swift         [281 lines] Travel time
│   │   ├── KeyboardShortcutManager.swift [~60 lines] Hotkeys
│   │   ├── GoogleOAuthManager.swift      [~80 lines] Google OAuth
│   │   └── MicrosoftOAuthManager.swift   [~80 lines] Microsoft OAuth
│   ├── Services/
│   │   ├── AppSettings.swift             [728 lines] Preferences & sync
│   │   ├── KeychainManager.swift         [162 lines] Token storage
│   │   └── StoreKitManager.swift         [~50 lines] In-app purchases
│   ├── Models/
│   │   ├── CalendarEvent.swift           Event data
│   │   ├── CalendarAccount.swift         Account data
│   │   ├── CalendarInfo.swift            Calendar metadata
│   │   ├── NotificationTracking.swift    Notification state
│   │   └── ... (supporting models)
│   ├── Views/
│   │   ├── CalendarDropdownView.swift    [551 lines] Main UI
│   │   ├── MeetingRowView.swift          [359 lines] Meeting card
│   │   ├── ConfigTab.swift               [520 lines] Settings tab
│   │   ├── CalendarsTab.swift            [479 lines] Calendar selection
│   │   ├── AccountsTab.swift             [245 lines] Account management
│   │   ├── LocationCardView.swift        [341 lines] Travel info
│   │   └── CoffeeView.swift              [210 lines] Tip jar
│   └── Resources/
│       ├── Images (PNG icons for platforms)
│       ├── Audio (notification sounds)
│       └── README.md
└── [Tests, build artifacts, etc.]
```

**Total: 30 Swift files, 7,029 lines**

---

## Summary

The MeetingNotifier codebase is well-structured with proper separation of concerns using MVVM architecture. The app uses modern Swift concurrency patterns (@MainActor) correctly. However, there are several crash-prone areas:

1. **Logging**: Currently minimal - only print() statements, no persistent logging
2. **Crash Reporting**: None detected - no integration with crash analytics
3. **Error Handling**: Present but inconsistent - mix of Result types and silent failures
4. **Threading**: Generally well-handled but some potential race conditions
5. **Memory Management**: Mostly correct but several potential reference cycles

The biggest gap is the absence of any logging infrastructure to track crashes and issues in production. Implementing structured logging with os.Logger and integrating a crash reporting service should be the first priority.

