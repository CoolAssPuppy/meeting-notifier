//
//  TranscriptionEngineProtocol.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import AVFoundation
import Foundation

/// Transcription engine protocol.
///
/// The protocol itself is NOT @MainActor so that protocol existentials
/// (any TranscriptionEngine) can be accessed from any thread without
/// triggering actor isolation checks. Individual methods that need
/// MainActor isolation are annotated explicitly.
protocol TranscriptionEngine: AnyObject, Sendable {
    var engineType: TranscriptionEngineType { get }
    @MainActor var isAvailable: Bool { get }

    @MainActor func start(locale: String) async throws
    @MainActor func stop() async
    @MainActor func setSegmentHandler(_ handler: @escaping @Sendable (TranscriptSegment) -> Void)

    /// Called on the audio render thread. Implementations must be thread-safe.
    nonisolated func processAudioBuffer(_ buffer: AVAudioPCMBuffer, speaker: SpeakerLabel)

    /// Returns a closure that processes audio buffers on the audio render thread.
    /// This avoids protocol existential dispatch on the hot path.
    nonisolated func makeBufferProcessor(speaker: SpeakerLabel) -> @Sendable (AVAudioPCMBuffer) -> Void
}
