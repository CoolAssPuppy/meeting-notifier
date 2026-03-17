//
//  TranscriptionCoordinator.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import AVFoundation
import Combine
import Foundation
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

    private init() {
        setupNotificationObservers()
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

        // Request mic permission
        let granted = await AudioCaptureManager.requestMicrophonePermission()
        guard granted else {
            state = .error
            error = "Microphone access is required for transcription"
            Logger.transcription.error("Microphone permission denied")
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

        // Save to file
        if let document = currentDocument {
            saveTranscript(document)
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

    private func saveTranscript(_ document: TranscriptDocument) {
        let settings = AppSettings.shared
        let formatter = TranscriptFormatter(
            speakerNameMe: settings.speakerDisplayName,
            speakerNameOthers: settings.othersDisplayName
        )

        // Start async save: summarize via OpenAI, then write file
        Task { @MainActor in
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
                    Logger.transcription.info("Meeting summary generated via \(platform.displayName)")
                } catch {
                    Logger.transcription.error("OpenAI summarization failed: \(error.localizedDescription)")
                    // Continue saving without summary
                }
            }

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
            } catch {
                Logger.transcription.error("Failed to save transcript: \(error.localizedDescription)")
                self.error = "Failed to save: \(error.localizedDescription)"
            }
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

        // Auto-offer transcription when mic activates during a meeting
        NotificationCenter.default.addObserver(
            forName: .microphoneDidActivate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self,
                      self.state == .idle,
                      AppSettings.shared.notetakerEnabled,
                      AppSettings.shared.autoOfferTranscription else {
                    return
                }

                // Check if there's a current or upcoming meeting
                let dataManager = CalendarDataManager.shared
                let now = Date()
                let activeMeeting = dataManager.events.first { event in
                    event.startDate <= now.addingTimeInterval(60) && event.endDate > now
                }

                if let meeting = activeMeeting {
                    Logger.transcription.info("Auto-offering transcription for: \(meeting.title)")
                    await self.startTranscription(for: meeting)
                }
            }
        }
    }

    // MARK: - Helpers

    private func formattedNow() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: Date())
    }
}
