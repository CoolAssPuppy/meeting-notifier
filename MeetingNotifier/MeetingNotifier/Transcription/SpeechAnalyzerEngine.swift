//
//  SpeechAnalyzerEngine.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import AVFoundation
import Foundation
import Speech
import os

/// Apple’s SpeechAnalyzer-based transcription engine.
///
/// The engine streams mic audio into `SpeechAnalyzer` via `AnalyzerInput`
/// buffers and emits `TranscriptSegment` instances whenever the analyzer
/// finalizes text for a given time range.
final class SpeechAnalyzerEngine: TranscriptionEngine {
    let engineType: TranscriptionEngineType = .apple

    @MainActor var isAvailable: Bool { SpeechTranscriber.isAvailable }

    // These properties are mutated from @MainActor contexts only. Marking them
    // nonisolated keeps the compiler happy about Sendable conformance without
    // forcing additional synchronization.
    nonisolated(unsafe) private var analyzer: SpeechAnalyzer?
    nonisolated(unsafe) private var transcriber: SpeechTranscriber?
    nonisolated(unsafe) private var analyzerTask: Task<Void, Never>?
    nonisolated(unsafe) private var resultTask: Task<Void, Never>?

    private let audioPipelineBox = AudioPipelineBox()
    private let resultState = ResultState()

    // MARK: - TranscriptionEngine

    @MainActor
    func start(locale: String) async throws {
        let authStatus = await requestSpeechAuthorization()
        guard authStatus == .authorized else {
            Logger.transcription.error("Speech recognition not authorized: \(String(describing: authStatus))")
            throw TranscriptionError.permissionDenied
        }

        let selectedLocale = Locale(identifier: locale)
        let preset = SpeechTranscriber.Preset.timeIndexedProgressiveTranscription
        let transcriber = SpeechTranscriber(
            locale: selectedLocale,
            transcriptionOptions: preset.transcriptionOptions,
            reportingOptions: preset.reportingOptions,
            attributeOptions: preset.attributeOptions
        )

        guard let bestFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: [transcriber],
            considering: nil
        ) else {
            Logger.transcription.error("SpeechAnalyzer cannot provide an audio format for locale: \(locale)")
            throw TranscriptionError.engineUnavailable
        }

        let stream = AsyncStream<AnalyzerInput>.makeStream(bufferingPolicy: .bufferingNewest(8))

        // Configure streaming pipeline before the audio tap starts sending buffers.
        audioPipelineBox.configure(
            analyzerFormat: bestFormat,
            continuation: stream.continuation,
            logger: Logger.transcription
        )
        resultState.updateSessionStart(Date())

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = analyzer
        self.transcriber = transcriber

        analyzerTask = Task.detached(priority: .userInitiated) {
            do {
                try await analyzer.start(inputSequence: stream.stream)
            } catch is CancellationError {
                // Normal tear-down.
            } catch {
                Logger.transcription.error("SpeechAnalyzer start failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        resultTask = Task.detached(priority: .utility) { [weak self, transcriber] in
            do {
                for try await result in transcriber.results {
                    try Task.checkCancellation()
                    self?.handleRecognitionResult(result)
                }
            } catch is CancellationError {
                // Normal tear-down.
            } catch {
                Logger.transcription.error("SpeechTranscriber results stream failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        Logger.transcription.info("SpeechAnalyzer engine started (locale: \(locale))")
    }

    @MainActor
    func stop() async {
        audioPipelineBox.finish()

        analyzerTask?.cancel()
        analyzerTask = nil

        resultTask?.cancel()
        resultTask = nil

        analyzer = nil
        transcriber = nil
        resultState.reset()

        Logger.transcription.info("SpeechAnalyzer engine stopped")
    }

    nonisolated func processAudioBuffer(_ buffer: AVAudioPCMBuffer, speaker: SpeakerLabel) {
        resultState.updateSpeaker(speaker)
        audioPipelineBox.process(buffer: buffer)
    }

    @MainActor
    func setSegmentHandler(_ handler: @escaping @Sendable (TranscriptSegment) -> Void) {
        resultState.setHandler(handler)
    }

    nonisolated func makeBufferProcessor(speaker: SpeakerLabel) -> @Sendable (AVAudioPCMBuffer) -> Void {
        let pipeline = audioPipelineBox
        let state = resultState
        return { buffer in
            state.updateSpeaker(speaker)
            pipeline.process(buffer: buffer)
        }
    }

    // MARK: - Result handling

    nonisolated private func handleRecognitionResult(_ result: SpeechTranscriber.Result) {
        // Only forward non-empty final results to avoid duplicate UI updates.
        guard result.isFinal else { return }

        let attributed = result.text
        let cleanedText = String(attributed.characters).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedText.isEmpty else { return }

        let snapshot = resultState.snapshot()
        let timeRange = extractTimeRange(from: attributed)

        let segmentStart: TimeInterval
        let segmentEnd: TimeInterval

        if let timeRange {
            let start = CMTimeGetSeconds(timeRange.start)
            let end = CMTimeGetSeconds(CMTimeRangeGetEnd(timeRange))
            segmentStart = max(0, start)
            segmentEnd = max(segmentStart, end)
        } else {
            let elapsed = Date().timeIntervalSince(snapshot.sessionStart)
            segmentEnd = elapsed
            segmentStart = max(0, elapsed - 2)
        }

        let segment = TranscriptSegment(
            speaker: snapshot.speaker,
            text: cleanedText,
            startTime: segmentStart,
            endTime: segmentEnd
        )
        snapshot.handler?(segment)
    }

    private func extractTimeRange(from attributedText: AttributedString) -> CMTimeRange? {
        var earliestStart: CMTime?
        var latestEnd: CMTime?

        for run in attributedText.runs {
            guard let range = run.attributes[AttributeScopes.SpeechAttributes.TimeRangeAttribute.self] else {
                continue
            }

            if let currentStart = earliestStart {
                if CMTimeCompare(range.start, currentStart) < 0 {
                    earliestStart = range.start
                }
            } else {
                earliestStart = range.start
            }

            let runEnd = CMTimeRangeGetEnd(range)
            if let currentEnd = latestEnd {
                if CMTimeCompare(runEnd, currentEnd) > 0 {
                    latestEnd = runEnd
                }
            } else {
                latestEnd = runEnd
            }
        }

        if let start = earliestStart, let end = latestEnd {
            return CMTimeRange(start: start, end: end)
        }
        return nil
    }

    private nonisolated func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}

// MARK: - Shared state containers

private final class ResultState: @unchecked Sendable {
    private let lock = NSLock()
    private var currentSpeaker: SpeakerLabel = .me
    private var sessionStartTime = Date()
    private var handler: (@Sendable (TranscriptSegment) -> Void)?

    struct Snapshot {
        let speaker: SpeakerLabel
        let sessionStart: Date
        let handler: (@Sendable (TranscriptSegment) -> Void)?
    }

    func updateSpeaker(_ speaker: SpeakerLabel) {
        lock.lock()
        currentSpeaker = speaker
        lock.unlock()
    }

    func updateSessionStart(_ date: Date) {
        lock.lock()
        sessionStartTime = date
        lock.unlock()
    }

    func setHandler(_ handler: @escaping @Sendable (TranscriptSegment) -> Void) {
        lock.lock()
        self.handler = handler
        lock.unlock()
    }

    func snapshot() -> Snapshot {
        lock.lock()
        defer { lock.unlock() }
        return Snapshot(
            speaker: currentSpeaker,
            sessionStart: sessionStartTime,
            handler: handler
        )
    }

    func reset() {
        lock.lock()
        currentSpeaker = .me
        sessionStartTime = Date()
        handler = nil
        lock.unlock()
    }
}

private final class AudioPipelineBox: @unchecked Sendable {
    private let lock = NSLock()
    private var pipeline: AudioInputPipeline?

    func configure(
        analyzerFormat: AVAudioFormat,
        continuation: AsyncStream<AnalyzerInput>.Continuation,
        logger: Logger
    ) {
        let pipeline = AudioInputPipeline(
            analyzerFormat: analyzerFormat,
            continuation: continuation,
            logger: logger
        )
        lock.lock()
        self.pipeline = pipeline
        lock.unlock()
    }

    func process(buffer: AVAudioPCMBuffer) {
        guard let pipeline = currentPipeline() else { return }
        pipeline.process(buffer: buffer)
    }

    func finish() {
        lock.lock()
        let pipeline = self.pipeline
        self.pipeline = nil
        lock.unlock()
        pipeline?.finish()
    }

    private func currentPipeline() -> AudioInputPipeline? {
        lock.lock()
        defer { lock.unlock() }
        return pipeline
    }
}

private final class AudioInputPipeline {
    private let analyzerFormat: AVAudioFormat
    private let continuation: AsyncStream<AnalyzerInput>.Continuation
    private let logger: Logger
    private var converter: AVAudioConverter?
    private var totalFrames: AVAudioFramePosition = 0

    init(
        analyzerFormat: AVAudioFormat,
        continuation: AsyncStream<AnalyzerInput>.Continuation,
        logger: Logger
    ) {
        self.analyzerFormat = analyzerFormat
        self.continuation = continuation
        self.logger = logger
    }

    func process(buffer: AVAudioPCMBuffer) {
        guard let prepared = prepare(buffer: buffer) else { return }

        let timescale = max(1, CMTimeScale(analyzerFormat.sampleRate.rounded()))
        let start = CMTime(value: CMTimeValue(totalFrames), timescale: timescale)
        totalFrames += AVAudioFramePosition(prepared.frameLength)

        continuation.yield(AnalyzerInput(buffer: prepared, bufferStartTime: start))
    }

    func finish() {
        continuation.finish()
    }

    private func prepare(buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        if converter == nil || converter?.inputFormat != buffer.format {
            converter = AVAudioConverter(from: buffer.format, to: analyzerFormat)
        }

        guard let converter else {
            logger.error("Failed to create AVAudioConverter for analyzer pipeline")
            return nil
        }

        let durationSeconds = Double(buffer.frameLength) / buffer.format.sampleRate
        let targetFrames = max(
            1,
            AVAudioFrameCount(durationSeconds * analyzerFormat.sampleRate)
        )

        guard let output = AVAudioPCMBuffer(
            pcmFormat: analyzerFormat,
            frameCapacity: targetFrames
        ) else {
            logger.error("Unable to allocate conversion buffer for analyzer pipeline")
            return nil
        }

        var conversionError: NSError?
        output.frameLength = targetFrames

        let conversionStatus = converter.convert(to: output, error: &conversionError) { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        guard conversionStatus == .haveData else {
            let description = conversionError?.localizedDescription ?? "unknown error"
            logger.error("AVAudioConverter failed: \(description, privacy: .public)")
            return nil
        }

        return output
    }
}
