import Foundation
import Security

@MainActor
class KeychainManager {
    static let shared = KeychainManager()
    private let serviceName = "com.strategicnerds.meetingnotifier"

    private init() {}

    func save(token: String, forAccount account: String) -> Bool {
        guard let tokenData = token.data(using: .utf8) else {
            print("[Keychain] ERROR: Failed to encode token as UTF-8 for account: \(account)")
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
            print("[Keychain] Successfully updated token for \(account)")
            return true
        } else if updateStatus == errSecItemNotFound {
            // Item doesn't exist, try to add it
            print("[Keychain] No existing item for \(account), attempting to add new item")

            var addQuery = searchQuery
            addQuery[kSecValueData as String] = tokenData
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

            if addStatus == errSecSuccess {
                print("[Keychain] Successfully added token for \(account)")
                return true
            } else if addStatus == errSecDuplicateItem || addStatus == -2147413719 {
                // Duplicate item error - try aggressive cleanup
                print("[Keychain] Duplicate item detected for \(account), attempting cleanup and retry")

                // Try deleting with minimal query
                let cleanupQuery: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: serviceName,
                    kSecAttrAccount as String: account,
                    kSecMatchLimit as String: kSecMatchLimitAll
                ]

                let deleteStatus = SecItemDelete(cleanupQuery as CFDictionary)
                print("[Keychain] Cleanup delete result: \(deleteStatus) (\(self.keychainErrorMessage(deleteStatus)))")

                // Retry add after cleanup
                let retryStatus = SecItemAdd(addQuery as CFDictionary, nil)
                if retryStatus == errSecSuccess {
                    print("[Keychain] Successfully added token after cleanup for \(account)")
                    return true
                } else {
                    print("[Keychain] ERROR: Failed to add token even after cleanup for \(account). Status: \(retryStatus) (\(self.keychainErrorMessage(retryStatus)))")
                    return false
                }
            } else {
                print("[Keychain] ERROR: Failed to add token for \(account). Status: \(addStatus) (\(self.keychainErrorMessage(addStatus)))")
                return false
            }
        } else {
            print("[Keychain] ERROR: Failed to update token for \(account). Status: \(updateStatus) (\(self.keychainErrorMessage(updateStatus)))")
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
