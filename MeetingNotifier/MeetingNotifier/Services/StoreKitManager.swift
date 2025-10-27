import Foundation
import StoreKit

/// Product identifiers for IAP
enum ProductIdentifier: String, CaseIterable {
    case coffee = "com.strategicnerds.meetingnotifier.coffee"

    var displayName: String {
        switch self {
        case .coffee: return "Buy Me Coffee"
        }
    }

    var description: String {
        switch self {
        case .coffee: return "Support MeetingNotifier development with a coffee!"
        }
    }
}

/// Manages In-App Purchases
@MainActor
class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var updates: Task<Void, Never>?

    private init() {
        // Listen for transaction updates
        updates = observeTransactionUpdates()

        // Load products
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    deinit {
        updates?.cancel()
    }

    /// Load available products from the App Store
    func loadProducts() async {
        isLoading = true
        errorMessage = nil

        do {
            let productIDs = ProductIdentifier.allCases.map { $0.rawValue }
            let storeProducts = try await Product.products(for: productIDs)

            DispatchQueue.main.async {
                self.products = storeProducts
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to load products: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    /// Purchase a product
    func purchase(_ product: Product) async throws -> Transaction? {
        isLoading = true
        errorMessage = nil

        let result = try await product.purchase()

        DispatchQueue.main.async {
            self.isLoading = false
        }

        switch result {
        case .success(let verification):
            // Check verification result
            let transaction = try checkVerified(verification)

            // Update purchased products
            await updatePurchasedProducts()

            // Finish the transaction
            await transaction.finish()

            return transaction

        case .userCancelled:
            return nil

        case .pending:
            return nil

        @unknown default:
            return nil
        }
    }

    /// Restore purchases
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil

        do {
            try await AppStore.sync()
            await updatePurchasedProducts()

            DispatchQueue.main.async {
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    /// Check if a product has been purchased
    func isPurchased(_ productID: String) -> Bool {
        purchasedProductIDs.contains(productID)
    }

    /// Update purchased products from current entitlements
    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }

            if transaction.revocationDate == nil {
                purchased.insert(transaction.productID)
            }
        }

        DispatchQueue.main.async {
            self.purchasedProductIDs = purchased
        }
    }

    /// Observe transaction updates
    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) {
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else {
                    continue
                }

                // Update purchased products
                await updatePurchasedProducts()

                // Finish transaction
                await transaction.finish()
            }
        }
    }

    /// Verify a transaction
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

/// Store errors
enum StoreError: Error {
    case failedVerification

    var localizedDescription: String {
        switch self {
        case .failedVerification:
            return "Transaction failed verification"
        }
    }
}
