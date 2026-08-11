import Foundation
import StoreKit
import WidgetKit

// Deliberately does not import SwiftUI: StoreKit.Transaction and
// SwiftUI.Transaction would collide.
final class StoreManager: ObservableObject {
    static let shared = StoreManager()
    static let fullMacrosProductID = "com.traisfoy.mactrak.fullmacros"

    @Published private(set) var fullMacrosProduct: Product?
    @Published private(set) var isUnlocked = MacroStore.fullMacrosUnlocked
    @Published private(set) var isPurchasing = false

    private init() {
        Task { await self.observeTransactionUpdates() }
        Task {
            await self.loadProduct()
            await self.refreshEntitlements()
        }
    }

    @MainActor
    var displayPrice: String {
        fullMacrosProduct?.displayPrice ?? "$2.99"
    }

    @MainActor
    func loadProduct() async {
        guard fullMacrosProduct == nil else { return }
        fullMacrosProduct = try? await Product.products(for: [Self.fullMacrosProductID]).first
    }

    @MainActor
    func purchase() async {
        if fullMacrosProduct == nil { await loadProduct() }
        guard let product = fullMacrosProduct, !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }

        guard let result = try? await product.purchase() else { return }
        if case .success(let verification) = result,
           case .verified(let transaction) = verification {
            await transaction.finish()
            setUnlocked(true)
        }
    }

    @MainActor
    func restorePurchases() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    @MainActor
    private func refreshEntitlements() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.fullMacrosProductID,
               transaction.revocationDate == nil {
                unlocked = true
            }
        }
        setUnlocked(unlocked)
    }

    private func observeTransactionUpdates() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                await transaction.finish()
                if transaction.productID == Self.fullMacrosProductID {
                    await setUnlocked(transaction.revocationDate == nil)
                }
            }
        }
    }

    @MainActor
    private func setUnlocked(_ unlocked: Bool) {
        isUnlocked = unlocked
        if MacroStore.fullMacrosUnlocked != unlocked {
            MacroStore.fullMacrosUnlocked = unlocked
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
