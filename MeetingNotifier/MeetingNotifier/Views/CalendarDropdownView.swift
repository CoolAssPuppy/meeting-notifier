//
//  CalendarDropdownView.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import SwiftUI

struct CalendarDropdownView: View {
    @ObservedObject var dataManager = CalendarDataManager.shared
    @ObservedObject var appSettings = AppSettings.shared
    @State var isRefreshing = false

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 0) {
                if appSettings.dropDownStyle == .simple {
                    simpleHeaderView
                } else {
                    glassHeaderView

                    LinearGradient(
                        colors: [
                            Color.primary.opacity(0.1),
                            Color.primary.opacity(0.05)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 1)
                }

                if hasAuthErrors {
                    if appSettings.dropDownStyle == .simple {
                        simpleAuthErrorBanner
                    } else {
                        glassAuthErrorBanner
                    }
                }

                if dataManager.isLoading && dataManager.events.isEmpty {
                    if appSettings.dropDownStyle == .simple {
                        simpleLoadingView
                    } else {
                        glassLoadingView
                    }
                } else if dataManager.events.isEmpty {
                    EmptyStateView()
                } else {
                    meetingListView
                }

                if appSettings.dropDownStyle == .simple {
                    Divider()
                    simpleFooterView
                } else {
                    LinearGradient(
                        colors: [
                            Color.primary.opacity(0.05),
                            Color.primary.opacity(0.1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 1)

                    glassFooterView
                }
            }
        }
        .frame(width: appSettings.dropDownStyle == .simple ? 320 : 380, height: appSettings.dropDownStyle == .simple ? 400 : 500)
        .clipShape(RoundedRectangle(cornerRadius: appSettings.dropDownStyle == .simple ? 10 : 16))
        .shadow(color: Color.black.opacity(appSettings.dropDownStyle == .simple ? 0.15 : 0.2), radius: appSettings.dropDownStyle == .simple ? 10 : 20, x: 0, y: appSettings.dropDownStyle == .simple ? 4 : 10)
        .overlay(
            Group {
                if appSettings.dropDownStyle == .simple {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
            }
        )
    }

    // MARK: - Shared helpers

    var hasAuthErrors: Bool {
        appSettings.accounts.contains { $0.authStatus != .valid }
    }

    private var backgroundGradient: some View {
        ZStack {
            if appSettings.dropDownStyle == .simple {
                Rectangle()
                    .fill(.regularMaterial)
            } else {
                Rectangle()
                    .fill(.ultraThinMaterial)

                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.03),
                        Color.clear,
                        Color.purple.opacity(0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    var meetingListView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                let todayEvents = dataManager.todayEvents()
                let tomorrowEvents = dataManager.tomorrowEvents()

                if !todayEvents.isEmpty {
                    if appSettings.dropDownStyle == .simple {
                        simpleSectionHeader(title: "Today")
                    } else {
                        glassSectionHeader(title: "Today", count: todayEvents.count)
                    }
                    ForEach(todayEvents) { event in
                        meetingRow(for: event)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.95).combined(with: .opacity),
                                removal: .scale(scale: 0.95).combined(with: .opacity)
                            ))
                    }
                }

                if !tomorrowEvents.isEmpty {
                    if !todayEvents.isEmpty {
                        Spacer()
                            .frame(height: appSettings.dropDownStyle == .simple ? 8 : 16)
                    }
                    if appSettings.dropDownStyle == .simple {
                        simpleSectionHeader(title: "Tomorrow")
                    } else {
                        glassSectionHeader(title: "Tomorrow", count: tomorrowEvents.count)
                    }
                    ForEach(tomorrowEvents) { event in
                        meetingRow(for: event)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.95).combined(with: .opacity),
                                removal: .scale(scale: 0.95).combined(with: .opacity)
                            ))
                    }
                }
            }
            .padding(.vertical, appSettings.dropDownStyle == .simple ? 8 : 12)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: dataManager.events.count)
        }
    }

    @ViewBuilder
    private func meetingRow(for event: CalendarEvent) -> some View {
        if appSettings.dropDownStyle == .simple {
            SimpleMeetingRowView(event: event) {
                handleEventTap(event)
            }
        } else {
            MeetingRowView(event: event) {
                handleEventTap(event)
            }
        }
    }

    private func handleEventTap(_ event: CalendarEvent) {
        guard let conferenceLink = event.conferenceLink,
              let url = URL(string: conferenceLink) else {
            return
        }

        AppSettings.shared.openURL(url, accountEmail: event.accountEmail)
    }
}

struct CalendarDropdownView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarDropdownView()
    }
}
