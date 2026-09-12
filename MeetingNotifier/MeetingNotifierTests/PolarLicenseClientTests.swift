//
//  PolarLicenseClientTests.swift
//  MeetingNotifierTests
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//
//  Polar's wire format and the two judgements made against it: what an HTTP
//  status means, and whether a key belongs to this product. Every helper under
//  test is static and pure, so none of this touches the network.
//

import XCTest
@testable import MeetingNotifier

final class PolarLicenseClientTests: XCTestCase {

    // MARK: - Factories

    private func response(_ code: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL.required("https://api.polar.sh/v1/customer-portal/license-keys/validate"),
                        statusCode: code,
                        httpVersion: nil,
                        headerFields: nil)!
    }

    private func json(_ raw: String) -> Data {
        Data(raw.utf8)
    }

    private func makeStatus(benefitId: String?) -> LicenseStatus {
        LicenseStatus(state: .granted, expiresAt: nil, customerId: "cus_1", benefitId: benefitId)
    }

    // MARK: - HTTP status

    func testSuccessfulResponsePassesThrough() {
        XCTAssertNoThrow(try PolarLicenseClient.checkStatus(response(200), data: Data()))
    }

    func testNotFoundMeansTheKeyIsUnknown() {
        XCTAssertThrowsError(try PolarLicenseClient.checkStatus(response(404), data: Data())) { error in
            XCTAssertEqual(error as? LicenseError, .invalidKey)
        }
    }

    func testActivationLimitIsRecognizedFromTheMessageText() {
        // Polar signals this in the error text, not the status code, so the
        // match is a substring test. If this test starts failing, Polar reworded
        // the message and `checkStatus` needs updating.
        let body = json(#"{"detail":"License key activation limit already reached."}"#)

        XCTAssertThrowsError(try PolarLicenseClient.checkStatus(response(403), data: body)) { error in
            XCTAssertEqual(error as? LicenseError, .activationLimitReached)
        }
    }

    func testOtherForbiddenResponsesCarryPolarsMessage() {
        let body = json(#"{"detail":"Something else went wrong."}"#)

        XCTAssertThrowsError(try PolarLicenseClient.checkStatus(response(403), data: body)) { error in
            XCTAssertEqual(error as? LicenseError,
                           .requestFailed(status: 403, message: "Something else went wrong."))
        }
    }

    func testServerErrorIsReportedWithItsStatus() {
        let body = json(#"{"error":"Internal Server Error"}"#)

        XCTAssertThrowsError(try PolarLicenseClient.checkStatus(response(500), data: body)) { error in
            XCTAssertEqual(error as? LicenseError,
                           .requestFailed(status: 500, message: "Internal Server Error"))
        }
    }

    // MARK: - The product pin

    func testKeyForThisProductIsAccepted() {
        XCTAssertNoThrow(try PolarLicenseClient.checkBenefit(makeStatus(benefitId: "benefit_meeting"),
                                                             expected: "benefit_meeting"))
    }

    func testKeyForASiblingProductIsRejected() {
        // The whole reason the pin exists: Polar grants on organization
        // membership, so a Mail Notifier key validates against this org too.
        XCTAssertThrowsError(try PolarLicenseClient.checkBenefit(makeStatus(benefitId: "benefit_mail"),
                                                                 expected: "benefit_meeting")) { error in
            XCTAssertEqual(error as? LicenseError, .wrongProduct)
        }
    }

    func testUnconfiguredPinAcceptsAnything() {
        // A fork or dev build has no paywall, so there is nothing to protect.
        XCTAssertNoThrow(try PolarLicenseClient.checkBenefit(makeStatus(benefitId: "benefit_mail"),
                                                             expected: ""))
    }

    func testMissingBenefitIdFailsOpen() {
        // If Polar ever stops sending the field, failing closed would lock out
        // every paying customer on the same day.
        XCTAssertNoThrow(try PolarLicenseClient.checkBenefit(makeStatus(benefitId: nil),
                                                             expected: "benefit_meeting"))
        XCTAssertNoThrow(try PolarLicenseClient.checkBenefit(makeStatus(benefitId: ""),
                                                             expected: "benefit_meeting"))
    }

    // MARK: - Decoding a validate response

    func testValidateResponseDecodes() throws {
        let body = json("""
        {
          "status": "granted",
          "expires_at": "2027-04-21T00:00:00Z",
          "benefit_id": "benefit_meeting",
          "customer_id": "cus_42"
        }
        """)

        let status = try PolarLicenseClient.decodeStatus(body)

        XCTAssertEqual(status.state, .granted)
        XCTAssertEqual(status.benefitId, "benefit_meeting")
        XCTAssertEqual(status.customerId, "cus_42")
        XCTAssertNotNil(status.expiresAt)
    }

    func testKeyWithNoExpiryDecodesToNil() {
        // How this product's benefit is configured: no TTL, so revocation rather
        // than expiry is the lapse signal.
        let body = json(#"{"status":"granted","benefit_id":"benefit_meeting"}"#)

        let status = try? PolarLicenseClient.decodeStatus(body)

        XCTAssertNil(status?.expiresAt)
        XCTAssertEqual(status?.state, .granted)
    }

    func testFractionalSecondsInTheExpiryStillParse() {
        // Polar sends fractional seconds on some fields and not others, and
        // ISO8601DateFormatter returns nil on the mismatch rather than coping.
        let plain = json(#"{"status":"granted","expires_at":"2027-04-21T00:00:00Z"}"#)
        let fractional = json(#"{"status":"granted","expires_at":"2027-04-21T00:00:00.123456Z"}"#)

        XCTAssertNotNil(try? PolarLicenseClient.decodeStatus(plain).expiresAt)
        XCTAssertNotNil(try? PolarLicenseClient.decodeStatus(fractional).expiresAt)
    }

    func testNestedCustomerObjectIsReadWhenThereIsNoCustomerId() {
        let body = json(#"{"status":"granted","customer":{"id":"cus_nested"}}"#)

        let status = try? PolarLicenseClient.decodeStatus(body)

        XCTAssertEqual(status?.customerId, "cus_nested")
    }

    func testUnreadableResponseThrows() {
        XCTAssertThrowsError(try PolarLicenseClient.decodeStatus(json("not json at all")))
    }

    // MARK: - Decoding an activate response

    func testActivateResponseDecodesTheNestedKey() throws {
        let body = json("""
        {
          "id": "activation_7",
          "license_key": {
            "status": "granted",
            "benefit_id": "benefit_meeting",
            "customer_id": "cus_42"
          }
        }
        """)

        let activation = try PolarLicenseClient.decodeActivation(body)

        XCTAssertEqual(activation.activationId, "activation_7")
        XCTAssertEqual(activation.status.state, .granted)
        XCTAssertEqual(activation.status.benefitId, "benefit_meeting")
    }

    func testActivateResponseFallsBackToTheTopLevelKeyShape() throws {
        let body = json(#"{"id":"activation_7","status":"granted","benefit_id":"benefit_meeting"}"#)

        let activation = try PolarLicenseClient.decodeActivation(body)

        XCTAssertEqual(activation.activationId, "activation_7")
        XCTAssertEqual(activation.status.benefitId, "benefit_meeting")
    }

    func testActivateResponseWithNoIdThrows() {
        XCTAssertThrowsError(try PolarLicenseClient.decodeActivation(json(#"{"status":"granted"}"#)))
    }

    // MARK: - Error messages

    func testDetailStringIsUsed() {
        XCTAssertEqual(PolarLicenseClient.errorMessage(json(#"{"detail":"Nope."}"#)), "Nope.")
    }

    func testErrorStringIsUsed() {
        XCTAssertEqual(PolarLicenseClient.errorMessage(json(#"{"error":"Nope."}"#)), "Nope.")
    }

    func testFastAPIValidationListIsUnwrapped() {
        let body = json(#"{"detail":[{"msg":"field required","loc":["body","key"]}]}"#)

        XCTAssertEqual(PolarLicenseClient.errorMessage(body), "field required")
    }

    func testNonJSONBodyIsTruncatedRatherThanDropped() {
        let body = json(String(repeating: "x", count: 500))

        let message = PolarLicenseClient.errorMessage(body)

        XCTAssertEqual(message.count, 200)
    }

    func testEmptyBodyGivesSomethingToShow() {
        XCTAssertEqual(PolarLicenseClient.errorMessage(Data()), "Unknown error")
    }
}
