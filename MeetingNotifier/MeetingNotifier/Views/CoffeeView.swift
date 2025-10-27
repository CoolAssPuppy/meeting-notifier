import SwiftUI
import StoreKit

struct CoffeeView: View {
    @StateObject private var storeManager = StoreKitManager.shared
    @State private var showThankYou = false
    @State private var isPurchasing = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            Divider()

            Spacer()

            // Content
            VStack(spacing: 24) {
                Text("MeetingNotifier is free.")
                    .font(.title3)

                Text("But you can buy me coffee ☕")
                    .font(.title2)
                    .fontWeight(.medium)

                if showThankYou {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)

                        Text("Thank you for your support!")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Your coffee has been received 🎉")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .transition(.scale.combined(with: .opacity))
                } else {
                    // Product list
                    if storeManager.isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding()
                    } else if let coffeeProduct = storeManager.products.first(where: { $0.id == ProductIdentifier.coffee.rawValue }) {
                        VStack(spacing: 16) {
                            // Product display
                            VStack(spacing: 8) {
                                Text(coffeeProduct.displayName)
                                    .font(.headline)

                                Text(coffeeProduct.description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }

                            // Purchase button
                            Button(action: {
                                Task {
                                    await purchaseCoffee(coffeeProduct)
                                }
                            }) {
                                HStack {
                                    Image(systemName: "cup.and.saucer.fill")
                                    Text("Buy Coffee - \(coffeeProduct.displayPrice)")
                                }
                                .font(.title3)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 16)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .disabled(isPurchasing)
                            .controlSize(.large)

                            if isPurchasing {
                                ProgressView()
                                    .padding(.top, 8)
                            }

                            // Already purchased indicator
                            if storeManager.isPurchased(coffeeProduct.id) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Already purchased - Thank you!")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.top, 8)
                            }
                        }
                    } else {
                        Text("Coffee not available at the moment")
                            .font(.body)
                            .foregroundColor(.secondary)

                        Button("Retry Loading Products") {
                            Task {
                                await storeManager.loadProducts()
                            }
                        }
                        .padding(.top, 8)
                    }

                    // Error message
                    if let error = storeManager.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                    }

                    // Restore button
                    Button("Restore Purchases") {
                        Task {
                            await storeManager.restorePurchases()
                        }
                    }
                    .buttonStyle(.link)
                    .padding(.top, 16)
                }
            }
            .padding()

            Spacer()

            // Footer note
            VStack(spacing: 8) {
                Text("All purchases are one-time and non-consumable")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Thank you for supporting independent development!")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)
            }
            .padding()
        }
        .background(.ultraThinMaterial)
    }

    private var headerBar: some View {
        HStack {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 32))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text("Support MeetingNotifier")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Buy Me Coffee")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding()
        .background(.regularMaterial)
    }

    private func purchaseCoffee(_ product: Product) async {
        isPurchasing = true

        do {
            let transaction = try await storeManager.purchase(product)

            if transaction != nil {
                withAnimation {
                    showThankYou = true
                }

                // Hide thank you message after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    withAnimation {
                        showThankYou = false
                    }
                }
            }
        } catch {
            print("Purchase failed: \(error)")
        }

        isPurchasing = false
    }
}

struct CoffeeView_Previews: PreviewProvider {
    static var previews: some View {
        CoffeeView()
    }
}
