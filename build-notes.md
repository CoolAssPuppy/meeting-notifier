# Build Notes

This project is a macOS Swift app built with Xcode. A build could not be performed
in this environment because Xcode and the Swift toolchain are not available.

## Prerequisites

- **Xcode 26+** (targeting macOS 26.0)
- **Swift 6.0**
- **macOS 26.0 SDK**

## Build Steps

1. Open `MeetingNotifier/MeetingNotifier.xcodeproj` in Xcode
2. Select the `MeetingNotifier` scheme
3. Build with `Cmd+B` or from terminal:
   ```bash
   cd MeetingNotifier
   xcodebuild -project MeetingNotifier.xcodeproj -scheme MeetingNotifier -configuration Debug build
   ```

### Alternative: Regenerate project with XcodeGen

If the `.pbxproj` is out of sync, regenerate it from `project.yml`:

```bash
cd MeetingNotifier
xcodegen generate
```

Then build as above.

## Changes Made

### 1. Deepgram Diarization (`diarize=true`)

**File:** `MeetingNotifier/Transcription/DeepgramEngine.swift`

- Added `&diarize=true` to the Deepgram WebSocket URL
- When Deepgram returns word-level speaker indices, groups consecutive words
  by speaker and emits separate `TranscriptSegment` instances per speaker
- Speaker 0 maps to `.me`, all others map to `.others`
- Falls back to the existing `currentSpeaker`-based labeling when diarization
  data is not present in the response

### 2. Echo Deduplication

**New file:** `MeetingNotifier/Transcription/EchoDeduplicator.swift`

- Thread-safe deduplicator that suppresses echo segments where the mic picks
  up system audio (e.g., user not wearing headphones)
- For each incoming "Me" segment, checks all recent "Others" segments within
  a +/-5 second time window
- Uses longest-common-subsequence similarity (like Python's
  `difflib.SequenceMatcher.ratio()`) with a 0.5 threshold
- If similarity exceeds threshold, the "Me" segment is dropped as an echo

**File:** `MeetingNotifier/Managers/TranscriptionCoordinator.swift`

- Integrated `EchoDeduplicator` into the segment handler pipeline
- Both `startTranscription()` and `resumeTranscription()` pass segments
  through the deduplicator before appending to the document
- Deduplicator state is reset at the start of each new session

### 3. Xcode Project File

**File:** `MeetingNotifier.xcodeproj/project.pbxproj`

- Added `EchoDeduplicator.swift` to PBXBuildFile, PBXFileReference,
  Transcription group, and Sources build phase
