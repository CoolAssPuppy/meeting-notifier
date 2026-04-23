//
//  OAuthRefreshSupport.swift
//  MeetingNotifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import Foundation
import AppAuth

/// Shared refresh-token flow for installed-client OAuth providers.
///
/// Google and Microsoft both follow the same pattern: look up the stored refresh
/// token, hit the provider's token endpoint through AppAuth, then persist the new
/// access token (and rotated refresh token, when returned). Centralizing the flow
/// here eliminates two near-identical copies in the provider managers so bug
/// fixes and policy changes land in one place.
enum OAuthRefreshSupport {

    struct ProviderConfig {
        let authorizationEndpoint: URL
        let tokenEndpoint: URL
        let clientID: String
        let clientSecret: String?
        let errorDomain: String
    }

    @MainActor
    static func refresh(
        account: CalendarAccount,
        provider: ProviderConfig,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let refreshToken = KeychainManager.shared.retrieveRefreshToken(forAccount: account.email) else {
            completion(.failure(NSError(
                domain: provider.errorDomain,
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No refresh token found"]
            )))
            return
        }

        let configuration = OIDServiceConfiguration(
            authorizationEndpoint: provider.authorizationEndpoint,
            tokenEndpoint: provider.tokenEndpoint
        )

        let tokenRequest = OIDTokenRequest(
            configuration: configuration,
            grantType: OIDGrantTypeRefreshToken,
            authorizationCode: nil,
            redirectURL: nil,
            clientID: provider.clientID,
            clientSecret: provider.clientSecret,
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
                        domain: provider.errorDomain,
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
}
