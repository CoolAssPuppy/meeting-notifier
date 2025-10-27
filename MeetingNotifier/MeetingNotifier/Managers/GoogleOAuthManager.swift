import Foundation
import AppAuth

@MainActor
class GoogleOAuthManager {
    static let shared = GoogleOAuthManager()

    static let clientID = "629178373267-j9cbevkq2p2sbtc12mrrdjeodjo8djvl.apps.googleusercontent.com"
    static let clientSecret: String? = nil  // iOS apps use PKCE, no secret needed
    static let redirectURL = "com.googleusercontent.apps.629178373267:/oauthredirect"

    private var currentAuthorizationFlow: OIDExternalUserAgentSession?

    private init() {}

    func authorize(completion: @escaping (Result<OIDAuthState, Error>) -> Void) {
        let configuration = OIDServiceConfiguration(
            authorizationEndpoint: URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!,
            tokenEndpoint: URL(string: "https://oauth2.googleapis.com/token")!
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
            redirectURL: URL(string: Self.redirectURL)!,
            responseType: OIDResponseTypeCode,
            additionalParameters: ["prompt": "select_account"]
        )

        currentAuthorizationFlow = OIDAuthState.authState(
            byPresenting: request,
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
        guard let refreshToken = KeychainManager.shared.retrieveRefreshToken(forAccount: account.email) else {
            completion(.failure(NSError(
                domain: "GoogleOAuth",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No refresh token found"]
            )))
            return
        }

        let configuration = OIDServiceConfiguration(
            authorizationEndpoint: URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!,
            tokenEndpoint: URL(string: "https://oauth2.googleapis.com/token")!
        )

        let tokenRequest = OIDTokenRequest(
            configuration: configuration,
            grantType: OIDGrantTypeRefreshToken,
            authorizationCode: nil,
            redirectURL: nil,
            clientID: Self.clientID,
            clientSecret: Self.clientSecret,
            scope: nil,
            refreshToken: refreshToken,
            codeVerifier: nil,
            additionalParameters: nil
        )

        OIDAuthorizationService.perform(tokenRequest) { response, error in
            Task { @MainActor in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let accessToken = response?.accessToken else {
                    completion(.failure(NSError(
                        domain: "GoogleOAuth",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "No access token in response"]
                    )))
                    return
                }

                _ = KeychainManager.shared.saveAccessToken(accessToken, forAccount: account.email)

                if let newRefreshToken = response?.refreshToken {
                    _ = KeychainManager.shared.saveRefreshToken(newRefreshToken, forAccount: account.email)
                }

                completion(.success(accessToken))
            }
        }
    }

    func extractEmail(from authState: OIDAuthState) -> String? {
        guard let idToken = authState.lastTokenResponse?.idToken else { return nil }
        guard let claims = decodeJWT(idToken) else { return nil }

        return claims["email"] as? String
    }

    private func decodeJWT(_ jwt: String) -> [String: Any]? {
        let segments = jwt.components(separatedBy: ".")
        guard segments.count > 1 else { return nil }

        var base64String = segments[1]
        let remainder = base64String.count % 4
        if remainder > 0 {
            base64String = base64String.padding(
                toLength: base64String.count + 4 - remainder,
                withPad: "=",
                startingAt: 0
            )
        }

        guard let data = Data(base64Encoded: base64String, options: .ignoreUnknownCharacters),
              let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return nil
        }

        return json
    }
}
