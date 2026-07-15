import Combine
import Foundation
import StoreKit

enum FavorecoPlan: String, Sendable {
    case free
    case lightLifetime
    case syncSubscription
    case fullLifetime

    nonisolated var displayName: String {
        switch self {
        case .free: return "無料"
        case .lightLifetime: return "ライト買い切り"
        case .syncSubscription: return "同期プラン"
        case .fullLifetime: return "完全買い切り"
        }
    }

    nonisolated var includesLocalFullFeatures: Bool { self != .free }
    nonisolated var includesSync: Bool { self == .syncSubscription || self == .fullLifetime }
}

enum FavorecoProductID {
    nonisolated static let lightLifetime = "com.nori.favoreco.light.lifetime"
    nonisolated static let syncMonthly = "com.nori.favoreco.sync.monthly"
    nonisolated static let syncYearly = "com.nori.favoreco.sync.yearly"
    nonisolated static let syncLifetimeAddon = "com.nori.favoreco.sync.lifetime.addon"
    nonisolated static let fullLifetime = "com.nori.favoreco.full.lifetime"

    nonisolated static let all: Set<String> = [
        lightLifetime,
        syncMonthly,
        syncYearly,
        syncLifetimeAddon,
        fullLifetime,
    ]
}

enum EntitlementAccess {
    nonisolated static var canUseSyncFeatures: Bool {
        let rawValue = UserDefaults.standard.string(forKey: AppStorageKeys.purchasedPlanCache) ?? ""
        return (FavorecoPlan(rawValue: rawValue) ?? .free).includesSync
    }
}

@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    @Published private(set) var products: [Product] = []
    @Published private(set) var currentPlan: FavorecoPlan = .free
    @Published private(set) var ownsLightLifetime = false
    @Published private(set) var ownsSyncLifetimeAddon = false
    @Published private(set) var isLoading = false
    @Published private(set) var message = ""

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = observeTransactions()
        Task { await refresh() }
    }

    deinit {
        updatesTask?.cancel()
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: FavorecoProductID.all)
                .sorted { productOrder($0.id) < productOrder($1.id) }
            await refreshEntitlements()
            message = products.isEmpty ? "商品情報を取得できません。App Store Connectの設定後に再確認してください。" : ""
        } catch {
            message = error.localizedDescription
            await refreshEntitlements()
        }
    }

    func purchase(_ product: Product) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verified(verification)
                await transaction.finish()
                await refreshEntitlements()
                message = "購入を反映しました。"
            case .pending:
                message = "購入は承認待ちです。"
            case .userCancelled:
                message = ""
            @unknown default:
                message = "購入結果を確認できませんでした。"
            }
        } catch {
            message = error.localizedDescription
        }
    }

    func restore() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            message = "購入情報を復元しました。"
        } catch {
            message = error.localizedDescription
        }
    }

    func product(id: String) -> Product? {
        products.first { $0.id == id }
    }

#if DEBUG
    func setDebugPlanOverride(_ plan: FavorecoPlan?) async {
        if let plan {
            UserDefaults.standard.set(plan.rawValue, forKey: AppStorageKeys.debugPlanOverride)
        } else {
            UserDefaults.standard.removeObject(forKey: AppStorageKeys.debugPlanOverride)
        }
        await refreshEntitlements()
    }
#endif

    private func observeTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if let transaction = try? self.verified(update) {
                    await transaction.finish()
                    await self.refreshEntitlements()
                }
            }
        }
    }

    private func refreshEntitlements() async {
        var activeProductIDs = Set<String>()
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? verified(result),
                  transaction.revocationDate == nil else { continue }
            activeProductIDs.insert(transaction.productID)
        }

        ownsLightLifetime = activeProductIDs.contains(FavorecoProductID.lightLifetime)
        ownsSyncLifetimeAddon = activeProductIDs.contains(FavorecoProductID.syncLifetimeAddon)
        if activeProductIDs.contains(FavorecoProductID.fullLifetime)
            || (ownsLightLifetime && ownsSyncLifetimeAddon) {
            currentPlan = .fullLifetime
        } else if activeProductIDs.contains(FavorecoProductID.syncMonthly)
            || activeProductIDs.contains(FavorecoProductID.syncYearly) {
            currentPlan = .syncSubscription
        } else if ownsLightLifetime {
            currentPlan = .lightLifetime
        } else {
            currentPlan = .free
        }
#if DEBUG
        if let rawValue = UserDefaults.standard.string(forKey: AppStorageKeys.debugPlanOverride),
           let overriddenPlan = FavorecoPlan(rawValue: rawValue) {
            currentPlan = overriddenPlan
        }
#endif
        UserDefaults.standard.set(currentPlan.rawValue, forKey: AppStorageKeys.purchasedPlanCache)
        await MonthlyReportNotificationScheduler.reschedule(isEntitled: currentPlan.includesSync)
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified(_, let error): throw error
        }
    }

    private func productOrder(_ id: String) -> Int {
        switch id {
        case FavorecoProductID.lightLifetime: return 0
        case FavorecoProductID.syncMonthly: return 1
        case FavorecoProductID.syncYearly: return 2
        case FavorecoProductID.syncLifetimeAddon: return 3
        case FavorecoProductID.fullLifetime: return 4
        default: return 99
        }
    }
}
