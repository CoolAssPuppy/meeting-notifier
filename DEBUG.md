# Transcription crash status

## Where things stand
- Launch the app, start a transcription, and it still crashes ~1–2 seconds later with the same `EXC_BREAKPOINT (code=1, subcode=0x1…bc4)` on a Speech framework worker thread.
- Every reproduction so far points to Swift 6 actor-isolation enforcement, not an audio graph error or throw.
- Running `log stream` from another terminal still shows nothing because Xcode injects `OS_ACTIVITY_MODE=disable` into debug launches; while that flag is present the process cannot publish unified logging events, so only the LLDB console captures `Logger.audio` / `Logger.transcription` output.

## What we’ve learned
1. **Custom analyzer pipeline** – We’re not using the stock `SFSpeechRecognizer` + `SFSpeechAudioBufferRecognitionRequest` path Apple documents. Instead we hand-roll a streaming `SpeechAnalyzer` pipeline that feeds `AnalyzerInput` buffers created from an `AVAudioEngine` mic tap, converts them to the analyzer’s preferred format, and tracks timestamps for diarization. None of the Swift concurrency annotations in that pipeline match Apple’s samples (because there are no samples for this architecture yet), so we are discovering runtime limitations the documentation does not cover.
2. **Concurrency pressure points** – Multiple iterations removed existential protocols, avoided `Task {}` creation on the audio render thread, and wrapped every buffer in `@Sendable` closures. Even after stripping the capture path down to `bufferHandler(buffer)` the runtime still traps, which strongly suggests a Swift 6 isolation bug somewhere inside the Speech framework when called the way we are calling it.
3. **Logging blind spot** – Because the debugger launch disables unified logging, external tools (`log stream --predicate 'subsystem == "com.strategicnerds.meetingnotifier" && category == "audio"'`) never see anything. The lack of logs was a tooling problem, not evidence that our code never executed.

## Why this approach feels blocked
- Apple only publicly documented ScreenCaptureKit and legacy `SFSpeechRecognizer` flows. There is no end-to-end guide for mic + system audio capture feeding straight into `SpeechAnalyzer`. We are combining three fast-evolving technologies: Core Audio taps (macOS 14.2+), SpeechAnalyzer (macOS 26), and Swift 6 strict concurrency. Each is documented in isolation, but there is zero guidance on how they behave together, especially on real-time audio threads. We are effectively debugging Apple’s runtime.
- Products like Granola, Notion AI, or Krisp succeed because they either (a) keep using the mature `SFSpeechRecognizer` APIs, (b) rely on ScreenCaptureKit’s more documented audio capture path, or (c) ship their own virtual audio driver where they can control threading entirely. None of them have published a SpeechAnalyzer-based pipeline yet, so we cannot piggyback on battle-tested patterns.
- Even basic diagnostics (symbolicating the trap address, running Thread Sanitizer, or changing `SWIFT_STRICT_CONCURRENCY`) cost hours per attempt because the crash is in optimized Apple binaries. We are burning time reverse-engineering framework internals with little leverage.

## Recommendation going forward
1. **Pause the SpeechAnalyzer path.** Treat it as an R&D track that we can revisit once Apple releases samples or documentation that cover strict-concurrency streaming pipelines.
2. **Stand up a production-friendly baseline:**
   - Capture mic audio via `AVAudioEngine` (what we already do).
   - Capture meeting/system audio via ScreenCaptureKit (documented, shipping since macOS 13, works with hardened runtime).
   - Feed both into the battle-tested `SFSpeechRecognizer` + `SFSpeechAudioBufferRecognitionRequest` flow or, if we still need on-device, use `DictationTranscriber` which mirrors the legacy API surface.
   - Deliver diarization initially via simple heuristics (mic channel vs. system channel). We can add smarter diarization later.
3. **Keep SpeechAnalyzer on a branch.** Use it to experiment with macOS 26-only features, but decouple it from the main product timeline until the runtime stops trapping under strict concurrency.
4. **Improve tooling:** remove `OS_ACTIVITY_MODE=disable` from the Launch scheme so unified logs show up in `log stream`, and add a diagnostic profile for running outside Xcode (`open build/Debug/MeetingNotifier.app`) when we need system logs.

This lets us ship transcription that behaves like the market incumbents (Granola, Notion AI) without getting blocked by undocumented Swift 6 + SpeechAnalyzer interactions. Once we have a stable baseline, we can revisit SpeechAnalyzer for macOS 26-specific advantages, but only after Apple provides better guidance—or after we have the slack to instrument the framework ourselves.
