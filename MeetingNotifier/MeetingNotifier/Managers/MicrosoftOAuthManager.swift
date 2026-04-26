import Foundation
import AppKit
import AppAuth
import os

@MainActor
class MicrosoftOAuthManager {
    static let shared = MicrosoftOAuthManager()

    static let clientID = "1a831c66-9273-46ed-a38b-9ed5eb5e80d8"
    static let redirectURL = "com.strategicnerds.meetingnotifier://oauthredirect"

    /// Microsoft Entra (Azure AD) "public client" registrations must not use a client
    /// secret — PKCE (enabled automatically by AppAuth) is the security boundary. A
    /// value is read from the local MicrosoftOAuthSecret.swift only for legacy
    /// "confidential client" configurations; it is nil for modern setups.
    static var clientSecret: String? {
        let raw = MicrosoftOAuthSecret.secret
        if raw.isEmpty { return nil }
        if raw.hasPrefix("YOUR_") || raw == "REPLACE_ME" { return nil }
        return raw
    }

    private var currentAuthorizationFlow: OIDExternalUserAgentSession?

    private init() {}

    func authorize(completion: @escaping (Result<OIDAuthState, Error>) -> Void) {
        let configuration = OIDServiceConfiguration(
            authorizationEndpoint: URL.required("https://login.microsoftonline.com/common/oauth2/v2.0/authorize"),
            tokenEndpoint: URL.required("https://login.microsoftonline.com/common/oauth2/v2.0/token")
        )

        let request = OIDAuthorizationRequest(
            configuration: configuration,
            clientId: Self.clientID,
            clientSecret: nil,
            scopes: [
                "openid",
                "profile",
                "email",
                "offline_access",
                "https://graph.microsoft.com/Calendars.Read"
            ],
            redirectURL: URL.required(Self.redirectURL),
            responseType: OIDResponseTypeCode,
            additionalParameters: ["prompt": "select_account"]
        )

        let window = NSApplication.shared.windows.first ?? NSWindow()
        currentAuthorizationFlow = OIDAuthState.authState(
            byPresenting: request,
            presenting: window,
            callback: { [weak self] state, error in
                self?.currentAuthorizationFlow = nil
                if let state = state {
                    completion(.success(state))
                } else {
                    completion(.failure(error ?? NSError(
                        domain: "MicrosoftOAuth",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Microsoft OAuth failed"]
                    )))
                }
            }
        )
    }

    func resumeAuthFlow(url: URL) -> Bool {
        guard let flow = currentAuthorizationFlow else { return false }
        let resumed = flow.resumeExternalUserAgentFlow(with: url)
        if resumed {
            currentAuthorizationFlow = nil
        }
        return resumed
    }

    func refreshToken(
        forAccount account: CalendarAccount,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        OAuthRefreshSupport.refresh(
            account: account,
            provider: Self.providerConfig,
            completion: completion
        )
    }

    private static let providerConfig = OAuthRefreshSupport.ProviderConfig(
        authorizationEndpoint: URL.required("https://login.microsoftonline.com/common/oauth2/v2.0/authorize"),
        tokenEndpoint: URL.required("https://login.microsoftonline.com/common/oauth2/v2.0/token"),
        clientID: clientID,
        clientSecret: clientSecret,
        errorDomain: "MicrosoftOAuth"
    )

    /// Fetch the authenticated user's email from Microsoft Graph /me.
    ///
    /// Replaces parsing the unverified ID token payload. The access token is bound to
    /// the correct identity by the provider; hitting /me over TLS delegates identity
    /// extraction to Microsoft instead of trusting an unsigned JWT body locally.
    func extractEmail(from authState: OIDAuthState) async -> String? {
        guard let accessToken = authState.lastTokenResponse?.accessToken else { return nil }
        let url = URL.required("https://graph.microsoft.com/v1.0/me")

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                Logger.auth.error("Microsoft /me returned non-200")
                return nil
            }
            let payload = try JSONDecoder().decode(MicrosoftUserInfo.self, from: data)
            return payload.mail ?? payload.userPrincipalName
        } catch {
            Logger.auth.error("Microsoft /me fetch failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}

private struct MicrosoftUserInfo: Decodable {
    let mail: String?
    let userPrincipalName: String?
}
