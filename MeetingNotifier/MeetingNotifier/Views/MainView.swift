//
//  MainView.swift
//  MeetingNotifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import SwiftUI

/// Root of the main window: sidebar + detail, with drawer overlays.
struct MainView: View {
    @ObservedObject private var themeStore = ThemeStore.shared
    @ObservedObject private var appSettings = AppSettings.shared
    @StateObject private var drawerState = DrawerState.shared

    @State private var selectedAccountEmail: String?

    var body: some View {
        let theme = themeStore.palette
        return ZStack(alignment: .top) {
            content
                .frame(minWidth: 880, minHeight: 580)
                .background(theme.background)

            WindowChrome(palette: theme)
                .frame(width: 0, height: 0)

            drawerOverlay(theme: theme)
        }
        .environment(\.theme, theme)
        .environment(\.colorScheme, theme.isDark ? .dark : .light)
        .onAppear {
            if selectedAccountEmail == nil {
                selectedAccountEmail = appSettings.accounts.first?.email
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        HStack(spacing: 0) {
            Sidebar(selectedEmail: $selectedAccountEmail)
                .frame(width: 260)

            if let email = selectedAccountEmail,
               let account = appSettings.accounts.first(where: { $0.email == email }) {
                AccountView(account: account)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                WelcomeView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private func drawerOverlay(theme: ThemePalette) -> some View {
        if drawerState.openDrawer != .none {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .transition(.opacity)
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.26)) {
                        drawerState.openDrawer = .none
                    }
                }

            Group {
                switch drawerState.openDrawer {
                case .settings:
                    SettingsDrawer(onClose: close)
                case .transcription:
                    TranscriptionDrawer(onClose: close)
                case .none:
                    EmptyView()
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            ))
        }
    }

    private func close() {
        withAnimation(.easeOut(duration: 0.26)) {
            drawerState.openDrawer = .none
        }
    }
}

// MARK: - Drawer state

enum DrawerKind { case none, settings, transcription }

@MainActor
final class DrawerState: ObservableObject {
    static let shared = DrawerState()
    @Published var openDrawer: DrawerKind = .none

    func open(_ kind: DrawerKind) {
        withAnimation(.easeOut(duration: 0.26)) {
            openDrawer = kind
        }
    }
}

// MARK: - Welcome state

private struct WelcomeView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: AppSpacing.xxl) {
            BrandMark(size: 56)

            VStack(spacing: 8) {
                Text("Welcome to Meeting Notifier")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(theme.foreground)
                Text("Connect a Google or Microsoft calendar to see every meeting in the menu bar, get timely notifications, and transcribe audio into markdown notes.")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 440)
            }

            HStack(spacing: AppSpacing.lg) {
                AppPrimaryButton(title: "Add Google account", systemImage: "plus") {
                    AppDelegate.shared?.addGoogleAccount()
                }
                AppSecondaryButton(title: "Add Microsoft account", systemImage: "plus") {
                    AppDelegate.shared?.addMicrosoftAccount()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
