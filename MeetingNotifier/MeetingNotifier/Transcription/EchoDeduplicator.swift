//
//  EchoDeduplicator.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation
import os

/// Detects and suppresses echo segments where the microphone picks up
/// system audio (e.g., when the user is not wearing headphones).
///
/// When both mic and system audio are being transcribed simultaneously,
/// the mic can pick up the remote participants' voices from the speakers.
/// This produces duplicate "Me" segments that echo what "Others" said.
///
/// The algorithm: for each incoming "Me" segment, check all recent "Others"
/// segments within a time window. If the text similarity exceeds a threshold,
/// the "Me" segment is considered an echo and should be dropped.
final class EchoDeduplicator: @unchecked Sendable {
    private let lock = NSLock()
    private var recentSegments: [TranscriptSegment] = []

    /// Maximum time difference (in seconds) between segments to consider them
    /// potential echoes. Accounts for transcription latency between the two streams.
    private let timeWindowSeconds: TimeInterval = 5.0

    /// Minimum text similarity ratio (0.0–1.0) to consider a segment an echo.
    private let similarityThreshold: Double = 0.5

    /// Maximum number of recent segments to keep for comparison.
    private let maxRecentSegments = 100

    /// Check whether a segment is an echo of a recently seen segment from the
    /// opposite audio source. If not an echo, the segment is recorded internally
    /// for future comparisons.
    ///
    /// - Returns: `true` if the segment should be kept, `false` if it's an echo.
    func shouldKeep(_ segment: TranscriptSegment) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        // Only check "Me" segments for being echoes of "Others" segments.
        // System audio is the cleaner source, so we always keep "Others".
        if segment.speaker == .me {
            let isEcho = recentSegments.contains { other in
                guard other.speaker == .others else { return false }
                let timeDiff = abs(segment.startTime - other.startTime)
                guard timeDiff <= timeWindowSeconds else { return false }
                return textSimilarity(segment.text, other.text) >= similarityThreshold
            }

            if isEcho {
                Logger.transcription.debug("Echo detected, dropping: \"\(segment.text.prefix(50))\"")
                return false
            }
        }

        // Record this segment for future comparisons
        recentSegments.append(segment)

        // Prune old segments to bound memory
        if recentSegments.count > maxRecentSegments {
            recentSegments.removeFirst(recentSegments.count - maxRecentSegments)
        }

        return true
    }

    /// Reset internal state (e.g., when starting a new transcription session).
    func reset() {
        lock.lock()
        recentSegments.removeAll()
        lock.unlock()
    }

    // MARK: - Text similarity

    /// Compute the similarity ratio between two strings using a longest-common-
    /// subsequence approach, similar to Python's `difflib.SequenceMatcher.ratio()`.
    private func textSimilarity(_ a: String, _ b: String) -> Double {
        let aLower = a.lowercased()
        let bLower = b.lowercased()

        guard !aLower.isEmpty && !bLower.isEmpty else { return 0 }

        let aChars = Array(aLower)
        let bChars = Array(bLower)
        let lcsLength = longestCommonSubsequenceLength(aChars, bChars)

        return Double(2 * lcsLength) / Double(aChars.count + bChars.count)
    }

    private func longestCommonSubsequenceLength(_ a: [Character], _ b: [Character]) -> Int {
        let m = a.count
        let n = b.count

        // Use two-row DP to save memory
        var prev = [Int](repeating: 0, count: n + 1)
        var curr = [Int](repeating: 0, count: n + 1)

        for i in 1...m {
            for j in 1...n {
                if a[i - 1] == b[j - 1] {
                    curr[j] = prev[j - 1] + 1
                } else {
                    curr[j] = max(prev[j], curr[j - 1])
                }
            }
            prev = curr
            curr = [Int](repeating: 0, count: n + 1)
        }

        return prev[n]
    }
}
