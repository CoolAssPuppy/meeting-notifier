import Foundation

/// Every event Meeting Notifier sends, named once.
///
/// Naming: `object_action`, snake_case, action in the past tense.
///
/// These were dot-separated (`account.added`) until 2026-07. PostHog treats the
/// dot as an ordinary character, so nothing broke, but the names sorted oddly
/// and matched nothing in the other apps. Events captured before the rename
/// keep their old names in PostHog forever; build an Action spanning both
/// spellings if you need a metric across the cut.
///
/// A typed enum rather than raw strings because a typo in a string literal is a
/// silent second event in PostHog that nobody notices for months.
enum TelemetryEvent: String {
    case accountAdded = "account_added"
    case accountSigninFailed = "account_signin_failed"
    case appLaunched = "app_launched"
    case meetingJoinClicked = "meeting_join_clicked"
    case menuOpened = "menu_opened"
    case notificationClicked = "notification_clicked"
    case notificationShown = "notification_shown"
    case shortcutUsed = "shortcut_used"
    case updateInstalled = "update_installed"
}
