# Design revamp: one unified UI for Meeting Notifier

This document is the companion to `theme-revamp.md`. `theme-revamp.md` covers the 10-theme palette system, ported from Mail Notifier. This document covers everything else — the shape of the app.

The goal: kill the `simple` vs `glass` duality, adopt Mail Notifier's surface shapes, and add one new surface that Mail Notifier doesn't have: a **Transcription drawer**.

Reference mockups live in the `Meeting Notifier` Paper file:
- Menu Popover — Kirk
- Main Window — Account Config — Kirk
- Main Window — Settings Drawer Open — Kirk
- Main Window — Transcription Drawer Open — Kirk
- Floating Widgets — Kirk

All designs were mocked in the `Kirk` theme (dark navy + Starfleet gold). The other 9 themes recolor automatically through the palette.

## What changes, at a glance

| Today | After |
|---|---|
| Menu popover has two rendering modes (`.simple` / `.glass`) selected in settings | One popover. Theme-driven. |
| Settings opens in a separate `NSWindow` with 4 tabs (Accounts, Calendars, Notes, Setup) | Main window is account management. Settings and Transcription live in two separate drawers that slide from the top of that window. |
| `NotetakerTab` buried inside settings | Transcription drawer — a first-class surface, reachable from both the popover footer and the main window sidebar footer. |
| Inline hardcoded colors, `.regularMaterial`, `.ultraThinMaterial`, platform-specific gradients | Every color reads from `theme.*`. Materials are gone. |
| `PeekWindowPanel` and `TranscriptionBannerPanel` visually disconnected from rest of app | Both repainted with palette tokens, gain a waveform/record indicator coherent with the rest. |

## Four surfaces

### 1. Menu bar popover

Width 380px, fixed. Three zones: header, body, footer.

**Header** (`theme.surface` band, 1px `theme.divider` separator):
- 26×26 gradient brand mark (`primary` → `primaryDeep`) with a calendar glyph in `primaryForeground`.
- App title (13 semibold) + status line ("Watching N calendars" with a `success` dot).
- On the right: a next-meeting pill in `warning` tones ("IN 7 MIN" + clock glyph). Hidden when nothing is scheduled.

**Body** (`theme.background`, scrollable):
- Section labels (`TODAY · TUE APR 21`, 10 tracking-wide `tertiary`) + right-aligned "Updated HH:MM" when data is fresh.
- Meeting rows (replaces both `MeetingRowView` and `SimpleMeetingRowView`).
  - 3px calendar stripe on the left (calendar color).
  - Top row: status badge (`LIVE` in `destructive` tones with pulsing dot / `IN N MIN` in `warning` tones / time only) · start-end time · platform chip on the right.
  - Title, 14 semibold, two-line max.
  - Meta row: calendar dot · calendar name · attendee count.
  - Physical-location rows gain a LocationCard (inset `cardInset` box with venue name + address).
- Empty state: brand-gradient rounded-rect icon (56×56) centered, muted "No meetings today" subtitle, primary "Add account" capsule button.

**Footer** (`theme.surface` band, 1px `theme.divider` separator, 36px):
- Left cluster: refresh, open-main-window (shown with `cardElevated` background when the window is open), settings-gear, transcription-waveform. All `AppIconButton`.
- Center: `ThemeStrip` — 10 dots, hover-expand, bouncy spring.
- Right: quit (destructive-tinted).

No theme-selector tabs anywhere else in the app. The popover footer is the single source of truth.

### 2. Main window — account configuration

Min size 880×580, `titlebarAppearsTransparent`, `fullSizeContentView`, `isMovableByWindowBackground`. Window appearance and background colored live via a `WindowChrome: NSViewRepresentable` that re-applies on every palette update.

**Sidebar**, 260px, `theme.surface`:
- Brand mark + app title + version/status line ("1.2.0 · Up to date").
- Section label `ACCOUNTS` with a warning-tinted unread count pill.
- Account rows. One row per connected provider account:
  - 22×22 provider badge (Google multicolor / Microsoft four-square / etc.) in a `cardElevated` square.
  - Display name (12 semibold) + meta ("Google · 3 calendars").
  - Trailing: upcoming-meetings pill (`warning` background, count in `primaryForeground`) OR `OFF` capsule if account disabled.
  - Selected: `primary` 10% fill + 25% primary stroke + full-opacity text.
- Footer: dashed-border "Add account" button + settings gear (opens settings drawer) + transcription waveform (opens transcription drawer).

**Content area** (right of the sidebar): displays the selected account, or a welcome/onboarding state if no account selected.

**Account detail** layout:
- Header band (28px h-padding, 18px v-padding, 1px `theme.divider` on bottom): 44×44 provider badge · identity stack (display name 17 semibold + meta row: provider label · `success` connected dot · last sync time) · header buttons (refresh + open provider in browser).
- Two-column scroll of cards:
  - **IDENTITY** — display name text field (inset input), monospaced account email (selectable, not editable).
  - **CALENDARS** — list of every calendar on the account. Color swatch (14×14 square), title + subtitle ("Primary · owner" / "Shared with team@"), trailing `AppToggle`. Hair-thin `dividerSubtle` separators.
  - **NOTIFICATIONS** — lead-time stepper, sound picker with preview, auto-join toggle.
  - **ACCOUNT MANAGEMENT** — sync toggle, reauthorize secondary button, destructive "Remove" row.

### 3. Settings drawer

Slides from the top of the main window. Animation: `easeOut(duration: 0.26)` for `move(edge: .top) + opacity`. Backdrop: `Color.black.opacity(0.55)`, tap-to-close, escape-key-to-close. Shape: `UnevenRoundedRectangle` with rounded bottom corners only (14px).

**Header**: 34×34 `card` icon square holding a gold gear · title "Settings" (18 semibold) · subtitle "General preferences · shortcuts · updates" · circular close button top-right.

**Body**, two-column grid:

Left column:
- **GENERAL** — Launch at login · Open window on launch · Double-booking preference picker (Prefer accepted / Prefer organizer / Show both).
- **MENU BAR** — Display mode segmented control (Icon / Title / Peek) · Urgent color toggle · Meeting link app picker.

Right column:
- **KEYBOARD SHORTCUTS** — Join next meeting recorder · Show meeting popover recorder.
- **UPDATES** — trailing "UP TO DATE" / "UPDATE AVAILABLE" pill · Auto-check toggle · Version (monospace) + "Check now" button.
- **SUPPORT** — donation copy · "Buy me a coffee" gradient button · "Star on GitHub" secondary button.

No transcription settings here. Drawer has no theme selector.

### 4. Transcription drawer (new)

Same geometry as the settings drawer. Different icon in the header (gold waveform). Header gets an extra right-side pill: live recording state.

- When not recording: `NOT RECORDING` in destructive-tinted pill.
- When recording: flashing red dot + `● RECORDING — 12:04` in destructive tones (same pill, active state).

**Body**, two-column:

Left column:
- **RECORDING** — Enable transcription toggle · Auto-offer on join toggle · Status indicator segmented control (Icon / Banner / Both).
- **ENGINE** — Three engine options as radio cards: Apple Speech (BUILT-IN badge, success-tinted) / Wispr Flow (API KEY badge, warning-tinted) / Deepgram (API KEY badge). Active engine gets `primary` tinted fill + primary ring. Locale picker below.

Right column:
- **OUTPUT** — Notes folder picker (folder icon in primary, monospace path, "Change" affordance) · Subfolder per calendar toggle · File name template row with "Edit" · Front matter toggle.
- **SUMMARIZATION** — Generate summary toggle · Provider picker (Anthropic / OpenAI / Gemini) · API key field with a `STORED IN KEYCHAIN` success pill and masked monospace value + "Update" action.
- **SPEAKERS** — "Me" row (gradient initials avatar + text field for my label) · "Everyone else" row (group icon + default label field) · Dedupe echo toggle.

**Why split settings and transcription?** The transcription surface is conceptually different work: it affects what gets saved to disk, how audio is handled, which API keys you paid for. Grouping it with launch-at-login would bury it. Two drawers keep each surface focused.

### 5. Floating widgets

**Peek window** (`NSPanel`, non-activating, float level) — mount point stays the same as `PeekWindowPanel.swift`. The SwiftUI view inside gets redrawn.
- Background: `theme.surface` at 92% alpha (so the desktop shows through subtly).
- 1px `theme.border`.
- Layout: warning-tinted "N MIN" time pill + title + primary gold join-arrow button.
- ~320px wide, 32px tall.

**Transcription banner** (`NSPanel`, float level) — mount point stays the same as `TranscriptionBannerPanel.swift`.
- Background: `theme.surface` at 95% alpha + destructive-tinted border + soft destructive glow (box-shadow).
- Layout: recording dot (destructive-tinted ring + solid dot) · mini waveform (bar chart driven by audio energy, gold peaks on a muted baseline) · title + meta line (mono timer `● 12:04` + engine name + speaker count) · pause + stop buttons.
- ~420px wide, auto height.

## Architecture — what to build, in what order

The theme plumbing is covered in `theme-revamp.md`. Do that first. The rest is structural:

### Phase 1: kill the duality

1. Delete `CalendarDropdownView+GlassStyle.swift` and `CalendarDropdownView+SimpleStyle.swift`.
2. Delete `SimpleMeetingRowView.swift` (merge the best bits into the new `MeetingRowView`).
3. Remove `DropDownStyle` from `SettingsEnums.swift` and drop the toggle from `AppDelegate.swift` (lines ~98–111 where popover size/content is chosen).
4. `CalendarDropdownView.swift` becomes the one popover root.

### Phase 2: build shared components

Create `Views/Components/SharedComponents.swift` mirroring Mail Notifier's:
- `AppCard`, `AppSettingRow`, `AppRowDivider`
- `AppSecondaryButton`, `AppPrimaryButton`, `AppIconButton` (with `AppButtonTint` enum: `foreground` / `primary` / `destructive`)
- `AppToggle` wrapping `Toggle().tint(theme.primary)`
- `AppPicker`, `AppTextField`, `AppStepper`, `AppSegmentedControl`
- `ProviderBadge` sized `.default(24)` / `.accountView(38)` / `.menuBar(22)` / `.big(44)`
- `ThemeStrip` (hover-expand dot group — copy verbatim from theme-revamp.md)
- `BrandMark` (gradient calendar glyph)

All read `@Environment(\.theme) private var theme`. None reference `Color.app*` or raw hex.

### Phase 3: restructure windows

Create:
- `Views/MainView.swift` — top-level root with `@ObservedObject ThemeStore.shared`, holds the `HSplitView` + drawer overlays.
- `Views/Sidebar.swift` — accounts list and footer buttons.
- `Views/AccountView.swift` — right-pane content.
- `Views/WelcomeView.swift` — onboarding shown when no account is selected.
- `Views/SettingsDrawer.swift` — top-slide drawer housing the General / Menu Bar / Keyboard / Updates / Support cards (content moves from `ConfigTab*`).
- `Views/TranscriptionDrawer.swift` — top-slide drawer housing Recording / Engine / Output / Summarization / Speakers cards (content moves from `NotetakerTab*`).
- `Views/WindowChrome.swift` — the `NSViewRepresentable` that updates `window.backgroundColor`, `appearance`, `titlebarAppearsTransparent`, `fullSizeContentView`, `isMovableByWindowBackground` on palette change.

Delete `SettingsView.swift` — no more tab container. Delete `AccountsTab.swift`, `CalendarsTab.swift`, `ConfigTab*`, `NotetakerTab*`, `NotificationsTab.swift` — their contents migrate into the drawers and account detail.

In `AppDelegate.swift`:
- Main window becomes a regular themed window hosting `MainView`.
- Menu bar popover hosts the new unified `MenuBarPopover` view.
- Keep `PeekWindowPanel` and `TranscriptionBannerPanel` as `NSPanel` hosts, but their SwiftUI trees get the new views + the `ThemeStore` environment wiring (the same `@ObservedObject + .environment(\.theme, ...)` pattern from theme-revamp.md §4).

### Phase 4: reskin the floating widgets

- `PeekWindowView.swift`: rewrite with theme palette. Mounted inside `PeekWindowPanel`.
- `TranscriptionBannerView.swift`: rewrite with theme palette + mini waveform driven by the existing `SystemAudioEnergyTracker`. Honors the "Dedupe echo" state and the engine label.

### Phase 5: purge

After each phase, `grep -rn 'Color\.app\|\.ultraThinMaterial\|\.regularMaterial\|\.regularMaterial\|Material(' Views/`. Anything that matches is a bug — material backgrounds do not belong in a themed app, they fight the palette.

## The transcription drawer — why this is the novel idea

Mail Notifier's shape is: popover + main window + one drawer. I'm proposing we make this app's shape: popover + main window + **two drawers**.

The reason is that transcription is a real second surface:
- It has its own runtime state (recording / not / paused).
- It has its own status UI (the floating banner).
- It has its own API key management (Wispr, Deepgram, Anthropic, OpenAI).
- It has its own output concerns (folder on disk, markdown format, YAML front matter).

Jamming it into a "Settings" tab makes it feel subordinate. A peer drawer makes it a peer surface. The popover footer surfaces both icons side by side (gear + waveform) which gives users a clear mental model: *general settings* vs *transcription workspace*.

The drawer mechanic also means opening transcription does not require switching windows or losing the account context behind it — you drop down, tweak a key, close, keep working.

## Visual checklist before shipping

From the review loop — when all 10 themes are wired up, switch between them and verify:
- Popover header brand-mark gradient updates (primary → primaryDeep per theme).
- Active `ThemeStrip` dot ring is readable on every ground.
- Account row "selected" state uses `primary` tint, not a hardcoded blue.
- Calendar stripe colors on meeting rows come from the calendar's chosen color (not palette) — those should NOT theme, they're per-calendar.
- Recording banner's red destructive glow recolors properly on `Hermione` / `Kirk` (palettes whose destructive is tuned per-theme).
- Peek window blur/alpha stays legible in `Hoth` (very light ground) and `Nerds` (pure black ground).
- System theme follows macOS Appearance flips within one runloop tick — same KVO test from theme-revamp.md §8.
