import Foundation
import Security
import os

@MainActor
class KeychainManager {
    static let shared = KeychainManager()
    private let serviceName = "com.strategicnerds.meetingnotifier"

    /// API keys sync via iCloud Keychain across devices.
    /// OAuth tokens stay local (device-specific).
    private let syncableAccounts: Set<String> = [
        "openai_api_key",
        "anthropic_api_key",
        "gemini_api_key",
        "wispr_api_key",
        "deepgram_api_key",
    ]

    private init() {}

    // MARK: - Public API

    func save(token: String, forAccount account: String) -> Bool {
        guard let tokenData = token.data(using: .utf8) else {
            Logger.keychain.error("Failed to encode token for account: \(account, privacy: .private)")
            return false
        }

        let shouldSync = syncableAccounts.contains(account)
        let accessibility = accessibilityClass(forSyncable: shouldSync)
        let query = baseQuery(account: account, synchronizable: shouldSync)

        let attributes: [String: Any] = [
            kSecValueData as String: tokenData,
            kSecAttrAccessible as String: accessibility,
        ]

        // Try update first
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return true }

        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = tokenData
            addQuery[kSecAttrAccessible as String] = accessibility

            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            if addStatus == errSecSuccess { return true }

            // Handle duplicate by cleaning up and retrying
            if addStatus == errSecDuplicateItem {
                SecItemDelete(query as CFDictionary)
                return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
            }

            Logger.keychain.error("Keychain add failed for \(account, privacy: .private): \(addStatus)")
            return false
        }

        Logger.keychain.error("Keychain update failed for \(account, privacy: .private): \(updateStatus)")
        return false
    }

    func retrieve(forAccount account: String) -> String? {
        let shouldSync = syncableAccounts.contains(account)
        var query = baseQuery(account: account, synchronizable: shouldSync)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

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
        let shouldSync = syncableAccounts.contains(account)
        let query = baseQuery(account: account, synchronizable: shouldSync)
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - OAuth token convenience (never synced)

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

    // MARK: - Private

    /// OAuth tokens (non-syncable) stay on this device and require an unlocked
    /// session. Syncable API keys must use a class compatible with iCloud
    /// Keychain sync (no `ThisDeviceOnly` variants).
    private func accessibilityClass(forSyncable syncable: Bool) -> CFString {
        if syncable {
            return kSecAttrAccessibleAfterFirstUnlock
        }
        return kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    }

    private func baseQuery(account: String, synchronizable: Bool) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
        ]
        if synchronizable {
            query[kSecAttrSynchronizable as String] = kCFBooleanTrue
        }
        return query
    }
}
