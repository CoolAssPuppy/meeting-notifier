//
//  ClassicMenuBuilder.swift
//  Meeting Notifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import AppKit

// MARK: - Closure-backed menu item

/// `NSMenuItem.target` is a weak reference, so an item that points at a
/// short-lived helper object would silently stop firing. Targeting itself
/// keeps the handler alive exactly as long as the menu that owns the item.
private final class ClassicMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(invoke), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func invoke() {
        handler()
    }
}

// MARK: - Builder

/// Builds the classic dropdown: your remaining day (and, after 5 PM, the day
/// ahead) as one row per meeting, each with a flyout whose first item is the
/// join link, plus the icon strip at the bottom.
///
/// Which days appear is not decided here. `CalendarDataManager` already filters
/// its events through `EventWindow`, which drops tomorrow before 5 PM local
/// time, so an afternoon click shows today and an evening click shows what's
/// left today followed by tomorrow.
@MainActor
enum ClassicMenuBuilder {
    struct Actions {
        var join: (CalendarEvent) -> Void
        var openInCalendar: (CalendarEvent) -> Void
        var copyLink: (CalendarEvent) -> Void
        var startTranscription: (CalendarEvent) -> Void
        var reauthorize: () -> Void
        var refresh: () -> Void
        var openWindow: () -> Void
        var openSettings: () -> Void
        var openTranscription: () -> Void
        var quit: () -> Void
    }

    /// Everything the menu needs to render one opening. Passed in rather than
    /// read from singletons so the builder stays a pure function of its input.
    struct Content {
        var today: [CalendarEvent]
        var tomorrow: [CalendarEvent]
        var isLoading: Bool
        var hasAccounts: Bool
        var hasAuthError: Bool
        var isNotetakerEnabled: Bool
        var travelInfo: (CalendarEvent) -> TravelTimeInfo?
        /// SF Symbol for the user's preferred travel mode. Passed in rather
        /// than read from `AppSettings.shared`, which is main-actor isolated.
        var travelModeIcon: String
    }

    private static let maximumTitleLength = 52
    private static let platformIconSize = NSSize(width: 14, height: 14)
    private static let colorDotSize = NSSize(width: 8, height: 8)

    static func makeMenu(content: Content, actions: Actions) -> NSMenu {
        let menu = NSMenu()
        // Items here are enabled explicitly. Automatic enabling walks the
        // responder chain and would grey out everything in a menu owned by an
        // .accessory app with no key window.
        menu.autoenablesItems = false

        if content.hasAuthError {
            menu.addItem(authErrorItem(actions: actions))
            menu.addItem(.separator())
        }

        appendBody(to: menu, content: content, actions: actions)

        menu.addItem(.separator())
        menu.addItem(footerItem(actions: actions))

        return menu
    }

    // MARK: Body

    private static func appendBody(to menu: NSMenu, content: Content, actions: Actions) {
        guard content.hasAccounts else {
            appendPlaceholder(NSLocalizedString("No accounts connected", comment: ""), to: menu)
            menu.addItem(ClassicMenuItem(title: NSLocalizedString("Add a calendar…", comment: ""),
                                         handler: actions.openSettings))
            return
        }

        let hasEvents = !content.today.isEmpty || !content.tomorrow.isEmpty

        if content.isLoading && !hasEvents {
            appendPlaceholder(NSLocalizedString("Loading…", comment: ""), to: menu)
            return
        }

        guard hasEvents else {
            appendPlaceholder(NSLocalizedString("Nothing left on your calendar", comment: ""), to: menu)
            return
        }

        // The Today header disappears once today is spent, so an evening click
        // opens straight onto tomorrow rather than an empty heading.
        if !content.today.isEmpty {
            appendSection(title: sectionTitle(NSLocalizedString("Today", comment: ""), date: Date()),
                          events: content.today,
                          to: menu,
                          content: content,
                          actions: actions)
        }

        if !content.tomorrow.isEmpty {
            if !content.today.isEmpty { menu.addItem(.separator()) }
            let tomorrowDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            appendSection(title: sectionTitle(NSLocalizedString("Tomorrow", comment: ""), date: tomorrowDate),
                          events: content.tomorrow,
                          to: menu,
                          content: content,
                          actions: actions)
        }
    }

    private static func appendSection(title: String,
                                      events: [CalendarEvent],
                                      to menu: NSMenu,
                                      content: Content,
                                      actions: Actions) {
        menu.addItem(.sectionHeader(title: title))
        for event in events {
            menu.addItem(eventItem(for: event, content: content, actions: actions))
        }
    }

    private static func sectionTitle(_ label: String, date: Date) -> String {
        "\(label) · \(date.headerDateString)"
    }

    private static func appendPlaceholder(_ title: String, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private static func authErrorItem(actions: Actions) -> NSMenuItem {
        let item = ClassicMenuItem(title: NSLocalizedString("Authorization expired — reconnect", comment: ""),
                                   handler: actions.reauthorize)
        let icon = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Warning")
        icon?.isTemplate = false
        item.image = icon
        return item
    }

    // MARK: Event row

    /// AppKit never sends an item's action when that item owns a submenu — the
    /// click opens the flyout instead. Every meeting has a flyout, so the join
    /// link leads it rather than living on the row.
    private static func eventItem(for event: CalendarEvent,
                                  content: Content,
                                  actions: Actions) -> NSMenuItem {
        let item = NSMenuItem(title: rowTitle(for: event), action: nil, keyEquivalent: "")
        item.image = colorDot(hex: event.calendarColorHex)
        item.toolTip = event.title
        item.submenu = flyout(for: event, content: content, actions: actions)
        return item
    }

    private static func rowTitle(for event: CalendarEvent) -> String {
        let marker = event.isHappening ? "● " : ""
        return "\(marker)\(event.formattedTime)  \(truncated(event.title))"
    }

    private static func truncated(_ title: String) -> String {
        let collapsed = title
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !collapsed.isEmpty else { return NSLocalizedString("(No title)", comment: "") }
        guard collapsed.count > maximumTitleLength else { return collapsed }
        return collapsed.prefix(maximumTitleLength).trimmingCharacters(in: .whitespaces) + "…"
    }

    // MARK: Flyout

    private static func flyout(for event: CalendarEvent,
                               content: Content,
                               actions: Actions) -> NSMenu {
        let submenu = NSMenu()
        submenu.autoenablesItems = false

        appendJoinItems(for: event, to: submenu, actions: actions)

        let openInCalendar = ClassicMenuItem(title: NSLocalizedString("Open in Calendar", comment: "")) {
            actions.openInCalendar(event)
        }
        openInCalendar.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Calendar")
        submenu.addItem(openInCalendar)

        if content.isNotetakerEnabled {
            let transcribe = ClassicMenuItem(title: NSLocalizedString("Start Transcription", comment: "")) {
                actions.startTranscription(event)
            }
            transcribe.image = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: "Transcription")
            submenu.addItem(transcribe)
        }

        submenu.addItem(.separator())
        appendInfoRows(for: event, to: submenu, content: content)

        return submenu
    }

    private static func appendJoinItems(for event: CalendarEvent,
                                        to submenu: NSMenu,
                                        actions: Actions) {
        guard event.conferenceLink != nil else { return }

        let title: String
        if let platform = event.videoPlatform {
            title = String(format: NSLocalizedString("Join %@", comment: "Join video conference"),
                           platform.displayName)
        } else {
            title = NSLocalizedString("Join meeting", comment: "Join an unrecognized conference link")
        }

        let join = ClassicMenuItem(title: title) { actions.join(event) }
        join.image = platformIcon(for: event.videoPlatform)
        join.attributedTitle = NSAttributedString(
            string: title,
            attributes: [.font: NSFont.menuFont(ofSize: 0).bold]
        )
        submenu.addItem(join)

        let copyLink = ClassicMenuItem(title: NSLocalizedString("Copy Link", comment: "")) {
            actions.copyLink(event)
        }
        copyLink.image = NSImage(systemSymbolName: "link", accessibilityDescription: "Link")
        submenu.addItem(copyLink)

        submenu.addItem(.separator())
    }

    /// Everything the pretty popover shows on a meeting card, as inert rows.
    /// `isEnabled = false` styles them as informational and kills click feedback.
    private static func appendInfoRows(for event: CalendarEvent,
                                       to submenu: NSMenu,
                                       content: Content) {
        submenu.addItem(infoItem(title: timeRange(for: event),
                                 symbolName: event.isHappening ? "record.circle" : "clock"))

        submenu.addItem(infoItem(title: event.calendarName, symbolName: "tray.full"))

        if event.attendeeCount > 1 {
            submenu.addItem(infoItem(
                title: String(format: NSLocalizedString("%d People", comment: "Number of attendees"),
                              event.attendeeCount),
                symbolName: "person.2"
            ))
        }

        if let location = event.location?.trimmingCharacters(in: .whitespacesAndNewlines), !location.isEmpty {
            submenu.addItem(infoItem(title: location, symbolName: "mappin.and.ellipse"))
        }

        if event.hasPhysicalLocation, let travel = content.travelInfo(event) {
            submenu.addItem(infoItem(title: travelTitle(for: travel),
                                     symbolName: content.travelModeIcon))
        }
    }

    private static func timeRange(for event: CalendarEvent) -> String {
        let range = "\(event.formattedTime) – \(endTimeString(for: event))"
        if event.isHappening {
            return String(format: NSLocalizedString("%@ · Happening now", comment: ""), range)
        }
        return "\(range) · \(event.timeUntilStart)"
    }

    private static func endTimeString(for event: CalendarEvent) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter.string(from: event.endDate)
    }

    private static func travelTitle(for travel: TravelTimeInfo) -> String {
        guard !travel.shouldLeaveNow else {
            return NSLocalizedString("Leave now to arrive in time", comment: "Travel time alert")
        }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return String(format: NSLocalizedString("Leave at %@ to arrive in time", comment: "Travel time with departure time"),
                      formatter.string(from: travel.leaveByTime))
    }

    private static func infoItem(title: String, symbolName: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        return item
    }

    // MARK: Footer

    private static func footerItem(actions: Actions) -> NSMenuItem {
        let item = NSMenuItem()
        item.view = ClassicMenuFooterView(actions: .init(refresh: actions.refresh,
                                                        openWindow: actions.openWindow,
                                                        openSettings: actions.openSettings,
                                                        openTranscription: actions.openTranscription,
                                                        quit: actions.quit))
        return item
    }

    // MARK: Images

    private static func platformIcon(for platform: VideoPlatform?) -> NSImage? {
        if let platform,
           let path = Bundle.main.path(forResource: platform.iconName, ofType: "png"),
           let image = NSImage(contentsOfFile: path) {
            image.size = platformIconSize
            return image
        }
        let fallback = NSImage(systemSymbolName: "video.fill", accessibilityDescription: "Join")
        fallback?.size = platformIconSize
        return fallback
    }

    private static func colorDot(hex: String) -> NSImage {
        let image = NSImage(size: colorDotSize, flipped: false) { rect in
            (NSColor(hex: hex) ?? .systemBlue).setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        image.isTemplate = false
        return image
    }
}

// MARK: - Bold menu font

private extension NSFont {
    var bold: NSFont {
        NSFontManager.shared.convert(self, toHaveTrait: .boldFontMask)
    }
}
