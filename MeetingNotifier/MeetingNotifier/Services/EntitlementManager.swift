//
//  EntitlementManager.swift
//  MeetingNotifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//
//  Owns entitlement for the paid multi-account capability: the license key and
//  activation id (Keychain), the cached status and expiry (UserDefaults), a
//  launch check plus a daily re-check at 00:00 Pacific, and the derived gate the
//  add-account and refresh paths read. The billing provider hides behind
//  `LicenseProvider`, so it stays swappable.
//
//  Grace: a successful validate replaces the record. A network or transient
//  server failure leaves the prior record untouched, so an outage never locks
//  out someone who paid. An explicit bad key lapses immediately. With no expiry
//  on the key (how the Polar benefit is configured), revocation on cancellation
//  is the lapse signal, and the app learns about it on its next successful
//  validate.
//

import Foundation
import Combine
import os

/// Where the license key and activation id live. A protocol so tests run
/// without touching the real Keychain, which would otherwise prompt.
@MainActor
protocol LicenseCredentialStore {
    func licenseValue(for account: String) -> String?
    func setLicenseValue(_ value: String?, for account: String)
}

/// Meeting Notifier's own Keychain wrapper, adapted to the store protocol.
///
/// Deliberately not added to `KeychainManager.syncableAccounts`: activation is
/// per Mac and the benefit allows five of them, so syncing the key through
/// iCloud would have two Macs fighting over one activation id.
extension KeychainManager: LicenseCredentialStore {
    func licenseValue(for account: String) -> String? {
        retrieve(forAccount: account)
    }

    func setLicenseValue(_ value: String?, for account: String) {
        if let value {
            if !save(token: value, forAccount: account) {
                Logger.license.error("Failed to write \(account, privacy: .public) to the keychain")
            }
        } else {
            _ = delete(forAccount: account)
        }
    }
}

/// The cached, persisted entitlement snapshot.
struct EntitlementRecord: Codable, Equatable, Sendable {
    var statusRaw: String
    var expiresAt: Date?
    var customerId: String?
    var lastValidatedAt: Date?

    var state: LicenseStatus.State { LicenseStatus.State(rawValue: statusRaw) ?? .unknown }
}

extension EntitlementRecord {
    /// Folds a provider status into a cached record at a given time. Declared in
    /// an extension so the memberwise initializer stays synthesized.
    init(from status: LicenseStatus, validatedAt: Date) {
        self.init(statusRaw: status.state.rawValue,
                  expiresAt: status.expiresAt,
                  customerId: status.customerId,
                  lastValidatedAt: validatedAt)
    }
}

/// The user-facing state of the subscription.
enum EntitlementState: Equatable, Sendable {
    /// Paid up. Every calendar account runs.
    case active
    /// Subscribed before, now expired or revoked. Extra accounts go locked.
    case lapsed
    /// Never subscribed. The free tier.
    case none
    /// No Polar organization is configured, so there is nothing to sell and no
    /// gate to enforce. What a fork or an unconfigured dev build looks like.
    case unavailable
}

@MainActor
final class EntitlementManager: ObservableObject {
    static let shared = EntitlementManager()

    /// The cached entitlement, source of truth for every gate. Published so the
    /// sidebar, account view, and paywall redraw the moment a key activates.
    @Published private(set) var record: EntitlementRecord?

    private let provider: LicenseProvider
    private let store: LicenseCredentialStore
    private let defaults: UserDefaults
    private let clock: @Sendable () -> Date
    private let timeZone: TimeZone
    private var dailyTask: Task<Void, Never>?

    /// Nonisolated because `isEntitledNow` and `loadRecord` read it off the
    /// main actor.
    nonisolated static let storageKey = "entitlement.record.v1"
    /// Keychain accounts, inside the same service the OAuth tokens use.
    private static let licenseKeyAccount = "license.key"
    private static let activationIdAccount = "license.activation_id"

    init(provider: LicenseProvider = PolarLicenseClient(),
         store: LicenseCredentialStore = KeychainManager.shared,
         defaults: UserDefaults = .standard,
         clock: @escaping @Sendable () -> Date = { Date() },
         timeZone: TimeZone = TimeZone(identifier: "America/Los_Angeles") ?? .current) {
        self.provider = provider
        self.store = store
        self.defaults = defaults
        self.clock = clock
        self.timeZone = timeZone
        self.record = Self.loadRecord(from: defaults)
    }

    // MARK: Lifecycle

    /// Validates on launch and schedules the daily re-check. Called once from
    /// `AppDelegate`.
    func start() {
        if PolarConfig.isBenefitPinMissing {
            Logger.license.error("POLAR_BENEFIT_ID is empty in a build that sells subscriptions. Any Strategic Nerds license key will unlock this app.")
        }
        Task { await validateNow() }
        scheduleDailyCheck()
    }

    func stop() {
        dailyTask?.cancel()
        dailyTask = nil
    }

    // MARK: Derived gate

    /// The one question every gate asks. True only while the license is granted
    /// and, when the provider supplies an expiry, before that expiry passes.
    var isEntitled: Bool {
        state == .active || state == .unavailable
    }

    /// Distinguishes "never subscribed" from "subscribed and lapsed", which the
    /// Settings card and the paywall word differently.
    var state: EntitlementState {
        guard PolarConfig.isConfigured else { return .unavailable }
        guard let record else { return .none }
        return Self.isEntitled(record: record, now: clock()) ? .active : .lapsed
    }

    /// The paid-through date, when there is one. `nil` on a key without an
    /// expiry, which is the normal case for this product.
    var expiresAt: Date? { record?.expiresAt }

    /// True once a key has been stored on this device, regardless of whether it
    /// still validates. Drives "Remove from this Mac" in Settings.
    var hasStoredKey: Bool {
        guard let key = store.licenseValue(for: Self.licenseKeyAccount) else { return false }
        return !key.isEmpty
    }

    // MARK: Operations

    /// Activates a pasted key, persisting the key and the activation id.
    func activate(key: String) async throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LicenseError.invalidKey }
        let activation = try await provider.activate(key: trimmed, deviceLabel: Self.deviceLabel())
        persist(licenseKey: trimmed, activationId: activation.activationId)
        apply(EntitlementRecord(from: activation.status, validatedAt: clock()))
    }

    /// Re-validates the stored key and folds the outcome in, with grace. Silent
    /// when no key is stored: the free tier is not an error state.
    func validateNow() async {
        guard let key = store.licenseValue(for: Self.licenseKeyAccount), !key.isEmpty else { return }
        let activationId = store.licenseValue(for: Self.activationIdAccount)
        let wasEntitled = isEntitled

        let result: Result<LicenseStatus, Error>
        do {
            result = .success(try await provider.validate(key: key, activationId: activationId))
        } catch {
            result = .failure(error)
        }

        if let updated = Self.reduce(current: record, result: result, now: clock()) {
            apply(updated)
        }

        if wasEntitled && !isEntitled {
            Telemetry.capture(.entitlementLapsed)
        }
    }

    /// Removes the license from this device: releases the activation remotely
    /// (best effort, so it disappears from the customer portal) and clears the
    /// cached entitlement.
    func removeLicense() async {
        if let key = store.licenseValue(for: Self.licenseKeyAccount), !key.isEmpty,
           let activationId = store.licenseValue(for: Self.activationIdAccount), !activationId.isEmpty {
            try? await provider.deactivate(key: key, activationId: activationId)
        }
        persist(licenseKey: nil, activationId: nil)
        record = nil
        defaults.removeObject(forKey: Self.storageKey)
        NotificationCenter.default.post(name: .entitlementChanged, object: nil)
    }

    // MARK: Pure logic (unit-tested)

    /// The gate: entitled only when the record is `granted` and not past its
    /// expiry. A nil, expired, revoked, disabled, or unrecognized record is not
    /// entitled.
    nonisolated static func isEntitled(record: EntitlementRecord?, now: Date) -> Bool {
        guard let record, record.state == .granted else { return false }
        if let expiresAt = record.expiresAt { return now < expiresAt }
        return true
    }

    /// The gate, read from the same persisted record the `isEntitled` property
    /// serves, without needing the manager itself. `CalendarDataManager` reads
    /// it on every refresh.
    ///
    /// Two fail-open paths. A UI-testing run unlocks everything, because the
    /// screenshot tests seed fake accounts and would otherwise photograph two
    /// locked badges. And an unconfigured build (no Polar organization, which is
    /// what a fork or a local dev build looks like) is treated as fully
    /// entitled, because shipping a paywall nobody can pay through would just
    /// break the app.
    nonisolated static func isEntitledNow(defaults: UserDefaults = .standard,
                                          now: Date = Date()) -> Bool {
        guard !CommandLine.arguments.contains("--uitesting") else { return true }
        guard PolarConfig.isConfigured else { return true }
        return isEntitled(record: loadRecord(from: defaults), now: now)
    }

    /// Folds a validate outcome into the cached record, which is where the grace
    /// rule lives. Success replaces the record. An explicit bad key lapses. Any
    /// other failure (offline, 5xx, timeout) keeps the prior record so a blip
    /// never locks out a payer.
    nonisolated static func reduce(current: EntitlementRecord?,
                                   result: Result<LicenseStatus, Error>,
                                   now: Date) -> EntitlementRecord? {
        switch result {
        case .success(let status):
            return EntitlementRecord(from: status, validatedAt: now)
        case .failure(let error as LicenseError) where error == .invalidKey || error == .wrongProduct:
            return EntitlementRecord(statusRaw: LicenseStatus.State.revoked.rawValue,
                                     expiresAt: current?.expiresAt,
                                     customerId: current?.customerId,
                                     lastValidatedAt: current?.lastValidatedAt)
        case .failure:
            return current
        }
    }

    /// Seconds until the next 00:00 in the given time zone, for the daily check.
    nonisolated static func secondsUntilNextMidnight(after now: Date, in timeZone: TimeZone) -> TimeInterval {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let nextMidnight = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime) else {
            return 24 * 60 * 60
        }
        return max(1, nextMidnight.timeIntervalSince(now))
    }

    // MARK: Internals

    private func apply(_ updated: EntitlementRecord) {
        guard updated != record else { return }
        record = updated
        if let data = try? JSONEncoder().encode(updated) {
            defaults.set(data, forKey: Self.storageKey)
        }
        // The event list is built from the entitlement, so a change has to reach
        // `CalendarDataManager` and the menu bar, not only the SwiftUI views
        // bound to `record`.
        NotificationCenter.default.post(name: .entitlementChanged, object: nil)
    }

    private func persist(licenseKey: String?, activationId: String?) {
        store.setLicenseValue(licenseKey, for: Self.licenseKeyAccount)
        store.setLicenseValue(activationId, for: Self.activationIdAccount)
    }

    private func scheduleDailyCheck() {
        dailyTask?.cancel()
        dailyTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let seconds = Self.secondsUntilNextMidnight(after: self.clock(), in: self.timeZone)
                try? await Task.sleep(for: .seconds(seconds))
                if Task.isCancelled { return }
                await self.validateNow()
            }
        }
    }

    /// Nonisolated because `isEntitledNow` reads it without the manager.
    /// Decoding a blob of `Data` needs no actor.
    nonisolated private static func loadRecord(from defaults: UserDefaults) -> EntitlementRecord? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(EntitlementRecord.self, from: data)
    }

    /// A friendly per-device label sent to Polar on activation, so the person can
    /// recognize each Mac in the customer portal.
    private static func deviceLabel() -> String {
        Host.current().localizedName ?? "Mac"
    }
}
