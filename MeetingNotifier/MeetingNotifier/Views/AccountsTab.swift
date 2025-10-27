import SwiftUI

struct AccountsTab: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 16) {
            if settings.accounts.isEmpty {
                emptyStateView
            } else {
                accountListView
            }

            Spacer()

            addAccountButtons
        }
        .padding(20)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No accounts connected")
                .font(.headline)

            Text("Add a Google or Microsoft account to get started")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var accountListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connected Accounts")
                .font(.headline)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(settings.accounts) { account in
                        accountRow(account)
                    }
                }
            }
        }
    }

    private func accountRow(_ account: CalendarAccount) -> some View {
        HStack(spacing: 12) {
            Image(systemName: account.provider == .google ? "g.circle.fill" : "cloud.fill")
                .font(.system(size: 24))
                .foregroundColor(account.provider == .google ? .red : .blue)

            VStack(alignment: .leading, spacing: 4) {
                Text(account.email)
                    .font(.body)

                Text(account.providerName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Remove") {
                removeAccount(account)
            }
            .foregroundColor(.red)
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private var addAccountButtons: some View {
        HStack(spacing: 12) {
            Button(action: addGoogleAccount) {
                HStack {
                    Image(systemName: "g.circle.fill")
                    Text("Add Google Account")
                }
            }

            Button(action: addMicrosoftAccount) {
                HStack {
                    Image(systemName: "cloud.fill")
                    Text("Add Microsoft Account")
                }
            }
        }
    }

    private func addGoogleAccount() {
        AuthManager.shared.addGoogleAccount { result in
            Task { @MainActor in
                switch result {
                case .success:
                    break
                case .failure(let error):
                    showError(error.localizedDescription)
                }
            }
        }
    }

    private func addMicrosoftAccount() {
        AuthManager.shared.addMicrosoftAccount { result in
            Task { @MainActor in
                switch result {
                case .success:
                    break
                case .failure(let error):
                    showError(error.localizedDescription)
                }
            }
        }
    }

    private func removeAccount(_ account: CalendarAccount) {
        let alert = NSAlert()
        alert.messageText = "Remove Account"
        alert.informativeText = "Are you sure you want to remove \(account.email)? This will stop syncing events from this account."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            settings.removeAccount(account)
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.runModal()
    }
}

struct AccountsTab_Previews: PreviewProvider {
    static var previews: some View {
        AccountsTab()
            .frame(width: 500, height: 600)
    }
}
