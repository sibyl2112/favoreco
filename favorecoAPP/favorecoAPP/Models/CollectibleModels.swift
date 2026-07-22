import Foundation
import SwiftData

enum CollectibleKind: String, CaseIterable, Identifiable {
    case capsuleToy = "capsule_toy"
    case acrylicKeychain = "acrylic_keychain"
    case canBadge = "can_badge"
    case bromide = "bromide"
    case sticker
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .capsuleToy: "カプセルトイ"
        case .acrylicKeychain: "アクリルキーホルダー"
        case .canBadge: "缶バッジ"
        case .bromide: "ブロマイド・カード"
        case .sticker: "ステッカー"
        case .other: "その他"
        }
    }
}

enum CollectibleTransactionKind: String, CaseIterable, Identifiable {
    case capsule = "capsule"
    case purchase = "purchase"
    case tradeReceived = "trade_received"
    case giftReceived = "gift_received"
    case tradeOut = "trade_out"
    case gifted = "gifted"
    case sold = "sold"
    case lost = "lost"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .capsule: "回して入手"
        case .purchase: "購入"
        case .tradeReceived: "交換で入手"
        case .giftReceived: "もらった"
        case .tradeOut: "交換で手放した"
        case .gifted: "譲った"
        case .sold: "売った"
        case .lost: "紛失・破損"
        }
    }

    var signedDirection: Int {
        switch self {
        case .capsule, .purchase, .tradeReceived, .giftReceived: 1
        case .tradeOut, .gifted, .sold, .lost: -1
        }
    }
}

@Model
final class CollectibleItem {
    var id: UUID = UUID()
    var name: String = ""
    var variantName: String = ""
    var sortOrder: Int = 0
    var isCompletionTarget: Bool = true
    var isArchived: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Attribute(.externalStorage)
    var imageData: Data?

    var series: ExperienceEvent?

    @Relationship(deleteRule: .cascade, inverse: \CollectibleTransaction.item)
    var transactions: [CollectibleTransaction]? = []

    init(
        id: UUID = UUID(),
        name: String = "",
        variantName: String = "",
        sortOrder: Int = 0,
        isCompletionTarget: Bool = true,
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        imageData: Data? = nil,
        series: ExperienceEvent? = nil
    ) {
        self.id = id
        self.name = name
        self.variantName = variantName
        self.sortOrder = sortOrder
        self.isCompletionTarget = isCompletionTarget
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.imageData = imageData
        self.series = series
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "種類 \(sortOrder + 1)" : trimmed
    }

    var currentQuantity: Int {
        max(0, (transactions ?? []).reduce(0) { total, transaction in
            total + transaction.signedQuantity
        })
    }

    var duplicateQuantity: Int { max(0, currentQuantity - 1) }
}

@Model
final class CollectibleTransaction {
    var id: UUID = UUID()
    var kindKey: String = CollectibleTransactionKind.purchase.rawValue
    var quantity: Int = 1
    var occurredAt: Date = Date()
    var amount: Decimal = 0
    var placeNameSnapshot: String = ""
    var memo: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var item: CollectibleItem?

    init(
        id: UUID = UUID(),
        kindKey: String = CollectibleTransactionKind.purchase.rawValue,
        quantity: Int = 1,
        occurredAt: Date = Date(),
        amount: Decimal = 0,
        placeNameSnapshot: String = "",
        memo: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        item: CollectibleItem? = nil
    ) {
        self.id = id
        self.kindKey = kindKey
        self.quantity = max(1, quantity)
        self.occurredAt = occurredAt
        self.amount = amount
        self.placeNameSnapshot = placeNameSnapshot
        self.memo = memo
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.item = item
    }

    var kind: CollectibleTransactionKind {
        CollectibleTransactionKind(rawValue: kindKey) ?? .purchase
    }

    var signedQuantity: Int { kind.signedDirection * max(1, quantity) }
}

struct CollectibleSeriesSummary {
    let targetCount: Int
    let collectedCount: Int
    let ownedQuantity: Int
    let duplicateQuantity: Int
    let spentAmount: Decimal

    var missingCount: Int { max(0, targetCount - collectedCount) }
    var progress: Double { targetCount == 0 ? 0 : Double(collectedCount) / Double(targetCount) }
    var isComplete: Bool { targetCount > 0 && collectedCount >= targetCount }

    static func make(series: ExperienceEvent) -> CollectibleSeriesSummary {
        let items = (series.collectibleItems ?? []).filter { !$0.isArchived }
        let targets = items.filter(\.isCompletionTarget)
        let transactions = items.flatMap { $0.transactions ?? [] }
        return CollectibleSeriesSummary(
            targetCount: targets.count,
            collectedCount: targets.filter { $0.currentQuantity > 0 }.count,
            ownedQuantity: items.reduce(0) { $0 + $1.currentQuantity },
            duplicateQuantity: items.reduce(0) { $0 + $1.duplicateQuantity },
            spentAmount: transactions
                .filter { $0.kind.signedDirection > 0 }
                .reduce(Decimal.zero) { $0 + $1.amount }
        )
    }
}
