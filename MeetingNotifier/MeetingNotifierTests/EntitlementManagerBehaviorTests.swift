//
//  EntitlementManagerBehaviorTests.swift
//  MeetingNotifierTests
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//
//  What activating and removing a license actually do, driven through
//  `EntitlementManager` with a fake provider and a fake credential store. This
//  is what the `LicenseProvider` and `LicenseCredentialStore` protocols exist
//  for: without them these paths could only be tested against the live Polar API
//  and the real Keychain, which would prompt.
//

import XCTest
@testable import MeetingNotifier

// MARK: - Fakes

private final class FakeCredentialStore: LicenseCredentialStore {
    var values: [String: String] = [:]

    func licenseValue(for account: String) -> String? { values[account] }

    func setLicenseValue(_ value: String?, for account: String) {
        if let value { values[account] = value } else { values.removeValue(forKey: account) }
    }
}

private struct FakeProvider: LicenseProvider {
    var activation: LicenseActivation?
    var activateError: Error?
    var validateResult: Result<LicenseStatus, Error>?
    /// Records that deactivate was called, so the test can assert the activation
    /// is released remotely and not just forgotten locally.
    let deactivated: DeactivationLog

    func activate(key: String, deviceLabel: String) async throws -> LicenseActivation {
        if let activateError { throw activateError }
        return activation ?? LicenseActivation(
            activationId: "activation_1",
            status: LicenseStatus(state: .granted, expiresAt: nil, customerId: "cus_1", benefitId: "b1"))
    }

    func validate(key: String, activationId: String?) async throws -> LicenseStatus {
        switch validateResult {
        case .success(let status): return status
        case .failure(let error): throw error
        case nil: throw LicenseError.notConfigured
        }
    }

    func deactivate(key: String, activationId: String) async throws {
        await deactivated.record(key: key, activationId: activationId)
    }
}

/// `LicenseProvider` is `Sendable`, so the fake cannot just mutate a captured
/// var from inside `deactivate`.
private actor DeactivationLog {
    private(set) var calls: [(key: String, activationId: String)] = []
    func record(key: String, activationId: String) { calls.append((key, activationId)) }
    var count: Int { calls.count }
    var last: (key: String, activationId: String)? { calls.last }
}

/// File scope rather than a property, because `EntitlementManager.clock` is
/// `@Sendable` and cannot capture the test case.
private let testNow = Date(timeIntervalSince1970: 1_800_000_000)

@MainActor
final class EntitlementManagerBehaviorTests: XCTestCase {

    private func makeDefaults() throws -> UserDefaults {
        let suite = "EntitlementBehavior.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: suite) }
        return defaults
    }

    // MARK: Activation

    func testActivatingStoresTheKeyAndTheActivationId() async throws {
        let store = FakeCredentialStore()
        let provider = FakeProvider(
            activation: LicenseActivation(
                activationId: "activation_xyz",
                status: LicenseStatus(state: .granted, expiresAt: nil, customerId: "cus_9", benefitId: "b1")),
            deactivated: DeactivationLog())
        let manager = EntitlementManager(provider: provider,
                                         store: store,
                                         defaults: try makeDefaults(),
                                         clock: { testNow })

        try await manager.activate(key: "  KEY-123  ")

        // Trimmed, because people paste with trailing whitespace out of an email.
        XCTAssertEqual(store.values["license.key"], "KEY-123")
        XCTAssertEqual(store.values["license.activation_id"], "activation_xyz")
        XCTAssertTrue(manager.hasStoredKey)
        XCTAssertEqual(manager.record?.state, .granted)
        XCTAssertEqual(manager.record?.customerId, "cus_9")
    }

    func testActivatingAnEmptyKeyIsRejectedWithoutCallingTheProvider() async throws {
        let store = FakeCredentialStore()
        let manager = EntitlementManager(provider: FakeProvider(deactivated: DeactivationLog()),
                                         store: store,
                                         defaults: try makeDefaults(),
                                         clock: { testNow })

        do {
            try await manager.activate(key: "   ")
            XCTFail("Expected an empty key to be rejected")
        } catch {
            XCTAssertEqual(error as? LicenseError, .invalidKey)
        }
        XCTAssertTrue(store.values.isEmpty)
    }

    func testAFailedActivationStoresNothing() async throws {
        let store = FakeCredentialStore()
        let provider = FakeProvider(activateError: LicenseError.wrongProduct,
                                    deactivated: DeactivationLog())
        let manager = EntitlementManager(provider: provider,
                                         store: store,
                                         defaults: try makeDefaults(),
                                         clock: { testNow })

        do {
            try await manager.activate(key: "SOMEONE-ELSES-KEY")
            XCTFail("Expected a wrong-product key to be rejected")
        } catch {
            XCTAssertEqual(error as? LicenseError, .wrongProduct)
        }
        XCTAssertTrue(store.values.isEmpty, "A rejected key must not be left on disk")
        XCTAssertNil(manager.record)
    }

    // MARK: Re-validation

    func testValidateWithNoStoredKeyIsSilent() async throws {
        // The free tier is not an error state.
        let manager = EntitlementManager(provider: FakeProvider(deactivated: DeactivationLog()),
                                         store: FakeCredentialStore(),
                                         defaults: try makeDefaults(),
                                         clock: { testNow })

        await manager.validateNow()

        XCTAssertNil(manager.record)
    }

    func testAnOfflineValidateLeavesAPayerEntitled() async throws {
        let store = FakeCredentialStore()
        store.values = ["license.key": "KEY-123", "license.activation_id": "activation_1"]
        let provider = FakeProvider(
            validateResult: .failure(URLError(.notConnectedToInternet)),
            deactivated: DeactivationLog())
        let defaults = try makeDefaults()
        let granted = EntitlementRecord(statusRaw: LicenseStatus.State.granted.rawValue,
                                        expiresAt: nil, customerId: "cus_1", lastValidatedAt: testNow)
        defaults.set(try JSONEncoder().encode(granted), forKey: EntitlementManager.storageKey)

        let manager = EntitlementManager(provider: provider, store: store,
                                         defaults: defaults, clock: { testNow })
        await manager.validateNow()

        XCTAssertEqual(manager.record?.state, .granted)
    }

    func testARevokedKeyLapsesOnTheNextValidate() async throws {
        let store = FakeCredentialStore()
        store.values = ["license.key": "KEY-123", "license.activation_id": "activation_1"]
        let revoked = LicenseStatus(state: .revoked, expiresAt: nil, customerId: "cus_1", benefitId: "b1")
        let provider = FakeProvider(validateResult: .success(revoked), deactivated: DeactivationLog())
        let manager = EntitlementManager(provider: provider, store: store,
                                         defaults: try makeDefaults(), clock: { testNow })

        await manager.validateNow()

        XCTAssertEqual(manager.record?.state, .revoked)
    }

    // MARK: Removal

    func testRemovingReleasesTheActivationAndClearsEverything() async throws {
        let store = FakeCredentialStore()
        store.values = ["license.key": "KEY-123", "license.activation_id": "activation_1"]
        let log = DeactivationLog()
        let manager = EntitlementManager(provider: FakeProvider(deactivated: log),
                                         store: store,
                                         defaults: try makeDefaults(),
                                         clock: { testNow })

        await manager.removeLicense()

        // Released remotely, so the slot frees up in the customer portal rather
        // than staying claimed by a Mac that no longer has the key.
        let calls = await log.count
        let last = await log.last
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(last?.activationId, "activation_1")
        XCTAssertTrue(store.values.isEmpty)
        XCTAssertNil(manager.record)
        XCTAssertFalse(manager.hasStoredKey)
    }

    func testRemovingWithNothingStoredDoesNotCallTheProvider() async throws {
        let log = DeactivationLog()
        let manager = EntitlementManager(provider: FakeProvider(deactivated: log),
                                         store: FakeCredentialStore(),
                                         defaults: try makeDefaults(),
                                         clock: { testNow })

        await manager.removeLicense()

        let calls = await log.count
        XCTAssertEqual(calls, 0)
    }
}
