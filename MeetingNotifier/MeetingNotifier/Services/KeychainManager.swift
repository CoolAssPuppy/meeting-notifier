import Foundation
import Security

@MainActor
class KeychainManager {
    static let shared = KeychainManager()
    private let serviceName = "com.meetingnotifier.app"

    private init() {}

    func save(token: String, forAccount account: String) -> Bool {
        guard let tokenData = token.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: tokenData
        ]

        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    func retrieve(forAccount account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        return token
    }

    func delete(forAccount account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    func saveRefreshToken(_ token: String, forAccount account: String) -> Bool {
        save(token: token, forAccount: "\(account)_refresh")
    }

    func retrieveRefreshToken(forAccount account: String) -> String? {
        retrieve(forAccount: "\(account)_refresh")
    }

    func deleteRefreshToken(forAccount account: String) -> Bool {
        delete(forAccount: "\(account)_refresh")
    }

    func saveAccessToken(_ token: String, forAccount account: String) -> Bool {
        save(token: token, forAccount: "\(account)_access")
    }

    func retrieveAccessToken(forAccount account: String) -> String? {
        retrieve(forAccount: "\(account)_access")
    }

    func deleteAccessToken(forAccount account: String) -> Bool {
        delete(forAccount: "\(account)_access")
    }
}
