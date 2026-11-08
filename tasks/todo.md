# UI cleanup (cleanup-ui)

## Theme animation containment
- [x] Keep the selected circle's spring motion within the Appearance card by clipping at the card edge.
- [x] Tune the selection spring while keeping a visible bounce and enough room for all expanded choices.
- [x] Parse changed Swift, then coordinate build, tests, and a live UI check.

Swift parse and `git diff --check` passed. The final test suite passed 200/200 (`/tmp/meeting-notifier-ui-review/contained-theme-test.xcresult`) and the Debug build passed (`/tmp/meeting-notifier-ui-review/contained-theme-build.log`). The user reviewed the final picker before release.

## Compact theme selector
- [x] Replace the Settings theme picker with a theme name and color circle at the right edge.
- [x] Show theme choices to the left on hover or click, update the theme on selection, and collapse with motion that honors Reduce Motion.
- [x] Make the trigger and choices usable with keyboard and VoiceOver in code.
- [x] Parse changed Swift, then coordinate the Xcode build and UI check.

Changed Swift parsed and `git diff --check` passed. The final test suite and build passed. Expanded and selected states were captured from a debug build in the shared screenshots directory; the user reviewed the final containment change before release.

## Release readiness for 1.6.0
- [x] Run the full Meeting Notifier test suite and retain the result bundle.
- [x] Run available lint or static checks, then a clean build.
- [x] Inspect the selector in the running app if the desktop is available.
- [x] Publish 1.6.0 with the requested note and verify the live feed.

Final release-file checks: `xcodebuild test` passed 200 tests, with `/tmp/meeting-notifier-ui-review/release-1.6.0-final.xcresult`. A Debug build passed. The public appcast shows 1.6.0, build 23, and the exact note “Some UI cleanup.” The signed DMG and its remote enclosure both have 4,582,750 bytes. Focused SwiftLint on `ThemeSelector.swift` passed. Whole-repo SwiftLint exited 2 with 53 existing errors in other project files; this repo does not require it for release.

## Plan
- [x] Remove repeated account status and decorative controls from the meeting popover while keeping meeting and calendar actions available.
- [x] Put appearance in Settings and arrange settings in one readable column without dropping a setting.
- [x] Check labels, empty states, and the Classic menu for parity in source.
- [x] Run the repository's test and build checks, inspect the app, and keep an artifact.

## Review
- The popover keeps its meeting and calendar actions. Quit is in More options, and theme selection is in Settings > Appearance.
- Settings keeps every existing card and control in a centered single column. Hidden control labels now have accessibility names.
- `git diff --check`, a Debug build, and `xcodebuild test` passed. The final test run executed 200 tests with zero failures; see `/tmp/meeting-notifier-ui-review/cleanup-test-final.log` and its `.xcresult`. One older transcription test had contradicted the hard-timeout behavior and was corrected before the passing run.
- The edited Settings and dropdown content were captured from the running debug app in `/Users/prashant/.codex/visualizations/2026/11/08/01a1b9c1-dfc3-7aa1-8a2e-b771e8dc5c85/screenshots`. The dropdown uses a temporary preview window with test meetings; direct menu bar placement remains to check. The preview code was removed, a normal build passed, and the installed app and saved settings were restored.

# Pretty vs Classic dropdown

Port the two-style menu structure from mail-notifier. Pretty is the existing
themed SwiftUI popover. Classic is a plain `NSMenu` that follows the system
light/dark appearance.

## Plan

- [ ] `Models/MenuStyleStore.swift` — `MenuStyle` enum (pretty/classic) plus a
      UserDefaults-backed singleton, matching `ThemeStore`'s shape.
- [ ] `TelemetryEvent` — add `menu_style_changed`.
- [ ] `Views/ClassicMenuBuilder.swift` — builds the classic dropdown: day
      sections, one row per meeting, a flyout per meeting whose first item is
      "Join Google Meet" / "Join Zoom" / etc.
- [ ] `Views/ClassicMenuFooterView.swift` — AppKit icon strip at the bottom
      (refresh, window, settings, transcription, quit).
- [ ] `Views/Components/MenuStylePicker.swift` — two tiles with miniatures.
- [ ] `AppDelegate+Menu.swift` — becomes the right-click menu only; the meeting
      rows move to `ClassicMenuBuilder`.
- [ ] `AppDelegate.swift` — route left-click by style, right-click to the
      right-click menu.
- [ ] `SettingsDrawer.swift` — a "Dropdown style" card holding the picker.
- [ ] Add all new files to `project.pbxproj`.
- [ ] Build and run the test suite.

## Day vs day-ahead

"Today" lists the meetings left today. Once nothing is left today, the Today
section drops out entirely and Tomorrow leads the menu, so an evening click
shows the day ahead rather than an empty header.

## Review

(filled in when the work lands)

## Review (2026-08-05)

Done. `MenuStyleStore` persists the choice in UserDefaults, matching
`ThemeStore`. Left-click routes through `toggleDropdown()`, so the keyboard
shortcut and the notification honour the style too. Right-click now has its own
menu (it had none before) and the previously dead `createNativeMenu` became it.

The classic dropdown gets its day split for free: `CalendarDataManager` already
filters events through `EventWindow`, which drops tomorrow before 5 PM.

Not done: the test runner fails to launch (`test runner hung before
establishing connection`) on clean `main` as well, so it is not from this work.
