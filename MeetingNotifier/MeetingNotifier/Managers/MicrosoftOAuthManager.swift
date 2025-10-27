import Foundation
import AppAuth

@MainActor
class MicrosoftOAuthManager {
    static let shared = MicrosoftOAuthManager()

    static let clientID = "a325ea11-cc04-4062-b65e-8418044ab444"
    static let clientSecret = MicrosoftOAuthSecret.secret
    static let redirectURL = "msala325ea11-cc04-4062-b65e-8418044ab444://auth/"

    private var currentAuthorizationFlow: OIDExternalUserAgentSession?

    private init() {}

    func authorize(completion: @escaping (Result<OIDAuthState, Error>) -> Void) {
        let configuration = OIDServiceConfiguration(
            authorizationEndpoint: URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize")!,
            tokenEndpoint: URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/token")!
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
        guard let refreshToken = KeychainManager.shared.retrieveRefreshToken(forAccount: account.email) else {
            completion(.failure(NSError(
                domain: "MicrosoftOAuth",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No refresh token found"]
            )))
            return
        }

        let configuration = OIDServiceConfiguration(
            authorizationEndpoint: URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize")!,
            tokenEndpoint: URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/token")!
        )

        let tokenRequest = OIDTokenRequest(
            configuration: configuration,
            grantType: OIDGrantTypeRefreshToken,
            authorizationCode: nil,
            redirectURL: nil,
            clientID: Self.clientID,
            clientSecret: nil,
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
                        domain: "MicrosoftOAuth",
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

        return claims["preferred_username"] as? String
            ?? claims["email"] as? String
            ?? claims["upn"] as? String
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
