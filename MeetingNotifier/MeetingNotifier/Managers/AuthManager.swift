import Foundation
import AppAuth
import os

@MainActor
class AuthManager {
    static let shared = AuthManager()

    private init() {}

    func addGoogleAccount(completion: @escaping (Result<CalendarAccount, Error>) -> Void) {
        addAccount(
            provider: .google,
            authorize: { GoogleOAuthManager.shared.authorize(completion: $0) },
            extractEmail: { await GoogleOAuthManager.shared.extractEmail(from: $0) },
            completion: completion
        )
    }

    func addMicrosoftAccount(completion: @escaping (Result<CalendarAccount, Error>) -> Void) {
        addAccount(
            provider: .microsoft,
            authorize: { MicrosoftOAuthManager.shared.authorize(completion: $0) },
            extractEmail: { await MicrosoftOAuthManager.shared.extractEmail(from: $0) },
            completion: completion
        )
    }

    /// Shared OAuth-then-save flow used by both providers. Diverges only in
    /// which authorize/extractEmail closures the caller passes — everything
    /// after `authState` lands is identical, so a bug fix in one path now
    /// fixes the other automatically.
    private func addAccount(
        provider: CalendarProvider,
        authorize: @escaping (@escaping (Result<OIDAuthState, Error>) -> Void) -> Void,
        extractEmail: @escaping @MainActor (OIDAuthState) async -> String?,
        completion: @escaping (Result<CalendarAccount, Error>) -> Void
    ) {
        authorize { result in
            Task { @MainActor in
                switch result {
                case .success(let authState):
                    guard let email = await extractEmail(authState) else {
                        completion(.failure(authError(
                            "Could not extract email from \(provider.displayName) OAuth response"
                        )))
                        return
                    }

                    guard let accessToken = authState.lastTokenResponse?.accessToken,
                          let refreshToken = authState.lastTokenResponse?.refreshToken else {
                        completion(.failure(authError("No tokens in OAuth response")))
                        return
                    }

                    // Ensure app is active/foreground so keychain permission dialog can appear
                    NSApp.activate(ignoringOtherApps: true)

                    let accessTokenSaved = KeychainManager.shared.saveAccessToken(accessToken, forAccount: email)
                    let refreshTokenSaved = KeychainManager.shared.saveRefreshToken(refreshToken, forAccount: email)

                    Logger.auth.debug("Keychain save results for \(email, privacy: .private) — Access: \(accessTokenSaved), Refresh: \(refreshTokenSaved)")

                    guard accessTokenSaved && refreshTokenSaved else {
                        let msg = "Failed to save credentials to keychain. Access: \(accessTokenSaved), Refresh: \(refreshTokenSaved)"
                        Logger.auth.error("\(msg)")
                        completion(.failure(authError(msg)))
                        return
                    }

                    // The gate belongs here rather than at the button, because
                    // this is the first point that knows WHICH account this is.
                    // Re-authorizing an account you already own is not an add and
                    // must never hit the paywall, or a free-tier user whose token
                    // expired is trapped with no way to repair it.
                    let isNewAccount = AppSettings.shared.account(forEmail: email) == nil
                    if isNewAccount && !AppSettings.shared.canAddAnotherAccount {
                        Logger.auth.info("Dropping a completed authorization: the free tier is full.")
                        AppDelegate.shared?.showPaywall(trigger: .addAccount)
                        completion(.failure(authError("A subscription is needed to connect another calendar.",
                                                     code: Self.paywallRejectionCode)))
                        return
                    }

                    var account = CalendarAccount(
                        email: email,
                        provider: provider,
                        isEnabled: true
                    )

                    if let existing = AppSettings.shared.account(forEmail: email) {
                        account.selectedCalendarIds = existing.selectedCalendarIds
                        AppSettings.shared.updateAccount(account)
                    } else {
                        AppSettings.shared.addAccount(account)
                    }

                    Logger.auth.info("Successfully authenticated and saved credentials for \(email, privacy: .private)")
                    completion(.success(account))

                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    func removeAccount(_ account: CalendarAccount) {
        AppSettings.shared.removeAccount(account)
    }

    func refreshTokenIfNeeded(
        forAccount account: CalendarAccount,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        switch account.provider {
        case .google:
            GoogleOAuthManager.shared.refreshToken(forAccount: account, completion: completion)
        case .microsoft:
            MicrosoftOAuthManager.shared.refreshToken(forAccount: account, completion: completion)
        }
    }

    func getValidAccessToken(
        forAccount account: CalendarAccount,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        if let accessToken = KeychainManager.shared.retrieveAccessToken(forAccount: account.email) {
            completion(.success(accessToken))
        } else {
            refreshTokenIfNeeded(forAccount: account, completion: completion)
        }
    }

}

extension AuthManager {
    /// Domain and code for "authorization succeeded, but the free tier is full".
    /// `AppDelegate` suppresses its alert: the paywall sheet is already up, and
    /// an alert on top of it would refuse the same click twice.
    static let paywallRejectionCode = 402

    static func isPaywallRejection(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == authErrorDomain && nsError.code == paywallRejectionCode
    }
}

private let authErrorDomain = "AuthManager"

private func authError(_ message: String, code: Int = -1) -> NSError {
    NSError(
        domain: authErrorDomain,
        code: code,
        userInfo: [NSLocalizedDescriptionKey: message]
    )
}

