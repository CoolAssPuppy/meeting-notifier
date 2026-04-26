//
//  CalendarManagerSupport.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation
import os

@MainActor
enum CalendarManagerSupport {

    // MARK: - Token

    static func getValidToken(forAccount account: CalendarAccount) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            AuthManager.shared.getValidAccessToken(forAccount: account) { result in
                continuation.resume(with: result)
            }
        }
    }

    // MARK: - Auth status

    static func markAccountAuthFailed(_ account: CalendarAccount, status: AuthStatus) {
        var updatedAccount = account
        updatedAccount.authStatus = status
        updatedAccount.lastAuthError = Date()
        AppSettings.shared.updateAccount(updatedAccount)

        NotificationManager.shared.showAuthFailureNotification(forAccount: account)
    }

    static func markAccountAuthValid(_ account: CalendarAccount) {
        guard account.authStatus != .valid else { return }

        var updatedAccount = account
        updatedAccount.authStatus = .valid
        updatedAccount.lastAuthError = nil
        AppSettings.shared.updateAccount(updatedAccount)
    }

    // MARK: - Authorized fetch

    /// Fetch + decode an authenticated request, with one-shot 401 retry that
    /// clears the cached access token so the next call refreshes it. Both
    /// provider managers used to copy this skeleton; now they all funnel
    /// through here. `T` must be Decodable so callers don't need to invent
    /// per-call parsing harnesses.
    static func fetchAuthorizedJSON<T: Decodable>(
        url: URL,
        account: CalendarAccount,
        decode type: T.Type,
        decoder: JSONDecoder = JSONDecoder(),
        operation: String,
        retryCount: Int = 0
    ) async throws -> T {
        let accessToken = try await getValidToken(forAccount: account)

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CalendarError.apiError("Invalid response")
        }

        if httpResponse.statusCode == 401 && retryCount == 0 {
            Logger.auth.warning("Access token expired for \(account.email, privacy: .private), refreshing…")
            _ = KeychainManager.shared.deleteAccessToken(forAccount: account.email)
            return try await fetchAuthorizedJSON(
                url: url,
                account: account,
                decode: type,
                decoder: decoder,
                operation: operation,
                retryCount: 1
            )
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                markAccountAuthFailed(account, status: .expired)
            }
            throw CalendarError.apiError("Failed to \(operation) (HTTP \(httpResponse.statusCode))")
        }

        markAccountAuthValid(account)

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            Logger.calendar.error("Failed to decode \(operation): \(error.localizedDescription, privacy: .public)")
            throw CalendarError.parseError("Invalid response shape for \(operation)")
        }
    }
}
