//
//  ConfigTab.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import SwiftUI
import AppKit
import os

struct ConfigTab: View {
    @ObservedObject var settings = AppSettings.shared

    @State var showingAppPicker = false
    @State var customAppURL: URL?
    @State var showingCoffee = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Form {
                    Section {
                        notificationsToggle
                        oneMinuteWarningToggle
                        customRemindersInfo
                        notificationPermissionsInfo
                    } header: {
                        sectionHeader(icon: "bell.fill", title: "Notifications", gradient: [.blue, .cyan])
                    }

                    Section {
                        meetAppPicker
                    } header: {
                        sectionHeader(icon: "link.circle.fill", title: "Meeting Links", gradient: [.purple, .pink])
                    }

                    Section {
                        menuBarToggle
                        if settings.menuBarDisplayMode == .inMenuBar {
                            displayModePicker
                            thresholdSlider
                            showAllDayToggle
                        }
                        if settings.menuBarDisplayMode == .peekWindow {
                            peekWindowThresholdSlider
                        }
                        attendeesToggle
                        doubleBookingPicker
                        meetingCountBadgeToggle
                    } header: {
                        sectionHeader(icon: "menubar.rectangle", title: "Menu Bar Display", gradient: [.green, .mint])
                    }

                    Section {
                        dropDownStylePicker
                    } header: {
                        sectionHeader(icon: "list.bullet.rectangle", title: "Drop Down Style", gradient: [.purple, .indigo])
                    }

                    Section {
                        soundsToggle
                    } header: {
                        sectionHeader(icon: "speaker.wave.2.fill", title: "Sounds", gradient: [.orange, .yellow])
                    }

                    Section {
                        travelTimeAlertsToggle
                        if settings.showTravelTimeAlerts {
                            travelModePicker
                        }
                        mapProviderPicker
                    } header: {
                        sectionHeader(icon: "location.circle.fill", title: "Travel & Location", gradient: [.teal, .cyan])
                    }

                    Section {
                        launchAtLoginToggle
                    } header: {
                        sectionHeader(icon: "power.circle.fill", title: "Startup", gradient: [.indigo, .blue])
                    }

                    Section {
                        keyboardShortcutsInfo
                    } header: {
                        sectionHeader(icon: "command.circle.fill", title: "Keyboard Shortcuts", gradient: [.red, .orange])
                    }

                    Section {
                        buyMeCoffeeButton
                    } header: {
                        sectionHeader(icon: "cup.and.saucer.fill", title: "Support", gradient: [.brown, .orange])
                    }

                    Section {
                        aboutSection
                    } header: {
                        sectionHeader(icon: "info.circle.fill", title: "About", gradient: [.gray, .secondary])
                    }
                }
                .formStyle(.grouped)
            }
            .padding(20)
        }
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.02),
                    Color.clear,
                    Color.purple.opacity(0.01)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .fileImporter(
            isPresented: $showingAppPicker,
            allowedContentTypes: [.application],
            allowsMultipleSelection: false
        ) { result in
            handleAppSelection(result)
        }
    }

    // MARK: - Section header

    func sectionHeader(icon: String, title: String, gradient: [Color]) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.primary)
        }
    }

    // MARK: - Helper methods

    func handleAppSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                customAppURL = url
                UserDefaults.standard.set(url.path, forKey: "customMeetAppPath")
            }
        case .failure(let error):
            Logger.settings.error("Error selecting app: \(error.localizedDescription)")
            settings.defaultMeetApp = .defaultBrowser
        }
    }
}

struct ConfigTab_Previews: PreviewProvider {
    static var previews: some View {
        ConfigTab()
            .frame(width: 500, height: 600)
    }
}
