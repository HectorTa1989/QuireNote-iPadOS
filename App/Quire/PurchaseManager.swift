import Combine
import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    static let proProductID = "quire.pro"

    @Published private(set) var isPro = false
    @Published private(set) var proProduct: Product?
    @Published var errorMessage: String?
    @Published private(set) var isPurchasing = false

    private var updatesTask: Task<Void, Never>?

    init() {
        #if DEBUG
        isPro = true
        #else
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard case let .verified(transaction) = update else { continue }
                await transaction.finish()
                await self?.refreshEntitlements()
            }
        }
        #endif
    }

    func load() async {
        do {
            proProduct = try await Product.products(for: [Self.proProductID]).first
            await refreshEntitlements()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func purchasePro() async {
        guard let proProduct else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await proProduct.purchase() {
            case let .success(verification):
                guard case let .verified(transaction) = verification else { return }
                await transaction.finish()
                await refreshEntitlements()
            case .pending, .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshEntitlements() async {
        #if DEBUG
        isPro = true
        #else
        var entitled = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result,
                  transaction.productID == Self.proProductID,
                  transaction.revocationDate == nil else { continue }
            entitled = true
        }
        isPro = entitled
        #endif
    }
}
