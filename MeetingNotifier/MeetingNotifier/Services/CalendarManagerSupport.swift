//
//  CalendarManagerSupport.swift
//  MeetingNotifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation

@MainActor
enum CalendarManagerSupport {
    static func getValidToken(forAccount account: CalendarAccount) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            AuthManager.shared.getValidAccessToken(forAccount: account) { result in
                continuation.resume(with: result)
            }
        }
    }

    @MainActor
    static func markAccountAuthFailed(_ account: CalendarAccount, status: AuthStatus) {
        var updatedAccount = account
        updatedAccount.authStatus = status
        updatedAccount.lastAuthError = Date()
        AppSettings.shared.updateAccount(updatedAccount)

        NotificationManager.shared.showAuthFailureNotification(forAccount: account)
    }

    @MainActor
    static func markAccountAuthValid(_ account: CalendarAccount) {
        guard account.authStatus != .valid else { return }

        var updatedAccount = account
        updatedAccount.authStatus = .valid
        updatedAccount.lastAuthError = nil
        AppSettings.shared.updateAccount(updatedAccount)
    }
}
