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

    func handleURLCallback(_ url: URL) -> Bool {
        // Match by URL scheme rather than full-string prefix. Both providers
        // use a unique custom scheme registered in Info.plist's URL types,
        // so a scheme match is the structurally correct dispatch.
        guard let scheme = url.scheme?.lowercased() else { return false }

        if let googleScheme = URL(string: GoogleOAuthManager.redirectURL)?.scheme?.lowercased(),
           scheme == googleScheme {
            return GoogleOAuthManager.shared.resumeAuthFlow(url: url)
        }
        if let microsoftScheme = URL(string: MicrosoftOAuthManager.redirectURL)?.scheme?.lowercased(),
           scheme == microsoftScheme {
            return MicrosoftOAuthManager.shared.resumeAuthFlow(url: url)
        }

        return false
    }
}

private func authError(_ message: String) -> NSError {
    NSError(
        domain: "AuthManager",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: message]
    )
}

