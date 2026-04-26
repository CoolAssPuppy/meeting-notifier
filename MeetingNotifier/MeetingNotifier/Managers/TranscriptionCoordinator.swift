//
//  TranscriptionCoordinator.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import AppKit
import AVFoundation
import Combine
import Foundation
import Speech
import os

@MainActor
final class TranscriptionCoordinator: ObservableObject {
    static let shared = TranscriptionCoordinator()

    @Published private(set) var state: TranscriptionState = .idle
    @Published private(set) var currentDocument: TranscriptDocument?
    @Published private(set) var error: String?
    @Published private(set) var isDiarizationActive = false

    private let audioCaptureManager = AudioCaptureManager()
    private let systemAudioCapturer = SystemAudioCapturer()
    private let echoDeduplicator = EchoDeduplicator()
    private let systemAudioEnergyTracker = SystemAudioEnergyTracker()
    private var micEngine: TranscriptionEngine?
    private var systemEngine: TranscriptionEngine?
    private var autoOfferTimer: Timer?

    // Inactivity detection (Bug 1)
    private var lastSegmentTimestamp: Date?
    private var inactivityTimer: Timer?
    private static let inactivityCheckInterval: TimeInterval = 10
    private static let inactivityTimeout: TimeInterval = 90

    // Auto-save for crash recovery (Bug 3)
    private var autoSaveTimer: Timer?
    private static let autoSaveInterval: TimeInterval = 30

    // When true, suppress auto-start until the mic is released.
    // Set on manual/inactivity stop, cleared on mic deactivation
    // or explicit user-initiated start.
    private var suppressAutoStart = false

    private init() {
        setupNotificationObservers()
        startAutoOfferPolling()
    }

    // MARK: - Public API

    func startTranscription(for event: CalendarEvent? = nil) async {
        guard state == .idle || state == .error else {
            Logger.transcription.warning("Cannot start transcription in state: \(self.state.rawValue)")
            return
        }

        let settings = AppSettings.shared
        guard settings.notetakerEnabled else {
            Logger.transcription.info("Notetaker is disabled")
            return
        }

        state = .waitingForPermission

        // Request both permissions: microphone and speech recognition
        let micGranted = await AudioCaptureManager.requestMicrophonePermission()
        guard micGranted else {
            state = .error
            error = "Microphone access is required. Open System Settings > Privacy & Security > Microphone."
            Logger.transcription.error("Microphone permission denied")
            return
        }

        let speechStatus = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else {
            state = .error
            error = "Speech recognition access is required. Open System Settings > Privacy & Security > Speech Recognition."
            Logger.transcription.error("Speech recognition permission denied: \(String(describing: speechStatus))")
            return
        }

        // Create separate engines for mic and system audio so each
        // has its own pipeline and speaker label (no race condition).
        micEngine = createEngine(type: settings.transcriptionEngine)
        guard let micEngine else {
            state = .error
            error = "Transcription engine is not available"
            return
        }

        // Create transcript document
        let title = event?.title ?? "Meeting \(formattedNow())"
        currentDocument = TranscriptDocument(
            meetingTitle: title,
            engine: settings.transcriptionEngine,
            locale: settings.transcriptionLocale,
            calendarEventId: event?.id,
            attendeeCount: event?.attendeeCount,
            attendeeNames: event?.attendeeNames,
            conferenceLink: event?.conferenceLink,
            calendarName: event?.calendarName
        )

        // Reset deduplicator and energy tracker for the new session
        echoDeduplicator.reset()
        systemAudioEnergyTracker.reset()

        // Shared segment handler for both engines, with echo deduplication.
        // For the Apple engine, relabel mic segments as "Others" when system
        // audio energy is detected (speaker bleed through the mic).
        let deduplicator = echoDeduplicator
        let energyTracker = systemAudioEnergyTracker
        let useEnergyLabeling = settings.transcriptionEngine == .apple
        let segmentHandler: @Sendable (TranscriptSegment) -> Void = { [weak self] segment in
            var labeled = segment
            if useEnergyLabeling && segment.speaker == .me && energyTracker.isActive {
                labeled = TranscriptSegment(
                    speaker: .others,
                    text: segment.text,
                    startTime: segment.startTime,
                    endTime: segment.endTime
                )
            }
            guard deduplicator.shouldKeep(labeled) else { return }
            Task { @MainActor in
                self?.currentDocument?.segments.append(labeled)
                self?.lastSegmentTimestamp = Date()
                Logger.transcription.debug("Segment received: speaker=\(labeled.speaker.rawValue) text=\"\(labeled.text.prefix(50))\"")
            }
        }
        micEngine.setSegmentHandler(segmentHandler)

        do {
            // Start mic engine
            try await micEngine.start(locale: settings.transcriptionLocale)
            let processBuffer = micEngine.makeBufferProcessor(speaker: .me)
            try audioCaptureManager.startMicCapture(bufferHandler: processBuffer)

            // Start system audio engine for "Others" diarization.
            // Non-fatal: if screen recording is denied, mic-only still works.
            await startSystemAudioCapture(
                engineType: settings.transcriptionEngine,
                locale: settings.transcriptionLocale,
                segmentHandler: segmentHandler
            )

            state = .recording
            error = nil
            lastSegmentTimestamp = Date()
            startInactivityTimer()
            startAutoSaveTimer()
            NotificationCenter.default.post(name: .transcriptionDidStart, object: nil)
            Logger.transcription.info("Transcription started for: \(title)")
        } catch {
            state = .error
            self.error = error.localizedDescription
            Logger.transcription.error("Failed to start transcription: \(error.localizedDescription)")
        }
    }

    func stopTranscription() async {
        guard state.isActive else { return }

        state = .saving
        suppressAutoStart = true
        stopInactivityTimer()
        stopAutoSaveTimer()

        // Stop capture and engines. SystemAudioCapturer.stopCapture()
        // has its own 3-second internal timeout to avoid hanging.
        audioCaptureManager.stopMicCapture()
        await systemAudioCapturer.stopCapture()
        await micEngine?.stop()
        await systemEngine?.stop()
        micEngine = nil
        systemEngine = nil
        isDiarizationActive = false

        // Finalize document
        currentDocument?.endDate = Date()

        // Update banner: ended
        updateBanner(.ended)

        // Save with AI summary
        if let document = currentDocument {
            updateBanner(.analyzing)
            await saveTranscript(document)
        }

        // Clean up recovery file after successful save
        removeRecoveryFile()

        state = .idle
        NotificationCenter.default.post(name: .transcriptionDidStop, object: nil)
        Logger.transcription.info("Transcription stopped and saved")

        currentDocument = nil
        error = nil
    }

    func pauseTranscription() {
        guard state == .recording else { return }
        audioCaptureManager.stopMicCapture()
        Task {
            await systemAudioCapturer.stopCapture()
            await systemEngine?.stop()
            systemEngine = nil
        }
        stopInactivityTimer()
        stopAutoSaveTimer()
        state = .paused
        updateBanner(.paused)
        Logger.transcription.info("Transcription paused")
    }

    func resumeTranscription() {
        guard state == .paused, let micEngine else { return }
        do {
            let processBuffer = micEngine.makeBufferProcessor(speaker: .me)
            try audioCaptureManager.startMicCapture(bufferHandler: processBuffer)

            let deduplicator = echoDeduplicator
            let energyTracker = systemAudioEnergyTracker
            let settings = AppSettings.shared
            let useEnergyLabeling = settings.transcriptionEngine == .apple
            let segmentHandler: @Sendable (TranscriptSegment) -> Void = { [weak self] segment in
                var labeled = segment
                if useEnergyLabeling && segment.speaker == .me && energyTracker.isActive {
                    labeled = TranscriptSegment(
                        speaker: .others,
                        text: segment.text,
                        startTime: segment.startTime,
                        endTime: segment.endTime
                    )
                }
                guard deduplicator.shouldKeep(labeled) else { return }
                Task { @MainActor in
                    self?.currentDocument?.segments.append(labeled)
                }
            }
            Task {
                await startSystemAudioCapture(
                    engineType: settings.transcriptionEngine,
                    locale: settings.transcriptionLocale,
                    segmentHandler: segmentHandler
                )
            }

            lastSegmentTimestamp = Date()
            startInactivityTimer()
            startAutoSaveTimer()
            state = .recording
            updateBanner(.recording)
            Logger.transcription.info("Transcription resumed")
        } catch {
            self.error = error.localizedDescription
            Logger.transcription.error("Failed to resume: \(error.localizedDescription)")
        }
    }

    // MARK: - Saving

    private func saveTranscript(_ document: TranscriptDocument) async {
        let settings = AppSettings.shared
        let formatter = TranscriptFormatter(
            speakerNameMe: settings.speakerDisplayName,
            speakerNameOthers: settings.othersDisplayName
        )

        // Summarize via AI if configured
        var summary: MeetingSummary?
        let platform = settings.summarizationPlatform
        if AISummarizer.hasApiKey(for: platform) && !document.segments.isEmpty {
            let plainText = formatter.plainTranscript(segments: document.segments)
            do {
                summary = try await AISummarizer.summarize(
                    transcript: plainText,
                    meetingTitle: document.meetingTitle,
                    platform: platform
                )
                Logger.transcription.info("Summary generated via \(platform.displayName)")
            } catch {
                Logger.transcription.error("AI summarization failed: \(error.localizedDescription)")
                updateBanner(.error("Summary failed: \(error.localizedDescription)"))
            }
        }

        // Write markdown file
        let markdown = formatter.formatMarkdown(
            document: document,
            summary: summary,
            frontMatterTemplate: settings.frontMatterTemplate.isEmpty ? nil : settings.frontMatterTemplate
        )
        let filename = formatter.generateFilename(document: document, schema: settings.fileNamingSchema)

        // Resolve the security-scoped bookmark, falling back to the raw path
        let baseFolderURL = settings.resolveNotesFolderURL()
            ?? URL(fileURLWithPath: settings.notesFolderPath)
        let didStartAccess = baseFolderURL.startAccessingSecurityScopedResource()
        defer { if didStartAccess { baseFolderURL.stopAccessingSecurityScopedResource() } }

        let folderURL = SubfolderResolver.resolveFolderURL(
            baseFolderURL: baseFolderURL,
            calendarName: document.calendarName,
            isEnabled: settings.calendarSubfoldersEnabled,
            mappings: settings.calendarSubfolderMappings
        )

        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            let candidateURL = folderURL.appendingPathComponent(filename)
            let fileURL = TranscriptFormatter.deduplicatedFileURL(for: candidateURL)
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
            Logger.transcription.info("Transcript saved to: \(fileURL.path)")
            dismissBannerAfterDelay(.saved)
        } catch {
            Logger.transcription.error("Failed to save transcript: \(error.localizedDescription)")
            self.error = "Failed to save: \(error.localizedDescription)"
            updateBanner(.error("Save failed: \(error.localizedDescription)"))
        }
    }

    // MARK: - System audio

    private func startSystemAudioCapture(
        engineType: TranscriptionEngineType,
        locale: String,
        segmentHandler: @escaping @Sendable (TranscriptSegment) -> Void
    ) async {
        let hasPermission = SystemAudioCapturer.hasScreenCapturePermission()
        Logger.transcription.info("System audio: screen capture permission = \(hasPermission)")
        guard hasPermission else {
            Logger.transcription.warning("Screen recording permission not granted, mic-only mode (no diarization)")
            isDiarizationActive = false
            return
        }

        // Apple's SpeechAnalyzer does not support concurrent instances.
        // Use energy-based speaker labeling: track system audio energy
        // and relabel mic segments when a remote participant is speaking.
        if engineType == .apple {
            do {
                let processBuffer = systemAudioEnergyTracker.makeBufferProcessor()
                try await systemAudioCapturer.startCapture(bufferHandler: processBuffer)
                isDiarizationActive = true
                Logger.transcription.info("System audio energy tracking active (Apple engine diarization)")
            } catch {
                isDiarizationActive = false
                Logger.transcription.warning("System audio capture failed: \(error.localizedDescription)")
            }
            return
        }

        // Deepgram/Wispr: create a second engine for system audio transcription.
        guard let engine = createEngine(type: engineType) else {
            Logger.transcription.warning("System audio engine unavailable (createEngine returned nil for \(engineType.rawValue)), mic-only mode")
            isDiarizationActive = false
            return
        }

        engine.setSegmentHandler(segmentHandler)

        do {
            try await engine.start(locale: locale)
            let processBuffer = engine.makeBufferProcessor(speaker: .others)
            try await systemAudioCapturer.startCapture(bufferHandler: processBuffer)
            systemEngine = engine
            isDiarizationActive = true
            Logger.transcription.info("System audio engine active, diarization enabled")
        } catch {
            await engine.stop()
            isDiarizationActive = false
            Logger.transcription.warning(
                "System audio capture failed (mic-only mode): \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Engine factory

    private func createEngine(type: TranscriptionEngineType) -> TranscriptionEngine? {
        // Refuse to instantiate engines that aren't fully implemented yet — their
        // `start()` won't actually produce transcripts. AppSettings already coerces
        // these on load, so hitting this path means something routed around that.
        guard type.isImplemented else {
            Logger.transcription.warning("Refusing to create non-implemented engine: \(type.rawValue, privacy: .public)")
            return nil
        }
        switch type {
        case .apple:
            let engine = SpeechAnalyzerEngine()
            return engine.isAvailable ? engine : nil
        case .wispr:
            let engine = WisprEngine()
            return engine.isAvailable ? engine : nil
        case .deepgram:
            let engine = DeepgramEngine()
            return engine.isAvailable ? engine : nil
        }
    }

    // MARK: - Notification observers

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .startTranscriptionRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.suppressAutoStart = false
                await self?.startTranscription()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .stopTranscriptionRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.stopTranscription()
            }
        }

        // Auto-offer transcription when mic activates.
        // Always starts, even without a calendar match. If there is a meeting,
        // attach it for metadata. If double-booked, use the user's preference.
        NotificationCenter.default.addObserver(
            forName: .microphoneDidActivate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let settings = AppSettings.shared
                Logger.transcription.info("Mic activated. State: \(self.state.rawValue), enabled: \(settings.notetakerEnabled), auto-offer: \(settings.autoOfferTranscription)")
                // The notification IS the activation, so micActive is true.
                await self.handleAutoOfferTrigger(isMicActive: true)
            }
        }

        // Mic released: auto-stop if recording, and clear the
        // suppression latch so the next mic activation can auto-start.
        NotificationCenter.default.addObserver(
            forName: .microphoneDidDeactivate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.suppressAutoStart = false
                guard self.state.isActive else { return }
                Logger.transcription.info("Mic deactivated while recording, stopping transcription")
                await self.stopTranscription()
                // Clear again since stopTranscription sets it
                self.suppressAutoStart = false
            }
        }
    }

    // MARK: - Auto-offer polling

    /// Polls every 5 seconds to catch cases where the mic was already active
    /// before a meeting started (no transition = no notification).
    private func startAutoOfferPolling() {
        autoOfferTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkAutoOffer()
            }
        }
    }

    private func checkAutoOffer() {
        let micActive = MeetingDetector.shared.isMicrophoneActive
        let settings = AppSettings.shared
        Logger.transcription.debug("AutoOffer check: state=\(self.state.rawValue) enabled=\(settings.notetakerEnabled) autoOffer=\(settings.autoOfferTranscription) micActive=\(micActive)")
        Task { await handleAutoOfferTrigger(isMicActive: micActive) }
    }

    // MARK: - Meeting matching

    /// Single entry point for auto-offer triggers from both the
    /// `.microphoneDidActivate` notification and the safety-net polling
    /// timer. Decision logic lives in `AutoOfferDecider`.
    private func handleAutoOfferTrigger(isMicActive: Bool) async {
        let settings = AppSettings.shared
        let decision = AutoOfferDecider.decide(
            state: state,
            suppressAutoStart: suppressAutoStart,
            notetakerEnabled: settings.notetakerEnabled,
            autoOfferEnabled: settings.autoOfferTranscription,
            isMicActive: isMicActive,
            candidates: CalendarDataManager.shared.events,
            doubleBookingPreference: settings.doubleBookingPreference
        )

        guard case .start(let meeting) = decision else { return }

        if let meeting {
            Logger.transcription.info("Auto-starting transcription for: \(meeting.title)")
        } else {
            Logger.transcription.info("Auto-starting transcription (no calendar match)")
        }
        await startTranscription(for: meeting)
    }

    // MARK: - Banner helpers

    private func updateBanner(_ state: BannerState) {
        guard let appDelegate = NSApp.delegate as? AppDelegate else { return }
        appDelegate.updateBannerState(state)
    }

    private func dismissBannerAfterDelay(_ state: BannerState) {
        guard let appDelegate = NSApp.delegate as? AppDelegate else { return }
        appDelegate.showBannerThenDismiss(state)
    }

    // MARK: - Inactivity detection

    private func startInactivityTimer() {
        stopInactivityTimer()
        inactivityTimer = Timer.scheduledTimer(
            withTimeInterval: Self.inactivityCheckInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkInactivity()
            }
        }
    }

    private func stopInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = nil
    }

    private func checkInactivity() {
        guard state == .recording,
              let lastTimestamp = lastSegmentTimestamp else { return }

        let now = Date()
        let micActive = MeetingDetector.shared.isMicrophoneActive
        guard Self.shouldAutoStopForInactivity(
            lastSegmentTimestamp: lastTimestamp,
            now: now,
            isMicActive: micActive,
            timeout: Self.inactivityTimeout
        ) else { return }

        let elapsed = now.timeIntervalSince(lastTimestamp)
        Logger.transcription.info(
            "No segments for \(Int(elapsed))s and mic inactive, auto-stopping transcription"
        )
        Task {
            await stopTranscription()
        }
    }

    /// While the mic is still in use by some app the meeting is likely ongoing
    /// and the user may simply be silent — hold off. Once the mic is released
    /// and the grace window has elapsed, the session is safe to tear down.
    nonisolated static func shouldAutoStopForInactivity(
        lastSegmentTimestamp: Date,
        now: Date,
        isMicActive: Bool,
        timeout: TimeInterval
    ) -> Bool {
        guard !isMicActive else { return false }
        return now.timeIntervalSince(lastSegmentTimestamp) >= timeout
    }

    // MARK: - Auto-save for crash recovery

    private func startAutoSaveTimer() {
        stopAutoSaveTimer()
        autoSaveTimer = Timer.scheduledTimer(
            withTimeInterval: Self.autoSaveInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.writeRecoveryFile()
            }
        }
    }

    private func stopAutoSaveTimer() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
    }

    private func writeRecoveryFile() {
        guard let document = currentDocument else { return }
        TranscriptRecoveryStore.write(document)
    }

    private func removeRecoveryFile() {
        TranscriptRecoveryStore.clear()
    }

    /// Called on app launch to recover a transcript from a prior crash.
    /// Saves the recovered document as markdown without AI summarization.
    @MainActor
    static func recoverTranscriptIfNeeded() {
        guard var document = TranscriptRecoveryStore.read() else { return }
        if document.endDate == nil {
            document.endDate = document.segments.last?.timestamp ?? document.startDate
        }

        let settings = AppSettings.shared
        let formatter = TranscriptFormatter(
            speakerNameMe: settings.speakerDisplayName,
            speakerNameOthers: settings.othersDisplayName
        )
        let markdown = formatter.formatMarkdown(document: document, summary: nil)
        let filename = formatter.generateFilename(document: document, schema: settings.fileNamingSchema)

        let baseFolderURL = settings.resolveNotesFolderURL()
            ?? URL(fileURLWithPath: settings.notesFolderPath)
        let didStartAccess = baseFolderURL.startAccessingSecurityScopedResource()
        defer { if didStartAccess { baseFolderURL.stopAccessingSecurityScopedResource() } }

        let subfolder = SubfolderResolver.resolve(
            calendarName: document.calendarName,
            isEnabled: settings.calendarSubfoldersEnabled,
            mappings: settings.calendarSubfolderMappings
        )
        let folderURL = subfolder.map { baseFolderURL.appendingPathComponent($0) } ?? baseFolderURL

        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            let candidateURL = folderURL.appendingPathComponent(filename)
            let fileURL = TranscriptFormatter.deduplicatedFileURL(for: candidateURL)
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
            Logger.transcription.info("Recovered transcript saved to: \(fileURL.path)")
        } catch {
            Logger.transcription.error("Transcript recovery write failed: \(error.localizedDescription, privacy: .public)")
        }
        TranscriptRecoveryStore.clear()
    }

    /// Best-effort save of current document, called from applicationWillTerminate.
    func emergencySave() {
        writeRecoveryFile()
    }

    // MARK: - Helpers

    private func formattedNow() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: Date())
    }
}
