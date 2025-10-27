import SwiftUI

struct AccountsTab: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var accountToRemove: CalendarAccount?
    @State private var showingRemoveAlert = false

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
        .alert("Remove Account", isPresented: $showingRemoveAlert, presenting: accountToRemove) { account in
            Button("Remove", role: .destructive) {
                settings.removeAccount(account)
            }
            Button("Cancel", role: .cancel) {}
        } message: { account in
            Text("Are you sure you want to remove \(account.email)? This will stop syncing events from this account.")
        }
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
            if let icon = account.provider.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: account.provider == .google ? "g.circle.fill" : "cloud.fill")
                    .font(.system(size: 20))
                    .foregroundColor(account.provider == .google ? .red : .blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(account.email)
                    .font(.system(size: 13))

                Text(account.providerName)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Remove") {
                removeAccount(account)
            }
            .buttonStyle(.borderless)
            .foregroundColor(.red)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
    }

    private var addAccountButtons: some View {
        HStack(spacing: 12) {
            Button(action: addGoogleAccount) {
                HStack(spacing: 8) {
                    if let icon = CalendarProvider.google.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "g.circle.fill")
                            .font(.system(size: 16))
                    }
                    Text("Add Google Account")
                        .font(.system(size: 13))
                }
            }
            .buttonStyle(.bordered)

            Button(action: addMicrosoftAccount) {
                HStack(spacing: 8) {
                    if let icon = CalendarProvider.microsoft.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "cloud.fill")
                            .font(.system(size: 16))
                    }
                    Text("Add Microsoft Account")
                        .font(.system(size: 13))
                }
            }
            .buttonStyle(.bordered)
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
        accountToRemove = account
        showingRemoveAlert = true
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
