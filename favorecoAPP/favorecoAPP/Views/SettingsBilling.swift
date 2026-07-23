import SwiftUI
import SwiftData
import StoreKit

struct BillingPlanSettingsView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager

    var body: some View {
        Form {
            Section("現在のプラン") {
                LabeledContent("プラン", value: purchaseManager.currentPlan.displayName)
                Text(planDescription)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("無料で使えること") {
                PlanFeatureRow(
                    title: "基本記録",
                    detail: "記録の作成、編集、閲覧。URL/動画リンク保存も含む。",
                    systemImage: "square.and.pencil"
                )
                PlanFeatureRow(
                    title: "写真",
                    detail: "1記録10枚まで。カバー写真とサムネイル表示も無料。",
                    systemImage: "photo"
                )
                PlanFeatureRow(
                    title: "カレンダー",
                    detail: "手動でカレンダーに追加。追加先カレンダーの選択も無料。",
                    systemImage: "calendar.badge.plus"
                )
                PlanFeatureRow(
                    title: "バックアップ",
                    detail: "JSON/CSVなどの手動エクスポートは無料の安全網として扱う。",
                    systemImage: "square.and.arrow.up"
                )
            }

            Section("Pro") {
                PlanHeaderRow(
                    title: "Favoreco Pro",
                    price: "¥2,500",
                    detail: "ローカルの記録機能を永久解放。同期と自作ジャンルは含めない。"
                )
                PlanFeatureRow(
                    title: "詳細統計・年間まとめ",
                    detail: "月/年/通算の深い統計、年間ベスト画像化など。",
                    systemImage: "chart.bar.xaxis"
                )
                PlanFeatureRow(
                    title: "OCR高度化",
                    detail: "複雑な半券、チケット、レシート、リスト画像の補助を強化。",
                    systemImage: "text.viewfinder"
                )
                PlanFeatureRow(
                    title: "URL高度取込",
                    detail: "公式ページの構造化データから日時・会場候補を取得。",
                    systemImage: "link.badge.plus"
                )
                PlanFeatureRow(
                    title: "ローカル写真無制限",
                    detail: "1記録の枚数上限なく、この端末へ写真を保存できます。",
                    systemImage: "photo.stack"
                )
                PlanFeatureRow(
                    title: "テーマ・フォント拡張",
                    detail: "追加テーマ、個別テーマ、高度なフォント変更候補。",
                    systemImage: "paintpalette"
                )
            }

            Section("Premium") {
                PlanHeaderRow(
                    title: "Favoreco Premium",
                    price: "月¥250 / 年¥2,000",
                    detail: "契約中はPro機能、自作ジャンル、同期と自動バックアップを利用可能。"
                )
                PlanFeatureRow(
                    title: "iCloud同期",
                    detail: "端末間同期、自動バックアップ、復元を扱う。",
                    systemImage: "icloud.and.arrow.up"
                )
                PlanFeatureRow(
                    title: "自作ジャンル",
                    detail: "自分専用のジャンルを作成し、記録項目や表示を整えられます。",
                    systemImage: "square.grid.2x2"
                )
                PlanFeatureRow(
                    title: "自動思い出レポート",
                    detail: "月刊Favoreco、年間Favorecoを自動生成し、写真やジャンル傾向から思い出カードを提案する。",
                    systemImage: "sparkles.rectangle.stack"
                )
                PlanFeatureRow(
                    title: "継続更新される補助",
                    detail: "外部候補、参照データ、入力補助など継続価値のある機能候補。",
                    systemImage: "sparkles"
                )
            }

            Section("Premium 永久版") {
                PlanHeaderRow(
                    title: "Favoreco Premium 永久版",
                    price: "¥6,000",
                    detail: "Pro購入後は¥3,500でアップグレードでき、どちらの購入経路でも合計¥6,000。"
                )
                PlanFeatureRow(
                    title: "Premium機能を永久利用",
                    detail: "Pro機能、自作ジャンル、同期と自動バックアップを、サブスクリプションなしで利用できます。",
                    systemImage: "checkmark.seal"
                )
            }

            Section("購入") {
                if purchaseManager.products.isEmpty {
                    Text("商品情報を取得できません。App Store Connectへ商品を登録すると購入ボタンが表示されます。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                } else {
                    if purchaseManager.currentPlan != .fullLifetime,
                       !purchaseManager.ownsLightLifetime,
                       let product = purchaseManager.product(id: FavorecoProductID.lightLifetime) {
                        StorePurchaseRow(title: "Favoreco Pro", product: product)
                    }
                    if purchaseManager.currentPlan != .fullLifetime,
                       let product = purchaseManager.product(id: FavorecoProductID.syncMonthly) {
                        StorePurchaseRow(title: "Premium 月額", product: product)
                    }
                    if purchaseManager.currentPlan != .fullLifetime,
                       let product = purchaseManager.product(id: FavorecoProductID.syncYearly) {
                        StorePurchaseRow(title: "Premium 年額", product: product)
                    }
                    if purchaseManager.ownsLightLifetime,
                       !purchaseManager.ownsSyncLifetimeAddon,
                       purchaseManager.currentPlan != .fullLifetime,
                       let product = purchaseManager.product(id: FavorecoProductID.syncLifetimeAddon) {
                        StorePurchaseRow(title: "Premium 永久版へアップグレード", product: product)
                    }
                    if !purchaseManager.ownsLightLifetime,
                       purchaseManager.currentPlan != .fullLifetime,
                       let product = purchaseManager.product(id: FavorecoProductID.fullLifetime) {
                        StorePurchaseRow(title: "Premium 永久版", product: product)
                    }
                }
                Button {
                    Task { await purchaseManager.restore() }
                } label: {
                    Label("購入を復元", systemImage: "arrow.clockwise")
                }
                .disabled(purchaseManager.isLoading)
            }

            if purchaseManager.isLoading {
                Section {
                    HStack {
                        ProgressView()
                        Text("App Storeを確認中です。")
                    }
                }
            }

            if !purchaseManager.message.isEmpty {
                Section("購入状況") {
                    Text(purchaseManager.message)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("補足") {
                NavigationLink {
                    SettingsDocumentView(title: "創設メンバー特典", bodyText: "既存¥980ユーザーと発売締切までの新規購入者に同期永久無料を付与する案を保持しています。締切日は未定です。")
                } label: {
                    Label("創設メンバー特典", systemImage: "person.2.badge.gearshape")
                }

                NavigationLink {
                    SettingsDocumentView(title: "DBパック管理", bodyText: "DBパックは商品として未確定です。寺社、会場、劇場、施設、辞書プリセットなど、権利と更新コストを確認できるものだけ検討します。")
                } label: {
                    Label("DBパック管理", systemImage: "shippingbox")
                }
            }
        }
        .navigationTitle("課金・プラン")
        .navigationBarTitleDisplayMode(.inline)
        .task { await purchaseManager.refresh() }
    }

    private var planDescription: String {
        switch purchaseManager.currentPlan {
        case .free: return "基本記録と無料機能を利用できます。"
        case .lightLifetime: return "Pro機能とローカル写真無制限を永久に利用できます。"
        case .syncSubscription: return "契約中はPro機能、自作ジャンル、同期、自動バックアップを利用できます。"
        case .fullLifetime: return "Pro機能、自作ジャンル、同期、自動バックアップを永久に利用できます。"
        }
    }
}

private struct StorePurchaseRow: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    let title: String
    let product: Product

    var body: some View {
        Button {
            Task { await purchaseManager.purchase(product) }
        } label: {
            HStack {
                Text(title)
                Spacer()
                Text(product.displayPrice)
                    .font(FavorecoTypography.bodyStrong)
            }
        }
        .disabled(purchaseManager.isLoading)
    }
}

private struct PlanHeaderRow: View {
    let title: String
    let price: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(FavorecoTypography.bodyStrong)
                Spacer()
                Text(price)
                    .font(FavorecoTypography.bodyStrong)
            }
            Text(detail)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}

private struct PlanFeatureRow: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(FavorecoTypography.bodyStrong)
                Text(detail)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}
