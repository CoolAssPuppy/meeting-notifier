# MeetingNotifier

A native macOS menu bar app that keeps you on top of your calendar meetings, transcribes them on-device, and saves clean markdown notes you can keep forever.

![macOS](https://img.shields.io/badge/macOS-26.0+-blue)
![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![License](https://img.shields.io/badge/license-Custom-green)

## Features

- **Multi-account calendars**: Connect any number of Google and Microsoft accounts.
- **Smart menu bar**: Next meeting, countdown, count badge, peek window — pick what you see.
- **One-click join**: Zoom, Google Meet, Microsoft Teams, Webex.
- **Keyboard shortcuts**:
  - `⌘⇧M` join next meeting
  - `⌘⇧O` toggle the popover
  - `⌘⇧R` refresh meetings
- **Notifications**: Customizable per-event reminders plus a 1-minute warning. Time-sensitive interruption level so they reach you on Focus.
- **Travel time alerts**: For meetings with a physical address, calculates driving / walking / transit time from your location and reminds you when to leave.
- **Double-booking handling**: Pick "fewer attendees" or "more attendees" as the tiebreaker; the menu bar follows your preference.
- **On-device transcription**: Apple SpeechAnalyzer for free / no API key, or Deepgram if you supply a key. System audio is captured via ScreenCaptureKit so remote participants are transcribed too.
- **AI meeting summaries**: Bring your own OpenAI / Anthropic / Gemini key. Output is a markdown note with a summary and action items, saved to a folder you choose.
- **Sparkle auto-update**: Signed updates over EdDSA — no App Store required.
- **iCloud settings sync**: Optional. Off by default for privacy-conscious users; tokens never leave your device either way.
- **Ten themes**: Light and dark palettes including Hoth, Risa, Cylon, Vader, Hermione, and a Strategic Nerds brand theme.

## Quick start

### Requirements

- macOS 26.0 (Tahoe) or later
- Xcode 26 or later (Swift 6.0 toolchain)
- A Google or Microsoft account for OAuth
- Optional: an OpenAI / Anthropic / Gemini API key for meeting summaries
- Optional: a Deepgram API key if you prefer that over Apple's on-device engine

### Build from source

```bash
git clone https://github.com/coolasspuppy/meeting-notifier.git
cd meeting-notifier/MeetingNotifier
xcodegen generate     # regenerates MeetingNotifier.xcodeproj from project.yml
open MeetingNotifier.xcodeproj
```

In Xcode, set your development team in **Signing & Capabilities**, then `⌘R`. The app appears as a menu-bar icon (no Dock icon — `LSUIElement: true`).

The project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) — install with `brew install xcodegen`. The Xcode project is regenerated from `MeetingNotifier/project.yml` rather than checked in by hand.

### OAuth setup

#### Google

1. Open [Google Cloud Console](https://console.cloud.google.com/apis/credentials).
2. Create or select a project, enable **Google Calendar API**.
3. Create an **OAuth 2.0 Client ID** of type **Desktop app**.
4. Update `MeetingNotifier/MeetingNotifier/Managers/GoogleOAuthManager.swift:9` with your client ID. Desktop OAuth apps don't require a client secret — `GoogleOAuthSecret.swift` can be left empty (PKCE handles auth security).

#### Microsoft

1. Open [Azure Portal — App Registrations](https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps).
2. **New registration** → name it MeetingNotifier, supported types = "Accounts in any organizational directory and personal Microsoft accounts".
3. Redirect URI: select **Public client/native** with `msauth.com.strategicnerds.meetingnotifier://auth`.
4. Add API permissions: `Calendars.Read`, `User.Read`.
5. Update `MicrosoftOAuthManager.swift:9` with your application (client) ID. Public clients use PKCE — no client secret needed.

If you do have legacy "confidential client" OAuth apps that still require a secret, copy the templates and fill them in:

```bash
cd MeetingNotifier/MeetingNotifier/Managers
cp GoogleOAuthSecret.swift.template GoogleOAuthSecret.swift
cp MicrosoftOAuthSecret.swift.template MicrosoftOAuthSecret.swift
```

These files are gitignored.

### Optional: PostHog telemetry

Anonymous usage events (account added, meeting joined, app launched) are captured via PostHog. Capture is opt-out and silently disabled when no API key is present. To wire your own project:

```bash
export POSTHOG_API_KEY=phc_yourKeyHere
xcodegen generate
```

The key is read from your shell environment at `xcodegen` time. There is **no key checked in** — forks and dev builds default to silent telemetry.

## Architecture

MeetingNotifier is a SwiftUI-on-AppKit menu bar app. Notable choices:

- **Hardened Runtime is on; App Sandbox is off.** The app polls CoreAudio for mic activity, captures system audio via ScreenCaptureKit, and writes to a user-chosen notes folder via security-scoped bookmarks. App Store sandbox enforcement isn't compatible with system-audio capture for transcription, so distribution is via Developer ID + Sparkle instead.
- **Tokens stay on this device.** OAuth access and refresh tokens live in the macOS Keychain and never sync. AI provider API keys (OpenAI / Anthropic / Gemini / Deepgram) sync via iCloud Keychain so you only need to enter them once across your Macs.
- **Settings sync is opt-in.** Off → device-local. On → preferences mirror across your Macs via NSUbiquitousKeyValueStore (no tokens, no transcript content).
- **Transcription is local-first.** Apple's SpeechAnalyzer runs on-device. If you opt into Deepgram, audio leaves the machine over TLS to their endpoint; otherwise, no audio ever leaves.
- **Mic-active detection is event-driven.** CoreAudio property listeners fire the moment any input device starts running, so transcription auto-starts immediately when you join a meeting (with a 5s safety-net poll as a fallback).

### Where things live

```
MeetingNotifier/
├── project.yml                          # XcodeGen source of truth
└── MeetingNotifier/
    ├── AppDelegate*.swift               # Menu bar, popover, native menu, drawers
    ├── Managers/
    │   ├── AuthManager.swift            # OAuth orchestration
    │   ├── GoogleOAuthManager.swift
    │   ├── MicrosoftOAuthManager.swift
    │   ├── OAuthRefreshSupport.swift    # Shared refresh-token flow
    │   ├── GoogleCalendarManager.swift  # Calendar API client (Codable)
    │   ├── MicrosoftCalendarManager.swift
    │   ├── CalendarDataManager.swift    # Aggregator + 5-min refresh + travel-time fanout
    │   ├── NotificationManager.swift    # UNUserNotifications + 1-minute warning
    │   ├── LocationManager.swift        # MKDirections-backed travel time
    │   ├── KeyboardShortcutManager.swift
    │   ├── MeetingDetector.swift        # CoreAudio property listeners → mic-activity events
    │   ├── AudioCaptureManager.swift    # AVAudioEngine mic tap + RMS for waveform
    │   ├── SystemAudioCapturer.swift    # ScreenCaptureKit "Others" stream
    │   ├── SystemAudioEnergyTracker.swift
    │   └── TranscriptionCoordinator.swift  # Session lifecycle + auto-offer
    ├── Models/
    │   ├── CalendarAccount.swift
    │   ├── CalendarEvent.swift
    │   ├── CalendarInfo.swift
    │   ├── CalendarAPIResponses.swift   # Codable response shapes for both providers
    │   ├── CalendarError.swift
    │   ├── EventWindow.swift            # 5pm-cutoff window for "today / today + tomorrow"
    │   ├── SettingsEnums.swift
    │   ├── NotetakerEnums.swift
    │   ├── ThemeStore.swift             # 10 palettes
    │   └── TranscriptDocument.swift
    ├── Services/
    │   ├── AppSettings.swift            # User prefs + iCloud KV sync
    │   ├── AppSettings+iCloudSync.swift
    │   ├── KeychainManager.swift
    │   ├── CalendarManagerSupport.swift # fetchAuthorizedJSON<T> helper
    │   ├── AISummarizer.swift           # OpenAI / Anthropic / Gemini
    │   ├── TranscriptFormatter.swift    # Markdown frontmatter + body
    │   ├── TranscriptRecoveryStore.swift
    │   ├── SubfolderResolver.swift
    │   ├── Telemetry.swift              # PostHog facade
    │   ├── UpdaterManager.swift         # Sparkle wrapper
    │   ├── URLOpener.swift
    │   ├── URL+Required.swift
    │   ├── MeetingLinkParser.swift
    │   ├── Logger.swift
    │   └── Formatters.swift
    └── Views/                           # SwiftUI: popover, drawers, banner, settings
```

## Privacy

- **OAuth tokens**: macOS Keychain only, never iCloud, never disk.
- **AI API keys**: iCloud Keychain so they sync across your Macs (you control via System Settings → Apple ID → iCloud → Passwords & Keychain).
- **Transcripts**: written to the folder you choose. Nothing is uploaded for AI summarization unless you've configured a provider key, and even then only the transcript text + meeting title goes out.
- **Telemetry**: anonymous, opt-out, no PII (no emails, no URLs, no transcript content). Disabled entirely when no API key is built in.
- **iCloud sync**: gated by a single user-facing toggle. Off = nothing leaves the device.

## Auto-update

Sparkle handles updates. The release process publishes a signed DMG to `https://coolasspuppy.com/meeting-notifier-updates`; the app checks daily and prompts the user with release notes before installing. Public EdDSA verification key is baked into `project.yml`.

## Distribution

The published builds are signed with a Developer ID certificate, notarized by Apple, and distributed via the Sparkle feed (not the App Store). The current version + build number live in `project.yml` (`CFBundleShortVersionString`, `CFBundleVersion`).

## Contributing

PRs welcome. A few rules:

1. The project is regenerated from `project.yml` — don't hand-edit `MeetingNotifier.xcodeproj`. Run `xcodegen generate` before committing.
2. Keep tests passing: `xcodebuild -scheme MeetingNotifier -destination 'platform=macOS' test`.
3. Don't introduce new force-unwraps for URLs; use `URL.required(_:)` for hardcoded literals.
4. New settings should follow the `readBool / readEnum / applyBool / applyEnum` helper pattern in `AppSettings`. The point is that adding a setting is a one-line edit per call site, not five.

## License

Custom Open Source License — see [LICENSE](LICENSE). You can fork and customize for personal use, but redistribution through the App Store requires permission. This protects the official MeetingNotifier while keeping the code open for learning.

## Credits

Built with Swift, SwiftUI, AppKit, [AppAuth-iOS](https://github.com/openid/AppAuth-iOS), [Sparkle](https://sparkle-project.org/), and [PostHog](https://posthog.com/).

Made by Strategic Nerds, Inc.

---

**Copyright © 2026 Strategic Nerds, Inc. All rights reserved.**
