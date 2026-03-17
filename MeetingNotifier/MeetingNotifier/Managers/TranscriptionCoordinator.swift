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

    private let audioCaptureManager = AudioCaptureManager()
    private var engine: TranscriptionEngine?
    private var cancellables = Set<AnyCancellable>()
    private var autoOfferTimer: Timer?

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

        // Create the transcription engine
        engine = createEngine(type: settings.transcriptionEngine)
        guard let engine else {
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
            conferenceLink: event?.conferenceLink
        )

        // Wire up segment handler
        engine.setSegmentHandler { [weak self] segment in
            Task { @MainActor in
                self?.currentDocument?.segments.append(segment)
            }
        }

        do {
            // Start engine
            try await engine.start(locale: settings.transcriptionLocale)

            // Get a direct buffer processor closure that captures only
            // Sendable state -- no protocol existential on the audio thread.
            let processBuffer = engine.makeBufferProcessor(speaker: .me)
            try audioCaptureManager.startMicCapture(bufferHandler: processBuffer)

            state = .recording
            error = nil
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

        // Stop capture and engine
        audioCaptureManager.stopMicCapture()
        await engine?.stop()
        engine = nil

        // Finalize document
        currentDocument?.endDate = Date()

        // Update banner: ended
        updateBanner(.ended)

        // Save with AI summary
        if let document = currentDocument {
            updateBanner(.analyzing)
            await saveTranscript(document)
        }

        state = .idle
        NotificationCenter.default.post(name: .transcriptionDidStop, object: nil)
        Logger.transcription.info("Transcription stopped and saved")

        currentDocument = nil
        error = nil
    }

    func pauseTranscription() {
        guard state == .recording else { return }
        audioCaptureManager.stopMicCapture()
        state = .paused
        Logger.transcription.info("Transcription paused")
    }

    func resumeTranscription() {
        guard state == .paused, let engine else { return }
        do {
            let processBuffer = engine.makeBufferProcessor(speaker: .me)
            try audioCaptureManager.startMicCapture(bufferHandler: processBuffer)
            state = .recording
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
        let folderURL = URL(fileURLWithPath: settings.notesFolderPath)

        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            let fileURL = folderURL.appendingPathComponent(filename)
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
            Logger.transcription.info("Transcript saved to: \(fileURL.path)")
            dismissBannerAfterDelay(.saved)
        } catch {
            Logger.transcription.error("Failed to save transcript: \(error.localizedDescription)")
            self.error = "Failed to save: \(error.localizedDescription)"
            updateBanner(.error("Save failed: \(error.localizedDescription)"))
        }
    }

    // MARK: - Engine factory

    private func createEngine(type: TranscriptionEngineType) -> TranscriptionEngine? {
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

                guard self.state == .idle,
                      settings.notetakerEnabled,
                      settings.autoOfferTranscription else {
                    return
                }

                // Find best matching meeting (or none)
                let meeting = self.findBestMeeting()
                if let meeting {
                    Logger.transcription.info("Auto-starting transcription for: \(meeting.title)")
                } else {
                    Logger.transcription.info("Auto-starting transcription (no calendar match)")
                }
                await self.startTranscription(for: meeting)
            }
        }

        // Auto-stop when mic deactivates (meeting ended)
        NotificationCenter.default.addObserver(
            forName: .microphoneDidDeactivate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.state.isActive else { return }
                print("[AutoStop] Mic deactivated while recording, stopping transcription")
                await self.stopTranscription()
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
        let settings = AppSettings.shared
        let micActive = MeetingDetector.shared.isMicrophoneActive

        // Debug: prints to Xcode console even with OS_ACTIVITY_MODE=disable
        print("[AutoOffer] state=\(state.rawValue) enabled=\(settings.notetakerEnabled) autoOffer=\(settings.autoOfferTranscription) micActive=\(micActive)")

        guard state == .idle,
              settings.notetakerEnabled,
              settings.autoOfferTranscription,
              micActive else {
            return
        }

        let meeting = findBestMeeting()
        print("[AutoOffer] STARTING transcription. Meeting: \(meeting?.title ?? "none")")

        Task {
            await startTranscription(for: meeting)
        }
    }

    // MARK: - Meeting matching

    /// Find the best calendar event for auto-transcription.
    /// Matches meetings happening now or starting within 5 minutes.
    /// If double-booked, uses the user's double-booking preference.
    private func findBestMeeting() -> CalendarEvent? {
        let now = Date()
        let candidates = CalendarDataManager.shared.events.filter { event in
            event.startDate <= now.addingTimeInterval(300) && event.endDate > now
        }

        guard !candidates.isEmpty else { return nil }
        if candidates.count == 1 { return candidates.first }

        // Double-booked: use the user's preference
        Logger.transcription.info("Double-booked: \(candidates.count) meetings, using preference: \(AppSettings.shared.doubleBookingPreference.rawValue)")
        switch AppSettings.shared.doubleBookingPreference {
        case .fewerAttendees:
            return candidates.sorted { $0.attendeeCount < $1.attendeeCount }.first
        case .moreAttendees:
            return candidates.sorted { $0.attendeeCount > $1.attendeeCount }.first
        }
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

    // MARK: - Helpers

    private func formattedNow() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: Date())
    }
}
