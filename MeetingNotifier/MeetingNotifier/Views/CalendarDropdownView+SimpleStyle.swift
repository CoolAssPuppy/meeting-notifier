//
//  CalendarDropdownView+SimpleStyle.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import SwiftUI

// MARK: - Simple style views

extension CalendarDropdownView {
    var simpleHeaderView: some View {
        EmptyView()
    }

    var simpleAuthErrorBanner: some View {
        Button(action: {
            NotificationCenter.default.post(name: .settingsRequested, object: nil)
        }) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)

                Text("Authentication required")
                    .font(.system(size: 13))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.1))
        }
        .buttonStyle(.plain)
    }

    var simpleLoadingView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)

            Text("Loading...")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var simpleFooterView: some View {
        VStack(spacing: 0) {
            SimpleMenuButton(title: "Settings", icon: "gearshape") {
                NotificationCenter.default.post(name: .settingsRequested, object: nil)
            }

            Divider()

            SimpleMenuButton(title: "Quit", icon: "power") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    func simpleSectionHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

// MARK: - Simple menu button

struct SimpleMenuButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(isHovered ? .white.opacity(0.7) : .secondary)
                    .frame(width: 16)

                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(isHovered ? .white : .primary)

                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? Color.accentColor : Color.clear)
            )
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
