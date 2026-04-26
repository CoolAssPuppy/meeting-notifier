//
//  TranscriptRecoveryStore.swift
//  MeetingNotifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//
//  Crash-recovery scratch file for in-progress transcripts. The coordinator
//  writes the current document here every 30s; on next launch we look for
//  the file and persist whatever segments we recovered as a markdown note.
//

import Foundation
import os

enum TranscriptRecoveryStore {

    static var fileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("MeetingNotifier/recovery", isDirectory: true)
            .appendingPathComponent("active-transcript.json")
    }

    /// Persist the current document JSON to the recovery file. Atomic write,
    /// 0600 perms, complete file protection. Best-effort — logs on failure.
    static func write(_ document: TranscriptDocument) {
        let url = fileURL
        do {
            let data = try JSONEncoder().encode(document)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: url.path
            )
        } catch {
            Logger.transcription.warning("Recovery file write failed: \(error.localizedDescription)")
        }
    }

    /// Read and decode any leftover recovery file. Returns nil when no file
    /// exists or the contents can't be decoded.
    static func read() -> TranscriptDocument? {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(TranscriptDocument.self, from: data)
        } catch {
            Logger.transcription.error("Recovery file decode failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Wipe the recovery file. Overwrites with empty bytes before unlinking
    /// so a stuck file (e.g. mid-Time-Machine) never carries stale content
    /// forward.
    static func clear() {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try? Data().write(to: url, options: [.atomic])
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            Logger.transcription.warning("Failed to remove recovery file: \(error.localizedDescription, privacy: .public)")
        }
    }
}
