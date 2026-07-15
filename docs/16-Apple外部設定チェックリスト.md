# Favoreco Apple外部設定チェックリスト

> Apple Developer / CloudKit Console / App Store Connectで行う作業
> 更新日: 2026-07-12

## 現在コードに設定済み

- Bundle ID: `com.nori.favoreco`
- iCloud Container: `iCloud.com.nori.favoreco`
- Team: `GDXKVW7W5X`
- Capabilities: CloudKit / iCloud Documents / WeatherKit
- StoreKit構成: `Favoreco.storekit`
- アプリ表示名: `Favoreco`
- Version / Build: `1.0 (1)`
- Deployment Target: iOS 18.0

## 1. Apple Developer

Identifiers > App IDs > `com.nori.favoreco`:

- iCloudをON
- CloudKitをON
- iCloud Containersで `iCloud.com.nori.favoreco` を関連付け
- WeatherKitをON
- App ID変更後、Development/Distribution provisioning profileを再生成またはAutomatic Signingで更新

Identifiers > iCloud Containers:

- `iCloud.com.nori.favoreco` が存在する
- 開発チームが正しい
- 別アプリのContainerを誤接続していない

## 2. CloudKit Console

1. `iCloud.com.nori.favoreco` を選択
2. Development環境で実機起動し、同期ONで一度データを保存
3. Records / SchemaでFavorecoのSwiftDataレコードタイプが作成されることを確認
4. 写真を含む記録、人物、場所、予定、チケットを同期して関係を確認
5. TestFlight前に `Deploy Schema Changes` でDevelopmentからProductionへ反映

注意:

- Productionへ反映後のスキーマ変更は慎重に行う
- Production反映前にモデル名、属性、optional関係を確定する
- 既存利用者データがある状態で属性削除や型変更をしない
- CloudKit DashboardのErrors、Logs、Usageを確認する

## 3. App Store Connect アプリ登録

Apps > New App:

- Name: Favoreco
- Primary Language: Japanese
- Bundle ID: `com.nori.favoreco`
- SKU: 例 `ranoviqo-favoreco-ios`
- User Access: Full Accessまたは運用方針に合わせる

App Information:

- Categoryを決める（候補: Lifestyle / Entertainment）
- Privacy Policy URLはRANOVIQO公式サイトのFavoreco専用URLを設定
- License Agreementは標準EULAまたは公開した利用規約に合わせる
- Age Rating質問へ実機能どおり回答

App Privacy:

- 端末内のみ、利用者のiCloud private database、Apple課金の区別を確認して回答する
- 運営者サーバーへ収集しないデータを「収集」と誤申告しない
- 将来Analytics、問い合わせフォーム、外部DB APIを追加した時は回答を更新する
- 写真、位置、購入、ユーザーコンテンツの扱いを公開ポリシーと一致させる

## 4. App Store Connect 商品

Non-Consumable:

| Product ID | 参考価格 | 内容 |
|---|---:|---|
| `com.nori.favoreco.light.lifetime` | ¥1,500 | 標準ジャンルの拡張機能、写真30枚、同期なし |
| `com.nori.favoreco.sync.lifetime.addon` | ¥5,000 | ライト所有者向け同期永久追加。単体では完全権利なし |
| `com.nori.favoreco.full.lifetime` | ¥6,000 | 完全買い切り。自作ジャンル、写真無制限、同期永久（個別合計より¥500お得） |

Auto-Renewable Subscription Group: `Favoreco Sync`

| Product ID | 参考価格 | 期間 |
|---|---:|---|
| `com.nori.favoreco.sync.monthly` | ¥250 | 1か月 |
| `com.nori.favoreco.sync.yearly` | ¥1,500 | 1年 |

各商品で必要:

- Reference Name
- 日本語Display Name / Description
- Price Schedule
- Review Screenshot
- Tax Category
- Availability
- Subscription Group内の表示順
- Review Notesに各商品の解放範囲を記載

商品IDはコードおよび `Favoreco.storekit` と完全一致させる。作成後の商品IDは再利用・変更できないため、登録前に最終確認する。

## 5. Sandbox / TestFlight

- Sandbox Testerを作成
- 月額購入、年額購入、買い切り、復元、期限切れ、返金/取消を確認
- 同期永久追加だけを購入しても完全権利にならないことを確認
- ライト購入後だけ同期永久追加を表示し、両方の購入後に完全権利になることを確認
- 完全買い切りを直接購入すると完全権利になることを確認
- サブスク失効後も既存データが残ることを確認
- TestFlightではXcodeのStoreKit ConfigurationではなくApp Store Connect商品を使う
- TestFlightビルドでCloudKit Production環境を確認

## 6. 審査素材

- iPhoneの主要サイズでスクリーンショット
- 必要ならiPadスクリーンショット（現在Universal設定）
- App Description / Keywords / Promotional Text
- Support URL
- Marketing URL
- Privacy Policy URL
- Review Notes
- 課金機能へ到達する操作手順
- iCloud同期、通知、カレンダー、写真、カメラを使う理由
- 審査用アカウントが不要なローカルアプリであること

## 7. リリース前の要判断

- 最低対応OSはiOS 18.0。iOS 26実機を主確認端末とし、iOS 18 Simulatorと公開前TestFlightで互換確認する
- iPad対応はデザイン完成度を見て判断する。含める場合は全主要画面をiPadで確認し、見送る場合は提出前にTargeted Device FamilyをiPhoneのみに変更する
- `com.nori.favoreco` と `iCloud.com.nori.favoreco` をRANOVIQOの恒久IDとして採用するか
- 創設メンバー特典の対象、締切日、権利付与方法
- 規約、プライバシー、問い合わせ、公式X、レビューURLの最終URL

## 8. Archive前チェック

```bash
cd /Users/doublefake/Documents/favoreco
xcodebuild -project favorecoAPP/favorecoAPP.xcodeproj \
  -scheme favorecoAPP \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  archive
```

Xcode Organizerから配布する場合:

1. Product > Archive
2. Validate App
3. Distribute App > App Store Connect
4. Upload
5. App Store ConnectでProcessing完了を待つ
6. TestFlight内部テストへ追加
7. 実機総合確認手順をTestFlightビルドでも再実施する
