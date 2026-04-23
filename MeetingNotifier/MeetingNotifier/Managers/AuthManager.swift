import Foundation
import AppAuth
import os

@MainActor
class AuthManager {
    static let shared = AuthManager()

    private init() {}

    func addGoogleAccount(completion: @escaping (Result<CalendarAccount, Error>) -> Void) {
        GoogleOAuthManager.shared.authorize { result in
            Task { @MainActor in
                switch result {
                case .success(let authState):
                    guard let email = await GoogleOAuthManager.shared.extractEmail(from: authState) else {
                        completion(.failure(NSError(
                            domain: "AuthManager",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Could not extract email from Google OAuth response"]
                        )))
                        return
                    }

                    guard let accessToken = authState.lastTokenResponse?.accessToken,
                          let refreshToken = authState.lastTokenResponse?.refreshToken else {
                        completion(.failure(NSError(
                            domain: "AuthManager",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "No tokens in OAuth response"]
                        )))
                        return
                    }

                    // Ensure app is active/foreground so keychain permission dialog can appear
                    NSApp.activate(ignoringOtherApps: true)

                    let accessTokenSaved = KeychainManager.shared.saveAccessToken(accessToken, forAccount: email)
                    let refreshTokenSaved = KeychainManager.shared.saveRefreshToken(refreshToken, forAccount: email)

                    Logger.auth.debug("Keychain save results for \(email, privacy: .private) - Access: \(accessTokenSaved), Refresh: \(refreshTokenSaved)")

                    guard accessTokenSaved && refreshTokenSaved else {
                        let errorMsg = "Failed to save credentials to keychain. Access: \(accessTokenSaved), Refresh: \(refreshTokenSaved)"
                        Logger.auth.error("\(errorMsg)")
                        completion(.failure(NSError(
                            domain: "AuthManager",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: errorMsg]
                        )))
                        return
                    }

                    var account = CalendarAccount(
                        email: email,
                        provider: .google,
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

    func addMicrosoftAccount(completion: @escaping (Result<CalendarAccount, Error>) -> Void) {
        MicrosoftOAuthManager.shared.authorize { result in
            Task { @MainActor in
                switch result {
                case .success(let authState):
                    guard let email = await MicrosoftOAuthManager.shared.extractEmail(from: authState) else {
                        completion(.failure(NSError(
                            domain: "AuthManager",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Could not extract email from Microsoft OAuth response"]
                        )))
                        return
                    }

                    guard let accessToken = authState.lastTokenResponse?.accessToken,
                          let refreshToken = authState.lastTokenResponse?.refreshToken else {
                        completion(.failure(NSError(
                            domain: "AuthManager",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "No tokens in OAuth response"]
                        )))
                        return
                    }

                    // Ensure app is active/foreground so keychain permission dialog can appear
                    NSApp.activate(ignoringOtherApps: true)

                    let accessTokenSaved = KeychainManager.shared.saveAccessToken(accessToken, forAccount: email)
                    let refreshTokenSaved = KeychainManager.shared.saveRefreshToken(refreshToken, forAccount: email)

                    Logger.auth.debug("Keychain save results for \(email, privacy: .private) - Access: \(accessTokenSaved), Refresh: \(refreshTokenSaved)")

                    guard accessTokenSaved && refreshTokenSaved else {
                        let errorMsg = "Failed to save credentials to keychain. Access: \(accessTokenSaved), Refresh: \(refreshTokenSaved)"
                        Logger.auth.error("\(errorMsg)")
                        completion(.failure(NSError(
                            domain: "AuthManager",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: errorMsg]
                        )))
                        return
                    }

                    var account = CalendarAccount(
                        email: email,
                        provider: .microsoft,
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
        let urlString = url.absoluteString

        if urlString.starts(with: GoogleOAuthManager.redirectURL) {
            return GoogleOAuthManager.shared.resumeAuthFlow(url: url)
        } else if urlString.starts(with: MicrosoftOAuthManager.redirectURL) {
            return MicrosoftOAuthManager.shared.resumeAuthFlow(url: url)
        }

        return false
    }
}
