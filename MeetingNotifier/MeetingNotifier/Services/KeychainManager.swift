import Foundation
import Security
import os

@MainActor
class KeychainManager {
    static let shared = KeychainManager()
    private let serviceName = "com.strategicnerds.meetingnotifier"

    private init() {}

    func save(token: String, forAccount account: String) -> Bool {
        guard let tokenData = token.data(using: .utf8) else {
            Logger.keychain.error("Failed to encode token as UTF-8 for account: \(account, privacy: .private)")
            return false
        }

        let searchQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: tokenData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        // Try to update existing item first
        let updateStatus = SecItemUpdate(searchQuery as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecSuccess {
            Logger.keychain.debug("Successfully updated token for \(account, privacy: .private)")
            return true
        } else if updateStatus == errSecItemNotFound {
            // Item doesn't exist, try to add it
            Logger.keychain.debug("No existing item for \(account, privacy: .private), attempting to add new item")

            var addQuery = searchQuery
            addQuery[kSecValueData as String] = tokenData
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

            if addStatus == errSecSuccess {
                Logger.keychain.debug("Successfully added token for \(account, privacy: .private)")
                return true
            } else if addStatus == errSecDuplicateItem || addStatus == -2147413719 {
                // Duplicate item error - try aggressive cleanup
                Logger.keychain.warning("Duplicate item detected for \(account, privacy: .private), attempting cleanup and retry")

                // Try deleting with minimal query
                let cleanupQuery: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: serviceName,
                    kSecAttrAccount as String: account,
                    kSecMatchLimit as String: kSecMatchLimitAll
                ]

                let deleteStatus = SecItemDelete(cleanupQuery as CFDictionary)
                Logger.keychain.debug("Cleanup delete result: \(deleteStatus) (\(self.keychainErrorMessage(deleteStatus)))")

                // Retry add after cleanup
                let retryStatus = SecItemAdd(addQuery as CFDictionary, nil)
                if retryStatus == errSecSuccess {
                    Logger.keychain.debug("Successfully added token after cleanup for \(account, privacy: .private)")
                    return true
                } else {
                    Logger.keychain.error("Failed to add token even after cleanup for \(account, privacy: .private). Status: \(retryStatus) (\(self.keychainErrorMessage(retryStatus)))")
                    return false
                }
            } else {
                Logger.keychain.error("Failed to add token for \(account, privacy: .private). Status: \(addStatus) (\(self.keychainErrorMessage(addStatus)))")
                return false
            }
        } else {
            Logger.keychain.error("Failed to update token for \(account, privacy: .private). Status: \(updateStatus) (\(self.keychainErrorMessage(updateStatus)))")
            return false
        }
    }

    private func keychainErrorMessage(_ status: OSStatus) -> String {
        switch status {
        case errSecSuccess:
            return "Success"
        case errSecDuplicateItem:
            return "Duplicate item"
        case errSecItemNotFound:
            return "Item not found"
        case errSecAuthFailed:
            return "Authentication failed"
        case errSecNotAvailable:
            return "Keychain not available"
        case errSecParam:
            return "Invalid parameters"
        case errSecAllocate:
            return "Memory allocation failed"
        case errSecInteractionNotAllowed:
            return "User interaction not allowed"
        case errSecMissingEntitlement:
            return "Missing entitlement"
        default:
            return "Unknown error code: \(status)"
        }
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
