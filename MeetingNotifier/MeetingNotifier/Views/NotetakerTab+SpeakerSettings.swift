//
//  NotetakerTab+SpeakerSettings.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import SwiftUI

// MARK: - Speaker label settings

extension NotetakerTab {
    var speakerNameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Your display name", text: $settings.speakerDisplayName)
                .textFieldStyle(.roundedBorder)

            Text("Your name as it appears in transcripts")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    var othersNameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Others display name", text: $settings.othersDisplayName)
                .textFieldStyle(.roundedBorder)

            Text("Label for other speakers")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
