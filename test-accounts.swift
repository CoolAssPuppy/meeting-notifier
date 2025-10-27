#!/usr/bin/env swift

import Foundation

// Test account decoding from UserDefaults with the specific app domain
let appDomain = "com.strategicnerds.meetingnotifier"
let defaults = UserDefaults(suiteName: appDomain)!

print("Using UserDefaults domain: \(appDomain)")

// Get accounts data directly
if let accountsData = defaults.data(forKey: "accounts") {
    print("Found accounts data: \(accountsData.count) bytes")

    // Try to decode it as a string first to see the JSON
    if let jsonString = String(data: accountsData, encoding: .utf8) {
        print("Accounts JSON: \(jsonString)")
    }

    // Now try to decode properly
    struct CalendarAccount: Codable {
        var email: String
        var provider: String
        var isEnabled: Bool
        var selectedCalendarIds: [String]
    }

    do {
        let decoder = JSONDecoder()
        let accounts = try decoder.decode([CalendarAccount].self, from: accountsData)
        print("✅ Successfully decoded \(accounts.count) accounts:")
        for account in accounts {
            print("  - \(account.email) (\(account.provider))")
        }
    } catch {
        print("❌ Error decoding accounts: \(error)")
    }

    // Try with Set instead of Array
    struct CalendarAccountWithSet: Codable {
        var email: String
        var provider: String
        var isEnabled: Bool
        var selectedCalendarIds: Set<String>
    }

    do {
        let decoder = JSONDecoder()
        let accounts = try decoder.decode([CalendarAccountWithSet].self, from: accountsData)
        print("✅ Successfully decoded \(accounts.count) accounts with Set:")
        for account in accounts {
            print("  - \(account.email) (\(account.provider))")
        }
    } catch {
        print("❌ Error decoding accounts with Set: \(error)")
    }
} else {
    print("❌ No accounts data found in UserDefaults")
}
