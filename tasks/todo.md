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
