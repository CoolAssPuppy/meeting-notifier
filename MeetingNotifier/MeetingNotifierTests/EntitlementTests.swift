//
//  EntitlementTests.swift
//  MeetingNotifierTests
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//
//  The subscription's decisions, tested as pure functions: is this record
//  entitled, what does a validate outcome do to the cached record (the grace
//  rule), when is the next daily check, and which accounts does the gate let
//  run.
//

import XCTest
@testable import MeetingNotifier

final class EntitlementTests: XCTestCase {

    // MARK: - Factories

    private func makeRecord(state: LicenseStatus.State = .granted,
                            expiresAt: Date? = nil,
                            customerId: String? = "cus_123",
                            lastValidatedAt: Date? = nil) -> EntitlementRecord {
        EntitlementRecord(statusRaw: state.rawValue,
                          expiresAt: expiresAt,
                          customerId: customerId,
                          lastValidatedAt: lastValidatedAt)
    }

    private func makeStatus(state: LicenseStatus.State = .granted,
                            expiresAt: Date? = nil,
                            customerId: String? = "cus_123",
                            benefitId: String? = "benefit_abc") -> LicenseStatus {
        LicenseStatus(state: state, expiresAt: expiresAt, customerId: customerId, benefitId: benefitId)
    }

    private func makeAccount(email: String,
                             isEnabled: Bool = true,
                             authStatus: AuthStatus = .valid) -> CalendarAccount {
        CalendarAccount(email: email, provider: .google, isEnabled: isEnabled, authStatus: authStatus)
    }

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: - The gate

    func testGrantedKeyWithNoExpiryIsEntitled() {
        // The normal case for this product: the Polar benefit has no TTL, so
        // the key carries no expiry and revocation is the lapse signal.
        XCTAssertTrue(EntitlementManager.isEntitled(record: makeRecord(), now: now))
    }

    func testGrantedKeyBeforeItsExpiryIsEntitled() {
        let record = makeRecord(expiresAt: now.addingTimeInterval(86_400))
        XCTAssertTrue(EntitlementManager.isEntitled(record: record, now: now))
    }

    func testGrantedKeyPastItsExpiryIsNotEntitled() {
        let record = makeRecord(expiresAt: now.addingTimeInterval(-1))
        XCTAssertFalse(EntitlementManager.isEntitled(record: record, now: now))
    }

    func testRevokedKeyIsNotEntitled() {
        XCTAssertFalse(EntitlementManager.isEntitled(record: makeRecord(state: .revoked), now: now))
    }

    func testDisabledKeyIsNotEntitled() {
        XCTAssertFalse(EntitlementManager.isEntitled(record: makeRecord(state: .disabled), now: now))
    }

    func testUnrecognizedStatusIsNotEntitled() {
        // A status string Polar might add later must not accidentally grant.
        let record = EntitlementRecord(statusRaw: "something_new",
                                       expiresAt: nil,
                                       customerId: nil,
                                       lastValidatedAt: nil)
        XCTAssertEqual(record.state, .unknown)
        XCTAssertFalse(EntitlementManager.isEntitled(record: record, now: now))
    }

    func testNoRecordIsNotEntitled() {
        XCTAssertFalse(EntitlementManager.isEntitled(record: nil, now: now))
    }

    // MARK: - Grace

    func testSuccessfulValidateReplacesTheRecord() {
        let current = makeRecord(state: .revoked, customerId: "cus_old")
        let status = makeStatus(state: .granted, customerId: "cus_new")

        let updated = EntitlementManager.reduce(current: current, result: .success(status), now: now)

        XCTAssertEqual(updated?.state, .granted)
        XCTAssertEqual(updated?.customerId, "cus_new")
        XCTAssertEqual(updated?.lastValidatedAt, now)
    }

    func testInvalidKeyLapsesImmediately() {
        let current = makeRecord(state: .granted)

        let updated = EntitlementManager.reduce(current: current,
                                                result: .failure(LicenseError.invalidKey),
                                                now: now)

        XCTAssertEqual(updated?.state, .revoked)
    }

    func testWrongProductLapsesImmediately() {
        // A key for a sibling Strategic Nerds app must not keep this one alive.
        let updated = EntitlementManager.reduce(current: makeRecord(state: .granted),
                                                result: .failure(LicenseError.wrongProduct),
                                                now: now)

        XCTAssertEqual(updated?.state, .revoked)
    }

    func testLapsingKeepsTheCustomerIdForSupport() {
        let current = makeRecord(state: .granted, customerId: "cus_keepme")

        let updated = EntitlementManager.reduce(current: current,
                                                result: .failure(LicenseError.invalidKey),
                                                now: now)

        XCTAssertEqual(updated?.customerId, "cus_keepme")
    }

    func testOfflineKeepsThePriorRecord() {
        // The one that protects people on planes.
        let current = makeRecord(state: .granted, lastValidatedAt: now.addingTimeInterval(-3600))

        let updated = EntitlementManager.reduce(current: current,
                                                result: .failure(URLError(.notConnectedToInternet)),
                                                now: now)

        XCTAssertEqual(updated, current)
    }

    func testServerErrorKeepsThePriorRecord() {
        let current = makeRecord(state: .granted)
        let failure = LicenseError.requestFailed(status: 503, message: "Service Unavailable")

        let updated = EntitlementManager.reduce(current: current, result: .failure(failure), now: now)

        XCTAssertEqual(updated, current)
    }

    func testFailureWithNoPriorRecordStaysEmpty() {
        let updated = EntitlementManager.reduce(current: nil,
                                                result: .failure(URLError(.timedOut)),
                                                now: now)

        XCTAssertNil(updated)
    }

    // MARK: - Daily check

    func testNextMidnightIsWithinADay() {
        let pacific = TimeZone(identifier: "America/Los_Angeles")!

        let seconds = EntitlementManager.secondsUntilNextMidnight(after: now, in: pacific)

        XCTAssertGreaterThan(seconds, 0)
        XCTAssertLessThanOrEqual(seconds, 24 * 60 * 60)
    }

    func testNextMidnightLandsOnMidnightInTheGivenZone() {
        let pacific = TimeZone(identifier: "America/Los_Angeles")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = pacific

        let seconds = EntitlementManager.secondsUntilNextMidnight(after: now, in: pacific)
        let components = calendar.dateComponents([.hour, .minute, .second],
                                                 from: now.addingTimeInterval(seconds))

        XCTAssertEqual(components.hour, 0)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.second, 0)
    }

    // MARK: - The read path the app actually uses

    /// `isEntitledNow` is what `CalendarDataManager` calls on every refresh. It
    /// reads the Polar config and the persisted record together, and these are
    /// the two answers that decide whether anyone ever sees a paywall.
    ///
    /// `PolarConfig` checks the process environment before Info.plist, which is
    /// what makes this testable without a configured bundle.

    private func withPolarOrg(_ orgId: String?, _ body: () -> Void) {
        let previous = ProcessInfo.processInfo.environment["POLAR_ORG_ID"]
        if let orgId { setenv("POLAR_ORG_ID", orgId, 1) } else { unsetenv("POLAR_ORG_ID") }
        defer {
            if let previous { setenv("POLAR_ORG_ID", previous, 1) } else { unsetenv("POLAR_ORG_ID") }
        }
        body()
    }

    private func makeDefaults() throws -> UserDefaults {
        let suite = "EntitlementTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: suite) }
        return defaults
    }

    private func store(_ record: EntitlementRecord, in defaults: UserDefaults) throws {
        let data = try JSONEncoder().encode(record)
        defaults.set(data, forKey: EntitlementManager.storageKey)
    }

    func testUnconfiguredBuildUnlocksEverything() throws {
        // A fork or a plain dev build. Shipping a paywall nobody can pay through
        // would just break the app.
        let defaults = try makeDefaults()

        withPolarOrg(nil) {
            XCTAssertTrue(EntitlementManager.isEntitledNow(defaults: defaults, now: now))
        }
    }

    func testConfiguredBuildWithNoLicenseIsGated() throws {
        // The free tier. If this ever returns true, nobody is asked to pay.
        let defaults = try makeDefaults()

        withPolarOrg("11111111-2222-3333-4444-555555555555") {
            XCTAssertFalse(EntitlementManager.isEntitledNow(defaults: defaults, now: now))
        }
    }

    func testConfiguredBuildWithAGrantedLicenseIsUnlocked() throws {
        let defaults = try makeDefaults()
        try store(makeRecord(state: .granted), in: defaults)

        withPolarOrg("11111111-2222-3333-4444-555555555555") {
            XCTAssertTrue(EntitlementManager.isEntitledNow(defaults: defaults, now: now))
        }
    }

    func testConfiguredBuildWithARevokedLicenseIsGated() throws {
        let defaults = try makeDefaults()
        try store(makeRecord(state: .revoked), in: defaults)

        withPolarOrg("11111111-2222-3333-4444-555555555555") {
            XCTAssertFalse(EntitlementManager.isEntitledNow(defaults: defaults, now: now))
        }
    }

    func testTheGateEndToEndPicksOneAccountOnTheFreeTier() throws {
        // The whole path `CalendarDataManager.refreshEvents` walks: config says
        // there is a paywall, no license is stored, so exactly one account runs.
        let defaults = try makeDefaults()
        let accounts = [makeAccount(email: "first@example.com"),
                        makeAccount(email: "second@example.com")]

        withPolarOrg("11111111-2222-3333-4444-555555555555") {
            let entitled = EntitlementManager.isEntitledNow(defaults: defaults, now: now)
            let result = AppSettings.partition(AppSettings.qualifying(accounts), isEntitled: entitled)

            XCTAssertEqual(result.active.map(\.email), ["first@example.com"])
            XCTAssertEqual(result.locked.map(\.email), ["second@example.com"])
        }
    }

    // MARK: - Which accounts run

    func testSubscriberRunsEveryAccount() {
        let accounts = [makeAccount(email: "a@example.com"),
                        makeAccount(email: "b@example.com"),
                        makeAccount(email: "c@example.com")]

        let result = AppSettings.partition(accounts, isEntitled: true)

        XCTAssertEqual(result.active.count, 3)
        XCTAssertTrue(result.locked.isEmpty)
    }

    func testFreeTierRunsOnlyTheFirstAccount() {
        let accounts = [makeAccount(email: "first@example.com"),
                        makeAccount(email: "second@example.com"),
                        makeAccount(email: "third@example.com")]

        let result = AppSettings.partition(accounts, isEntitled: false)

        XCTAssertEqual(result.active.map(\.email), ["first@example.com"])
        XCTAssertEqual(result.locked.map(\.email), ["second@example.com", "third@example.com"])
    }

    func testFreeTierWithOneAccountLocksNothing() {
        let accounts = [makeAccount(email: "only@example.com")]

        let result = AppSettings.partition(accounts, isEntitled: false)

        XCTAssertEqual(result.active.count, 1)
        XCTAssertTrue(result.locked.isEmpty)
    }

    func testNoAccountsPartitionsToNothing() {
        let result = AppSettings.partition([], isEntitled: false)

        XCTAssertTrue(result.active.isEmpty)
        XCTAssertTrue(result.locked.isEmpty)
    }

    func testDisabledAccountDoesNotHoldTheFreeSlot() {
        // Turning an account off shouldn't strand the free slot on something
        // that isn't running.
        let accounts = [makeAccount(email: "off@example.com", isEnabled: false),
                        makeAccount(email: "on@example.com")]

        let result = AppSettings.partition(AppSettings.qualifying(accounts), isEntitled: false)

        XCTAssertEqual(result.active.map(\.email), ["on@example.com"])
        XCTAssertTrue(result.locked.isEmpty)
    }

    func testICloudPlaceholderDoesNotHoldTheFreeSlot() {
        // An account synced from iCloud but never authorized on this Mac arrives
        // as .needsAuth and fetches nothing. Letting it hold the free slot would
        // lock the calendar the person actually uses.
        let accounts = [makeAccount(email: "ghost@example.com", authStatus: .needsAuth),
                        makeAccount(email: "real@example.com")]

        let result = AppSettings.partition(AppSettings.qualifying(accounts), isEntitled: false)

        XCTAssertEqual(result.active.map(\.email), ["real@example.com"])
        XCTAssertTrue(result.locked.isEmpty)
    }

    func testExpiredAccountDoesNotHoldTheFreeSlot() {
        let accounts = [makeAccount(email: "stale@example.com", authStatus: .expired),
                        makeAccount(email: "fresh@example.com")]

        let result = AppSettings.partition(AppSettings.qualifying(accounts), isEntitled: false)

        XCTAssertEqual(result.active.map(\.email), ["fresh@example.com"])
    }

    func testFreeSlotFollowsStoredOrderSoMakeFreeCanMoveIt() {
        // "Use this one instead" moves an account to index 0. The partition has
        // to honor that, or the button would do nothing.
        let accounts = [makeAccount(email: "wanted@example.com"),
                        makeAccount(email: "unwanted@example.com")]

        let result = AppSettings.partition(accounts, isEntitled: false)

        XCTAssertEqual(result.active.map(\.email), ["wanted@example.com"])
    }
}
