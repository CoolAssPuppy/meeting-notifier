import Foundation
import AppKit
import AppAuth
import os

@MainActor
class GoogleOAuthManager {
    static let shared = GoogleOAuthManager()

    static let clientID = "629178373267-231fgipboj4pb20vhgi672lqm2917ha2.apps.googleusercontent.com"
    static let redirectURL = "com.googleusercontent.apps.629178373267-231fgipboj4pb20vhgi672lqm2917ha2:/oauthredirect"

    /// OAuth client secret, if the local GoogleOAuthSecret.swift supplies a real value.
    ///
    /// A native macOS app can never keep a client secret actually secret. The security
    /// boundary for this install is PKCE (automatically enabled by AppAuth) plus the
    /// custom-scheme redirect bound to this app. If your Google Cloud OAuth app is
    /// configured as a "Desktop / installed" or "iOS" client, leave the secret field
    /// empty — Google will accept PKCE-only requests. A value is only passed through
    /// when the local secret file contains a non-placeholder string, for compatibility
    /// with legacy OAuth app configurations that still require one.
    static var clientSecret: String? {
        let raw = GoogleOAuthSecret.secret
        if raw.isEmpty { return nil }
        if raw.hasPrefix("YOUR_") || raw == "REPLACE_ME" { return nil }
        return raw
    }

    private var currentAuthorizationFlow: OIDExternalUserAgentSession?

    private init() {}

    func authorize(completion: @escaping (Result<OIDAuthState, Error>) -> Void) {
        let configuration = OIDServiceConfiguration(
            authorizationEndpoint: URL.required("https://accounts.google.com/o/oauth2/v2/auth"),
            tokenEndpoint: URL.required("https://oauth2.googleapis.com/token")
        )

        let request = OIDAuthorizationRequest(
            configuration: configuration,
            clientId: Self.clientID,
            clientSecret: Self.clientSecret,
            scopes: [
                "openid",
                "profile",
                "email",
                "https://www.googleapis.com/auth/calendar.readonly"
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
                        domain: "GoogleOAuth",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Google OAuth failed"]
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
        authorizationEndpoint: URL.required("https://accounts.google.com/o/oauth2/v2/auth"),
        tokenEndpoint: URL.required("https://oauth2.googleapis.com/token"),
        clientID: clientID,
        clientSecret: clientSecret,
        errorDomain: "GoogleOAuth"
    )

    /// Fetch the authenticated user's email from Google's OpenID userinfo endpoint.
    ///
    /// This replaces parsing the unverified ID token payload. We never validated the
    /// ID token signature/audience/issuer locally, so trusting the `email` claim from
    /// its base64-decoded body meant trusting any caller who could hand us a shaped
    /// string. Hitting userinfo over TLS with the newly-minted access token delegates
    /// identity to Google directly.
    func extractEmail(from authState: OIDAuthState) async -> String? {
        guard let accessToken = authState.lastTokenResponse?.accessToken else { return nil }
        let url = URL.required("https://openidconnect.googleapis.com/v1/userinfo")

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                Logger.auth.error("Google userinfo returned non-200")
                return nil
            }
            let payload = try JSONDecoder().decode(GoogleUserInfo.self, from: data)
            return payload.email
        } catch {
            Logger.auth.error("Google userinfo fetch failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}

private struct GoogleUserInfo: Decodable {
    let email: String?
}
