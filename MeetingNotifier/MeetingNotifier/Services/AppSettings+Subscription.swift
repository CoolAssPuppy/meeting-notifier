//
//  AppSettings+Subscription.swift
//  MeetingNotifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//
//  Which calendar accounts the subscription lets run. Split out of
//  `AppSettings` for the same reason `AppSettings+iCloudSync` is: the main file
//  is long enough, and this is one self-contained question.
//
//  The two statics are pure and take the account list as an argument, so they
//  answer without the store and test without one.
//

import Foundation

extension AppSettings {
    // MARK: - Subscription gate

    /// How many calendar accounts run without a subscription. Everything past
    /// this needs the paid plan. One number, one place, so changing the free
    /// tier is a one-line edit rather than a hunt through the gates.
    nonisolated static let freeAccountLimit = 1

    /// Accounts that are switched on and actually authorized on this Mac.
    ///
    /// The `.valid` half matters. An account synced from iCloud but never
    /// authorized here arrives as `.needsAuth`, and `loadAccounts()` creates
    /// those placeholders on every new Mac. Letting one hold the free slot would
    /// lock the calendar the person actually uses behind a paywall while a
    /// placeholder that fetches nothing sits in the free seat.
    nonisolated static func qualifying(_ accounts: [CalendarAccount]) -> [CalendarAccount] {
        accounts.filter { $0.isEnabled && $0.authStatus == .valid }
    }

    var qualifyingAccounts: [CalendarAccount] { Self.qualifying(accounts) }

    /// Splits accounts into the ones that may run and the ones the subscription
    /// gates.
    ///
    /// The free slots go to the first qualifying accounts in stored order, which
    /// is the order the sidebar shows. `makeFree(_:)` moves an account to the
    /// front, and that is how someone chooses which calendar stays free.
    ///
    /// Pure and static, taking the array as an argument, so it tests without a
    /// store, a network, or a UI.
    nonisolated static func partition(_ accounts: [CalendarAccount],
                          isEntitled: Bool,
                          limit: Int = freeAccountLimit)
        -> (active: [CalendarAccount], locked: [CalendarAccount]) {
        guard !isEntitled else { return (accounts, []) }
        let cut = Swift.max(0, limit)
        return (Array(accounts.prefix(cut)), Array(accounts.dropFirst(cut)))
    }

    /// The entitlement as the manager holds it in memory. Everything here is
    /// `@MainActor`, so there is no reason to decode the persisted copy again —
    /// and `Sidebar` calls `isLocked` once per row, which made that decode
    /// happen N times per redraw.
    private var isEntitledNow: Bool { EntitlementManager.shared.isEntitled }

    /// Qualifying accounts allowed to run under the current entitlement.
    var activeAccounts: [CalendarAccount] {
        Self.partition(qualifyingAccounts, isEntitled: isEntitledNow).active
    }

    /// Qualifying accounts the subscription is holding back. Empty when entitled.
    var lockedAccounts: [CalendarAccount] {
        Self.partition(qualifyingAccounts, isEntitled: isEntitledNow).locked
    }

    /// The ids of every paused account, for callers checking many accounts in a
    /// row. `Sidebar` builds this once per redraw rather than asking per row.
    var lockedAccountIDs: Set<String> {
        Set(lockedAccounts.map(\.id))
    }

    /// True when the given account is one the subscription has paused. Drives
    /// the account banner. In a loop, prefer `lockedAccountIDs`.
    func isLocked(_ account: CalendarAccount) -> Bool {
        lockedAccounts.contains { $0.id == account.id }
    }

    /// True when another account can be connected without paying. The first one
    /// is always free.
    var canAddAnotherAccount: Bool {
        if isEntitledNow { return true }
        return qualifyingAccounts.count < Self.freeAccountLimit
    }

    /// Moves an account to the front of the list, which hands it the free slot.
    /// The escape hatch for someone who does not want to pay but connected the
    /// wrong calendar first.
    func makeFree(_ account: CalendarAccount) {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }), index > 0 else { return }
        let moved = accounts.remove(at: index)
        accounts.insert(moved, at: 0)
    }
}
