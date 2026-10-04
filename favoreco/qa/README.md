# 無料ローカル・リリース監査

追加サービス・有料API・外部パッケージ不要。Python 3とXcodeを使います。CloudKitへの書込み、購入、既存端末の初期化は行いません。自動検証の成功は公開許可ではなく、実機確認は別に残します。

## 毎回の静的チェック

```bash
cd /Users/doublefake/Documents/favoreco
python3 favoreco/qa/release_audit.py
```

終了コード0は実施したチェックが成功、1は不備です。画面表示された一時フォルダに`report.json`と個別ログを保存します。`manualRequired`は成功しても消えません。記録する範囲は、共通ルーターのシートへの供給位置、既知APIのPrivacy Manifest、バックアップ形式、StoreKitの5商品ID、施設／イベント生成、施設IDの重複・親参照・座標範囲・必須項目です。座標の0/0は現行仕様の未入力値として件数に含めません。公式情報の鮮度やCloudKitの現在値は検証しません。

## 全テストと公開向けビルド

専用Simulatorを作成する例（iOS 18.6 runtime導入済みの場合）:

```bash
cd /Users/doublefake/Documents/favoreco
xcrun simctl create Favoreco-Release-Audit com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro com.apple.CoreSimulator.SimRuntime.iOS-18-6
```

表示されたUUIDを指定します。通常の個人用Simulatorを誤指定した場合は実行を拒否します。

```bash
cd /Users/doublefake/Documents/favoreco
python3 favoreco/qa/release_audit.py --simulator '<上で表示されたUUID>' --release-build
```

XCTestの`.xcresult`、テストログ、署名なしReleaseビルドログ、JSON判定を保存します。`--output`で保管先を指定する場合は実行ごとに新しいディレクトリを使ってください。既存の`.xcresult`を上書きしません。Xcodeのキャッシュ再利用には`--derived-data-path /private/tmp/favoreco-release-audit-derived`を指定できます。各ビルド・テストの待ち時間は最大20分です。

## 自動化の限界

- 7ジャンルの詳細と再記録フォームをWindowへ実表示するテストは、ボタンの連続操作・写真選択・実機ジェスチャーを代替しません。
- 500記録と50写真ペイロードのテストはSQLite再読込時の内容・関連の保持を確認します。実サイズ写真50枚のデコード、端末メモリ、一覧速度の負荷試験ではありません。
- 全ボタンを無差別に押す操作は、データ削除・外部カレンダー登録・購入も含むため実装していません。操作対象と期待値を決めた検証を増やします。
- CloudKitの複数端末同期、実機通知、Sandbox課金、App Store Connect、色・文字・指での操作感は別の公開ゲートです。
- 詳細は[今回の監査報告](release-audit-2026-09-29.md)を参照してください。
