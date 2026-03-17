# Meeting transcription and note-taking feature plan

## The problem

Granola charges $18/month. Notion AI charges $10/month per seat. Otter.ai charges $16.99/month. All of them force you into their ecosystem, their note format, their storage. You just want your meeting transcribed, speaker-labeled, and saved as a Markdown file where you tell it to go.

## How it works today

The meeting-notifier app already knows about your meetings. It pulls events from Google and Microsoft calendars, shows them in the menu bar, and tracks which ones are happening right now via `CalendarEvent.isHappening`. The app has no audio capabilities today.

## What we're building

A transcription feature that:

1. Detects when a meeting is active (mic/camera open during a calendar event, though we also want to detect mic/speaker and pop the alert when there is no calendar event to accommodate impromptu meetings)
2. Asks if you want to transcribe
3. Captures both your mic and the meeting's audio as separate streams
4. Transcribes in real time with speaker separation
5. Saves structured Markdown notes with YAML front matter to a user-specified folder

---

## Technical research findings

### Audio capture on macOS

**Two streams needed:** microphone input (you) and system audio (everyone else).

| Method | macOS version | Permissions | Notes |
|--------|--------------|-------------|-------|
| AVAudioEngine (mic) | 13+ | Microphone | Standard mic capture. Well-documented. |
| Core Audio Taps (system) | 14.2+ | Audio Capture | New API for tapping process or system audio. No kernel extensions. |
| ScreenCaptureKit (system) | 13+ | Screen & System Audio Recording | More mature but heavier permission ask. |
| BlackHole virtual device | Any | None (user installs driver) | Too much setup for end users. |

**Decision: AVAudioEngine for mic + Core Audio Taps for system audio.** This gives us the narrowest permission scope and the cleanest separation. Core Audio Taps (macOS 14.2+) is the right call since the app already targets recent macOS. If we need to support macOS 13, fall back to ScreenCaptureKit for system audio.

Required entitlements:
- `com.apple.security.device.audio-input` (microphone)
- `NSAudioCaptureUsageDescription` in Info.plist (system audio via Core Audio Taps)
- `NSSpeechRecognitionUsageDescription` in Info.plist (for SpeechAnalyzer)

### Transcription engine options

#### Apple SpeechAnalyzer (macOS 26, shipped)

Apple's first-party on-device transcription framework. Ships with macOS 26 Tahoe. Free, private, fast. This is the recommended default engine.

**API surface:**

| Class | Purpose |
|-------|---------|
| `SpeechAnalyzer` | Session manager. Routes audio buffers through modules. |
| `SpeechTranscriber` | Speech-to-text module. Two presets: `.offlineTranscription` and `.progressiveLiveTranscription`. |
| `SpeechDetector` | Voice activity detection (VAD). Detects speech presence without transcribing. |
| `DictationTranscriber` | Fallback for unsupported hardware/languages. Same as legacy `SFSpeechRecognizer`. |
| `AssetInventory` | Language model download management. Models are system-wide, shared across apps. |
| `AnalyzerInput` | Wrapper around `AVAudioPCMBuffer` for streaming audio into the analyzer. |

**Key capabilities:**
- Real-time streaming via `AsyncStream<AnalyzerInput>` fed to `analyzer.start(inputSequence:)`
- Volatile (partial) results and final results via `transcriber.results` AsyncSequence
- Audio timestamp attribution via `.audioTimeRange` attribute option (sample-accurate `CMTimeRange`)
- 43 locales supported (en_US, en_GB, ja_JP, zh_CN, etc.)
- On-device only, no data leaves the machine
- Models downloaded on demand via `AssetInventory`, stored system-wide

**Performance (M4 Mac mini benchmarks):**
- 70x real-time (1 second of wall clock processes 70 seconds of audio)
- 34-minute file transcribed in 45 seconds (vs. 1:41 for Whisper Large V3 Turbo)
- 14.0% WER on earnings22 dataset (comparable to WhisperKit base.en at 15.2%)

**Audio pipeline for live transcription:**

```swift
// 1. Get required format
let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])

// 2. Create input stream
let (inputSequence, continuation) = AsyncStream<AnalyzerInput>.makeStream()

// 3. Tap AVAudioEngine, convert to analyzer format, yield AnalyzerInput
audioEngine.inputNode.installTap(onBus: 0, bufferSize: 4096, format: nodeFormat) { buffer, _ in
    let converted = try converter.convertBuffer(buffer, to: format)
    continuation.yield(AnalyzerInput(buffer: converted))
}

// 4. Start analyzer
try await analyzer.start(inputSequence: inputSequence)

// 5. Read results
for try await result in transcriber.results {
    if result.isFinal { finalText += result.text }
}
```

**Limitations:**
- No speaker diarization (must use separate library or two-channel approach)
- No language auto-detection (must specify locale)
- No custom vocabulary (proper nouns may be less accurate)
- macOS 26+ only (no backward compat)
- Falls back to `DictationTranscriber` on older hardware

**Required permissions:**
- `NSSpeechRecognitionUsageDescription` in Info.plist
- `NSMicrophoneUsageDescription` in Info.plist
- Speech Recognition capability in Xcode Signing & Capabilities

#### Wispr Flow API (premium cloud option)

Wispr is not standard speech-to-text. It's a voice interface that combines ASR with LLM post-processing. The pipeline: ASR inference (<200ms) then LLM inference (<200ms, fine-tuned Llama on Baseten) then delivery. Total <700ms p99. The LLM layer auto-removes filler words, fixes self-corrections ("let's meet at 6, actually 7" becomes "Let's meet at 7"), adds punctuation, and adapts tone based on application context.

**Access:** Currently limited to enterprise partners. Contact enterprise@wisprflow.ai. API keys from platform.wisprflow.ai.

**Base URL:** `https://platform-api.wisprflow.ai/api/v1/dash/`

**Authentication:**
- Org API key: `Bearer fl-xxxxxx` (server-side)
- Client JWT tokens (recommended, lower latency): generated via `/generate_access_token`

**REST endpoints:**
- `POST /api` (org key auth)
- `POST /client_api` (client token auth)

**WebSocket endpoints (recommended):**
- `wss://platform-api.wisprflow.ai/api/v1/dash/ws?api_key=Bearer%20<KEY>` (org key)
- `wss://platform-api.wisprflow.ai/api/v1/dash/client_ws?client_key=Bearer%20<KEY>` (client token)

**Audio format:** 16kHz mono PCM WAV, base64 encoded. Max 25MB / 6 minutes per REST request. WebSocket streams in ~50ms chunks.

**WebSocket protocol:**
1. Connect
2. Send auth message with language and context
3. Stream audio via `append` messages (position-tracked, packets array with volumes)
4. Send `commit` with total packet count
5. Receive partial and final transcription responses

**Context schema (what makes Wispr special):**

```json
{
  "context": {
    "app": { "name": "MeetingNotifier", "type": "other" },
    "dictionary_context": ["Supabase", "Prashant", "standup"],
    "user_first_name": "Prashant",
    "user_last_name": "Sridharan",
    "conversation": {
      "participants": ["Alice", "Bob"],
      "messages": [...]
    }
  }
}
```

You can feed it meeting attendee names via `dictionary_context` and participant names via `conversation.participants` to improve proper noun accuracy.

**What Wispr does NOT do:**
- No speaker diarization (single-speaker dictation focus)
- No on-device/offline mode
- No published per-minute pricing (token-based, credits system)
- No official Swift SDK

**What Wispr does better than anyone:**
- Polished output. Text reads like it was typed, not spoken.
- Filler removal, self-correction handling, contextual tone adaptation.
- Sub-700ms end-to-end latency with LLM processing included.
- 100+ languages with code-switching support.

#### Other engines (comparison)

| Engine | Cost | Latency | Diarization | Offline | Best for |
|--------|------|---------|-------------|---------|----------|
| **Apple SpeechAnalyzer** | Free | 70x real-time | No | Yes | Default. Fast, private, free. |
| **Wispr Flow** | Token-based | <700ms | No | No | Polished output, auto-editing. |
| **WhisperKit** | Free (base) | Near real-time | Via SpeakerKit ($) | Yes | Fallback for pre-macOS 26. |
| **Deepgram** | $0.46/hr | <300ms | Yes, built-in | No | True multi-speaker diarization. |
| **AssemblyAI** | $0.45/hr | Real-time | Yes, best accuracy | No | Best diarization error rate (2.9%). |
| **OpenAI Whisper API** | $0.36/hr | Batch only | No | No | Post-processing only. |

### Transcription engine decision

**Tiered approach with Apple SpeechAnalyzer as the default:**

1. **Default (free, on-device):** Apple SpeechAnalyzer with `.progressiveLiveTranscription` preset. Free, fast, private. Two-channel speaker separation (mic = "Me", system audio = "Others"). No third-party dependencies.

2. **Premium option 1 -- Wispr Flow:** For users who want polished, auto-edited output. Filler removal, self-correction handling, contextual formatting. User provides API key. Best output quality, but single-speaker (no diarization).

3. **Premium option 2 -- Deepgram:** For users who need true multi-speaker diarization. Identifies individual remote speakers. User provides API key.

4. **Fallback (pre-macOS 26):** WhisperKit for users on macOS 14/15. On-device, free, but requires model download.

### Detecting mic/camera activity

No official Apple API for "is the microphone currently in use by another app." Available approaches:

1. **CoreAudio property listeners** -- monitor `kAudioDevicePropertyDeviceIsRunningSomewhere` on input devices. Fires when any app starts/stops using the mic.
2. **IOKit camera detection** -- monitor camera device nodes for active state changes.
3. **SpeechDetector (macOS 26)** -- Apple's voice activity detection module. Can detect speech presence in an audio stream without transcribing. Configurable sensitivity level.

**Decision: CoreAudio property listener for mic + IOKit for camera.** When triggered:
- If a calendar event is happening or starting within 5 minutes, prompt with the meeting title: "Transcribe 'Weekly Standup'?"
- If no calendar event matches, still prompt: "Transcribe this meeting?" with a text field to name it (defaults to "Untitled Meeting" with timestamp).

This handles both scheduled and impromptu meetings.

### Speaker identification without meeting platform APIs

True speaker identification (matching voices to attendee names) would require either:
- Connecting to Zoom/Meet/Teams APIs (complex, per-platform, requires OAuth per service)
- Voice fingerprinting (train on each speaker's voice over time, like Otter.ai)
- Manual labeling by the user after the fact

**Decision for v1:** Two-channel approach.
- Mic input = labeled "Me" (use the user's name from their calendar account)
- System audio = labeled "Others" or the meeting organizer/title context
- Post-meeting, the user can edit speaker labels in the Markdown file
- **v2:** Add voice fingerprinting. Store voice embeddings per contact. Match new audio segments against known voices. FluidAudio can do this on-device with 0.017 RTF (60x real-time) on M1.

---

## Architecture

### New files and modules

```
MeetingNotifier/
  Transcription/
    AudioCaptureManager.swift        -- Mic + system audio capture
    TranscriptionEngine.swift        -- Protocol for transcription backends
    SpeechAnalyzerEngine.swift       -- Apple SpeechAnalyzer implementation (default)
    WisprEngine.swift                -- Wispr Flow WebSocket implementation (premium)
    DeepgramEngine.swift             -- Deepgram WebSocket implementation (premium)
    WhisperKitEngine.swift           -- WhisperKit fallback for pre-macOS 26
    TranscriptionSession.swift       -- Manages a single transcription session
    TranscriptionCoordinator.swift   -- Orchestrates detection, prompting, capture, saving
    MeetingDetector.swift            -- CoreAudio/IOKit listeners for mic/camera
    TranscriptFormatter.swift        -- Converts raw transcript to Markdown
    TranscriptionSettings.swift      -- User preferences for transcription
  Models/
    TranscriptSegment.swift          -- Individual transcribed segment with speaker/timestamp
    TranscriptDocument.swift         -- Full meeting transcript document
```

### Data flow

```
MeetingDetector (mic/camera listener)
  |
  v
TranscriptionCoordinator
  |-- correlates with CalendarDataManager.events (is a meeting happening?)
  |-- if yes: prompt with meeting title
  |-- if no: prompt for impromptu meeting (user can name it)
  |-- on user approval:
  |     |
  |     v
  |   AudioCaptureManager
  |     |-- AVAudioEngine (mic stream)
  |     |-- Core Audio Taps (system audio stream)
  |     |
  |     v
  |   TranscriptionEngine (SpeechAnalyzer / Wispr / Deepgram / WhisperKit)
  |     |-- receives audio buffers
  |     |-- emits TranscriptSegment objects
  |     |
  |     v
  |   TranscriptionSession
  |     |-- accumulates segments
  |     |-- tracks speaker labels
  |     |-- tracks meeting metadata
  |     |
  |     v
  |   TranscriptFormatter
  |        |-- generates Markdown with YAML front matter
  |        |-- saves to user-specified folder
```

### Key protocols

```swift
protocol TranscriptionEngine {
    func start(micStream: AsyncStream<AVAudioPCMBuffer>,
               systemStream: AsyncStream<AVAudioPCMBuffer>) async throws
    func stop() async
    var segments: AsyncStream<TranscriptSegment> { get }
}

protocol TranscriptOutput {
    func save(document: TranscriptDocument, to url: URL) throws
}
```

### SpeechAnalyzer integration pattern

Two `SpeechAnalyzer` instances running concurrently, one per audio stream:

```swift
class SpeechAnalyzerEngine: TranscriptionEngine {
    private var micAnalyzer: SpeechAnalyzer?
    private var systemAnalyzer: SpeechAnalyzer?

    func start(micStream: AsyncStream<AVAudioPCMBuffer>,
               systemStream: AsyncStream<AVAudioPCMBuffer>) async throws {

        let micTranscriber = SpeechTranscriber(
            locale: Locale(identifier: "en_US"),
            preset: .progressiveLiveTranscription
        )
        let systemTranscriber = SpeechTranscriber(
            locale: Locale(identifier: "en_US"),
            preset: .progressiveLiveTranscription
        )

        micAnalyzer = SpeechAnalyzer(modules: [micTranscriber])
        systemAnalyzer = SpeechAnalyzer(modules: [systemTranscriber])

        // Feed mic stream to micAnalyzer
        // Feed system stream to systemAnalyzer
        // Merge results, tagging mic as "Me" and system as "Others"
        // Interleave by timestamp into unified segment stream
    }
}
```

### Wispr integration pattern

WebSocket client using `URLSessionWebSocketTask`:

```swift
class WisprEngine: TranscriptionEngine {
    private var webSocket: URLSessionWebSocketTask?

    func start(micStream: AsyncStream<AVAudioPCMBuffer>,
               systemStream: AsyncStream<AVAudioPCMBuffer>) async throws {

        // 1. Call warmup endpoint
        // 2. Connect WebSocket with client token
        // 3. Send auth message with meeting context:
        //    - dictionary_context populated from attendee names
        //    - user name from calendar account
        // 4. Mix mic + system audio (Wispr has no diarization,
        //    so we either send mixed audio or run two sessions)
        // 5. Convert to 16kHz PCM, base64 encode
        // 6. Stream via append messages in ~50ms chunks
        // 7. Receive polished text back
    }
}
```

**Wispr context enrichment:** When a calendar event is matched, populate the Wispr context with:
- `dictionary_context`: attendee names, meeting title words, calendar name
- `user_first_name` / `user_last_name`: from calendar account
- `conversation.participants`: from CalendarEvent attendees

This gives Wispr the vocabulary to spell proper nouns correctly.

---

## Feature specification

### 1. Meeting detection and transcription prompt

**Triggers:**
- CoreAudio property listener detects mic activation
- Works with or without a matching calendar event

**UI flow for scheduled meetings:**

```
[Menu bar icon]
     |
     v (mic detected, calendar event found)
[Dropdown notification from menu bar]
  "Transcribe 'Weekly Standup'?"
  [Start Transcription] (blue button)
```

**UI flow for impromptu meetings:**

```
[Menu bar icon]
     |
     v (mic detected, no calendar event)
[Dropdown notification from menu bar]
  "Transcribe this meeting?"
  [Meeting name: _______________] (text field, default: "Untitled Meeting")
  [Start Transcription] (blue button)
```

**Menu bar states:**

| State | Top menu item |
|-------|--------------|
| No mic/camera active | (normal menu items) |
| Mic/camera active, not transcribing | "Start Transcription" |
| Actively transcribing | "Stop Transcribing" (with red dot indicator) |
| Transcription just saved | "View Notes" (briefly, then resets) |

**Implementation notes:**
- Use `NSStatusItem` button action to show a small popover/panel for the prompt
- The prompt auto-populates meeting title from the matching calendar event
- For impromptu meetings, the user names the meeting or accepts the default
- Add a keyboard shortcut for start/stop (configurable in settings)
- The prompt should dismiss if the mic deactivates before the user responds

### 2. Audio capture

**Microphone capture (AVAudioEngine):**

```swift
class AudioCaptureManager {
    private let micEngine = AVAudioEngine()
    private var systemTap: AudioTap?

    func startCapture() async throws -> (
        mic: AsyncStream<AVAudioPCMBuffer>,
        system: AsyncStream<AVAudioPCMBuffer>
    ) {
        // Request mic permission
        // Install tap on mic input node
        // Create Core Audio Tap for system audio
        // Return both streams
    }
}
```

**System audio capture (Core Audio Taps, macOS 14.2+):**

```swift
let tapDescription = CATapDescription(
    stereoMixdownOfProcesses: [] // empty = all system audio
)
// Or target specific meeting app process:
let tapDescription = CATapDescription(
    stereoMixdownOfProcesses: [zoomPID]
)
```

**Audio format considerations:**
- SpeechAnalyzer: use `SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith:)` to get the required format, then convert via `AVAudioConverter`
- Wispr: 16kHz mono PCM WAV, base64 encoded
- Deepgram: 16kHz mono PCM
- Buffer size: 4096 frames for SpeechAnalyzer (per Apple's sample code)

### 3. Transcription

**Apple SpeechAnalyzer (default):**

- No model download needed (system manages models via `AssetInventory`)
- If locale model isn't installed, prompt download via `AssetInventory.assetInstallationRequest(supporting:)`
- Use `.progressiveLiveTranscription` preset for real-time
- Enable `.volatileResults` for fast partial results
- Enable `.audioTimeRange` for sample-accurate timestamps
- Two separate analyzer instances: one for mic, one for system audio
- Merge and interleave results by `CMTimeRange`

**Wispr Flow (premium):**

- WebSocket streaming in ~50ms audio chunks
- Enrich context with attendee names and meeting title
- Output is already polished (no post-processing needed)
- Single-speaker: either mix both channels or pick one
- Practical approach: run mic through Wispr for "Me" (polished), run system audio through SpeechAnalyzer for "Others" (raw but free)

**Deepgram (premium with diarization):**

- WebSocket connection for real-time streaming
- Send combined audio with diarization enabled
- Receives word-level timestamps and speaker labels
- Can distinguish individual remote speakers

**TranscriptSegment model:**

```swift
struct TranscriptSegment: Codable, Identifiable {
    let id: UUID
    let speaker: Speaker
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let confidence: Float?

    enum Speaker: Codable {
        case me(name: String)
        case other(name: String?)
        case unknown
    }
}
```

### 4. Output format

**Default Markdown template:**

```markdown
---
title: "Weekly Standup"
date: 2026-03-17
time: "09:00-09:30"
duration: 30
attendees:
  - name: "Prashant"
    role: "organizer"
  - name: "Alice"
  - name: "Bob"
calendar: "Work"
account: "prashant@company.com"
tags: []
---

# Weekly Standup
**March 17, 2026 | 9:00 AM - 9:30 AM | 30 minutes**

## Transcript

**Prashant** (0:00)
Good morning everyone. Let's go through updates.

**Others** (0:05)
Hi Prashant. I finished the API integration yesterday...

**Prashant** (0:32)
Great. Any blockers?

**Others** (0:35)
One thing -- the staging database is running slow...

## Summary
<!-- Auto-generated summary goes here if AI summarization is enabled -->
```

**File naming schema (user-configurable):**

Default: `{yyyy}{mm}{dd}-{title}.md`

Available tokens:
- `{yyyy}`, `{mm}`, `{dd}` -- date components
- `{HH}`, `{MM}` -- time components
- `{title}` -- meeting title (sanitized for filesystem)
- `{calendar}` -- calendar name
- `{account}` -- account email
- `{duration}` -- meeting duration in minutes
- `{attendee_count}` -- number of attendees

Examples:
- `{yyyy}{mm}{dd}-{title}` -> `20260317-weekly-standup.md`
- `{yyyy}-{mm}-{dd}/{title}` -> `2026-03-17/weekly-standup.md` (subfolder per date)
- `{calendar}/{yyyy}{mm}{dd}-{title}` -> `Work/20260317-weekly-standup.md`

**YAML front matter (user-configurable):**

Settings will include a template editor where users define their front matter schema. The app provides variables that get interpolated:

```
Front matter template:
---
title: "{title}"
date: {date}
time: "{start_time}-{end_time}"
duration: {duration}
type: meeting
status: raw
attendees: {attendees_yaml}
---
```

Users can add their own static fields (like `type: meeting` or `status: raw` for their PKM workflow). The app interpolates dynamic values and passes through static text.

### 5. Settings UI

New "Transcription" tab in Settings with sections:

**General:**
- Enable/disable transcription feature (master toggle)
- Keyboard shortcut for start/stop transcription
- Auto-offer transcription when mic activates (on/off)
- Offer for scheduled meetings only vs. all mic activity

**Transcription engine:**
- Engine picker: "On-Device (Apple)" / "Wispr Flow" / "Deepgram" / "On-Device (WhisperKit)"
- Language/locale picker (for SpeechAnalyzer)
- Model download status (for SpeechAnalyzer and WhisperKit)
- API key field (for Wispr or Deepgram)

**Output:**
- Notes folder path (folder picker)
- File naming schema (text field with token reference)
- YAML front matter template (multi-line text editor)
- Include raw transcript (on/off)
- Include AI summary (on/off, future feature)

**Speaker labels:**
- Your display name (pre-filled from calendar account)
- Default label for others ("Others" / "Meeting" / custom)

---

## Implementation phases

### Phase 1: Audio detection and capture

**Goal:** Detect when mic/camera are active, capture both audio streams.

Files to create:
- `MeetingDetector.swift` -- CoreAudio property listener for mic, IOKit for camera
- `AudioCaptureManager.swift` -- AVAudioEngine (mic) + Core Audio Taps (system audio)

Files to modify:
- `Info.plist` -- add `NSMicrophoneUsageDescription`, `NSAudioCaptureUsageDescription`, `NSSpeechRecognitionUsageDescription`
- `MeetingNotifier.entitlements` -- add audio input, speech recognition capabilities

Acceptance criteria:
- App detects when mic activates/deactivates
- App captures mic audio as PCM buffers
- App captures system audio as PCM buffers
- Both streams are time-aligned
- Permissions are requested cleanly on first use

### Phase 2: Transcription prompt UI

**Goal:** Show transcription prompt in menu bar when mic/camera detected.

Files to create:
- `TranscriptionCoordinator.swift` -- orchestrates detection + calendar correlation + UI

Files to modify:
- `AppDelegate.swift` -- add transcription menu items, handle state changes
- `MenuBarView.swift` -- add "Start/Stop Transcription" items
- `CalendarDropdownView.swift` -- add transcription controls to popover view

Acceptance criteria:
- When mic activates during a calendar event, prompt appears with meeting title
- When mic activates without a calendar event, prompt appears for impromptu meeting with naming field
- "Start Transcription" appears as top menu item when mic/camera active
- Clicking it starts capture and changes to "Stop Transcribing"
- "Stop Transcribing" stops capture
- State resets when mic/camera deactivate

### Phase 3: On-device transcription (Apple SpeechAnalyzer)

**Goal:** Transcribe captured audio using Apple's SpeechAnalyzer framework.

Files to create:
- `TranscriptionEngine.swift` -- protocol
- `SpeechAnalyzerEngine.swift` -- Apple SpeechAnalyzer implementation
- `TranscriptSegment.swift` -- data model
- `TranscriptionSession.swift` -- accumulates segments during a meeting

Dependencies: None (SpeechAnalyzer is a system framework)

Acceptance criteria:
- Language model downloaded if needed via AssetInventory
- Two SpeechAnalyzer instances running (mic + system audio)
- Mic audio transcribed and labeled as "Me"
- System audio transcribed and labeled as "Others"
- Segments have timestamps relative to meeting start
- Volatile results shown in real-time, replaced by final results
- Transcription runs without noticeable UI lag

### Phase 4: Output and saving

**Goal:** Save transcripts as formatted Markdown files.

Files to create:
- `TranscriptFormatter.swift` -- Markdown generation with YAML front matter
- `TranscriptDocument.swift` -- full document model
- `TranscriptionSettings.swift` -- output preferences

Files to modify:
- `AppSettings.swift` -- add transcription settings properties
- `SettingsWindow.swift` -- add Transcription settings tab

Acceptance criteria:
- Transcript saved as Markdown to user-specified folder
- File named according to user's schema
- YAML front matter populated from calendar event data (or user-entered title for impromptu meetings)
- Transcript formatted with speaker labels and timestamps
- Settings UI allows configuring folder, naming, and front matter template

### Phase 5: Wispr Flow integration (premium)

**Goal:** Add Wispr Flow as a premium transcription engine.

Files to create:
- `WisprEngine.swift` -- WebSocket client for Wispr Flow API

Acceptance criteria:
- User can enter Wispr API key in settings
- WebSocket connection established with warmup
- Meeting context (attendee names, title) sent to Wispr for accuracy
- Output is polished text with filler removal and auto-editing
- Graceful fallback to SpeechAnalyzer if connection fails

### Phase 6: Deepgram integration (premium with diarization)

**Goal:** Add Deepgram as an option for true multi-speaker diarization.

Files to create:
- `DeepgramEngine.swift` -- WebSocket streaming implementation

Acceptance criteria:
- User can enter Deepgram API key in settings
- Switching to Deepgram engine uses cloud transcription with diarization
- Individual remote speakers labeled separately
- Graceful fallback if network unavailable

### Phase 7: Polish and future features

- AI-generated meeting summary (send transcript to Claude API for summary)
- Voice fingerprinting for speaker identification via FluidAudio (on-device, 60x real-time on M1)
- Export to other formats (PDF, Notion, Obsidian)
- Search across past transcripts
- WhisperKit fallback engine for pre-macOS 26 users

---

## Dependencies

| Package | Purpose | License | Required |
|---------|---------|---------|----------|
| None (Phase 1-4) | SpeechAnalyzer is a system framework | N/A | Phase 1-4 |
| [FluidAudio](https://github.com/FluidInference/FluidAudio) | On-device diarization (Phase 7) | MIT | Optional |
| [WhisperKit](https://github.com/argmaxinc/WhisperKit) | Fallback for pre-macOS 26 (Phase 7) | MIT | Optional |

Wispr and Deepgram use WebSocket APIs directly. No SDK needed.

## Permissions required

| Permission | Why | When requested |
|-----------|-----|----------------|
| Microphone | Capture user's voice | First transcription attempt |
| Speech Recognition | SpeechAnalyzer transcription | First transcription attempt |
| Audio Capture (system) | Capture meeting audio from speakers | First transcription attempt |
| Files & Folders | Save transcripts to user-chosen folder | When user picks output folder |

## Risks and mitigations

**Risk: Core Audio Taps API is poorly documented.**
Mitigation: Reference [AudioCap](https://github.com/insidegui/AudioCap) and [AudioTee](https://github.com/makeusabrew/audiotee) open-source projects that use it successfully. If it proves too fragile, fall back to ScreenCaptureKit.

**Risk: SpeechAnalyzer accuracy on proper nouns and technical terms.**
Mitigation: No custom vocabulary support in SpeechAnalyzer. For meetings where accuracy on names matters, Wispr's `dictionary_context` or Deepgram handle this better. Post-meeting editing in the Markdown file is always an option.

**Risk: System audio capture picks up notifications, music, etc.**
Mitigation: If possible, target only the meeting app's process via Core Audio Taps (requires detecting which app is the meeting). Otherwise, document that users should mute other audio sources during transcription.

**Risk: App Store rejection for audio capture.**
Mitigation: Core Audio Taps and AVAudioEngine are official Apple APIs. SpeechAnalyzer is Apple's own framework. Include clear privacy descriptions. If App Store is needed, ScreenCaptureKit is the safer API choice for system audio.

**Risk: Wispr API access is currently partner-only.**
Mitigation: Build the integration now, gate it behind settings. When access opens up (or we get partner access), it's ready. SpeechAnalyzer is the free default regardless.

**Risk: Running two SpeechAnalyzer instances concurrently (mic + system).**
Mitigation: Apple's design supports multiple modules per analyzer, and the framework runs in a separate process. Test concurrent instances early in Phase 3. Fallback: interleave audio from both sources into a single analyzer with speaker tagging based on source.

## Cost comparison

For a 1-hour meeting per day, 20 meetings per month:

| Solution | Monthly cost |
|----------|-------------|
| Granola | $18.00 |
| Otter.ai | $16.99 |
| Notion AI | $10.00/seat |
| **This app (SpeechAnalyzer)** | **$0.00** |
| **This app (Wispr Flow)** | TBD (token-based) |
| **This app (Deepgram)** | **~$9.20** (20hrs x $0.46) |

The free on-device option using Apple's own framework is the differentiator. No model downloads, no API costs, no data leaving the machine. Wispr and Deepgram are there for users who want polished output or true multi-speaker diarization.
