# APP_NAME Project Log

> 「なぜそうしたか / どう遷移したか」を残すログ。仕様書が「今どうあるか」、ここが「なぜそうなったか」。
> 追記フォーマットは `docs/_templates/project-log-entry.md` を参照。

<!-- 新しい変更を上に追記していく -->

## 2026-07-14: Home・8ジャンル・設定の構造ラフを再作成

### 変更概要
- Home、標準8ジャンル、設定トップを10画面の比較ボードとしてSVG/PNG化した。
- Homeは最新の合意を優先し、`ジャンル選択 / これから行く予定 / チケットスケジュール / アテンション`の順で表示した。
- 各ジャンルを共通テンプレートへ寄せず、観劇のチケット要対応、映画のポスターライブラリ、酒のボトル棚、御朱印帳など、ジャンル別の専用構造を描き分けた。
- Xcode実装に合わせ、英字・数字はCormorant Garamond、日本語本文はNoto Sans JP、情緒見出しとジャンル名はNoto Serif JPを指定した。

### 変更意図
旧Home実装と共通ジャンルトップを基にした初回ラフでは、直近に確定したHomeの優先順位とジャンル別エキスパート表示を表現できていなかったため。日本語とフォントを正確に確認できるよう、生成画像ではなく編集可能なSVGを正本にした。

### 主な変更ファイル
- `favoreco/assets/mockups/genre-home-settings-structure-v2.svg`
- `favoreco/assets/mockups/genre-home-settings-structure-v2.png`

### 確認結果（実機 / ビルド）
- `xmllint --noout`でSVG構文検証成功。
- SVGから2400×1660pxのPNGを生成し、10画面の欠け、重なり、主要セクション名、色分けを目視確認した。
- アプリコードは変更していないため、Xcodeビルドは対象外。

### 残課題
- Homeの最新表示順を`docs/15-画面情報設計.md`とSwiftUI実装へ反映する作業は別途必要。
- 実装時は0件/1件/複数件、Dynamic Type、ダークモード、iPhone幅違いで再検証する。

## 2026-07-14: 中央+の4入口とクイック登録を整理した

### 変更概要
- 中央`+`をカスタムのボトムシートに変更し、`予定を立てる / 体験済みを記録 / クイック登録 / チケットスケジュールを追加`の固定順にした。
- `予定を立てる`は申込情報OFF、`チケットスケジュールを追加`は申込情報ONで同じ予定入力基盤を開くようにした。
- クイック登録をジャンルとタイトル必須にし、アイキャッチ、URL、メモを任意入力にした。
- URLタイトル取得、写真OCR、カメラOCRを入力補助として追加し、取得結果は確認後にタイトルへ反映するようにした。
- Inboxの任意アイキャッチを外部ストレージ属性で保存し、HomeとInbox詳細で表示、写真付き完全/自動バックアップで復元可能にした。

### 変更意図
Homeに追加ショートカット帯を重ねず、中央`+`だけから目的別の入口へ到達できるようにするため。また、正式記録まで入力する時間がない時も、タイトルとジャンルを起点にURLや画像を後で整理できるようにするため。

### 主な変更ファイル
- `favorecoAPP/favorecoAPP/Views/MainTabView.swift`
- `favorecoAPP/favorecoAPP/Views/AddTicketPlanView.swift`
- `favorecoAPP/favorecoAPP/Views/AddInboxItemView.swift`
- `favorecoAPP/favorecoAPP/Views/InboxDetailView.swift`
- `favorecoAPP/favorecoAPP/Views/HomeView.swift`
- `favorecoAPP/favorecoAPP/Models/CoreModels.swift`
- `favorecoAPP/favorecoAPP/Services/QuickCaptureImageService.swift`
- `favorecoAPP/favorecoAPP/Services/JSONBackupExportService.swift`
- `favorecoAPP/favorecoAPP/Services/JSONBackupImportService.swift`
- `docs/15-画面情報設計.md`
- `docs/project-log.md`

### 確認結果
- 中央`+`入口変更後と、Inbox画像モデル追加後に段階的に全体ビルドを行った。
- iOS 18.0をDeployment TargetとするiPhone Simulator向けDebug・署名なし全体ビルド成功。
- 旧バックアップでInbox画像キーがない場合は`nil`として読み込む任意プロパティにした。

### 残課題
- 実機でカメラ権限、日本語OCR、URLメタデータ取得、アイキャッチの保存/再起動後表示を確認する。
- Inboxから正式記録へ変換する時、アイキャッチをVisitの写真へ引き継ぐ処理は後続で接続する。
- URLからの画像候補取得は現時点では対象外で、タイトル候補と解決後URLだけを反映する。

## 2026-07-14: Homeジャンル入口の2案を実機比較可能にした

### 変更概要
- Home上部のジャンル入口を、`1段横スクロール`と`4列グリッド`の2案で切り替えられるようにした。
- Debugビルドの`設定 > 開発`に`Homeジャンル表示`セグメントを追加した。
- どちらの案も同じコンパクトなアイコン+名称とし、選択時は従来のジャンルトップを開く。

### 変更意図
横スクロールの操作量と縦スクロールへの干渉、4列×2段の一覧性とHomeを占有する高さを、モックではなく実機のタップとスワイプで比較するため。

### 主な変更ファイル
- `favorecoAPP/favorecoAPP/Views/HomeView.swift`
- `favorecoAPP/favorecoAPP/Views/SettingsView.swift`
- `favorecoAPP/favorecoAPP/Utilities/AppStorageKeys.swift`
- `docs/15-画面情報設計.md`
- `docs/project-log.md`

### 確認結果
- iOS 18.0をDeployment TargetとするiPhone Simulator向けDebug・署名なし全体ビルド成功。
- レイアウト変更時にHomeが`AppStorage`を監視し、画面再起動なしで反映されることをコード確認した。
- 0件では従来の空状態、1件以上では各ジャンルトップへの導線を共通で使うことをコード確認した。

### 残課題
- iPhone実機で両案の縦・横スクロール、タップ範囲、8ジャンル時の高さを比較して最終案を決める。
- 4列案でカスタムジャンルが増えた時の3段以上の見え方を実機で確認する。
- 最終決定後はDebug切替と比較用保存キーを削除し、採用案だけに整理する。

## 2026-07-12: 最低対応をiOS 18へ変更

### 変更概要
- Debug/ReleaseのDeployment TargetをiOS 18.0へ変更した。
- iOS 26で導入されたMKMapItemのlocation/addressは26以上で使用し、iOS 18〜25ではplacemarkとCNPostalAddressFormatterへフォールバックするようにした。
- iOS 26実機を先に確認し、iOS 18はSimulatorと公開前TestFlightで補完する検証方針へ更新した。
- iOS 18 Simulator runtimeの追加手順を実機総合確認書へ追記した。

### 変更意図
iOS 26.5限定で対象利用者を狭めず、iOS 18利用者にも提供しながら、手元にiOS 18実機がない検証制約をSimulatorとTestFlightで補うため。

### 主な変更ファイル
- `favorecoAPP/favorecoAPP.xcodeproj/project.pbxproj`
- `favorecoAPP/favorecoAPP/Services/PlaceSearchService.swift`
- `favoreco/CLAUDE.md`
- `docs/15-実機総合確認手順.md`
- `docs/16-Apple外部設定チェックリスト.md`
- `docs/project-log.md`

### 確認結果
- iOS 18.0をDeployment TargetにしたiPhone向けRelease・署名なし全体ビルド成功。
- iOS 18互換エラーは場所検索の2 APIだけで、availability分岐後に解消した。
- iOS 26では新MapKit API、iOS 18〜25では従来APIが選ばれることをコード確認した。
- 現在のMacにはiOS 26.2/26.4/26.5 runtimeのみで、iOS 18 Simulator runtimeは未導入。

### 残課題
- Xcode ComponentsからiOS 18 Simulator runtimeを導入し、主要フローを画面確認する。
- 公開前にiOS 18実機のTestFlight協力者で写真、Map、通知、カレンダーを確認する。

## 2026-07-12: 対応OSを確定しiPad対応判断を保留

### 変更概要
- v1の最低対応OSをiOS 26.5で確定した。
- iPadはUniversal設定を検証用に残し、初版の正式対応はデザイン完成度と実機確認結果で公開直前に判断する方針にした。

### 変更意図
旧OS互換対応へ範囲を広げず現行実装を安定させつつ、iPadは未完成なレイアウトのまま対応端末として公開しないため。

### 主な変更ファイル
- `favoreco/CLAUDE.md`
- `docs/16-Apple外部設定チェックリスト.md`
- `docs/project-log.md`

### 確認結果
- XcodeのDeployment TargetがiOS 26.5、Targeted Device Familyが現時点でiPhone/iPadであることを確認した。

### 残課題
- 公開直前にiPad主要画面を確認し、正式対応またはiPhone限定を決定する。

## 2026-07-12: Apple外部設定監査と実機総合確認手順を整備

### 変更概要
- アプリ表示名を `Favoreco` に固定し、カメラ/カレンダー権限説明を日本語で実用途に合わせた。
- Entitlements、iCloud Container、WeatherKit、StoreKit 5商品、SchemeのStoreKit構成を監査した。
- 実機確認を初回起動から同期、課金、大量写真、削除まで順番に実施できる総合手順書を追加した。
- Apple Developer、CloudKit Console、App Store Connect商品、Sandbox/TestFlight、審査素材の外部設定チェックリストを追加した。
- Releaseビルドで検出した課金権利キャッシュキーのMainActor警告を解消した。

### 変更意図
コード実装完了後の実機確認とApple側設定を漏れなく進め、Debugビルドでは見えないRelease固有の問題も公開前に発見できる状態にするため。

### 主な変更ファイル
- `favorecoAPP/favorecoAPP.xcodeproj/project.pbxproj`
- `favorecoAPP/favorecoAPP/Utilities/AppStorageKeys.swift`
- `docs/15-実機総合確認手順.md`
- `docs/16-Apple外部設定チェックリスト.md`
- `docs/project-log.md`

### 確認結果
- Entitlements plist検証成功。
- StoreKit構成JSON検証成功。
- iPhone向けRelease・署名なし全体ビルド成功。
- Bundle ID、iCloud Container、5つの商品IDがコード、StoreKit構成、手順書で一致することを確認した。

### 残課題
- 実機総合確認手順を実施し、結果と不具合を記録する。
- Apple Developer/App Store Connect/CloudKit Productionの操作はアカウント画面で実施する。
- iOS 26.5を最低対応にするか、iPadを初版対応に含めるかを公開前に確定する。

## 2026-07-12: リンク・サポートと規約参照本文を接続

### 変更概要
- RANOVIQO公式サイトとお問い合わせを外部リンクへ接続した。
- アプリ共有をiOS標準のShareLinkへ接続した。
- 現在の保存、写真メタデータ、位置情報、カレンダー、通知、OCR、StoreKit、iCloud、削除/バックアップ仕様に沿った利用規約とプライバシーポリシー参照本文をアプリ内へ追加した。
- Instagram/Threads入口を外し、URL未確定の公式Xは誤リンクを作らず公開準備中表示にした。
- App Store ID未確定のレビュー導線は無効のまま維持した。

### 変更意図
空のプレースホルダーや無効な共有ボタンを解消し、公開URLが未整備でも利用者がアプリ内でデータの扱いを確認できる状態にするため。最終正本はRANOVIQOドメイン側へ置く方針を維持する。

### 主な変更ファイル
- `favorecoAPP/favorecoAPP/Views/SettingsView.swift`
- `favoreco/CLAUDE.md`
- `docs/project-log.md`

### 確認結果
- iPhone向け署名なし全体ビルド成功。
- 利用規約/プライバシーはネット接続なしで表示でき、公式サイト/問い合わせ/共有だけが外部URLを使うことをコード確認した。
- SwiftDataモデル、CloudKitスキーマ、保存データの変更なし。

### 残課題
- 公開前に本文の法務確認を行い、RANOVIQOドメインへ同内容のWeb正本と恒久的な問い合わせフォームまたはメールを公開する。
- App Store IDと公式X URL確定後にレビュー/公式X導線を接続する。

## 2026-07-12: 前年の年間Favorecoを自動提案へ追加

### 変更概要
- 同期プラン以上の統計画面に「昨年の年間Favoreco」を自動提案として追加した。
- 通知を消した後でも、統計画面から前年を選択済みの年間レポートへ戻れるようにした。
- 未契約時の説明を、月刊だけでなく月刊・年間の両方を示す文言へ更新した。

### 変更意図
年間通知からの一度きりの入口だけでなく、あとから前年の振り返りを何度でも開ける常設導線を用意し、月刊と年間のPremium体験を揃えるため。

### 主な変更ファイル
- `favorecoAPP/favorecoAPP/Views/MainTabView.swift`
- `favoreco/CLAUDE.md`
- `docs/project-log.md`

### 確認結果
- 前年開始日の算出に年間通知と同じロジックを使用することをコード確認した。
- SwiftDataモデルとCloudKitスキーマの変更なし。

### 残課題
- 実機で自動提案カードから前年へ遷移することを確認する。

## 2026-07-12: 統計に記録推移とジャンル構成グラフを追加

### 変更概要
- Swift Chartsを使い、直近12か月の記録数を折れ線と面で表示する推移グラフを追加した。
- ジャンル別記録を上位5件と「その他」へ集約し、ドーナツグラフと件数凡例を追加した。
- グラフはライト買い切り以上へ接続し、無料では数値をぼかさず機能説明を表示する。
- 記録0件では専用の空状態を表示し、0件の月も12か月軸から除外しないようにした。
- グラフ集計ではPhotoBlobの画像データを読まず、Visitの日付とジャンルだけを使う。

### 変更意図
基本件数の羅列だけでなく、記録が増えた時に活動の波とジャンル横断の偏りを一目で見返せるようにし、ライト以上の詳細統計へ具体的な価値を持たせるため。

### 主な変更ファイル
- `favorecoAPP/favorecoAPP/Views/MainTabView.swift`
- `favoreco/CLAUDE.md`
- `docs/project-log.md`

### 確認結果
- iPhone向け署名なし全体ビルド成功。
- 無料、ライト以上で0件、ライト以上で記録ありの3分岐をコード確認した。
- 直近12か月は常に12点、ジャンルは最大6区分になることを確認した。
- SwiftDataモデル、写真保存、CloudKitスキーマの変更なし。

### 残課題
- 実機でDynamic Type、ダークモード、ジャンル名が長い場合の凡例を確認する。
- 外部データを組み合わせたPremium高度レポートはV2候補。

## 2026-07-12: 年間Favorecoの自動提案通知を接続

### 変更概要
- 同期プラン以上の思い出レポート通知に、毎年1月1日10時の年間Favoreco通知を追加した。
- 月刊は毎月1日9時、年間は毎年1月1日10時とし、1月1日に2件が同時配信されないようにした。
- 年間通知をタップすると統計タブへ移動し、前年を選択した年間Favorecoを直接開くようにした。
- 月刊/年間の通知遷移フラグを分離し、両方が残った場合も片方を失わないようにした。
- 自動バックアップとStoreKitが未接続と残っていた正本記述を、現在の実装状態へ更新した。

### 変更意図
月刊だけで止まっていたPremiumの自動思い出提案を年間までつなぎ、毎年の振り返りを利用者の明示操作なしで発見できるようにするため。画像は通知時に生成せず、通知先画面を開いた時に端末内データを集計する既存方針を維持する。

### 主な変更ファイル
- `favorecoAPP/favorecoAPP/Services/MonthlyReportNotificationScheduler.swift`
- `favorecoAPP/favorecoAPP/AppDelegate.swift`
- `favorecoAPP/favorecoAPP/Utilities/AppStorageKeys.swift`
- `favorecoAPP/favorecoAPP/Views/MainTabView.swift`
- `favorecoAPP/favorecoAPP/Views/SettingsView.swift`
- `favoreco/CLAUDE.md`
- `docs/project-log.md`

### 確認結果
- iPhone向け署名なし全体ビルド成功。
- 月刊/年間で通知IDと遷移先を分離し、予約更新/解除では両方を処理することをコード確認した。
- 同期プラン権利がない場合は通知予約も通知先レポート遷移も実行しないことを確認した。
- SwiftDataモデルとCloudKitスキーマの変更なし。

### 残課題
- 実機で通知許可ON、同期プラン権利ありの状態における予約件数と通知タップ遷移を確認する。
- 高度グラフと外部データ補助を含むPremium高度レポートは後続候補。

## 2026-07-11: OCR取込設定を入力画面へ接続

### 変更概要
- 記録・入力補助のOCR取込ON/OFFを全記録フォームのOCRユニットへ反映した。
- OFF時はPhotosPickerとVision文字認識を停止し、設定OFFの状態を表示する。
- 保存済みOCRテキストと手入力TextEditorはOFF時も残し、設定変更でデータを失わないようにした。
- 認識開始時にも設定値を再確認し、切替直後の不要な解析を防ぐ。
- 基本OCRは無料、高度な項目自動振り分けはPro候補であることを設定画面に明記した。

### 変更意図
表示だけだったOCR設定を実挙動へ反映しつつ、OFF操作で既存記録が消える誤解やデータ損失を防ぐため。

### 主な変更ファイル
- `favorecoAPP/favorecoAPP/Views/AddExperienceView.swift`
- `favorecoAPP/favorecoAPP/Views/SettingsView.swift`
- `favoreco/CLAUDE.md`
- `docs/project-log.md`

### 確認結果
- OCRUnitEditorがAppStorageを直接参照するため、新規記録/編集/回追加の全導線へ反映されることを確認した。
- OFF時もTextEditorとocrText bindingを維持し、PhotosPicker/Vision解析だけを停止することをコード確認した。
- `swiftc -frontend -parse` で変更したSwiftファイルの構文チェック成功。
- iOS向け署名なし全体ビルド成功、警告なし。

### 残課題
- 実機で設定切替後のフォーム更新、画像選択、OCR結果追記を確認する。
- タイトル/日時/会場/金額への候補振り分けは高度OCRとして後続。

## 2026-07-11: 写真圧縮設定を実保存へ接続

### 変更概要
- 記録・入力補助の写真圧縮85%/65%を、写真追加時のJPEG再エンコードへ反映した。
- 新規記録、記録編集、既存対象への回追加の全導線で同じAppStorage値を使う。
- 保存済み異常値に備え、実処理では50〜95%へクランプする。
- 設定文言を画質優先/容量優先へ明確化し、長辺1600px縮小とメタデータ非継承を説明した。

### 変更意図
表示だけだった圧縮設定を実際の容量/画質へ反映し、Mystoriumと同じく利用者が保存方針を選べるようにするため。

### 主な変更ファイル
- `favorecoAPP/favorecoAPP/Views/AddExperienceView.swift`
- `favorecoAPP/favorecoAPP/Views/SettingsView.swift`
- `favoreco/CLAUDE.md`
- `docs/project-log.md`

### 確認結果
- PhotoUnitEditorで設定値を一元的に読むため、新規記録/編集/回追加の全導線へ反映されることをコード確認した。
- 0.5〜0.95のクランプ、長辺1600px再描画、圧縮後DataからのbyteCount保存を確認した。
- `swiftc -frontend -parse` で変更したSwiftファイルの構文チェック成功。
- iOS向け署名なし全体ビルド成功、警告なし。

### 残課題
- 実機で同一写真を85%/65%保存し、見た目とbyteCount差を確認する。
- 画像処理のバックグラウンド化は大量写真の性能確認後に対応する。

## 2026-07-11: 月刊・年間Favorecoの期間切替を実装

### 変更概要
- レポート画面へ全Visitを渡し、選択中の月/年で画面内集計する構造へ変更した。
- 月刊は前月/翌月、年間は前年/翌年へ矢印で移動できるようにした。
- 現在の月/年では未来方向のボタンを無効にした。
- 期間変更時は金額を再び隠し、生成済み共有画像を破棄する。
- 画面、共有テキスト、カード画像の期間と集計内容を同じ選択期間へ統一した。

### 変更意図
今月/今年だけでなく過去の体験を月刊・年間単位で遡り、同じ形式の思い出カードとして見返せるようにするため。

### 主な変更ファイル
- `favorecoAPP/favorecoAPP/Views/MainTabView.swift`
- `favoreco/CLAUDE.md`
- `docs/project-log.md`

### 確認結果
- Calendarの月/年加算とgranularity比較を使い、12月/1月をまたぐ移動、現在期間での未来移動無効、過去空期間の年月表示をコード確認した。
- 画面集計、カードプレビュー、画像スナップショット、共有文がすべて選択期間を参照することを確認した。
- `swiftc -frontend -parse` で変更したSwiftファイルの構文チェック成功。
- iOS向け署名なし全体ビルド成功、警告なし。

### 残課題
- 実機で期間移動アニメーション、空期間、期間変更後の画像/テキスト共有を確認する。
- 任意期間・去年同月比較・予定/申込統計は後続。

## 2026-07-11: 記録ごとのカバー写真指定を実装

### 変更概要
- 写真ユニットの各サムネイルに星ボタンを追加し、カバー写真を選択できるようにした。
- 新規写真の先頭を自動選択し、選択中写真を削除した場合は残りの先頭へ自動移行する。
- `Visit.eyecatchPath` にカバー写真のrelativePathを保存し、新規対象では代表パスにも反映する。
- 編集時は保存済み/追加予定写真をまたいでカバーを変更できる。
- 詳細画面ではカバー写真を先頭表示し、複数写真時はカバーバッジを表示する。

### 変更意図
複数写真の登録順に依存せず、Home・一覧・詳細で利用者が見せたい写真を一貫して使えるようにするため。

### 主な変更ファイル
- `favorecoAPP/favorecoAPP/Views/AddExperienceView.swift`
- `favorecoAPP/favorecoAPP/Views/ExperienceDetailView.swift`
- `favoreco/CLAUDE.md`
- `docs/project-log.md`

### 確認結果
- 新規対象/既存対象への回追加/記録編集で、追加時自動選択、星切替、削除時フォールバック、保存パスをコード確認した。
- 詳細、Homeギャラリー、一覧がカバー写真を優先し、旧データやパス不一致時は作成日の古い写真へフォールバックすることを確認した。
- `swiftc -frontend -parse` で変更したSwiftファイルの構文チェック成功。
- iOS向け署名なし全体ビルド成功、警告なし。

### 残課題
- 実機で追加、切替、カバー削除、編集キャンセル、Home/一覧/詳細、再起動後の保持を確認する。

## 2026-07-11: ThumbnailLoaderのSwift 6隔離警告を解消

### 変更概要
- スレッドセーフなNSCache共有値を `nonisolated(unsafe)` で明示した。
- purge / cached / makeThumbnailを `nonisolated` にし、Task.detachedからMainActor越境なしで呼べるようにした。
- SwiftDataモデルはメイン側でDataへ切り出してから渡す既存境界を維持した。

### 変更意図
バックグラウンドサムネイル生成がMainActor扱いになる警告を解消し、Swift 6言語モードでエラー化するのを防ぐため。

### 主な変更ファイル
- `favorecoAPP/favorecoAPP/Utilities/ThumbnailLoader.swift`
- `docs/project-log.md`

### 確認結果
- `swiftc -frontend -parse` で変更したSwiftファイルの構文チェック成功。
- iOS向け署名なし全体ビルドが警告ゼロで成功し、HomeView / VisitSummaryRowに出ていたMainActor隔離警告2件の解消を確認した。

### 残課題
- 実機で一覧/Homeのサムネイル表示、スクロール、メモリ警告後の再生成を確認する。

## 2026-07-11: 月刊・年間Favorecoの画像カード共有を実装

### 変更概要
- 月刊/年間レポートの集計値から360×450ptの縦長カードを生成するViewを追加した。
- ImageRendererで3倍解像度のUIImageを端末内生成し、iOS共有シートへ渡すようにした。
- 共有シートから画像保存、SNS、メッセージ等へ共有できる。
- カードには記録/写真/ジャンル/平均評価、ハイライト、最多ジャンル、最多場所、上位ジャンルを表示する。
- プライバシー配慮として金額は画像と共有文に含めない。
- 従来のテキスト共有とクリップボードコピーも残した。

### 変更意図
自動レポートやPremium同期より先に、ローカル集計だけで「残して共有したくなる」手動レポートの価値を確認できるようにするため。

### 主な変更ファイル
- `favorecoAPP/favorecoAPP/Views/MainTabView.swift`
- `favoreco/CLAUDE.md`
- `docs/project-log.md`

### 確認結果
- 空データでは画像共有を表示しない既存分岐、少数/複数ジャンル、長いハイライトの2行制限と縮小率をコード確認した。
- `swiftc -frontend -parse` で変更したSwiftファイルの構文チェック成功。
- iOS向け署名なし全体ビルド成功。既存の `ThumbnailLoader` MainActor警告が2件あるが、今回変更によるエラーはなし。

### 残課題
- 実機で共有シート、画像保存、SNS共有、文字切れを確認する。
- 期間切替、写真を使ったテンプレ、自動生成/通知、去年同月比較は後続。

## 2026-07-11: 二段階確認つき全データ削除を実装

### 変更概要
- 全データ削除の専用画面を追加し、対象件数と削除/保持範囲を表示した。
- `削除する` の確認文言入力後、最終確認ダイアログを経ないと実行できないようにした。
- 全SwiftDataモデル、関連通知、Web/写真キャッシュを削除する処理を追加した。
- 親モデルのcascadeを使い、親を持たない孤立モデルだけ個別削除する順序にした。
- 全モデル削除と標準ジャンル再生成を同じSwiftData保存に含め、ジャンル0件の状態を保存しない。
- 保存成功後に初回ジャンル選択へ戻す。
- Home表示や入力補助などの設定値は利用者の好みとして保持する。

### 変更意図
不可逆な全削除を誤操作しにくくし、削除直後もジャンル0件で起動不能にならない初期化経路を作るため。

### 主な変更ファイル
- `favorecoAPP/favorecoAPP/Services/RecordDeletionService.swift`
- `favorecoAPP/favorecoAPP/Views/SettingsView.swift`
- `favoreco/CLAUDE.md`
- `docs/project-log.md`

### 確認結果
- 全モデルの取得、通知取消、親cascade、孤立モデル削除、標準ジャンル同時再生成、保存後の初回選択復帰をコード確認した。
- `swiftc -frontend -parse` で変更したSwiftファイルの構文チェック成功。
- iOS向け署名なし全体ビルド成功。既存の `ThumbnailLoader` MainActor警告が2件あるが、今回変更によるエラーはなし。

### 残課題
- 実機で通知取消、削除後の画面切替、標準ジャンル再生成、通常起動を確認する。
- 写真externalStorageが削除後に端末容量へ反映されるタイミングを実機で確認する。

## 2026-07-11: キャッシュ削除とアーカイブ完全削除を実装

### 変更概要
- データ管理にWebキャッシュと写真サムネイルキャッシュの削除を追加した。
- キャッシュ削除では記録と写真本体を変更しないことを画面に明記した。
- 非表示済みの対象、予定、申込、登録情報、SNS、人物、場所を確認後に完全削除できるようにした。
- 非表示対象の配下にある記録/写真/予定/申込も関係に従って削除し、関連する通知を取り消す。
- 非表示ジャンルは記録分類/表示設定として保持し、アーカイブ完全削除の対象外にした。
- 全データ削除は専用の二段階確認画面を次段階で実装する入口に留めた。

### 変更意図
容量整理と不要データ削除を提供しつつ、キャッシュと原本の混同、非表示ジャンルの消失、通知の残存を防ぐため。

### 主な変更ファイル
- `favorecoAPP/favorecoAPP/Services/RecordDeletionService.swift`
- `favorecoAPP/favorecoAPP/Views/SettingsView.swift`
- `favoreco/CLAUDE.md`
- `docs/project-log.md`

### 確認結果
- アーカイブ親のcascade対象を明示的に二重削除しない順序、人物リンク削除、通知取消をコード確認した。
- `swiftc -frontend -parse` で変更したSwiftファイルの構文チェック成功。
- iOS向け署名なし全体ビルド成功。既存の `ThumbnailLoader` MainActor警告が2件あるが、今回変更によるエラーはなし。

### 残課題
- 実機でキャッシュ削除後の写真再表示、アーカイブ対象と通常データの分離、通知取消を確認する。
- 全データ削除を確認文言入力と二段階確認つきで実装する。

## 2026-07-11: CSVインポートの安全な実保存を接続

### 変更概要
- 検証済みCSVの正常行だけをExperienceEvent / Visitとして保存する処理を追加した。
- 空ジャンルはユーザーが選んだ既定ジャンルを使い、CSV内のジャンル名は既存の有効ジャンルだけに照合する。
- 未登録ジャンルを勝手に作らず、未知ジャンル行としてスキップする。
- `visit_id` が既存なら更新し、IDなしで日付/タイトル/会場が一致する行は重複としてスキップする。
- rating / amount / UUID形式も保存前検証へ追加した。
- 追加、更新、対象追加、重複、不正行、未知ジャンルの結果件数を表示する。
- 保存失敗時はSwiftDataの未保存変更をロールバックする。

### 変更意図
表計算や他アプリから記録を戻せる無料の導線を完成させつつ、誤記によるジャンル乱立と重複登録を防ぐため。

### 主な変更ファイル
- `favorecoAPP/favorecoAPP/Services/CSVImportService.swift`
- `favorecoAPP/favorecoAPP/Views/CSVImportView.swift`
- `favoreco/CLAUDE.md`
- `docs/project-log.md`

### 確認結果
- 日付、UUID、rating、amountの検証分岐と、UUID更新/重複スキップ/未知ジャンルスキップをコード確認した。
- `swiftc -frontend -parse` で変更したSwiftファイルの構文チェック成功。
- iOS向け署名なし全体ビルド成功。既存の `ThumbnailLoader` MainActor警告が2件あるが、今回変更によるエラーはなし。

### 残課題
- 実機でエクスポートCSVの往復、既存UUID更新、未知ジャンル、重複スキップ、再起動後の保持を確認する。
- 大量CSVのバックグラウンド解析とバッチ保存は性能確認後に対応する。

## 2026-07-11: CSVインポートの事前検証・プレビューを実装

### 変更概要
- UTF-8 CSVをFilesから選択し、保存前に解析する画面を追加した。
- 必須列 `date` / `title`、YYYY-MM-DDの日付、空タイトル、余剰列を行単位で検証する。
- 正常行/要修正行の件数と先頭20件を表示し、この段階ではSwiftDataを変更しない。
- 引用符、エスケープされた引用符、セル内カンマ/改行、CRLF、BOM付きヘッダーに対応した。
- 設定 > データ管理のCSVインポートを準備中ページから実画面へ接続した。

### 変更意図
外部CSVをいきなり保存せず、列不足や日付不正を利用者が確認できる安全な入口を先に完成させるため。

### 主な変更ファイル
- `favorecoAPP/favorecoAPP/Services/CSVImportService.swift`
- `favorecoAPP/favorecoAPP/Views/CSVImportView.swift`
- `favorecoAPP/favorecoAPP/Views/SettingsView.swift`
- `favoreco/CLAUDE.md`
- `docs/project-log.md`

### 確認結果
- BOM、CRLF、引用符、セル内カンマ/改行、不正日付、空タイトルを含む単体入力で、正常2件/要修正1件に分かれることを確認した。
- `swiftc -frontend -parse` で変更したSwiftファイルの構文チェック成功。
- iOS向け署名なし全体ビルド成功。既存の `ThumbnailLoader` MainActor警告が2件あるが、今回変更によるエラーはなし。

### 残課題
- ジャンル名の照合/作成方針、UUIDまたは内容による重複判定、正常行だけの保存を次段階で接続する。
- 実機でFiles選択、BOM/CRLF、引用符付き複数行、要修正表示を確認する。

## 2026-07-11: JSONバックアップのUUIDマージ復元を実装

### 変更概要
- 検証済みJSONを既存SwiftDataへUUID基準で追加・更新する復元処理を実装した。
- ジャンル、対象、記録、Inbox、SNS、人物、人物リンク、場所、予定、登録情報、チケット申込を復元対象にした。
- カテゴリ/対象/記録/人物/場所/予定/名義の関係をIDから再構築した。
- 写真バイナリがないメタデータは空画像を作らずスキップした。
- Keychain参照、外部カレンダーID、通知予約IDは端末固有のためクリアした。
- 実行前確認と、追加/更新/写真スキップ/端末固有参照解除の結果サマリーを追加した。
- 復元後も最低1ジャンルが有効になる補正を実行する。
- 最低1ジャンル補正を復元モデルと同じ保存に含め、処理失敗時は画面側でSwiftDataの未保存変更をロールバックする。

### 変更意図
既存データを一括削除せず、手動JSONバックアップから記録本体と関係を安全に戻せる最低限の復元経路を完成させるため。

### 主な変更ファイル
- `favorecoAPP/favorecoAPP/Services/JSONBackupImportService.swift`
- `favorecoAPP/favorecoAPP/Views/JSONImportView.swift`
- `favoreco/CLAUDE.md`
- `docs/project-log.md`

### 確認結果
- 新規追加、同一UUID更新、関係再構築、写真スキップ、端末固有参照解除、最低1ジャンル補正をコード確認。
- `swiftc -frontend -parse` で変更したSwiftファイルの構文チェック成功。
- iOS向け署名なしビルドは、CoreSimulatorService停止によりAsset Catalog処理で失敗。環境復旧後に全体ビルドが必要。

### 残課題
- 実機で「書き出し→データ変更→復元→再起動」の往復確認を行う。
- SwiftData保存後に端末が異常終了するケースを含む厳密なトランザクション検証、旧schema移行、写真付き完全バックアップは次段階。

## 2026-07-11: JSONインポートのファイル検証・内容プレビューを実装

### 変更概要
- データ管理のJSONインポート入口をプレースホルダーから実画面へ置き換えた。
- FilesからJSONを選択し、Favoreco用ファイルか、schemaVersionが対応範囲かを検証するようにした。
- 書き出し日時、総モデル数、ジャンル/対象/記録/人物/場所/予定/チケット等の件数を復元前に表示する。
- 壊れたJSON、別アプリ用JSON、新しい未対応schemaは具体的なエラーで拒否する。
- 写真メタデータ件数と、写真/動画本体がJSONに含まれず復元できない制約を明示した。

### 変更意図
復元処理へ渡す前にファイルの正当性と内容をユーザーが確認できる安全な入口を作り、既存データを壊すリスクを下げるため。

### 主な変更ファイル
- `favorecoAPP/favorecoAPP/Services/JSONBackupImportService.swift`（新規）
- `favorecoAPP/favorecoAPP/Views/JSONImportView.swift`（新規）
- `favorecoAPP/favorecoAPP/Views/SettingsView.swift`
- `favoreco/CLAUDE.md`
- `docs/project-log.md`

### 確認結果
- 正常schema、壊れたJSON、別appName、schema 0、未来schema、写真0件/複数件の分岐をコード確認。
- `swiftc -frontend -parse` で変更したSwiftファイルの構文チェック成功。
- iOS向け署名なしビルドは、CoreSimulatorService停止によりAsset Catalog処理で失敗。環境復旧後に全体ビルドが必要。

### 残課題
- UUID基準の追加/更新、関係再構築、結果サマリーを次段階で接続する。
- 実機でFiles選択、セキュリティスコープ、件数表示を確認する。

## 2026-07-11: 予定・チケット保存前の日付順検証を追加

### 変更概要
- 予定終了が開始より前、開場が開始より後の場合に保存を止めるようにした。
- 申込開始/締切、申込締切/当落発表、当落発表/入金締切の順序が逆の場合に保存を止めるようにした。
- 予定作成/編集と申込単体作成/編集の両方で、具体的な修正文をアラート表示する。
- 発券開始と入金締切は販売方式による例外を考慮し、順序を強制しない。

### 変更意図
実機テスト前に明確な日付逆転を入力時点で防ぎ、次アクション・通知の不自然な挙動を減らすため。

### 主な変更ファイル
- `favorecoAPP/favorecoAPP/Views/AddTicketPlanView.swift`
- `favorecoAPP/favorecoAPP/Views/EditTicketAttemptView.swift`
- `favoreco/CLAUDE.md`
- `docs/project-log.md`

### 確認結果
- 各日付ペアの正常順、同時刻、逆転、トグルOFFの分岐をコード確認。
- `swiftc -frontend -parse` で変更したSwiftファイルの構文チェック成功。
- iOS向け署名なしビルドは、CoreSimulatorService停止によりAsset Catalog処理で失敗。環境復旧後に全体ビルドが必要。

### 残課題
- 実機でアラート文、修正後の保存、通知予約日を確認する。

## 2026-07-11: チケット状態に応じた必要日付の入力漏れ検知を追加

### 変更概要
- 抽選応募予定/発売待ち/当落待ち/入金待ち/発券待ちで、状態に必要な日付が未設定の場合に入力確認を表示するようにした。
- 入力漏れ申込をチケット一覧の「要対応」と件数へ含めた。
- Calendar予定行、予定詳細の申込カード、チケット一覧で確認文を表示した。
- 検索語にも入力確認文を含め、一覧では日付付きアクションがない場合に入力漏れを優先して並べる。

### 変更意図
実機テスト前にデータ不足を見つけやすくし、通知されない原因を実装不具合と取り違えないようにするため。

### 主な変更ファイル
- `favorecoAPP/favorecoAPP/Utilities/TicketDefinitions.swift`
- `favorecoAPP/favorecoAPP/Views/MainTabView.swift`
- `favorecoAPP/favorecoAPP/Views/PlanDetailView.swift`
- `favorecoAPP/favorecoAPP/Views/TicketOverviewView.swift`
- `favoreco/CLAUDE.md`
- `docs/project-log.md`

### 確認結果
- 状態別の必要日付、未設定日付、終端状態、要対応件数の分岐をコード確認。
- `swiftc -frontend -parse` で変更したSwiftファイルの構文チェック成功。
- iOS向け署名なしビルドは、CoreSimulatorService停止によりAsset Catalog処理で失敗。環境復旧後に全体ビルドが必要。

### 残課題
- 実機で入力確認表示、編集後の解消、通知予約への反映を確認する。

## 2026-07-11: 個別に非表示にした申込の復元を追加

### 変更概要
- チケット一覧のフィルターに「非表示」を追加した。
- 予定本体は有効で、個別申込だけ非表示にした項目を一覧・検索できるようにした。
- 長押しまたはスワイプから申込を再表示できるようにした。
- 再表示後、終端状態以外は現在有効な通知を再予約する。
- 予定ごと非表示になっている申込は、申込だけ戻して不整合にならないよう復元対象外とした。

### 変更意図
誤操作や一時整理で非表示にした個別申込を、安全に戻せる退避場所を用意するため。

### 主な変更ファイル
- `favorecoAPP/favorecoAPP/Services/TicketAttemptStatusUpdater.swift`
- `favorecoAPP/favorecoAPP/Views/TicketOverviewView.swift`
- `favoreco/CLAUDE.md`
- `docs/project-log.md`

### 確認結果
- 個別アーカイブのみ抽出、予定アーカイブ除外、復元保存、通知再予約条件をコード確認。
- `swiftc -frontend -parse` で変更したSwiftファイルの構文チェック成功。
- iOS向け署名なしビルドは、CoreSimulatorService停止によりAsset Catalog処理で失敗。環境復旧後に全体ビルドが必要。

### 残課題
- 実機で非表示フィルター、検索、再表示後の件数・通知更新を確認する。

## 2026-07-11: チケット一覧に申込編集・非表示スワイプを追加

### 変更概要
- チケット一覧の左スワイプから申込編集を直接開けるようにした。
- 右スワイプから確認後、対象申込だけをアーカイブできるようにした。予定本体と他の申込は残す。
- アーカイブ処理を共通サービスへ移し、申込編集画面と一覧で同じ保存・通知取消処理を使うようにした。
- 一覧で保存失敗した場合は既存のエラーアラートへ表示する。

### 変更意図
複数先行・複数名義を管理する際、予定詳細へ移動せず個別申込を編集・整理できるようにするため。

### 主な変更ファイル
- `favorecoAPP/favorecoAPP/Services/TicketAttemptStatusUpdater.swift`
- `favorecoAPP/favorecoAPP/Views/EditTicketAttemptView.swift`
- `favorecoAPP/favorecoAPP/Views/TicketOverviewView.swift`
- `favoreco/CLAUDE.md`
- `docs/project-log.md`

### 確認結果
- 対象申込のみのアーカイブ、予定/他申込の保持、通知取消、編集シート導線をコード確認。
- `swiftc -frontend -parse` で変更したSwiftファイルの構文チェック成功。
- iOS向け署名なしビルドは、CoreSimulatorService停止によりAsset Catalog処理で失敗。環境復旧後に全体ビルドが必要。

### 残課題
- 実機で左右スワイプ、確認ダイアログ、編集保存、非表示後の件数更新を確認する。

## 2026-07-11: チケット一覧に横断検索・直接追加を追加

### 変更概要
- チケット一覧に検索欄を追加し、予定名、会場、主催、プレイガイド、名義/登録アカウント、状態、入手経路、メモから検索できるようにした。
- 検索結果に対して既存フィルターを適用し、上部の申込/要対応/取得済み件数も検索結果に連動させた。
- 検索中の0件は専用の検索結果なし表示にした。
- チケット一覧右上の＋から `AddTicketPlanView` を直接開けるようにした。

### 変更意図
申込件数が増えても目的の予定・名義・プレイガイドを見つけられ、一覧内で追加から状態管理まで完結できるようにするため。

### 主な変更ファイル
- `favorecoAPP/favorecoAPP/Views/TicketOverviewView.swift`
- `favoreco/CLAUDE.md`
- `docs/project-log.md`

### 確認結果
- 空検索、部分一致、状態名/入手経路検索、検索0件、検索後フィルターの条件をコード確認。
- `swiftc -frontend -parse` で変更したSwiftファイルの構文チェック成功。
- iOS向け署名なしビルドは、CoreSimulatorService停止によりAsset Catalog処理で失敗。環境復旧後に全体ビルドが必要。

### 残課題
- 実機で日本語検索、キーボード表示、追加シート保存後の一覧反映を確認する。

## 2026-07-11: 状態未更新の期限超過チケットを要対応に保持

### 変更概要
- 未来日の次アクションがなくなった後も、状態に応じた未処理アクションを要対応として表示するようにした。
- 申込前は申込締切超過、発売前は発売開始済み、当落待ちは当落確認、当選/入金待ちは入金期限超過、発券待ちは発券可能を表示する。
- 期限超過/確認待ちはCalendar、予定詳細、チケット一覧で赤く表示する。

### 変更意図
期限を過ぎた直後に一覧から消えると、状態更新や入金・発券確認を忘れるため。状態が次へ進むまで要対応として残す。

### 主な変更ファイル
- `favorecoAPP/favorecoAPP/Utilities/TicketDefinitions.swift`
- `favorecoAPP/favorecoAPP/Views/MainTabView.swift`
- `favorecoAPP/favorecoAPP/Views/PlanDetailView.swift`
- `favorecoAPP/favorecoAPP/Views/TicketOverviewView.swift`
- `favoreco/CLAUDE.md`
- `docs/project-log.md`

### 確認結果
- 未来日、期限超過、日付未設定、終端状態の分岐をコード確認。
- `swiftc -frontend -parse` で変更したSwiftファイルの構文チェック成功。
- iOS向け署名なしビルドは、CoreSimulatorService停止によりAsset Catalog処理で失敗。環境復旧後に全体ビルドが必要。

### 残課題
- 実機で赤い要確認表示と、長押し状態更新後に要対応から外れることを確認する。

## 2026-07-11: チケット一覧からのクイック状態更新を追加

### 変更概要
- チケット一覧の行を長押しし、現在状態に応じた次の状態へ直接更新できるようにした。
- 状態更新処理を `TicketAttemptStatusUpdater` へ集約し、予定詳細とチケット一覧で共用した。
- 落選・見送り・参加済みでは通知を取消し、それ以外では保存後に通知を再予約する既存挙動を維持した。
- 一覧側で保存失敗時のアラートを追加した。

### 変更意図
チケット一覧を確認だけでなく日常の状態管理にも使えるようにし、複数画面で通知処理が食い違うことを防ぐため。

### 主な変更ファイル
- `favorecoAPP/favorecoAPP/Services/TicketAttemptStatusUpdater.swift`（新規）
- `favorecoAPP/favorecoAPP/Views/PlanDetailView.swift`
- `favorecoAPP/favorecoAPP/Views/TicketOverviewView.swift`
- `favoreco/CLAUDE.md`
- `docs/project-log.md`

### 確認結果
- 共通処理の状態更新、保存、通知取消/再予約条件をコード確認。
- `swiftc -frontend -parse` で変更したSwiftファイルの構文チェック成功。
- iOS向け署名なしビルドは、CoreSimulatorService停止によりAsset Catalog処理で失敗。環境復旧後に全体ビルドが必要。

### 残課題
- 実機で長押しメニュー、一覧フィルターからの即時移動、通知予約の変化を確認する。

## 2026-07-11: チケット横断一覧・要対応フィルターを追加

### 変更概要
- Calendar右上にチケット一覧への入口を追加した。
- 全TicketAttemptを `すべて / 要対応 / 検討・申込 / 取得済み / 終了` で絞り込める一覧を追加した。
- 申込総数、要対応数、取得済み数を上部に表示し、各行に予定名、日時、状態、プレイガイド/入手経路、次のアクションを表示する。
- 行から既存の予定詳細へ遷移し、編集・申込追加・長押し状態変更など既存フローを再利用する。

### 変更意図
Homeアテンションは重要度順の最大5件に限定されるため、申込が増えた時にも全件と要対応を見失わないチケット管理の正規導線を用意するため。

### 主な変更ファイル
- `favorecoAPP/favorecoAPP/Views/TicketOverviewView.swift`（新規）
- `favorecoAPP/favorecoAPP/Views/MainTabView.swift`
- `favoreco/CLAUDE.md`
- `docs/project-log.md`

### 確認結果
- 空データ、要対応0件、複数申込、終了済み申込、Plan参照なしの各ケースで表示条件をコード確認。
- `swiftc -frontend -parse` で新規画面のSwift構文チェック成功。
- iOS向け署名なしビルドは、CoreSimulatorService停止によりAsset Catalog処理で失敗。環境復旧後に全体ビルドが必要。

### 残課題
- 実機でフィルター切替、Calendarからの遷移、長い予定名/プレイガイド名の表示を確認する。

## 2026-07-11: 進捗文書監査・Home固定順を正本へ再整合

### 変更概要
- 外部作業で作成された進捗文書を、実装仕様正本・現行コード・作業ログと照合した。
- Homeの並びが正本の固定順から変更されていたため、`アテンション → 体験ギャラリー → あとで記録 → 最近の記録 → ジャンル一覧 → 統計サマリ → お気に入り/ベスト` に戻した。
- 空セクション非表示、単一Empty State、`LazyHStack`、非同期サムネイル/ダウンサンプリングは仕様と両立するため維持した。
- 現在の優先順位を「チケットv1仕上げ・実機確認項目整理 → JSONインポート/復元」と明記した。
- 月刊/年間Favorecoは下書き・集計・共有テキストまで実装済みであり、写真/動画バイナリはJSONバックアップ対象外であることを正本へ追記した。

### 変更意図
直近改善の有効部分を残しつつ、ユーザーと合意済みのHome情報順序と実装優先順位を正本へ戻すため。

### 主な変更ファイル
- `favorecoAPP/favorecoAPP/Views/HomeView.swift`
- `favoreco/CLAUDE.md`
- `docs/project-log.md`

### 確認結果
- Homeの各表示トグル条件と空データ条件を維持したまま、表示順だけが正本と一致することをコードで確認。
- iOS向け署名なしビルドを実行したが、CoreSimulatorServiceが利用できずAsset Catalog処理で停止した。今回の変更箇所に起因するSwiftコンパイルエラーは検出されていないが、環境復旧後に再ビルドが必要。

### 残課題
- Homeの固定順と空セクション非表示を実機で確認する。
- チケットv1仕上げ後、JSONインポート/復元へ進む。

## 2026-07-10: サムネイル実装の堅牢化（レビュー8観点対応）

### 対応内容
- **task(id:)に写真ID＋表示サイズを含める**：`.task(id: thumbnailTaskID)`（`"<photoID>@<pixel>"`）に変更。サイズ変更でも再取得され、サイズ違いは別キャッシュ。
- **遅延到着の上書き防止（セル再利用対策）**：`Task.detached` 完了後に `guard !Task.isCancelled, firstPhoto?.id == targetID`。別写真に切り替わった後に古い結果が届いても上書きしない。
- **メモリ警告でキャッシュ破棄**：`UIApplication.didReceiveMemoryWarningNotification` を購読し `cache.removeAllObjects()`（NSCache自動退避に加え明示）。`purge()` も追加。
- **最大ピクセルのクランプ**：ギャラリー `min(200×scale, 1200)`／行 `min(80×scale, 480)`。scale過剰を防止（保存上限1600px以下）。

### レビュー観点の評価（元から満たしていた点）
- **スレッド安全**：NSCache はスレッドセーフ（set/object/remove を内部同期）。static let 初期化も一度きり。actor不要。
- **NSCache競合**：並行 set/object でも安全。
- **失敗時プレースホルダー**：生成失敗＝nil → `if let thumbnailImage` が偽 → プレースホルダー表示。
- **EXIF向き**：`kCGImageSourceCreateThumbnailWithTransform: true` で回転を反映済み（`UIImage(cgImage:)` は .up で正しい）。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Utilities/ThumbnailLoader.swift（メモリ警告purge・コメント）
- favorecoAPP/favorecoAPP/Views/HomeView.swift（task id・遅延ガード・クランプ）
- favorecoAPP/favorecoAPP/Views/VisitSummaryRow.swift（同上）

### 確認結果（実機 / ビルド）
コード整合確認。**xcodebuild／実機（縦横向き写真・高速スクロールでの取り違え・メモリ警告時）はMac側で要確認**。

## 2026-07-10: Homeスクロールのカクつき対策（画像を非同期ダウンサンプル化）

### 原因（静的解析）
- `ExperienceGalleryCard`（体験ギャラリー）と `VisitSummaryRow`（最近の記録）が、`firstPhotoImage` 計算プロパティ内で **`UIImage(data:)` をbody評価のたびに同期・フル解像度デコード**していた。写真は最大1600pxで保存されるのに、190px幅カード・64px行サムネに使うため、メインスレッドで毎回フルデコード＝横/縦スクロールで確実にフレーム落ち。

### 対策（Homeの表示のみ・情報/モデル/通知/JSON不変）
- **`ThumbnailLoader.swift`（新規）**：ImageIO の `CGImageSourceCreateThumbnailAtIndex`＋`kCGImageSourceThumbnailMaxPixelSize` で**必要サイズだけデコード（ダウンサンプル）**。`NSCache`（スレッドセーフ）で再利用。
- 両コンポーネントを**非同期ロードに変更**：`@State thumbnailImage` ＋ `.task(id: firstPhoto?.id)` で、`Data`（値型）だけを `Task.detached` に渡してメインスレッド外で生成→完了後に反映。SwiftData プロパティ（`photo.data`）はメインで読み、スレッドを跨がない。
- サムネ目標サイズ：ギャラリー=200pt×displayScale、行=80pt×displayScale。キャッシュキーに写真ID＋サイズを含める。
- スクロール中はプレースホルダー→画像差し込み。キャッシュヒットで再表示は即時。

### 効果
メインスレッドの同期フルデコードを撤去し、可視セル分だけ・縮小サイズで・非同期にデコード。ギャラリー水平スクロール／最近の記録の縦スクロールのカクつきを解消。

### 既知の残改善（今回未対応・任意）
- `ExperienceGalleryCard`/`VisitSummaryRow` は各インスタンスが `@Query personLinks`（全EventPersonLink取得）を持つ。リンクが大量だと軽い負荷。将来、親から渡す等で削減可（今回は画像デコードの主要因のみ対応）。
- `ExperienceDetailView` のヒーロー画像は単一大画像のため今回対象外（一覧スクロールではない）。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Utilities/ThumbnailLoader.swift（新規）
- favorecoAPP/favorecoAPP/Views/HomeView.swift（ExperienceGalleryCard）
- favorecoAPP/favorecoAPP/Views/VisitSummaryRow.swift（最近の記録行）

### 確認結果（実機 / ビルド）
コード整合確認（波括弧・同期デコード撤去・参照）。**xcodebuild／実機の体感（大量＋写真付き記録でのスクロール滑らかさ・Instruments の hitches 確認）はMac側で要確認**。

## 2026-07-10: Home画面の情報優先順位・表示整理（HomeViewのみ）

### 変更概要（情報は増やさず整理。データモデル/通知/JSON/SwiftData構造は不変）
- **セクションを優先順位で並べ替え**：①次の予定・締切（アテンション）→②最近の記録→③体験ギャラリー→④お気に入り・統計→⑤その他（Inbox・カテゴリ）。従来の attention→ギャラリー→Inbox→最近→カテゴリ→統計→お気に入り から再配置。
- **空セクション非表示**：中身が無いセクションは出さない（`showsX && !データ.isEmpty`）。従来は各セクションが空プレースホルダー行を並べていた。
- **全空時の単一プレースホルダー**：記録・予定・締切・Inbox がいずれも無い時だけ `homeEmptyState` を1つ表示（`isHomeContentEmpty`）。7個の空行→1個の導線に集約。
- **heroのオンボ文を条件化**：「まずは体験ジャンルを選んで…」は全空時のみ表示。記録があるユーザーは上部が締まり、次の予定・最近の記録が前に出る（完成条件＝3秒で理解に寄与）。
- **スクロール性能**：体験ギャラリーの水平行を `HStack`→`LazyHStack`（写真デコードを遅延）。件数は既に上限（アテンション5・ギャラリー8・最近5・Inbox3）。
- **表示設定との整合**：7トグル（showsAttention/RecentRecords/ExperienceGallery/Favorites/StatsSummary/Inbox/Categories）は全て条件に維持。
- Home→詳細の導線（PlanDetail/ExperienceDetail/InboxDetail/CategoryTop への NavigationLink）は既存のまま。

### 変更禁止事項の遵守
新機能追加なし・データモデル/通知/JSON変更なし・大規模リファクタなし（表示順・条件・余白・性能のみ）。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/HomeView.swift（のみ）

### 確認結果（実機 / ビルド）
コード整合確認（波括弧・参照シンボル・トグル維持）。**xcodebuild／実機（0件・記録のみ・予定のみ・予定+記録・大量データ・表示ON/OFF・詳細遷移・スクロール）はMac側で要確認**。

### 残課題
- Mac側で各データ量パターンの見栄え・スクロール・詳細遷移を実機確認。

## 2026-07-10: 通常記録に削除機能を追加（ハード削除＋関連整理・方式1）

### 変更概要
監査で欠落していた通常記録の削除を、ユーザー選択の**方式1（ハード削除＋関連整理）**＋追加条件で実装。データモデル定義は変更せず、削除時の後始末のみ追加。
- **`RecordDeletionService.swift`（新規）**：削除ロジックを集約。
  - `deleteVisit`：この記録(Visit)だけ削除。**Eventは残す（0件になっても自動削除しない）**。Plan.visit の該当参照を nil 解除、EventPersonLink の visit 参照を削除、`modelContext.delete(visit)`（PhotoBlobは Visit.photos の `.cascade` で連鎖・CoreModels:593で確認）、`modelContext.save()` を明示。
  - `deleteEvent`：対象(Event)と配下すべてを削除。Event の `.cascade` で Visit/Plan（→PhotoBlob/TicketAttempt）が連鎖。inverse未定義の EventPersonLink（event参照・配下visit参照）を先に削除、外部 Plan.visit 参照を nil 解除、`save()` 明示。
- **ExperienceDetailView**：メニューに **「この記録だけ削除」**（破壊的）＋確認ダイアログ（対象名・他記録は残る旨）。
- **EventDetailView**：メニューに **「この対象とすべての記録を削除」**（破壊的）＋確認ダイアログに**関連記録件数（visits.count）を表示**。
- 両画面とも**削除失敗時は assertionFailure＋`.alert` で画面にエラーメッセージ表示**。成功時は `dismiss()`。一覧(Home/Calendar/Category)は @Query で自動反映。

### 追加条件の充足
Visit/Event削除を明確分離／確認ダイアログ／Visit削除でEvent保持・0件でも自動削除しない／Event削除は件数表示／Plan.visit nil解除／EventPersonLink等を先に解除・削除／PhotoBlob cascadeを実コード確認／save()明示／失敗時に画面エラー表示／大規模リファクタなし。

### 変更しないもの
CoreModels（データモデル定義）・通知・JSON構造は不変（削除の後始末のみ）。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Services/RecordDeletionService.swift（新規）
- favorecoAPP/favorecoAPP/Views/ExperienceDetailView.swift（Visit単体削除）
- favorecoAPP/favorecoAPP/Views/EventDetailView.swift（Event全体削除）

### 確認結果（実機 / ビルド）
コード整合確認（波括弧・import・参照シンボル・cascade根拠）。**xcodebuild／実機（Visit削除でEvent保持・Event削除で件数表示と全消去・Plan.visit解除・再起動保持・一覧反映）はMac側で要確認**。

### 残課題
- Mac側で削除の実機確認（特に：他Visitが残るEventでVisit1件削除→Event残存／Event削除→配下Visit・写真・Plan全消去／削除後の一覧・再起動反映）。

## 2026-07-10: 通常記録ワークフローv1 静的監査（削除機能の欠落を検出・要判断）

### 前提
- 実機なし（Linux）のため、11シナリオ（新規対象→初回記録→Home/Calendar反映→詳細→編集→2回目記録→Event非重複→写真/評価/タグ保持→削除→再起動保持）を**静的トレース＋2観点の並行監査**で確認。

### 監査結果：既存フローは正しい（修正不要）
- **Event/Visit責務分離＝正しい**：Event＝対象情報（title/seriesName/officialURL/category）のみ、Visit＝回情報（日時/評価/座席/金額/メモ/写真/outcome/unitFields）のみ。`AddExperienceView.save`（新規）・`AddVisitView.save`（追記）・`EditExperienceView.save`（編集）いずれも遵守。
- **2回目記録でEventは複製しない（シナリオ8 OK）**：`AddVisitView` は既存 `ExperienceEvent` を受け取り `Visit(event: event)` を1件insertするのみ。新Event生成なし。導線は `CategoryTopView` の行内＋→`selectedEventForNewVisit`。
- **編集の差分処理＝正しい**：写真/人物リンクは削除マーク→`modelContext.delete`→pending挿入で二重挿入なし。共有PersonMasterは消さずEventPersonLinkのみ削除。
- **再起動保持＝OK**：`ModelConfiguration(isStoredInMemoryOnly: false)`。Home/Calendar/Categoryは@Query自動反映（onAppearスナップショットなし）。
- **クラッシュ無し**：対象パスに強制アンラップ無し・リレーションは optional/`?? []`。

### 検出した重大ギャップ（要ユーザー判断）
- **通常記録の「削除」UIが存在しない**：ExperienceDetailView/EventDetailView/CategoryTop/Home いずれにも Visit/Event の削除（onDelete/swipe/modelContext.delete）が無い。→ **対象機能「削除」・シナリオ10「削除後の反映」は現状実行不能**。
- **実装方式に制約の衝突**：`ExperienceEvent` は `isArchived` を持つが **`Visit` は `isArchived` を持たない**。仕様「既存データモデルは変更しない」を守るとVisitのソフト削除ができず、Visit単体削除はハード削除（`modelContext.delete`）しかない。その場合 `Visit.photos` はcascadeで消えるが、**EventPersonLink（visit参照）と Plan.visit は inverse未定義のため手動クリーンアップが必要**（放置すると孤立リンク/ダングリング参照）。

### 参考（低確度・未修正）
- `AddVisitView` の2回目記録で人物リンクが `event: nil, visit: visit`（visitスコープ）。他フローは `event`スコープ。詳細表示は event/visit 両方を拾うため当該回には表示される＝観測上の破綻はなし。設計意図次第のため今回は変更せず。
- `CategoryTopView` の `sheet(isPresented:)`＋内部if-letはタイミング的に空シートの微リスク（`sheet(item:)`推奨）。クラッシュではない・低。

### 主な変更ファイル
- docs/project-log.md（本記録のみ・コード変更なし＝既存フローに修正すべきバグが無かったため）

### 確認結果（実機 / ビルド）
静的監査のみ。ビルド/実機はMac側。

### 残課題（要判断）
- **削除機能の実装方針**：①Event単位のソフト削除（Event.isArchived流用＋各一覧にフィルタ追加・Visit単体削除は不可）／②ハード削除（Visit/Event＋関連手動クリーンアップ・不可逆・モデル不変）／③Visit.isArchived追加（最もきれいだが「モデル変更しない」に抵触）／④別タスク化。方針決定後に実装＋実機確認。

## 2026-07-10: チケットワークフローv1 静的監査＋不具合修正（outcomeKey体系不一致）

### 前提（正直な範囲）
- 依頼は「実機検証と不具合修正」だが、**開発環境がLinux（Xcode/実機なし）のため実機操作は不可**。代わりに9シナリオ（予定作成→表示→状態遷移→複数申込→当選〜発券→参加記録作成→申込削除→予定削除→通知再予約）を**コードで静的トレースして監査**した（データモデル整合／Home・Calendar反映の2観点で並行レビュー）。

### 見つけた不具合と修正
- **[修正] 参加記録の成果キーが別体系だった（PlanDetailView.createVisitFromPlan）**：`outcomeKey` に**チケット状態キー**（`issued`/`waitingPayment` 等）を入れていたが、Visitの成果は `planned/applied/won/paid/ticketed/attended/canceled` 系（成果ピッカー・ExperienceDetailView が期待）。→ 別体系のキーは詳細で生キー表示・ピッカーで「未設定」・再保存で消失し得た。参加記録作成＝出席なので **`outcomeKey = "attended"`（両表示系で有効）** に修正。データモデル・通知IDは不変・最小差分。

### 監査で「正常」と確認した点
- Plan↔TicketAttempt は `.cascade`＋inverse で孤立なし。Event↔Visit/Plan も cascade 正常。全リレーション optional・配列は `?? []`／optional chaining でnil追記クラッシュなし。状態enumは文字列rawで安定・強制アンラップなし。
- 削除は**ソフト削除（isArchived）**方式：予定削除=`archivePlan`（全attempt＋plan通知cancel）、申込削除=`archiveAttempt`（当該attempt通知cancel）。一覧（Home/Calendar/CategoryTop/PlanDetail）は `!isArchived` で除外＝削除後に消える。
- 状態遷移（updateAttemptStatus）：終端(lost/skipped/attended)で通知cancel・それ以外でreschedule＋save。Home/Calendarは@Queryで自動反映（onAppearスナップショットなし）。

### 未修正・要実機確認（低〜中確度・今回は変更せず）
- Calendar の状態バッジ／次アクションが、TicketAttempt単体のstatusKey変更で更新されるか（Observationで追随する見込みだが未実測）。
- 複数日にまたぐ予定はカレンダー上 `startsAt` の日のみ配置（期間バーは将来仕様）。
- Plan↔Visit は inverse 未定義の単方向to-one（CloudKit inverse要件・将来の同期時に要検討）。**「既存データモデルは変更しない」指示によりモデル改修は今回見送り**。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/PlanDetailView.swift（outcomeKey修正・1箇所）

### 確認結果（実機 / ビルド）
静的監査＋コード整合確認のみ。**xcodebuild／9シナリオの実機通し確認はMac側で必須**。

### 残課題
- Mac側で9シナリオを通し検証。上記「要実機確認」3点の挙動確認。

## 2026-07-10: 通知デバッグ画面に集中モード注意書き等を追加

### 変更概要（NotificationDebugView のみ）
- 通知権限セクション末尾に**黄色の注意書き**（`exclamationmark.triangle.fill`・caption）：「集中モード・通知要約・通知設定により通知が表示されない場合／iPhoneの設定 > 通知 > Favoreco と 設定 > 集中モード を確認」。
- **「集中モード: 確認できません」**（APIで取得不可のため明記）を追加。
- **「通知設定を開く」ボタン**（`openURL(UIApplication.openSettingsURLString)`）を追加。
- テスト通知の予約成功メッセージを「通知を予約しました。表示されない場合は集中モードや通知設定を確認してください。」へ変更。

### 変更しないもの（仕様どおり）
通知予約ロジック／各Scheduler／通知ID／AppDelegate／前面通知処理 は不変（NotificationDebugView.swift のみ変更）。

### 確認結果（実機 / ビルド）
コードレベル整合確認。**ビルド・実機（集中モードON/OFFでの表示/抑止）はMac側**。

## 2026-07-10: 前面通知表示対応（UNUserNotificationCenterDelegate）

### 変更概要
- アプリ**前面表示中もローカル通知（チケット申込締切・当落・入金締切等）をバナー/サウンド/バッジで表示**する対応。iOS標準では前面時にバナーが出ないため、`UNUserNotificationCenterDelegate` を設定して明示表示させる。
- `AppDelegate.swift`（新規）：`UIApplicationDelegate` + `UNUserNotificationCenterDelegate`。`didFinishLaunchingWithOptions` で `UNUserNotificationCenter.current().delegate = self`、async版 `willPresent` で `[.banner, .sound, .badge]` を返す。
- `favorecoAPPApp.swift`：`@UIApplicationDelegateAdaptor(AppDelegate.self)` を追加（1行）。

### 変更しないもの（仕様どおり）
TicketNotificationScheduler／TicketAccountNotificationScheduler／NotificationDebugView／通知ID／通知タイミング／AppStorage は一切変更なし（表示挙動のみ追加）。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/AppDelegate.swift（新規）
- favorecoAPP/favorecoAPP/favorecoAPPApp.swift（DelegateAdaptor 追加）

### 確認結果（実機 / ビルド）
コードレベルで整合確認（波括弧バランス・import・シンボル）。**xcodebuild／実機確認はMac側で必要**（当環境はLinuxでXcodeなし）。実機手順：①起動 ②通知診断で5秒テスト通知 ③前面のまま待機 ④バナー表示確認 ⑤バックグラウンドでも従来通り。

### 残課題
- Mac側でビルド・前面/バックグラウンド両方の通知表示を実機確認。

## 2026-07-10: チケット申込のクイック状態更新を追加

### 変更概要
- `TicketStatusTransitionDefinition` を追加し、チケット状態ごとの次に進める状態を定義した。
- 予定詳細の申込カードにコンテキストメニューを追加し、申込済み、当選/落選、入金待ち、発券待ち、発券済み、参加済みなどへクイック更新できるようにした。
- クイック更新時に `Plan.stateKey` と `TicketAttempt.statusKey` を更新し、落選/見送り/参加済みでは該当通知をキャンセル、それ以外では通知を再予約するようにした。

### 変更意図
チケットは登録して終わりではなく、申込、当落、入金、発券、参加済みへ何度も状態が進むため。毎回編集フォームを開かずに、予定詳細から状態だけ素早く更新できるようにして、実運用での入力負荷を下げる。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Utilities/TicketDefinitions.swift（状態遷移定義）
- favorecoAPP/favorecoAPP/Views/PlanDetailView.swift（申込カードのクイック更新メニュー）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedTicketQuickStatus CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機で申込カード長押し時の見え方と、各状態更新後の通知再予約/キャンセルを確認する。
- 状態遷移の文言は、実際に使いながら「申込済み」「取得済み」などのニュアンスを調整する。

## 2026-07-10: チケットの次アクション表示を共通化

### 変更概要
- チケット申込の未来日から、次に注意すべき「次のアクション」を返す `TicketNextActionDefinition` を追加した。
- 予定詳細のヘッダーに、申込件数、次の注意日、記録済み状態のサマリーチップを表示するようにした。
- 予定詳細の各申込カードに、次のアクション帯とプレイガイド/購入先名を表示するようにした。
- カレンダー/直近予定の予定行にも、次の注意日を1行表示するようにした。

### 変更意図
複数先行・複数名義を登録した時に、予定詳細へ入る前後どちらでも「次に何を見ればいいか」を判断できるようにするため。締切、当落、入金、発券などの要対応を一覧と詳細で同じ基準にそろえ、チケット管理の見落としを減らす。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Utilities/TicketDefinitions.swift（次アクション共通判定）
- favorecoAPP/favorecoAPP/Views/PlanDetailView.swift（サマリーチップ、申込カードの次アクション表示）
- favorecoAPP/favorecoAPP/Views/MainTabView.swift（予定行の次アクション表示）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedTicketNextSummary CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機で複数申込を登録し、最も近い未来日が一覧/詳細で同じように表示されるか確認する。
- 期限切れ直後の扱い、時刻未入力時の見え方は実データで調整する。

## 2026-07-10: 予定詳細の開く先を優先順位つきにした

### 変更概要
- `PlanDetailView` のメニューに、状況に応じた「申込・購入ページを開く / プレイガイドを開く / 公式URLを開く」を追加した。
- 開く先は `TicketAttempt.purchaseURL`、`TicketGuideDefinition` から推定したプレイガイドURL、`Plan.officialURL/sourceURL` の順に決めるようにした。
- プレイガイド未選択・申込URL未入力でも、公式URLがあれば公式サイトへ戻れるようにした。

### 変更意図
チケット登録後に、購入ページや公式サイトへ戻る導線を迷わせないため。申込・購入URLが未入力でも、プレイガイドや公式URLへフォールバックすることで、登録の手間と再検索を減らす。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/PlanDetailView.swift（優先開き先メニュー）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedTicketOpenNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機でUniversal Links対応サービスがアプリへ遷移するか確認する。
- プレイガイドトップURLではなく個別公演URLを保存した場合、最優先で個別ページが開くことを確認する。

## 2026-07-10: プレイガイド標準DBと購入URL自動入力を追加

### 変更概要
- `TicketGuideDefinition` を追加し、標準プレイガイド/チケットサイトのローカル辞書を持つようにした。
- 予定・チケット追加/編集フォームと申込単体追加/編集フォームに「プレイガイド」選択を追加した。
- 標準プレイガイドを選ぶと、`ticketSite` と `purchaseURL` にサイト名/URLを自動入力するようにした。
- `カスタム` を選ぶと、購入先・サイト名と申込/購入URLを手入力できるようにした。
- 購入URL入力を金額・座席セクションからチケット申込セクションへ移し、抽選応募予定/発売待ちでも使えるようにした。

### 変更意図
チケット登録時に毎回プレイガイド名やURLを手入力しなくてよいようにするため。標準DBで主要な購入先をワンタップ入力しつつ、FC独自サイトや小規模公演などはカスタム入力で逃がせるようにした。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Utilities/TicketDefinitions.swift（TicketGuideDefinition追加）
- favorecoAPP/favorecoAPP/Views/AddTicketPlanView.swift（プレイガイド選択/URL自動入力）
- favorecoAPP/favorecoAPP/Views/EditTicketAttemptView.swift（プレイガイド選択/URL自動入力）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedTicketGuideNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 標準プレイガイド一覧は実機確認後に不足分を追加する。
- 各プレイガイドのURLはトップ/汎用入口であり、個別公演URLはカスタムで上書きする。
- 将来、ユーザー作成のプレイガイド辞書やDBパック化を検討する。

## 2026-07-10: チケット入力を段階式フローに整理

### 変更概要
- チケット入力の入口として `気になる / 抽選応募予定 / 発売待ち / 取得済み` を追加した。
- `抽選応募予定` は申込開始/締切、当落発表、入金締切、名義/FC/カード枠を中心に表示するようにした。
- `発売待ち` は発売開始、購入先、発券開始を中心に表示するようにした。
- `取得済み` は詳細状態（当選/入金待ち/発券待ち/発券済み/参加済み）、金額、枚数、座席、購入URLを表示するようにした。
- `気になる` は日付・金額・座席を隠し、最低限の情報だけ保存しやすくした。
- 既存の `TicketAttempt.statusKey` / `entryRouteKey` は維持し、新しい入口はUI上の出し分けとして既存キーへ落とし込むようにした。

### 変更意図
従来の全部入りフォームだと「申込前」と「発売前」の温度感が分かりにくかったため。ユーザーが最初に自然な言葉で状態を選び、その状態に必要な項目だけ入力する形にして、チケット登録の迷いを減らす。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Utilities/TicketDefinitions.swift（チケット入力フロー定義）
- favorecoAPP/favorecoAPP/Views/AddTicketPlanView.swift（予定・チケット追加/編集の段階式表示）
- favorecoAPP/favorecoAPP/Views/EditTicketAttemptView.swift（申込単体追加/編集の段階式表示）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedTicketFlowNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機で各入口を選んだ時の表示項目が自然か確認する。
- `取得済み` で当選済み/購入済み/招待確定の細かな表現が足りるか確認する。
- 複数申込の一覧で、抽選応募予定/発売待ち/取得済みの見え方を確認する。

## 2026-07-10: 予定から参加記録を作成する導線を追加

### 変更概要
- `PlanDetailView` のメニューに「参加記録を作成 / 参加記録を開く」を追加した。
- 未作成の場合は確認ダイアログを挟み、予定のタイトル、日時、会場、チケット状態、座席、金額、メモを引き継いだ `ExperienceEvent` / `Visit` を作成するようにした。
- 作成した `Visit` を `Plan.visit` に紐付け、作成後は記録詳細へ遷移するようにした。
- 参加記録作成時は `Plan.stateKey` を `attended` にし、最新申込が落選/見送りでなければ `TicketAttempt.statusKey` も `attended` に更新するようにした。

### 変更意図
チケット予定を「行って終わり」にせず、そのまま体験記録へつなげるため。最初は最小の記録を自動作成し、あとから詳細編集で写真や感想を追加できる流れにする。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/PlanDetailView.swift（参加記録作成/表示導線）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedPlanToVisitNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機で予定詳細から参加記録作成後、記録詳細へ遷移し、Home/記録一覧/CalendarでVisitとして見えることを確認する。
- 作成後に詳細編集で写真・感想・人物などを追記する導線の使い勝手を確認する。
- 複数申込がある場合、どの申込を参加記録へ反映するかは現状「更新日時が新しい申込」を採用する。必要なら明示選択UIを追加する。

## 2026-07-10: 登録情報の非表示と期限通知キャンセルを追加

### 変更概要
- 登録情報編集画面に、既存 `TicketAccount` を非表示にする管理ボタンを追加した。
- 非表示時は `TicketAccount.isArchived = true`、`renewalNotify = false` にし、FC・会員期限通知をキャンセルするようにした。
- 非表示にした登録情報は、既存申込履歴を残したまま、申込フォーム候補とHome期限アテンションから外れる。

### 変更意図
登録情報を間違って作った場合や使わなくなったFC/会員/カード枠を安全に整理できるようにするため。チケット申込履歴との参照を壊さず、通知だけ残る事故を避ける。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（登録情報非表示導線）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedAccountArchiveNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機で非表示後に、登録情報一覧、申込フォーム候補、Home期限アテンションから消えることを確認する。
- 既存の申込詳細では、履歴として名義/アカウント参照が壊れないことを確認する。

## 2026-07-10: FC・会員期限アテンションと通知を接続

### 変更概要
- `TicketAccountNotificationScheduler` を追加し、FC・会員期限の30日前/7日前/当日朝通知を予約/キャンセルできるようにした。
- 登録情報保存時に、期限通知ONならFC・会員期限通知を再予約し、OFFならキャンセルするようにした。
- 通知設定で「通知を有効化」「FC・会員期限」を切り替えた時、既存登録情報の期限通知を予約/キャンセルするようにした。
- Homeアテンションに、期限通知ONかつ45日以内に期限が来る `TicketAccount` を表示するようにした。
- 実機確認は後回しにするため、確認項目を残課題に明記した。

### 変更意図
チケット周りの残りとして、申込や公演日だけでなく、FC・会員・カード枠などの更新期限を見落とさない導線を作るため。通知とHomeアテンションの両方に出すことで、通知許可をまだ出していないユーザーにも期限が見えるようにした。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Services/TicketAccountNotificationScheduler.swift（FC・会員期限通知）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（登録情報保存/通知設定変更時の予約・キャンセル）
- favorecoAPP/favorecoAPP/Views/HomeView.swift（FC・会員期限アテンション）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedMembershipNoSign CODE_SIGNING_ALLOWED=NO build` 成功。
- 実機通知の到達確認は後回し。

### 残課題
- 実機で通知許可ON後、登録情報の期限通知が30日前/7日前/当日朝に予約されることを確認する。
- 通知設定OFF、登録情報の期限通知OFF、登録情報削除/アーカイブ時に通知が残らないことを確認する。
- Homeアテンションに45日以内のFC・会員期限が表示され、期限切れ/通知OFF/アーカイブ済みは出ないことを確認する。
- チケット予定詳細のカレンダー追加、予定削除後のHome/Calendar非表示、申込通知キャンセルも実機で合わせて確認する。

## 2026-07-10: チケット周りv1を仕上げ

### 変更概要
- `EditTicketAttemptView` を追加し、1つの予定に複数のチケット申込を追加/編集できるようにした。
- `PlanDetailView` のメニューに、予定編集、申込追加、カレンダーに追加、予定削除を追加した。
- 申込カードをタップすると、該当 `TicketAttempt` を編集できるようにした。
- 申込削除は物理削除ではなくアーカイブ＋通知キャンセルにした。
- 予定削除は `Plan` と紐づく申込をアーカイブし、予定/申込の予約済み通知をキャンセルするようにした。
- 予定詳細から `CalendarEventEditSheet` を開き、外部カレンダーへ手動追加できるようにした。

### 変更意図
チケット管理v1として、予定作成、詳細確認、編集、複数申込、申込削除、予定削除、通知再予約/キャンセル、外部カレンダー手動追加まで一連の往復を成立させるため。ユーザーのデータを守るため、削除はまずアーカイブで扱う。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/EditTicketAttemptView.swift（申込単体の追加/編集）
- favorecoAPP/favorecoAPP/Views/PlanDetailView.swift（申込追加/編集、予定削除、カレンダー追加）
- favorecoAPP/favorecoAPP/Views/AddTicketPlanView.swift（共通日付行の可視性調整）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedTicketFinishNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機で通知到達、外部カレンダー追加、削除後のHome/Calendar非表示を確認する。
- 外部カレンダーイベントID保存と自動更新/削除追従は未実装。
- FC・会員期限通知は登録情報側の期限アテンション実装時に接続する。

## 2026-07-10: 予定・チケット編集と通知再予約を追加

### 変更概要
- `AddTicketPlanView` を追加/編集兼用にし、既存 `Plan` と最新 `TicketAttempt` からDraftへ読み込めるようにした。
- `PlanDetailView` に編集ボタンを追加し、予定・チケット詳細から編集シートを開けるようにした。
- 編集保存時に `Plan` / 最新 `TicketAttempt` を更新し、通知予約IDを更新して再予約するようにした。
- 編集時に申込情報をOFFにした場合、既存の最新 `TicketAttempt` を削除せずアーカイブし、該当通知をキャンセルするようにした。
- `TicketNotificationScheduler.cancel` を追加し、予定/チケット通知の明示キャンセルをできるようにした。

### 変更意図
Homeアテンション/Calendar/詳細画面で確認できる予定・チケットを、実際に修正できる状態へ進めるため。通知日時の変更や申込情報の取り消しに合わせて、古い通知が残らないよう再予約/キャンセルの基本動作も同時に接続した。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/AddTicketPlanView.swift（編集モード、既存Plan読み込み、更新保存）
- favorecoAPP/favorecoAPP/Views/PlanDetailView.swift（編集導線）
- favorecoAPP/favorecoAPP/Services/TicketNotificationScheduler.swift（通知キャンセル）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedPlanEditNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機で編集後の通知再予約/キャンセルを確認する。
- 複数TicketAttemptの編集・追加・履歴表示を作る。
- 予定/チケット削除と、外部カレンダー連携済みイベントの扱いを決める。

## 2026-07-10: 予定・チケット詳細画面を追加

### 変更概要
- `PlanDetailView` を追加し、予定の基本情報、公式情報、メモ、紐づくチケット申込を確認できるようにした。
- チケット申込カードで、状態、先行区分、名義/アカウント、申込開始/締切、当落、入金、発券、金額、座席、購入URL、メモを表示するようにした。
- Homeアテンションの予定/チケット行から `PlanDetailView` へ遷移できるようにした。
- Calendarの選択日/直近予定に出るPlan行から `PlanDetailView` へ遷移できるようにした。

### 変更意図
HomeアテンションとCalendarに出した予定・チケットを、タップして詳しく確認できる状態にするため。編集に進む前に、保存済みデータの見え方と情報量を先に固めた。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/PlanDetailView.swift（予定・チケット詳細画面）
- favorecoAPP/favorecoAPP/Views/HomeView.swift（Homeアテンションから予定詳細へ遷移）
- favorecoAPP/favorecoAPP/Views/MainTabView.swift（CalendarのPlan行から予定詳細へ遷移）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedPlanDetailNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 予定・チケット編集画面を作る。
- 編集後に通知再予約/キャンセルを行う。
- Home/Calendarから外部カレンダー追加や申込URLへ進む導線を整理する。

## 2026-07-10: Homeアテンションを予定・チケット中心へ接続

### 変更概要
- `HomeView` に `Plan` / `TicketAttempt` のQueryを追加し、横断ミニ統計の「今後の予定」に未来日Planを含めるようにした。
- Homeアテンションで、申込開始、申込締切、当落発表、入金締切、発券開始、公演予定を日付・優先度順に表示するようにした。
- 落選、参加済み、見送り、アーカイブ済みのチケット/予定はアテンションに出さないようにした。
- チケット系アテンションが足りない場合だけ、未来日Visitと未整理Inboxを補助表示するようにした。

### 変更意図
通知予約まで接続したチケット/予定情報を、アプリ起動直後に確認できる形へ進めるため。ユーザーがまず見るHomeのファーストビューに、締切・当落・入金・発券などの見落としたくない情報を集約する。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/HomeView.swift（Plan/TicketAttemptアテンション接続）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedHomeAttentionNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- Homeアテンションから予定/チケット詳細へ遷移する画面を作る。
- FC・会員期限、外部カレンダー予定、通知リマインダーを同じ枠へ追加する。
- 予定・チケット編集画面を作り、日付変更時の通知再予約とHome表示更新をつなぐ。

## 2026-07-10: チケット通知予約を予定・申込日付へ接続

### 変更概要
- `TicketNotificationScheduler` を追加し、`Plan` / `TicketAttempt` の日付からiOS通知を予約できるようにした。
- `AddTicketPlanView` の保存後に、通知設定とiOS通知許可状態を確認して、申込開始、申込締切、当落、入金締切、発券開始、公演前日/当日通知を予約するようにした。
- 通知予約IDを `TicketAttempt.notificationSettingsRaw` に保存し、再予約時は古い候補IDを削除してから追加するようにした。
- 締切系通知は前日と1時間前、公演通知は前日20:00と当日9:00を初期仕様にした。

### 変更意図
通知設定とチケット日付モデルをつなぎ、予定・申込を保存した時点で実際にリマインドできる状態へ進めるため。Homeアテンションやチケット編集画面へ進む前に、通知IDの命名と再予約の基本動作を先に固めた。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Services/TicketNotificationScheduler.swift（予定・申込通知予約サービス）
- favorecoAPP/favorecoAPP/Views/AddTicketPlanView.swift（保存後の通知予約接続）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedTicketNotificationsNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機で通知許可、予定保存後の通知予約、実通知到達を確認する。
- 予定・チケット編集画面で日付変更時の再予約/キャンセルを接続する。
- 通知設定を後からONにした時、既存予定へ一括再予約する導線を作る。
- Homeアテンションを `Plan` / `TicketAttempt` の締切・当落中心へ切り替える。

## 2026-07-10: 予定・チケット追加UIとカレンダー表示を接続

### 変更概要
- `AddTicketPlanView` を追加し、中央 `+` から「予定・チケットを追加」を開けるようにした。
- 予定のジャンル、タイトル、日時、開場、会場、公式URLを `Plan` として保存できるようにした。
- チケット申込を同時作成する場合、状態、先行区分、名義/アカウント、申込開始/締切、当落、入金、発券、金額、枚数、座席、購入URLを `TicketAttempt` として保存できるようにした。
- 登録情報・連携ハブで作った `TicketAccount` を申込の名義/アカウントとして選べるようにした。
- Calendarに `Plan` を表示し、月グリッド/選択日/直近予定で予定・チケットを確認できるようにした。

### 変更意図
前回追加した `Plan` / `TicketAttempt` / `TicketAccount` を、実際にユーザーが入力できる状態へ進めるため。まず保存と確認の往復を作り、次に通知予約やHomeアテンションへ接続できるようにした。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/AddTicketPlanView.swift（予定・チケット追加フォーム）
- favorecoAPP/favorecoAPP/Views/MainTabView.swift（中央+導線、CalendarのPlan表示）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedTicketPlanInputNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- `Plan` / `TicketAttempt` の編集画面を作る。
- 通知予約を申込開始/締切、当落、入金、発券、公演前日/当日へ接続する。
- Homeアテンションを `Plan` / `TicketAttempt` 中心へ切り替える。
- チケット申込一覧、当選率/名義別統計は後続。

## 2026-07-10: チケット予定モデルと登録情報ハブを追加

### 変更概要
- `Plan` / `TicketAttempt` / `TicketAccount` のSwiftDataモデルを追加し、アプリSchemaへ登録した。
- `Plan` を予定/公演回、`TicketAttempt` を申込1件、`TicketAccount` をFC/プレイガイド/劇場会員/カード枠などの登録情報として分離した。
- `TicketDefinitions` を追加し、チケット状態、先行区分、アカウント種別のキー/表示名を定義した。
- 設定 > マイ に「登録情報・連携」ハブを追加し、`TicketAccount` を登録/編集できるようにした。
- JSONバックアップに `Plan` / `TicketAccount` / `TicketAttempt` のDTOを追加した。Keychainパスワード本体は書き出さず、参照キーの有無だけを出す。
- `Color+Hex` にColorPicker保存用のHEX変換を追加した。

### 変更意図
チケット/予定管理をVisit直持ちから分離し、複数先行、落選履歴、名義別集計、通知更新に耐える土台を作るため。次に申込入力UIと通知予約を実装する前に、予定・申込・登録情報の責務境界を先に固定した。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Models/CoreModels.swift（Plan / TicketAccount / TicketAttempt追加）
- favorecoAPP/favorecoAPP/favorecoAPPApp.swift（Schema登録）
- favorecoAPP/favorecoAPP/Utilities/TicketDefinitions.swift（チケット定義）
- favorecoAPP/favorecoAPP/Utilities/Color+Hex.swift（HEX変換追加）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（登録情報・連携ハブ、JSONエクスポート追従）
- favorecoAPP/favorecoAPP/Services/JSONBackupExportService.swift（バックアップDTO追加）
- favorecoAPP/favorecoAPP/Services/ExternalCalendarOverlayService.swift（EventKit警告対策）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedTicketModelsNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- `Plan` / `TicketAttempt` の追加・編集UIを作る。
- 申込開始/締切、当落、入金、発券、公演前日/当日の通知予約を `TicketAttempt` / `Plan` の日付へ接続する。
- Homeアテンション、Calendar、Statsを未来日Visit中心からPlan/TicketAttempt中心へ切り替える。
- 既存 `Visit.outcomeKey` / `seatText` からTicketAttemptへ移行する導線を検討する。

## 2026-07-10: カレンダー重ね表示と通知設定を接続

### 変更概要
- EventKit読み取り用の `ExternalCalendarOverlayStore` を追加し、iOSカレンダーに登録済みの外部予定をDTOとして取得できるようにした。
- `CalendarView` に「外部カレンダーを重ねる」トグル、権限表示、許可ボタン、再読み込みボタンを追加した。
- 月カレンダーではFavoreco記録の点と外部予定の点を分け、選択日/直近予定に外部カレンダー行を薄く表示するようにした。
- `NotificationSettingsView` をプレースホルダーから、通知全体と通知タイプ別ON/OFFを保存する画面に変更した。
- 通知全体ON時に `UNUserNotificationCenter` の通知許可を求め、iOS通知許可状態を表示するようにした。
- 写真ユニット内のサムネイルプレビューへ選択中のカバー比率を反映し、御朱印ジャンルでは未設定時に標準御朱印帳サイズを補完するようにした。

### 変更意図
チケット/予定モデルに進む前に、カレンダーと通知のOS連携の入口を固めるため。外部カレンダーはFavorecoの正本データに混ぜず、予定把握用の読み取りレイヤーとして扱う。通知は予約対象の日付モデルが揃う前に、まずユーザーが必要な通知タイプを選べる設定を実データとして保持する。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Services/ExternalCalendarOverlayService.swift（EventKit読み取りサービス）
- favorecoAPP/favorecoAPP/Views/MainTabView.swift（外部カレンダー重ね表示）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（通知設定の保存/許可接続）
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（写真比率プレビュー/御朱印帳サイズ補完）
- favorecoAPP/favorecoAPP/Utilities/AppStorageKeys.swift（通知/外部カレンダー設定キー追加）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedCalendarNotificationNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機で外部カレンダー権限ダイアログ、Googleカレンダー予定の表示、外部予定の色/件数表示を確認する。
- 通知の実予約は、次の `Plan` / `TicketAttempt` / 公演日モデル追加後に接続する。

## 2026-07-10: 写真カバー比率と御朱印帳ユニットを接続

### 変更概要
- 写真ユニットにカバー比率Pickerを追加し、正方形、映画ポスター、チラシ/ポスター、書影、横長ラベル、御朱印帳標準から選べるようにした。
- `VisitUnitFields` に `eyecatchAspectRatioKey` と `goshuinBookSizeKey` を追加した。
- 御朱印ジャンル向けに `goshuinBook` ユニットを追加し、御朱印帳サイズを保存できるようにした。
- 御朱印ジャンルの初期有効ユニットに `goshuinBook` を含めた。

### 変更意図
写真/カバー/比率指定まわりを、将来のカード表示・レポート画像化・御朱印帳表示へつなげるため。ジャンルごとに写真の自然な比率が違うため、画像自体を切り抜く前に記録側へ表示意図を保存する。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Utilities/EyecatchAspectRatio.swift（比率/御朱印帳サイズ定義）
- favorecoAPP/favorecoAPP/Utilities/VisitUnitFields.swift（保存項目追加）
- favorecoAPP/favorecoAPP/Utilities/RecordUnitDefinition.swift（御朱印帳ユニット追加）
- favorecoAPP/favorecoAPP/Services/CategoryPresetSeeder.swift（御朱印ジャンルの初期ユニット更新）
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（写真比率/御朱印帳入力UI接続）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedPhotoRatioNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機で写真比率Picker、御朱印帳サイズPicker、既存記録編集時の復元を確認する。
- 選択した比率をHome/一覧/詳細/レポート画像の表示に反映する処理は後続で行う。

## 2026-07-10: 思い出レポートのカードプレビューを追加

### 変更概要
- `月刊Favoreco` / `年間Favoreco` 下書き画面にカードプレビューを追加した。
- カード内に、レポート名、対象期間、記録数、写真数、ジャンル数、最多ジャンル、よく出てきた場所、カード候補を表示した。
- 画像書き出し前の見た目確認として、アクセントカラーの薄いグラデーションを使った。

### 変更意図
共有テキストだけではレポートの完成形が見えにくいため、まず画面内で「思い出カードっぽい」見た目を確認できるようにするため。次の画像化/保存/共有に進む前のUI土台にする。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/MainTabView.swift（カードプレビュー追加）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedReportCardPreviewNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機でカードの情報量、Dynamic Type、長い会場名/タイトルの折り返しを確認する。
- 画像として書き出す処理、保存、SNS向けテンプレは未実装。

## 2026-07-10: 思い出レポートを共有シートから送れるようにした

### 変更概要
- `月刊Favoreco` / `年間Favoreco` 下書き画面に `共有する` ボタンを追加した。
- 共有用テキストを `ShareLink` でiOS共有シートへ渡せるようにした。
- コピー導線は `テキストをコピー` として残した。

### 変更意図
クリップボード経由だけでなく、標準共有シートから直接メッセージやSNSへ送れるようにするため。画像カード化の前に、共有文の内容と共有導線の手触りを確認できる状態にした。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/MainTabView.swift（ShareLink追加）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedReportShareLinkNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機で共有シートの表示、各アプリへの渡り方、共有文の長さを確認する。
- 画像カード生成、保存、SNS向けテンプレは未実装。

## 2026-07-10: 思い出レポートの共有用テキストコピーを実装

### 変更概要
- `月刊Favoreco` / `年間Favoreco` 下書き画面に、共有用テキストをコピーするボタンを追加した。
- コピー内容は、記録数、写真数、ジャンル数、平均評価、最多ジャンル、よく出てきた場所、カード候補、`#Favoreco` を含む要約にした。
- コピー後に確認アラートを表示するようにした。

### 変更意図
画像化の前段として、まずレポートの要約を外へ出せる軽い共有導線を作るため。将来の画像カード生成やShareLink接続に進む前に、どの情報を共有するかの形を固める。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/MainTabView.swift（共有用テキストコピー追加）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedReportCopyNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機でクリップボードコピー、アラート、共有文言の長さを確認する。
- 画像カード生成、ShareLink、保存、SNS向けテンプレは未実装。

## 2026-07-10: 月刊/年間Favorecoの下書き画面を実装

### 変更概要
- 統計タブの `月刊Favoreco` / `年間Favoreco` をタップ可能にした。
- 今月/今年のVisitから、記録数、写真数、ジャンル数、平均評価、最多ジャンル、最多場所、金額、ジャンル傾向、カード候補を表示する下書き画面を追加した。
- 下書き画面でも金額は初期非表示にし、目アイコンで表示/非表示を切り替えるようにした。

### 変更意図
Premium候補の自動思い出レポートを、単なる予告ではなく、まずローカル集計の下書きとして触れる状態にするため。画像化、自動生成、同期込みのレポートへ進む前に、どんな情報がカード化に使えるかを画面で確認できるようにした。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/MainTabView.swift（レポート下書き画面追加）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedReportDraftNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機で月刊/年間カードのタップ感、空データ、多件データ、金額伏せ字、Dynamic Type時の見え方を確認する。
- レポート画像化、共有、通知、自動生成、去年同月比較、同期込み集計は未実装。

## 2026-07-10: 思い出レポートをPremium候補として画面に反映

### 変更概要
- 統計タブに `月刊Favoreco` / `年間Favoreco` の思い出レポート予告枠を追加した。
- 課金・プラン画面の同期プラン候補に `自動思い出レポート` を追加した。
- 正本仕様に、基本統計=無料、詳細統計/年間まとめ=Pro、同期込み自動レポート=Premium候補の境界を追記した。

### 変更意図
サブスクの価値を「同期だけ」ではなく、毎月/毎年、自動で届く思い出カードとして見せる方向に固めるため。Spotify Wrapped、Apple Music Replay、Google Photos Memories、日記アプリの要約系に近い価値を、favorecoでは体験記録・写真・ジャンル横断の文脈で出す。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/MainTabView.swift（思い出レポート予告枠追加）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（同期プラン候補に自動思い出レポート追加）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedReportPreviewNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機で統計タブ下部の情報量、ロック表現の強さ、無料ユーザーへの圧迫感を確認する。
- 実際の月次カード/年間カード生成、通知、自動生成、画像書き出しは未実装。

## 2026-07-10: 統計の金額を初期非表示にした

### 変更概要
- 統計タブの `記録済み金額` カードを、初期状態では伏せ字表示に変更した。
- 目アイコンで金額の表示/非表示を切り替えられるようにした。
- 金額表示に `privacySensitive` を付け、プライバシー情報として扱う意図をコード上にも反映した。

### 変更意図
金額はチケット代、遠征費、購入額など生活情報に近いプライバシー情報なので、統計画面を開いた瞬間に見えないよう配慮するため。無料/有料に関係なく、金額系の統計はユーザー操作で明示的に見る方針にする。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/MainTabView.swift（支出カードの非表示/表示切替）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedStatsPrivacyNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機で目アイコンのタップ領域、Dynamic Type時の金額伏せ字表示、スクリーンショット/画面共有時の見え方を確認する。

## 2026-07-10: 統計タブに簡易集計を実装

### 変更概要
- `StatsView` を準備中表示から、保存済みVisitを集計する簡易統計画面へ変更した。
- 総記録数、今年の記録、今月の記録、平均評価のサマリーカードを追加した。
- ジャンル別回数、記録済み金額、評価概要を表示するセクションを追加した。

### 変更意図
Home横断ミニ統計に続いて、下部タブの「統計」も空の入口ではなく、記録が増えた時にすぐ価値が出る最低限の集計画面にするため。詳細統計や年間まとめは後続で拡張し、まず無料で見られる基本統計を先に固める。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/MainTabView.swift（StatsView実装）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedStatsTabNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機で0件、1件、多件、金額未入力、評価未入力、Dynamic Type時の見え方を確認する。
- 詳細統計、期間切替、年間まとめ、グラフ、Plan/TicketAttempt追加後の予定/申込統計は未実装。

## 2026-07-10: カレンダータブを月表示にした

### 変更概要
- `CalendarView` をプレースホルダーから、Visitの日付を表示する月カレンダーへ変更した。
- 月移動、日付選択、記録がある日のドット表示、選択日の記録一覧、直近予定一覧を追加した。
- カレンダー上の記録から `ExperienceDetailView` へ遷移できるようにした。

### 変更意図
外部カレンダーへ手動追加できるようになったため、アプリ内でも日付軸で記録を見返せる最低限のカレンダーを先に作るため。予定/申込/訪問済みの厳密な分離は後続のPlan/TicketAttemptモデルで拡張する。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/MainTabView.swift（CalendarView実装）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedCalendarTabNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機で月初曜日、縦幅、Dynamic Type、記録件数が多い日の見え方を確認する。
- 外部カレンダー読み取り重ね表示、Plan/TicketAttemptによる予定/申込の分離は未実装。

## 2026-07-10: 記録詳細からカレンダー手動追加を実装

### 変更概要
- `CalendarEventEditSheet` を追加し、EventKitUIのネイティブイベント編集画面をSwiftUIから表示できるようにした。
- `ExperienceDetailView` の基本情報に `カレンダーに追加` ボタンを追加した。
- カレンダー追加時に、記録タイトル、日時、場所、座席、チケット状態、金額、メモ、公式URLをイベント下書きへ入れるようにした。
- 生成Info.plist用にカレンダー利用説明文をDebug/Release両方へ追加した。

### 変更意図
無料機能として決めていた「手動でカレンダーに追加」を、Mystorium同様にユーザー操作で使える状態にするため。ネイティブ編集画面を使うことで、iOSに登録済みのApple/Googleカレンダーをユーザーが選べる余地を残す。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Services/CalendarEventEditSheet.swift（EventKitUIラッパー追加）
- favorecoAPP/favorecoAPP/Views/ExperienceDetailView.swift（カレンダー追加ボタンとイベント下書き作成）
- favorecoAPP/favorecoAPP.xcodeproj/project.pbxproj（カレンダー利用説明文追加）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedCalendarAddNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機で初回権限ダイアログ、保存/キャンセル、Googleカレンダー選択の挙動を確認する。
- 外部カレンダーイベントIDの保存、更新/削除、読み取り重ね表示は未実装。

## 2026-07-10: 初回説明オンボーディングを実装

### 変更概要
- `GenreOnboardingView` をジャンル選択直行から、説明4ステップ + ジャンル選択 + 開始確認の流れに変更した。
- 価値訴求、記録できる内容、ジャンル横断、安心材料を短く見せてからジャンル選択に進むようにした。
- 既存の「1ジャンル以上必須」「最後に有効ジャンル0件にしない」保存ルールは維持した。

### 変更意図
初回ユーザーに、何のアプリか、何を残せるか、なぜジャンルを選ぶのかを先に伝えるため。権限要求や同期案内は初回で重くせず、まずHomeへ入れる軽い導線にする。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/GenreOnboardingView.swift（初回説明ステップとUI部品追加）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedOnboardingFlowNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機で縦幅の短い端末やDynamic Type時の見え方を確認する。
- 文言とステップ数は実機確認後に短縮/調整する。

## 2026-07-10: JSONバックアップを書き出せるようにした

### 変更概要
- `JSONBackupExportService` を追加し、復元前提の手動バックアップJSONを生成できるようにした。
- データ管理の `JSONエクスポート` を準備中ページから実際の書き出し画面へ差し替えた。
- JSON書き出し画面で、ジャンル/対象/Visit/人物/人物リンク/場所/Inbox/SNS/写真メタデータの件数を確認できるようにした。

### 変更意図
CSVは表計算向けの見返し用なので、アプリへ戻す将来復元に備えた構造化バックアップも無料の安全網として早めに置くため。写真バイナリは容量と復元設計が重いため、今回は記録本体と紐付けID、写真メタデータまでに限定した。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Services/JSONBackupExportService.swift（バックアップDTOとJSON FileDocument追加）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（JSONエクスポート画面追加）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedJSONExportNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- JSONインポート/復元、写真/動画バイナリを含む完全バックアップ、バックアップ互換性チェックは未実装。
- 将来の復元時は既存データを壊さないマージ方式と、ID衝突時の扱いを設計する。

## 2026-07-10: CSVエクスポートを実装

### 変更概要
- `CSVExportService` を追加し、保存済みVisitをUTF-8 CSVに変換できるようにした。
- データ管理の `CSVエクスポート` を準備中ページから実際の書き出し画面へ差し替えた。
- CSV書き出し画面で対象件数、形式、写真を含めないこと、出力列を確認できるようにした。

### 変更意図
無料で守る手動バックアップ/持ち出し導線の最初の実処理として、表計算アプリで開ける記録一覧CSVを出せるようにするため。JSONバックアップより先に軽いCSVを入れることで、端末内データを確認・退避しやすくする。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Services/CSVExportService.swift（CSV生成とFileDocument追加）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（CSVエクスポート画面追加）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedCSVExportNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- JSONバックアップ、CSVインポート、写真を含むバックアップは未実装。
- 人物・団体、写真、詳細オプションなどの複雑なサブデータをCSVへ展開するかは後続で検討する。

## 2026-07-10: Homeにも人物・団体サマリーを反映

### 変更概要
- Homeの最近の記録を共通 `VisitSummaryRow` へ差し替えた。
- 体験ギャラリーカードにも `EventPersonLink` から人物・団体を最大2件表示するようにした。
- Home内の独自 `VisitRow` / `FlowMetaItem` / `FlowMetaLine` を削除し、一覧表現の重複を減らした。

### 変更意図
Records、カテゴリトップ、対象詳細の履歴で人物・団体が見えるようになったため、Homeでも同じ情報が自然に見えるように揃えるため。Homeはアプリを開いた最初の見返し面なので、写真・場所だけでなく「誰の体験か」も短く出す。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/HomeView.swift（Home最近の記録を共通サマリーへ差し替え、ギャラリーに人物・団体表示追加）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedHomePeopleNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 役割表示やジャンル別の人物ラベル最適化は後続で調整する。
- Homeの体験ギャラリーは現状 `@Query` で人物リンクを参照しているため、件数が増えた段階でSnapshot/DTO化を検討する。

## 2026-07-10: AppIconをワインレッドしおり案へ差し替え

### 変更概要
- XcodeのAppIcon本体を `favoreco-app-icon-wine-bookmark-1024.png` へ差し替えた。
- AppIcon.appiconset内の未参照PNGを削除し、asset catalog警告が出ない状態にした。

### 変更意図
ワインレッド系の高級感と、Fなししおりモチーフのわかりやすさを実機確認できる状態にするため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Assets.xcassets/AppIcon.appiconset/Contents.json（AppIcon参照差し替え）
- favorecoAPP/favorecoAPP/Assets.xcassets/AppIcon.appiconset/favoreco-app-icon-wine-bookmark-1024.png（Xcode AppIcon用PNG）
- favorecoAPP/favorecoAPP/Assets.xcassets/AppIcon.appiconset/favoreco-app-icon-1024.png（未参照旧PNGを削除）
- favorecoAPP/favorecoAPP/Assets.xcassets/AppIcon.appiconset/favoreco-app-icon-no-f-bookmark-1024.png（未参照旧PNGを削除）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `sips` で1024x1024pxであることを確認。
- ビルド確認は下の人物サマリー実装とまとめて実施。

### 残課題
- 実機ホーム画面で小サイズ視認性を確認する。

## 2026-07-10: 人物サマリーと対象履歴行を強化

### 変更概要
- `VisitSummaryRow` に `EventPersonLink` の簡易取得を追加し、人物・団体を最大2件までサマリー表示するようにした。
- `EventDetailView` の履歴行を独自の `EventVisitRow` から `VisitSummaryRow` に差し替えた。
- 未使用になった `EventVisitRow` を削除した。
- AppIcon.appiconset内に残っていた未参照の旧アイコンPNGを削除し、asset catalog警告を解消した。

### 変更意図
人物・団体ユニットを入力できるようになったため、詳細画面を開かなくても一覧で「誰に紐づく記録か」が見えるようにするため。対象詳細の履歴もRecords/カテゴリ内最近の記録と同じ情報密度に揃えた。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/VisitSummaryRow.swift（人物・団体サマリー表示追加）
- favorecoAPP/favorecoAPP/Views/EventDetailView.swift（履歴行を共通サマリー行へ差し替え）
- favorecoAPP/favorecoAPP/Assets.xcassets/AppIcon.appiconset/favoreco-app-icon-1024.png（未参照旧アイコンPNGを削除）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedPersonSummaryIconNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 人物・団体の表示順/役割表示は簡易。ジャンル別サマリーで「主演」「作者」「アーティスト」などの見せ方を後続で調整する。
- Home内の独自サマリーカードにも人物表示を横展開する。

## 2026-07-10: AppIconをFなししおり案へ差し替え

### 変更概要
- XcodeのAppIcon本体を `favoreco-app-icon-no-f-bookmark-1024.png` へ差し替えた。
- ライト/ダーク/ティント用のAppIconエントリすべてで同じ1024px画像を参照するようにした。

### 変更意図
F文字に依存しない、体験記録/しおり感が伝わる案を実機確認できる状態にするため。比較用に作成した候補のうち、まずFなししおり案をアプリ本体へ反映した。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Assets.xcassets/AppIcon.appiconset/Contents.json（AppIcon参照差し替え）
- favorecoAPP/favorecoAPP/Assets.xcassets/AppIcon.appiconset/favoreco-app-icon-no-f-bookmark-1024.png（Xcode AppIcon用PNG）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `sips` で1024x1024pxであることを確認。
- ビルド/実機確認は未実施。

### 残課題
- 実機ホーム画面で小サイズ視認性を確認する。
- 必要なら採用案を再度差し替える。

## 2026-07-10: 記録一覧とカテゴリ内記録にサマリー行を適用

### 変更概要
- `VisitSummaryRow` を追加し、記録一覧で写真、カテゴリ、日付、場所、評価、チケット状態、金額、OCR/詳細オプション有無、短いメモを表示できるようにした。
- `RecordsView` の行表示を `VisitSummaryRow` に差し替え、Listの余白と区切り線を調整した。
- `CategoryTopView` の最近の記録にも同じサマリー行を適用し、カテゴリ内ではカテゴリ名を省略するようにした。

### 変更意図
Homeだけでなく、記録一覧やカテゴリ内でも保存したユニット情報が見えるようにするため。写真、予定状態、支出、OCR/詳細有無が一覧で見えることで、詳細画面を開く前に記録の内容を思い出しやすくする。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/VisitSummaryRow.swift（共通サマリー行追加）
- favorecoAPP/favorecoAPP/Views/MainTabView.swift（RecordsViewに適用）
- favorecoAPP/favorecoAPP/Views/CategoryTopView.swift（カテゴリ内最近の記録に適用）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedVisitSummaryNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- Home側の独自カードと共通サマリー部品の重複整理は後続で行う。
- 人物・団体のサマリー表示、EventDetailView履歴行への横展開は未実装。

## 2026-07-10: Homeサマリーカードの表示情報を強化

### 変更概要
- Homeの体験ギャラリーカードに、カテゴリ、チケット状態、日付、場所、金額、OCR有無、詳細オプション有無を表示するようにした。
- Homeの最近の記録カードに、写真サムネイル、カテゴリ色、日付、場所、評価、チケット状態、金額、OCR/詳細オプション有無、短いメモを表示するようにした。
- 写真がない記録ではジャンルアイコンとテーマカラーを使ったプレースホルダーを表示するようにした。

### 変更意図
標準入力ユニットが一通り保存できるようになったため、Homeで「何を記録したか」が一目でわかる状態に近づけるため。詳細画面まで開かなくても、写真・予定状態・支出・取込有無が見えると、アプリを開いた時の見返し体験が強くなる。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/HomeView.swift（体験ギャラリー/最近の記録カード強化）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedHomeCardsNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 人物・団体のサマリー表示は未接続。`EventPersonLink` の取得方法を整理してから追加する。
- RecordsView / CategoryTopView / EventDetailView の一覧行にも同じサマリー表現を横展開する。

## 2026-07-10: 詳細オプションユニットの実入力を追加

### 変更概要
- `advanced` ユニットを準備中表示から実入力に変更した。
- 新規記録、既存対象への回追加、保存済み記録編集で、ラベル/値の自由項目を複数追加できるようにした。
- 自由項目は `VisitUnitFields.advancedEntries` として `Visit.unitFieldsRaw` にJSON保存する。
- 空の自由項目は保存時に除外し、詳細画面には入力済み項目だけ表示するようにした。
- 記録詳細画面に `詳細オプション` セクションを追加した。

### 変更意図
ジャンルごとに必要な細かい項目は実データを触るまで揺れるため、いきなり専用モデルにせず、まず自由項目として保存できる受け皿を作った。日本酒の精米歩合、美術展の所要時間、御朱印の印種別など、後から検索/統計に昇格したい値の試験場として使う。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（詳細オプション入力、保存、編集、回追加への接続）
- favorecoAPP/favorecoAPP/Views/ExperienceDetailView.swift（詳細オプション表示）
- favorecoAPP/favorecoAPP/Utilities/VisitUnitFields.swift（自由項目配列を追加）
- favorecoAPP/favorecoAPP/Utilities/RecordUnitDefinition.swift（advancedユニットを実装済みに変更）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedAdvancedNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- ジャンル別の詳細項目プリセット、入力型（数値/日付/選択肢）、統計への昇格は後続で行う。
- 自由項目の並び替え、テンプレ保存、重複ラベル補正は未実装。

## 2026-07-10: OCR・取込ユニットの実入力を追加

### 変更概要
- `importOCR` ユニットを準備中表示から実入力に変更した。
- 新規記録、既存対象への回追加、保存済み記録編集で、画像からVision OCRを実行し、読み取りテキストを保存できるようにした。
- 読み取り結果は手入力で修正・追記できるテキスト欄として扱い、`Visit.unitFieldsRaw` にJSON保存するようにした。
- 記録詳細画面に、保存済みOCRテキストを表示する `OCR・取込` セクションを追加した。
- `VisitUnitFields` を追加し、ジャンル別の追加ユニット値を後続で拡張できる保存形式にした。

### 変更意図
半券、チケット、レシート、リスト画像から文字を拾えると入力負荷が下がるため、まずはタイトル/日時/会場への自動振り分けではなく、読み取り結果を安全に保存・編集・詳細確認できる受け皿を作った。後続でURL取込やOCR高度化、項目候補への振り分けを重ねられるよう、`unitFieldsRaw` のJSONに閉じ込めた。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（OCR画像選択、Vision OCR、読み取りテキスト入力/保存）
- favorecoAPP/favorecoAPP/Views/ExperienceDetailView.swift（OCRテキスト表示）
- favorecoAPP/favorecoAPP/Utilities/VisitUnitFields.swift（追加ユニット値のJSON保存形式）
- favorecoAPP/favorecoAPP/Utilities/RecordUnitDefinition.swift（importOCRユニットを実装済みに変更）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedOCRNoSign2 CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- OCR結果をタイトル、日時、会場、金額、人物などへ自動候補化する処理は未実装。
- 複数画像OCR、OCR履歴、チケット写真との紐付け、Pro向け高度OCRは後続で行う。

## 2026-07-10: チケット・予定ユニットの実入力を追加

### 変更概要
- `ticketPlan` ユニットを準備中表示から実入力に変更した。
- 新規記録、既存対象への回追加、保存済み記録編集で、チケット状態と座席・チケットメモを入力できるようにした。
- チケット状態は `Visit.outcomeKey`、座席・チケットメモは `Visit.seatText` に保存する。
- 記録詳細画面の基本情報に、チケット状態と座席・チケットメモが入力されている場合だけ表示するようにした。
- `RecordUnitDefinition` で `ticketPlan` を実装済みユニットとして扱うようにした。

### 変更意図
観劇/ライブ/テーマパーク系で重要な「申込中」「当選」「発券済み」「座席」を、まず既存の `Visit` フィールドに接続して実データを入れられるようにした。申込締切、当落日、入金期限、発券日などの細かい予定管理は後続で専用モデル/通知と合わせて拡張する。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（チケット・予定入力、保存、編集、回追加への接続）
- favorecoAPP/favorecoAPP/Views/ExperienceDetailView.swift（チケット状態/座席メモ表示）
- favorecoAPP/favorecoAPP/Utilities/RecordUnitDefinition.swift（ticketPlanユニットを実装済みに変更）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedTicketPlanNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 申込締切、当落日、入金期限、発券日、公演前日/当日通知への接続は未実装。
- チケット画像/OCRとの連携、席種/座席の構造化、カレンダー反映は後続で行う。

## 2026-07-10: 金額ユニットの実入力を追加

### 変更概要
- `money` ユニットを準備中表示から実入力に変更した。
- 新規記録、既存対象への回追加、保存済み記録編集で、合計金額を入力できるようにした。
- 入力値は `Visit.amount` に `Decimal` として保存し、カンマ、円記号付きの入力も数値化するようにした。
- 記録詳細画面の基本情報に、金額が入力されている場合だけ円表示で出すようにした。
- `RecordUnitDefinition` で `money` を実装済みユニットとして扱うようにした。

### 変更意図
チケット代、購入額、交通費などはジャンル横断の統計や年間まとめで使えるため、まずは内訳管理ではなく「合計金額メモ」として保存できる状態にした。費目別の詳細管理や遠征費分解は、実データの使い方を見ながら後続で追加する。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（金額入力、保存、編集、回追加への接続）
- favorecoAPP/favorecoAPP/Views/ExperienceDetailView.swift（金額表示）
- favorecoAPP/favorecoAPP/Utilities/RecordUnitDefinition.swift（moneyユニットを実装済みに変更）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedMoneyUnitNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 金額内訳、費目別管理、統計画面への反映は未実装。
- 無料/有料境界に応じた高度な統計表示は後続で行う。

## 2026-07-10: 人物・団体ユニットの実入力を追加

### 変更概要
- `people` ユニットを準備中表示から実入力に変更した。
- 新規記録、既存対象への回追加、保存済み記録編集で、人物・団体名と役割を追加できるようにした。
- 入力された人物・団体は `PersonMaster` を正規化名で再利用し、なければ新規作成するようにした。
- `ExperienceEvent` / `Visit` との紐付けは `EventPersonLink` に保存し、役割はリンク側の `roleKey` / `displayRole` に持たせた。
- 編集画面では保存済みリンクの削除予約と、新規追加予定リンクの削除ができるようにした。
- 入力中の名前に対して、既存 `PersonMaster` から簡易候補を表示するようにした。
- 記録詳細画面に、人物・団体を役割つきで表示するセクションを追加した。
- `RecordUnitDefinition` で `people` を実装済みユニットとして扱うようにした。

### 変更意図
観劇/ライブ/映画/本/美術展などで、人物・団体は記録価値と後続の統計・検索・重複統合に直結するため、早めにマスターとリンクを実際に動かすため。巨大な外部名鑑やApple Music連携はまだ接続せず、まずは手入力で正本データを作り、後から外部候補を入力補助として重ねられる構造にした。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（人物・団体入力、既存候補、PersonMaster再利用、EventPersonLink保存）
- favorecoAPP/favorecoAPP/Views/ExperienceDetailView.swift（人物・団体セクション表示）
- favorecoAPP/favorecoAPP/Utilities/RecordUnitDefinition.swift（peopleユニットを実装済みに変更）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/favorecoDerivedPeopleUnit build` 成功。

### 残課題
- PersonMaster一覧、詳細編集、重複統合UIは未実装。
- Apple Music / MusicBrainz / Wikidata / TMDb等の外部候補は未接続。
- Home/一覧/サマリーカードへの人物・団体表示は未接続。
- 役割プリセットは共通固定。ジャンル別の初期候補最適化は後続で行う。

## 2026-07-10: 写真ユニットの実入力を追加

### 変更概要
- `AddExperienceView` / `AddVisitView` / `EditExperienceView` の `photos` ユニットを準備中表示から実入力に変更した。
- 写真ライブラリから画像を選択し、JPEG 85%・最大幅1600pxに再エンコードして `PhotoBlob.data` に保存するようにした。
- 新規記録、既存対象への回追加、保存済み記録編集のすべてで写真追加を可能にした。
- 編集画面では保存済み写真のサムネイル表示と削除予約、新規追加予定写真の削除ができるようにした。
- 1記録あたり写真10枚までの上限表示を追加した。
- 記録詳細画面で、写真が1枚なら大きく、複数枚ならグリッドで表示するようにした。
- `RecordUnitDefinition` で `photos` と `officialInfo` を実装済みユニットとして扱うようにした。

### 変更意図
仮データだけでなく、実際の記録でも写真付きの体験を残せるようにするため。favorecoは写真が主役の体験記録アプリなので、入力アコーディオンの次に写真ユニットを接続し、Home/詳細で見返す流れを早期に確認できるようにした。写真メタデータ削除方針に合わせ、保存時は元データをそのまま持たず、再エンコードした画像データを保存する。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（写真選択・サムネイル・削除・PhotoBlob保存）
- favorecoAPP/favorecoAPP/Views/ExperienceDetailView.swift（複数写真表示）
- favorecoAPP/favorecoAPP/Utilities/RecordUnitDefinition.swift（写真/公式情報ユニットを実装済みに変更）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/favorecoDerivedPhotoUnit build` 成功。

### 残課題
- カメラ直起動、カバー写真指定、写真の並び替え、動画サムネイル、バックグラウンド画像処理は未実装。
- 写真メタデータ削除は再エンコードで落とす方針の初期実装。今後、ImageIOでの明示的なメタデータ除去確認を追加する。
- 写真上限10枚はUI表示のみ。将来の課金/権利判定と厳密に接続する。

## 2026-07-10: 入力アコーディオン土台と仮データ削除/写真表示を追加

### 変更概要
- `AddExperienceView` / `EditExperienceView` / `AddVisitView` を、ユニット単位の `DisclosureGroup` で入力する土台に変更した。
- `basic`、`officialInfo`、`memo` は既存保存項目に接続し、`people`、`ticketPlan`、`photos`、`importOCR`、`money`、`advanced` は準備中ユニットとして表示するようにした。
- 各ユニットに、必須/入力済み/任意/準備中のステータスを表示した。
- `DebugDataSeeder` の仮データ挿入を、先頭4ジャンルではなく全ジャンルに1件ずつ作るように変更した。
- 仮データ挿入前に既存の仮データを削除し、重複して増え続けないようにした。
- 設定の開発セクションに `仮データを削除` ボタンを追加した。
- 仮データ写真を1px PNGではなく、ジャンル色のPNGとして生成して `PhotoBlob.data` に保存するようにした。
- Homeの体験ギャラリーと記録詳細で、先頭の `PhotoBlob.data` を実画像として表示するようにした。

### 変更意図
ジャンルごとに入力項目が長くなる前提に合わせ、早い段階でMystorium同様の折りたたみ入力構造へ移行するため。仮データは画面確認用なので、各ジャンルに最低1件あり、写真が実際に見える必要がある。追加だけで削除できないと検証データが増え続けるため、通常データと区別できるデバッグURL/パスを使って安全に削除できるようにした。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（入力アコーディオン土台）
- favorecoAPP/favorecoAPP/Services/DebugDataSeeder.swift（全ジャンル仮データ、写真生成、削除処理）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（仮データ削除ボタン）
- favorecoAPP/favorecoAPP/Views/HomeView.swift（ギャラリー写真表示）
- favorecoAPP/favorecoAPP/Views/ExperienceDetailView.swift（詳細写真表示）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/favorecoDerivedAccordionDebug build` 成功。

### 残課題
- `people`、`ticketPlan`、`photos`、`importOCR`、`money`、`advanced` の実入力UIを順番に接続する。
- 仮データ写真のデザインは検証用の簡易画像なので、本番サンプル用には後でカテゴリ別の見栄えを調整する。
- 仮データ削除はデバッグ用URL/パスのみを対象にしているため、将来のデバッグデータ拡張時は同じ識別ルールを守る。

## 2026-07-10: 課金・プラン画面に無料/有料境界を表示

### 変更概要
- `BillingPlanSettingsView` に、無料で使えること、Pro買い切り候補、同期サブスク候補、フル買い切り候補の表示を追加した。
- 無料枠には、基本記録、写真10枚、カレンダー手動追加/追加先選択、手動バックアップを明記した。
- Pro買い切り候補には、詳細統計/年間まとめ、OCR高度化、テーマ/フォント拡張を表示した。
- 同期サブスク候補には、iCloud同期、自動バックアップ、継続更新される入力補助/参照データ候補を表示した。
- フル買い切り候補には、ライト買い切り+同期永久の頭金方式を表示した。
- StoreKitは未接続のまま、購入/復元は入口のみ維持した。

### 変更意図
課金実装前に、ユーザーにも開発側にも無料/有料の境界が見える状態にするため。購入処理を先に作ると後から文言やプラン構造を変えづらいため、まず設定画面に仕様を反映し、アプリ内の情報設計を固める。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（課金・プラン画面の境界表示追加）
- favoreco/CLAUDE.md（課金・プラン画面の現仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/favorecoDerivedBillingPlan build` 成功。

### 残課題
- StoreKit商品ID、価格、購入復元、権利判定を実装する。
- 実際の無料制限、Pro解放、同期サブスク解放を機能フラグに接続する。
- DBパックの扱いは、参照データの権利/規約/更新コスト確認後に確定する。

## 2026-07-10: 新ユニットID採用と人物/場所リンクモデルを追加

### 変更概要
- `RecordUnitDefinition` を、`basic` / `people` / `ticketPlan` / `photos` / `importOCR` / `money` / `officialInfo` / `memo` / `advanced` の9ユニットへ更新した。
- 旧 `U1` / `U3` / `U4` などの `enabledUnitsRaw` が残っていても新ユニットへ読み替える互換マップを追加した。
- `CategoryPresetSeeder` の標準ジャンル初期ユニットを、確定済みのジャンル別構成へ更新した。
- 自作ジャンル追加のテンプレ初期値も新ユニットIDへ更新した。
- `EventPersonLink` を追加し、人物/団体と `ExperienceEvent` / `Visit` の関係役割をリンク側に保存できるようにした。
- `Visit.placeMaster` を追加し、会場スナップショットを残したまま `PlaceMaster` へ参照できるようにした。
- OCR高度化はPro買い切り候補に寄せる方針を正本仕様へ反映した。

### 変更意図
入力アコーディオンの標準構成が固まったため、古いU番号ベースの実装を早めに整理し、標準ジャンル・自作ジャンル・設定画面で同じユニット語彙を使えるようにするため。人物/団体は作品・回ごとに役割が変わるため、マスター本体ではなく中間リンクに役割を持たせる。場所は過去記録を壊さないよう、既存の会場名/座標スナップショットを残しつつマスター参照を足した。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Utilities/RecordUnitDefinition.swift（新ユニットIDと旧ID互換マップ）
- favorecoAPP/favorecoAPP/Services/CategoryPresetSeeder.swift（標準ジャンル初期ユニット更新）
- favorecoAPP/favorecoAPP/Views/GenreManagementView.swift（自作ジャンル初期ユニット更新）
- favorecoAPP/favorecoAPP/Views/CategoryTopView.swift（プレビューのユニットID更新）
- favorecoAPP/favorecoAPP/Models/CoreModels.swift（`EventPersonLink` と `Visit.placeMaster` 追加）
- favorecoAPP/favorecoAPP/favorecoAPPApp.swift（Schema登録）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/favorecoDerivedUnitLinks build` 成功。

### 残課題
- `EventPersonLink` と `PlaceMaster` を使う入力/詳細/統合UIを実装する。
- 課金・プラン画面に無料/Pro/Premium境界の表示を追加する。
- 記録入力アコーディオンを本実装し、各ユニットの入力項目をジャンル別に接続する。

## 2026-07-09: 無料/有料境界表とPerson/Place最小モデルを追加

### 変更概要
- 無料/Pro買い切り候補/Premium候補の境界を表に整理した。
- 無料は、基本記録、写真10枚、URL/動画リンク保存、カレンダー手動追加/追加先選択、基本統計、手動バックアップまで広めに扱う方針にした。
- Premium候補は、同期/自動バックアップ、外部候補補助、高度取込、OCR高度化、カレンダー片方向自動更新/一括追加を中心にした。
- `PersonMaster` の最小SwiftDataモデルを追加した。
- `PlaceMaster` の最小SwiftDataモデルを追加した。
- アプリSchemaに `PersonMaster` / `PlaceMaster` を登録した。
- カレンダーのv1範囲を、手動追加/追加先選択に加えて、外部カレンダー予定の読み取り重ね表示までにした。
- 動画のv1範囲を、外部リンク保存、Photos参照、サムネイル表示までにした。

### 変更意図
企画で決まった無料/有料境界を一覧化し、後から課金設計で迷わないようにするため。人物・会場は横断マスターとして後続の入力補助、重複統合、サマリーカード、統計に効くため、まずCloudKit互換の最小モデルだけを追加した。カレンダーと動画は、便利さと実装/容量コストのバランスを取り、v1の現実的な範囲を明確にした。

### 主な変更ファイル
- favoreco/CLAUDE.md（無料/有料境界表、カレンダーv1範囲、動画v1範囲を更新）
- favorecoAPP/favorecoAPP/Models/CoreModels.swift（`PersonMaster` / `PlaceMaster` 追加）
- favorecoAPP/favorecoAPP/favorecoAPPApp.swift（Schema登録）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/favorecoDerivedPersonPlace build` 成功。

### 残課題
- `PersonMaster` / `PlaceMaster` と `ExperienceEvent` / `Visit` を結ぶリンクモデルを設計する。
- 重複候補UI、統合UI、外部候補取得UIを実装する。
- 外部カレンダー読み取り重ね表示と動画サムネイルの実装を行う。

## 2026-07-09: 美術展ユニット/関係タイプ/サマリーカード方針を確定

### 変更概要
- 美術展の初期有効ユニットを、基本情報、人物・団体、チケット・予定、写真、OCR・取込、公式情報、メモに決定した。
- 人物/団体を記録に紐付ける時は、PersonMaster自体の固定種別だけでなく、紐付け側に関係タイプ/役割を持つ方針にした。
- 関係タイプの初期セットを、アーティスト、出演、主演、作家、作者、監督、脚本、演出、原作、音楽、演奏、翻訳、キュレーター、主催、制作、出版社、ゲスト、その他にした。
- Home/一覧/サマリーカードの共通ベースを、カバー写真、ジャンル色/アイコン、タイトル、日付、場所、人物/団体1〜2件、評価またはステータス、短いメモ1行にした。
- ジャンル別サマリー案として、観劇/ライブ、映画、本、美術展、酒、御朱印、テーマパーク/おでかけの表示項目を整理した。

### 変更意図
美術展は作品や会場だけでなく、作家、キュレーター、主催などの関係者が記録価値になるため人物・団体ユニットを初期ONにする。人物/団体はジャンルを横断するため、マスター自体に役割を固定せず、各記録との関係として役割を持つ。サマリーカードは実装後に精査する前提で、まずジャンルごとの情報優先度を揃える。

### 主な変更ファイル
- favoreco/CLAUDE.md（美術展初期ユニット、関係タイプ、サマリーカード方針を追加）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- ドキュメントのみ。ビルド対象なし。

### 残課題
- `RecordUnitDefinition` とカテゴリseedを今回の初期有効ユニットへ合わせる。
- PersonMaster/PlaceMaster実装時に、関係タイプを保存するリンクモデルを設計する。
- サマリーカードUIを実装後、実機で情報量と見た目を精査する。

## 2026-07-09: カレンダー追加先選択の方針を追加

### 変更概要
- 外部カレンダー書き出しのUI文言を、`iOSカレンダーに追加` ではなく `カレンダーに追加` として扱う方針にした。
- `カレンダーに追加` ボタン押下後、初回はEventKit権限を求め、追加先はiOSに登録されているカレンダー一覧から選ぶ方針にした。
- Googleカレンダーも、iOS標準カレンダーに登録済みで書き込み可能なら追加先として表示される扱いにした。
- 次回以降は最後に使ったカレンダーを初期選択し、設定で既定の追加先カレンダーを変更できるようにする方針にした。
- 無料は手動追加と追加先選択まで、Premium候補はfavorecoで作った予定の片方向自動更新、一括追加、自動で既定カレンダーへ追加とした。

### 変更意図
ユーザー視点ではApple/Googleのブランド名より「どのカレンダーに入れるか」が重要。EventKit経由ではiOSに登録されたカレンダー一覧を扱うため、Google Calendar APIを直接使わず、iCloud/Google/共有カレンダーを同じUIで選べる形にする。

### 主な変更ファイル
- favoreco/CLAUDE.md（カレンダー追加先選択と無料/Premium境界を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- ドキュメントのみ。ビルド対象なし。

### 残課題
- EventKitで取得したカレンダー一覧の表示名、アカウント種別、書き込み可否の見せ方を設計する。
- 既定の追加先カレンダー保存キーを追加する。

## 2026-07-09: 会場マスター/iOSカレンダー書き出し/動画方針を追加

### 変更概要
- 会場/場所は横断の `PlaceMaster` として扱い、劇場、ライブ会場、映画館、美術館、寺社、酒蔵、飲食店、施設などをタグ/種別で切り分ける方針にした。
- 会場の重複候補は、名称、住所、座標、よみ、公式URLから判定し、「同じ会場の可能性があります」と提示してユーザー確認で統合する方針にした。
- 無料制限は広めにし、1記録あたり写真10枚、URL保存、YouTube/PV/個人動画などの外部リンク保存、iOSカレンダーへの手動追加を無料にする方針にした。
- iOSカレンダー書き出しは、Mystorium同様にユーザーが押す「カレンダーに追加」ボタンから始める方針にした。
- EventKitで作成した外部カレンダーイベントの識別子を保存し、後から更新/削除できる余地を持たせる方針にした。
- 外部カレンダー予定の読み取り重ね表示、一括登録、変更追従、双方向同期は技術的には可能な範囲があるが、権限・重複・競合解決が重いためv2以降/有料候補にした。
- 動画は容量とiCloud同期負荷が大きいため、v1では外部リンク保存とPhotos参照/サムネ中心を基本にし、動画ファイルのアプリ内コピー/Cloud同期/バックアップ同梱は明示ON/容量警告つき、またはv2以降の有料候補とした。

### 変更意図
favorecoは会場・場所がジャンルをまたいで出てくるため、ジャンル別に分けず横断マスター化する方が統計や重複統合に強い。カレンダーはユーザーの標準カレンダーへ乗せられると便利だが、完全同期は複雑なため、まずMystoriumで実績のある手動追加を安全な土台にする。動画は思い出価値が高い一方で容量負荷が大きいため、リンク/参照を基本にして保存と同期は明示的に扱う。

### 主な変更ファイル
- favoreco/CLAUDE.md（PlaceMaster、無料制限、iOSカレンダー、動画方針を追加）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- ドキュメントのみ。ビルド対象なし。

### 残課題
- `PlaceMaster` の実モデル、重複候補判定、統合UIを実装する。
- EventKitの手動追加、外部イベントID保存、更新/削除導線を設計する。
- 動画をPhotos参照で扱う場合の権限、サムネ保存、バックアップ対象外の説明文を設計する。

## 2026-07-09: ジャンル別の初期有効ユニット方針を追加

### 変更概要
- 観劇/ライブは、基本情報、人物・団体、チケット・予定、写真、OCR・取込、金額、公式情報、メモを初期有効にする方針にした。
- 映画は、基本情報、人物・団体、写真、OCR・取込、公式情報、メモを初期有効にする方針にした。
- 本は、基本情報、人物・団体、写真、OCR・取込、メモを初期有効にする方針にした。
- 酒/御朱印は、基本情報、写真、OCR・取込、メモを初期有効にする方針にした。
- テーマパーク/おでかけ施設は、基本情報、チケット・予定、写真、OCR・取込、金額、公式情報、メモを初期有効にする方針にした。
- 美術展は未確定とし、作家/主催を重視する展示寄りにするか、施設訪問寄りに軽くするかを残課題にした。

### 変更意図
観劇/ライブはチケット・予定・金額まで必要な重い入力にする一方、酒/御朱印は軽く記録できる形を優先する。ジャンルごとの初期表示を変えることで、横断アプリでありながら最初の入力負荷をジャンルに合わせて調整する。

### 主な変更ファイル
- favoreco/CLAUDE.md（ジャンル別初期有効ユニット方針を追加）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- ドキュメントのみ。ビルド対象なし。

### 残課題
- 美術展の初期有効ユニットを決める。
- `RecordUnitDefinition` とカテゴリseedの実装を、今回の標準ユニット/初期有効ユニットへ合わせて更新する。

## 2026-07-09: DBパックは商品確定せず参照データ候補として検討に変更

### 変更概要
- DBパック単体販売を、現時点で確定商品にせず検討扱いに変更した。
- 課金・プランは、無料 / Pro買い切り / Premiumサブスクを主軸にし、DBパックは実データの権利/規約/更新コストを確認してから判断する方針にした。
- 有名な寺社、ライブ会場、劇場、施設などの公開性が高く安定したスポット/会場データや、御朱印の印種別、酒のスペック、OCR補助語彙などの辞書・プリセットを参照データ候補として残した。
- 取得・同梱・再配布・キャッシュ・有料提供の可否が確認できないデータはDBとして持たない方針を明記した。
- 記録は参照データに依存させず、名称/住所/座標などをユーザー記録へスナップショット保存する方針を維持した。

### 変更意図
DBパックは実装してみないと価値・権利・保守コストが見えにくく、先に商品として固定すると危ない。寺社やライブ会場のように扱いやすそうなデータはあるが、ジャンルごとに条件が違うため、まずは入力補助/参照データ候補として扱い、持てるものだけを安全に採用する。

### 主な変更ファイル
- favoreco/CLAUDE.md（DBパック/参照データ方針を検討扱いに更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- ドキュメントのみ。ビルド対象なし。

### 残課題
- ジャンルごとに、利用可能な参照データソースとライセンス/規約を確認する。
- 参照データをPremiumに含めるか、買い切りパック化するか、無料の入力補助に留めるかを実装前に判断する。

## 2026-07-09: 入力アコーディオンの標準ユニット構成を更新

### 変更概要
- 記録追加/編集フォームの標準アコーディオンを、基本情報 / 人物・団体 / チケット・予定 / 写真 / OCR・取込 / 金額 / 公式情報 / メモ / 詳細オプションに整理した。
- 会場・住所・日付・種別・評価はイベント/訪問の核なので、場所ユニットではなく基本情報に含める方針にした。
- 写真と半券/OCRは分け、写真はギャラリー/思い出、OCR・取込は半券/チケット/レシート/リスト画像からの読み取りに寄せる方針にした。
- 公式URL、SNS投稿リンク、参考URLは、メモではなく公式情報ユニットとして分離する方針にした。

### 変更意図
入力画面が長くなるジャンルでも迷わないように、情報の性質でユニットを分けるため。会場や住所は記録の基本軸であり、写真/OCR/公式リンクは用途が違うため、同じブロックに混ぜない方がジャンル別ON/OFFや将来の自動取込にもつなげやすい。

### 主な変更ファイル
- favoreco/CLAUDE.md（入力アコーディオン標準構成を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- ドキュメントのみ。ビルド対象なし。

### 残課題
- `RecordUnitDefinition` の既存ユニット名/説明を、今回の標準構成に合わせて実装側で更新する。
- 各ジャンルの初期有効ユニット（映画/観劇/本/御朱印/酒など）を決める。

## 2026-07-09: 人物マスター統合と外部候補優先順位を決定

### 変更概要
- 人物/アーティストマスターはジャンル別DBに分けず、Mystoriumの制作団体マスター同様に横断DBとして扱う方針にした。
- 人物の種別は固定カテゴリだけで分断せず、タグ/役割で「アーティスト」「俳優」「作家」「監督」「演者」などを表現する方針にした。
- 重複統合は最初から必要な機能とし、保存時/検索時に「似た人物があります」と提示し、ユーザー確認で統合できるUIを用意する方針にした。
- 外部候補は正確性の高いソースを優先し、音楽=Apple Music / MusicBrainz / Wikidata、映画=TMDb / Wikidata、本=国会図書館系 / Open Library、観劇=手入力中心 + 公式URL/OCRを基本候補にした。
- 記録詳細画面は保存情報を原則すべて表示し、Home/一覧/サマリーカードは厳選情報だけを表示する方針にした。

### 変更意図
人物はジャンルをまたいで登場するため、音楽・映画・観劇・本で別々に持つと重複と統計分断が起きる。横断DBにしてタグ/役割で文脈を表すことで、「この人の映画」「この人の舞台」「この人の本」などをあとから自然に集計できる。外部DBは入力補助として使い、正確性と権利確認を優先する。

### 主な変更ファイル
- favoreco/CLAUDE.md（人物マスター統合、タグ/役割、外部候補優先、詳細/サマリー方針を追加）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- ドキュメントのみ。ビルド対象なし。

### 残課題
- 重複候補の判定条件（表記ゆれ、よみ、外部ID一致、同一ジャンル内の近似名）を設計する。
- 統合時にVisit/ExperienceEvent/出演・関係リンクが壊れないよう、リレーション移行手順を設計する。
- 外部ソースごとの利用規約、画像利用、キャッシュ可否を実装前に確認する。

## 2026-07-09: 人物/アーティストマスターの必須/任意項目方針を追加

### 変更概要
- `PersonMaster` は、表示名と種別/役割だけで保存できる最小マスターとして扱う方針にした。
- 別名、メモ、公式URL、SNSはDB必須にせず、詳細オプション/アコーディオンで扱う方針にした。
- MusicBrainz ID、Wikidata QID、Apple Music IDなどの外部IDは、ユーザー入力項目ではなく、候補取得・名寄せ用のoptional内部IDとして扱う方針にした。
- 無料/ローカルではユーザーが記録した人物の再利用、Premium/サブスクでは外部候補読み込みを入力補助としてONにする方向にした。
- 写真メタデータ削除はON固定とし、GPS/Exif等は写真ファイルから削除、訪問日・会場・天気などは `Visit` 側で管理する方針を追記した。

### 変更意図
人物マスターを最初から巨大なタレント名鑑として作ると、実装・保守・権利確認・名寄せが重くなる。まずはユーザーの記録から育つ個人用マスターを正本にし、外部DBは候補提示と補助に限定することで、入力の楽さとデータの安全性を両立する。

### 主な変更ファイル
- favoreco/CLAUDE.md（人物/アーティストマスターと外部候補補助の方針を追加）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- ドキュメントのみ。ビルド対象なし。

### 残課題
- `PersonMaster` の実モデル、検索UI、重複統合UIを実装する。
- 外部候補取得に使うソース（MusicBrainz / Wikidata / Apple Music等）の利用規約、画像利用、キャッシュ可否を実装前に確認する。
- Premium/サブスクでどこまで候補補助を開放するか、DBパック単体販売との境界を確定する。

## 2026-07-09: 公演前日/当日通知だけ初期ONに変更

### 変更概要
- 通知初期設定を、公演前日/当日だけ初期ONに変更した。
- 申込締切、当落、入金、発券、FC・会員期限、思い出リマインダーは引き続き初期OFFで、ユーザーが必要なものを選ぶ方針にした。
- iOS通知許可は起動直後に求めず、通知を有効化する操作やチケット/予定作成時に用途を説明してから求める方針は維持した。

### 変更意図
申込/入金/発券などの実務通知はうるさくなりやすいためユーザー選択にする。一方で、公演前日/当日は体験直前のリマインドとして自然で、記録アプリとしての安心感にもつながるため標準で助ける。

### 主な変更ファイル
- favoreco/CLAUDE.md（通知初期設定方針を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- ドキュメントのみ。ビルド対象なし。

### 残課題
- `NotificationSettingsView` に、公演前日/当日の初期ONと各通知タイプ別ON/OFFを実装する。

## 2026-07-09: Mystorium課金4プラン構造を参照モデルとして追加

### 変更概要
- Mystoriumの同期実装後4プラン構造を、favorecoの課金設計の参照モデルとして `favoreco/CLAUDE.md` に追記した。
- 構造は、無料 / ライト買い切り¥1,500 / 同期サブスク月¥250・年¥1,500 / フル買い切り¥6,000。
- フル¥6,000は、ライト¥1,500 + バックアップ・同期永久¥4,500 の頭金方式とし、どの購入ルートでも合計が揃う考え方を記録した。
- 創設メンバー特典として、既存¥980ユーザー＋発売締切までの新規購入者に同期永久無料を付与する考え方を記録した。
- favorecoはDBパック単体販売が加わるため、最終命名（Pro/Premium vs ライト/フル）とDBパックの関係は実装前に確定する残課題とした。

### 変更意図
Mystoriumで整理済みの「買い切り主役＋控えめサブスク＋頭金方式」を、favorecoの課金設計でも再利用できるようにするため。一方でfavorecoは参照DB/DBパックがあるため、Mystorium構造をそのままコピーせず、転用時の論点も残す。

### 主な変更ファイル
- favoreco/CLAUDE.md（Mystorium課金モデル参照を追加）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- ドキュメントのみ。ビルド対象なし。

### 残課題
- favorecoの最終プラン名を Pro/Premium 系にするか、ライト/フル 系に寄せるか決める。
- DBパック単体販売をライト/フル/サブスクとどう並べるか決める。
- 無料ティアの写真枚数（3〜5枚）を確定する。

## 2026-07-09: 通知初期設定はユーザー選択に決定

### 変更概要
- 申込締切、当落、入金、発券、公演前日/当日、FC・会員期限、思い出リマインダーは初期ONにせず、ユーザーが必要なものを選ぶ方針にした。
- iOS通知許可は起動直後に求めず、通知を有効化する操作やチケット/予定作成時に、用途を説明してから求める方針にした。

### 変更意図
通知はチケット/予定管理の価値に直結する一方で、最初から多く鳴るとアプリの印象が悪くなる。必要な通知だけユーザーが選ぶ形にして、通知の信頼性と快適さを優先する。

### 主な変更ファイル
- favoreco/CLAUDE.md（通知初期設定方針を追加）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- ドキュメントのみ。ビルド対象なし。

### 残課題
- `NotificationSettingsView` に、通知タイプ別のON/OFFと通知許可説明UIを実装する。

## 2026-07-09: リンク/サポートと規約置き場方針を追加

### 変更概要
- 利用規約、プライバシーポリシー、問い合わせページの正本をRANOVIQO公式ドメイン配下に置く方針にした。
- 問い合わせは公式Xを主導線にしてよいが、App Store審査、削除依頼、プライバシー問い合わせ、法務連絡のためにメールまたはフォームの恒久窓口もRANOVIQOドメイン側に置く方針にした。
- 公式SNSはXを置き、InstagramはFacebookログイン制約があるため現時点では置かない方針にした。
- 規約/プライバシーポリシー草案で扱う項目として、写真メタデータ削除、位置情報、同期/iCloud、手動バックアップ、Apple Music連携、MapKit、WeatherKit、参照DB、課金/サブスク/DBパック、問い合わせ/削除依頼を列挙した。

### 変更意図
SNSはユーザーとの距離が近くサポート導線として使いやすいが、規約やプライバシー問い合わせには恒久URLと安定した窓口が必要になる。アプリ・デザイン・写真活動をRANOVIQO屋号に集約する前提で、アプリ内には入口を置き、正本はRANOVIQOドメインに集約する。

### 主な変更ファイル
- favoreco/CLAUDE.md（リンク/サポートと規約置き場方針を追加）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- ドキュメントのみ。ビルド対象なし。

### 残課題
- RANOVIQOドメイン上のURL構成を確定する。
- 利用規約/プライバシーポリシー/問い合わせページの草案を作成する。

## 2026-07-09: 課金/マイ/テーマ設定方針を追加

### 変更概要
- 課金・プランを、無料 / Pro買い切り / Premiumサブスク / DBパック単体販売の4層で整理した。
- Pro買い切りは、ローカルのフル機能所有（自作カテゴリ、詳細統計、年間まとめ、エクスポート、上限緩和、買い切りテーマ/フォント等）を担う方針にした。
- Premiumサブスクは、iCloud同期、自動バックアップ、継続更新される参照DBアクセス、月次/年次リキャップ、思い出再提示、限定テーマ/フォントなど継続価値を担う方針にした。価格感はMystorium参考で月額200〜250円、年額1,500円前後を仮説にした。
- DBパック単体販売は、特定カテゴリの参照DBを買い切りで使いたい人向けの選択肢として残した。
- マイ領域に、プロフィール/SNSだけでなく、FC・プレイガイド・劇場会員・カード枠・外部カレンダー連携を含める方針にした。
- フォントは基本固定（Noto Sans JP / Noto Serif JP / Cormorant Garamond）とし、将来のフォント変更はPro/Premium側のカスタマイズ候補にした。
- Home表示設定は、将来ファーストビューの優先表示を選べる余地を残す方針にした。
- テーマは、標準では白ベース＋ジャンル色アクセント、全体テーマONでは全体統一、個別テーマONではジャンルごとのテーマ/色世界を設定できる方針にした。高度な個別テーマはPro/Premium候補にした。

### 変更意図
Mystoriumの「買い切り主役＋控えめサブスク」を参考にしつつ、favorecoでは横断ジャンル・参照DB・同期/バックアップがあるため、所有価値と継続価値を分けて課金設計するため。チケット/観劇/ライブ管理では登録情報・連携が重要になるため、マイ領域に早めに受け皿を作る。

### 主な変更ファイル
- favoreco/CLAUDE.md（課金/マイ/テーマ設定方針を追加）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- ドキュメントのみ。ビルド対象なし。

### 残課題
- Pro/Premium/DBパックの最終価格、無料制限、買い切りDBパックの更新範囲を実装前に確定する。
- 設定画面に、登録情報・連携、テーマ、フォント、Home優先表示、プラン比較の具体UIを追加する。

## 2026-07-09: 同期/バックアップ境界と削除系設定方針を確定

### 変更概要
- 同期・バックアップの無料/有料境界を、ローカル手動書き出しバックアップは無料、iCloud同期/自動バックアップは有料寄りとした。
- データ管理に、キャッシュ削除、写真キャッシュ削除、アーカイブデータ削除、全データ削除の削除系入口を置く方針にした。
- 不可逆操作は通常導線から一段深く置き、確認文言入力/二段階確認などの誤操作防止を必須にした。

### 変更意図
ユーザーの記録が端末内に閉じ込められないよう、Mystorium同様の手動バックアップは無料の安全網として残すため。一方で、継続的なiCloud同期や自動バックアップは運用コストがかかるため有料寄りにする。削除系は必要だが危険なので、データ管理に集約しつつ誤操作防止を設計条件にする。

### 主な変更ファイル
- favoreco/CLAUDE.md（同期/バックアップ境界と削除系設定方針を追加）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- ドキュメントのみ。ビルド対象なし。

### 残課題
- `DataManagementView` に削除系の実UIを追加する。
- `SyncBackupSettingsView` / `BillingPlanSettingsView` に無料/有料境界がわかる表示を追加する。

## 2026-07-09: 入力/編集フォームのアコーディオン方針を追加

### 変更概要
- 記録追加/編集フォームは、Mystorium同様にユニット単位のアコーディオンUIを基本方針にした。
- 基本情報、写真/半券、チケット、リスト/OCR、場所/天気、金額、メモなどを折りたたみ可能なブロックとして扱う方針を `favoreco/CLAUDE.md` に追記した。
- 保存後は編集画面ではなく記録詳細画面へ戻る前提を明記した。

### 変更意図
favorecoはジャンルごとに入力項目が大きく変わり、観劇・ライブ・パーク・酒・本などでは編集画面が長くなりやすい。最初からユニット単位の折りたたみ前提にしておくことで、入力負荷を抑えつつ、後からチケット/OCR/写真/金額などを追加しやすくするため。

### 主な変更ファイル
- favoreco/CLAUDE.md（入力/編集フォームのアコーディオン方針追加）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- ドキュメントのみ。ビルド対象なし。

### 残課題
- `AddExperienceView` / `EditExperienceView` の実UIはまだ最小フォーム。次の入力フォーム改修でアコーディオンUIへ移行する。

## 2026-07-09: 記録・入力補助設定を追加

### 変更概要
- 設定トップに `記録・入力補助` セクションを追加した。
- `RecordInputAssistSettingsView` を追加し、記録の初期値、写真、入力補助、後日検討の4ブロックに整理した。
- デフォルト記録日を「今日」、デフォルトジャンルを「最後に使ったジャンル / Homeで選択中のジャンル」、記録追加後を「詳細を開く」にした。
- 写真追加の初期動作を「カメラを開く / 写真ライブラリを開く」、写真圧縮を「85% / 65%」から選べるようにした。
- URL取込候補、OCR取込、Map検索、天気自動付与、入力補助辞書のON/OFFを追加した。
- Apple Music連携はV2以降で検討として表示だけにした。

### 変更意図
favorecoの勝ち筋である「記録の楽さ」を設定として育てられるようにするため。記録フォームそのものではなく、記録時の初期値・入力補助・自動取得の好みをまとめる場所として定義した。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（記録・入力補助画面追加）
- favorecoAPP/favorecoAPP/Utilities/AppStorageKeys.swift（記録・入力補助用キー追加）
- favoreco/CLAUDE.md（現在仕様を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- 各設定値は保存するが、記録追加画面・写真処理・URL/OCR/Map/天気取得への実接続は未実装。
- Apple Music連携は重さ、権限、画像利用、同名アーティスト問題を踏まえてV2以降で検討する。

## 2026-07-09: 設定トップ構造を確定形に近づけた

### 変更概要
- `SettingsView` のトップセクションを マイ / 表示 / ジャンル / 通知 / データ管理 / 同期・バックアップ / 課金・プラン / リンク・サポート / 開発 に整理した。
- `NotificationSettingsView` を追加し、申込開始/締切、当落、入金、発券、公演前日/当日、FC・会員期限、思い出リマインダーの入口を置いた。
- `SyncBackupSettingsView` を追加し、iCloud同期、自動バックアップ、復元、同期トラブル診断をデータ管理から分離した。
- `BillingPlanSettingsView` を追加し、現在のプラン、アップグレード、購入復元、Pro機能一覧、DBパック管理の入口を置いた。
- `SupportLinksView` を追加し、公式サイト、規約、プライバシーポリシー、問い合わせ、レビュー、シェア、公式SNSをまとめた。

### 変更意図
ユーザー確認で合意した設定カテゴリに合わせ、今後の実装が散らからないように器を先に確定するため。記録入力設定は検討中のため、今回のトップ構造には入れない。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（設定トップと各サブ設定入口）
- favoreco/CLAUDE.md（設定画面の現在仕様を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- 通知、同期、バックアップ、課金、外部リンク、レビュー/シェアはプレースホルダー。
- 記録入力設定は何を含めるか検討中。

## 2026-07-09: 表示設定分離とデータ管理/リンク入口を追加

### 変更概要
- `SettingsView` を マイ / 表示 / ジャンル / データ管理 / リンク / 開発 にセクション整理した。
- Home表示ON/OFFを `SettingsView` 直下から `DisplaySettingsView` に移動した。
- `DataManagementView` を追加し、記録/写真/Inbox/ジャンル/対象の件数表示、同期プレースホルダー、JSON/CSVインポート/エクスポート入口、バックアップ説明を置いた。
- リンクセクションを追加し、利用規約 / プライバシーポリシー / お問い合わせの入口を作った。
- デバッグ用の写真付き仮データ追加ボタンを開発セクションへ整理した。

### 変更意図
設定画面が今後、同期・バックアップ・課金・規約・表示調整を受け止められるように、先に器を分けておくため。2/3/4は入口中心に留め、実データを変更する処理はまだ接続しない。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（設定セクション整理、表示設定/データ管理/リンク入口追加）
- favoreco/CLAUDE.md（実装状態と重要ルールを更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- iCloud同期、JSON/CSVインポート/エクスポート、規約本文、問い合わせ導線はプレースホルダー。
- 文字サイズ、外観モードは表示のみで未実装。
- 設定画面のセクション整理は入れたが、課金/同期/通知などの詳細設計は次以降で詰める。

## 2026-07-09: Home上部の横断ミニ統計を実装

### 変更概要
- `HomeView` のHero直下に横断ミニ統計を追加した。
- 指標は `今後の予定`、`今年の記録`、`総記録数` の3つにした。
- 現時点では `今後の予定` を未来日Visit数、`今年の記録` を今年のVisit数、`総記録数` を全Visit数として集計する。
- `HomeMiniStatCell` を追加し、3カラムでコンパクトに表示するようにした。

### 変更意図
Mystoriumで実績のある「開いてすぐ全体感がわかる」導線をfavorecoにも入れるため。ジャンル横断アプリなので、Home上部に全体の予定/今年/累計が見えると、アテンションや体験ギャラリーへ入る前に現在地が掴みやすい。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/HomeView.swift（横断ミニ統計追加）
- favoreco/CLAUDE.md（実装状態を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- Plan / TicketAttempt モデル追加後、`今後の予定` は未来日VisitではなくPlan中心の集計へ切り替える。
- 横断ミニ統計は常設表示。将来、表示設定に含めるかは運用後に判断する。

## 2026-07-09: Home表示設定と体験ギャラリーを実装

### 変更概要
- Homeの固定表示順を、アテンション / 体験ギャラリー / あとで記録 / 最近の記録 / ジャンル一覧 / 統計サマリ / お気に入り・ベストにした。
- `SettingsView` に `Home表示` セクションを追加し、各HomeセクションをON/OFFできるようにした。
- `AppStorageKeys` にHome表示用キーを追加した。
- `HomeView` にアテンション枠を追加した。現状は未来日Visitと未整理Inboxを表示する。
- `HomeView` に体験ギャラリー枠を追加した。現状は最近のVisitを横スクロールカードで表示する。
- 統計サマリとお気に入り/ベストは初期OFFのプレースホルダーとして用意した。

### 変更意図
Homeを「やることが見える実用の入口」と「開いた瞬間に体験棚が見えてテンションが上がる入口」の両方にするため。並び替えは入れず、固定順とON/OFFだけにして設定を重くしすぎない。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/HomeView.swift（Homeセクション追加・固定順表示）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（Home表示ON/OFF追加）
- favorecoAPP/favorecoAPP/Utilities/AppStorageKeys.swift（Home表示キー追加）
- favoreco/CLAUDE.md（実装状態を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- アテンションの本命である申込締切、当落、入金、発券、会員期限、通知リマインダーの専用モデルは未実装。
- 体験ギャラリーは写真データの実表示ではなく、現状は色付きカードとSF Symbol表示。
- Homeセクションの並び替えは未実装。必要になるまで固定順で運用する。

## 2026-07-09: 自作ジャンル作成を実装

### 変更概要
- `RecordCategory` に自作ジャンル用の `templateTypeKey`、`targetNameLabel`、`recordUnitName`、`dateLabel` を追加した。
- ジャンル管理の右上 `+` から `AddCustomGenreView` を開き、自作ジャンルを追加できるようにした。
- 自作ジャンル作成時に、表示名、アイコン、テーマカラー、テンプレタイプ、呼び名、有効ユニットを設定できるようにした。
- テンプレタイプは鑑賞系 / 訪問系 / 読書系 / コレクション系 / 飲食系 / 自由の6種類にした。
- `GenreDetailSettingsView` でもテンプレタイプ、呼び名、有効ユニットを編集できるようにした。
- `CategoryRecordTemplate` を更新し、自作ジャンルの入力フォーム文言を保存済みラベルから生成するようにした。
- `CategoryPresetSeeder.ensureAtLeastOneActiveCategory` を標準ジャンル限定ではなく全ジャンル対象にし、自作ジャンルだけが有効な場合に標準ジャンルが勝手に復帰しないようにした。

### 変更意図
標準ジャンルだけでなく、ユーザーの趣味や生活に合わせた記録ジャンルを作れるようにするため。作成時は軽く始められ、あとから詳細設定で呼び名やユニットを育てられる構成にした。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Models/CoreModels.swift（RecordCategoryに自作ジャンル用フィールド追加）
- favorecoAPP/favorecoAPP/Views/GenreManagementView.swift（自作ジャンル追加・詳細編集拡張）
- favorecoAPP/favorecoAPP/Utilities/CategoryRecordTemplate.swift（自作ジャンル用フォーム文言生成）
- favorecoAPP/favorecoAPP/Utilities/RecordUnitDefinition.swift（必須ユニット/並び順ヘルパー）
- favorecoAPP/favorecoAPP/Services/CategoryPresetSeeder.swift（標準プリセットの新フィールド設定・最低1ジャンル補正）
- favoreco/CLAUDE.md（実装状態を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- アイコンはSF Symbol文字列入力のまま。将来ピッカー化する。
- 自作ジャンルの削除/複製は未実装。現状は非表示で運用する。
- ユニットON/OFFは入力フォームの出し分けまでは未接続。保存値と詳細表示/編集の土台まで。

## 2026-07-09: ジャンル管理v1を実装

### 変更概要
- `GenreManagementView` を追加し、設定からジャンル一覧を管理できるようにした。
- 表示/非表示を `RecordCategory.isArchived` で切り替え、最後の1件は非表示にできないようにした。
- 並び替えを `sortOrder` に保存し、Home / 追加導線 / ジャンル切替に効く土台にした。
- `GenreDetailSettingsView` で表示名、アイコン、テーマカラー、紐付けSNS一覧、有効ユニット一覧を確認/編集できるようにした。
- `RecordUnitDefinition` を追加し、`enabledUnitsRaw` を人間が読めるユニット名/説明に変換した。

### 変更意図
初回選択だけでなく、運用中にジャンルを育てられるようにするため。非表示は削除ではなく、記録は残しつつ入口から外す。テーマカラーやSNS紐付け、有効ユニットをジャンル単位で見られるようにして、年間まとめや自作ジャンルの土台にする。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/GenreManagementView.swift（ジャンル一覧・詳細設定）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（ジャンル管理導線追加）
- favorecoAPP/favorecoAPP/Utilities/RecordUnitDefinition.swift（有効ユニット定義）
- favoreco/CLAUDE.md（実装状態を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- 自作ジャンル追加は未実装。
- 有効ユニットは現時点では表示中心で、本格的なON/OFF制御は未実装。
- アイコン入力はSF Symbol文字列の直接入力。将来ピッカー化する。

## 2026-07-09: プロフィールSNS管理を実装

### 変更概要
- `SocialAccount` モデルを追加し、SNSアカウントを複数保存できるようにした。
- `SocialPlatform` を追加し、Instagram / X / Threads / Facebook の表示名、アイコン、ID/URL入力からのURL解決をまとめた。
- `ProfileSettingsView` を追加し、プロフィール設定内でSNS一覧、追加、編集、外部リンクオープンができるようにした。
- `EditSocialAccountView` を追加し、SNS種別、メモ/名前、IDまたはURL、ジャンル紐付け、用途メモを保存できるようにした。
- `SettingsView` にプロフィール導線を追加した。
- `ModelContainer` とプレビュー用modelContainerに `SocialAccount` を追加した。

### 変更意図
映画・観劇・本などジャンルごとに使い分けるSNSを、プロフィールの一部として登録できるようにするため。IDだけでもURLでも入力でき、タップで外部SNSへ飛べるようにして、記録アプリ内の自己紹介/公開導線の下地にする。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Models/CoreModels.swift（SocialAccountモデル追加）
- favorecoAPP/favorecoAPP/Utilities/SocialPlatform.swift（SNS種別とURL解決）
- favorecoAPP/favorecoAPP/Views/ProfileSettingsView.swift（SNS一覧・追加・編集）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（プロフィール導線追加）
- favorecoAPP/favorecoAPP/favorecoAPPApp.swift（ModelContainer更新）
- favoreco/CLAUDE.md（実装状態を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- プロフィール表示名・アイコン編集は未実装。
- SNSの並び替え、実機での外部アプリ遷移確認は未実施。

## 2026-07-09: 4タブ＋中央追加ボタンのルートナビを実装

### 変更概要
- `MainTabView` を追加し、Home / 記録 / カレンダー / 統計 の4タブ構成にした。
- 下部中央にタブではない大きな `+` ボタンを重ね、記録開始の常設導線にした。
- 中央 `+` から、有効ジャンルへの記録追加と `AddInboxItemView` によるあとで記録を選べるようにした。
- `ContentView` の初回完了後入口を `HomeView` から `MainTabView` に変更した。
- Home右上の設定ギア/Inbox追加ボタンを整理し、右上プロフィールアイコンから `SettingsView` を開くようにした。
- 記録 / カレンダー / 統計タブは、まず最小の一覧・プレースホルダーとして追加した。

### 変更意図
favorecoの主要導線を「横断Home」「横断記録一覧」「日付軸」「統計」に整理し、記録開始だけはMystorium同様に中央の `+` に集約するため。設定は下部タブに置かず、将来のマイ/プロフィール領域として右上プロフィールアイコンへ寄せる。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/MainTabView.swift（4タブルート・中央追加ボタン・記録/カレンダー/統計タブ）
- favorecoAPP/favorecoAPP/ContentView.swift（初回完了後入口をMainTabViewへ変更）
- favorecoAPP/favorecoAPP/Views/HomeView.swift（右上プロフィール入口へ整理）
- favoreco/CLAUDE.md（実装状態を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- 中央 `+` の見た目・タブバーとの重なりは実機でタップ領域を確認する。
- カレンダー / 統計はプレースホルダー。実データ表示は未実装。

## 2026-07-09: ジャンルトップ見出しスイッチャーを実装

### 変更概要
- `CategoryTopView` のヒーロー見出しを、ジャンル名 + 下向きアイコンのスイッチャーにした。
- 見出しタップで有効ジャンル一覧のメニューを開き、別ジャンルの `CategoryTopView` へ遷移できるようにした。
- 画面全体スワイプではなく、見出しの明示操作でジャンル切り替えする設計にした。
- `favoreco/CLAUDE.md` に現在の画面構成を反映した。

### 変更意図
favorecoはページ内ユニットで横スクロールを多用する想定のため、画面全体の横スワイプによるジャンル遷移は避ける。ジャンルトップの主役である見出しをそのまま切り替え導線にすることで、ノイズを増やさず現在地と移動先を両立する。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/CategoryTopView.swift（見出しスイッチャー追加）
- favoreco/CLAUDE.md（実装状態を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- 実機でメニューからのジャンル遷移感、戻る履歴の積まれ方を確認する。
- ジャンル数が多い場合の検索/並び替えは未実装。

## 2026-07-09: 初回ジャンル選択とデバッグデータ投入を実装

### 変更概要
- `GenreOnboardingView` を追加し、初回起動時に記録したい標準ジャンルをチェック選択できるようにした。
- 選択完了前は `ContentView` からオンボーディングを表示し、完了後に `HomeView` を表示するようにした。
- `CategoryPresetSeeder` を更新し、初回選択後にseedが全カテゴリを勝手に再表示しないようにした。
- 全ジャンルが非表示になった場合でも、先頭の標準カテゴリを復帰させる保険を入れた。
- `SettingsView` を追加し、初回ジャンル選択のやり直しと写真付き仮データ追加ボタンを置いた。
- `DebugDataSeeder` を追加し、有効ジャンルに対して `ExperienceEvent` / `Visit` / `PhotoBlob` / `InboxItem` の仮データを投入できるようにした。

### 変更意図
ユーザーごとに記録したいジャンルを絞れる初期導線を作るため。あわせて、Mystoriumで発生した「全チェック解除で起動不能」系の事故を避けるため、UIとseedの両方で最低1ジャンルが有効になるようにした。開発確認を速くするため、設定から写真付きサンプルデータを投入できるようにした。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/GenreOnboardingView.swift（初回ジャンル選択）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（設定・デバッグ入口）
- favorecoAPP/favorecoAPP/Services/DebugDataSeeder.swift（写真付き仮データ投入）
- favorecoAPP/favorecoAPP/Services/CategoryPresetSeeder.swift（選択状態保持・最低1ジャンル復帰）
- favorecoAPP/favorecoAPP/ContentView.swift（初回導線切替）
- favorecoAPP/favorecoAPP/Views/HomeView.swift（設定ボタン・空ジャンル表示）
- favorecoAPP/favorecoAPP/Utilities/AppStorageKeys.swift（AppStorageキー管理）
- favoreco/CLAUDE.md（実装状態を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- 実機で初回インストール状態の画面遷移確認は未実施。
- デバッグ投入した `PhotoBlob` の写真表示UIは未実装。現状はデータ投入確認用。

## 2026-07-09: Inboxから本記録への変換導線を実装

### 変更概要
- `InboxDetailView` を追加し、InboxItemの詳細確認、カテゴリ候補の選択、本記録への変換、削除ができるようにした。
- HomeのInbox行を詳細画面へのNavigationLinkにし、未解決Inboxだけを表示するようにした。
- `AddExperienceView` に初期Draftと保存時フックを追加し、InboxItemのタイトル / URL / メモを引き継げるようにした。
- `AddExperienceView` / `EditExperienceView` で公式URLを保存・編集できるようにした。
- `favoreco/CLAUDE.md` に現在の画面構成を反映した。

### 変更意図
Inboxを一時保存で終わらせず、記録作成の入口として使える状態にするため。既存の記録追加フォームを再利用し、保存時だけ `ExperienceEvent` / `Visit` とInboxItemの状態をまとめて更新する。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/InboxDetailView.swift（Inbox詳細・変換導線）
- favorecoAPP/favorecoAPP/Views/HomeView.swift（Inbox詳細遷移・未解決フィルタ）
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（初期Draft、保存フック、公式URL入力）
- favoreco/CLAUDE.md（実装状態を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- InboxItemから既存対象への回追加、予定/申込への変換は未実装。
- 変換完了後に詳細画面を自動的に閉じる/作成した記録へ遷移する導線は未実装。

## 2026-07-09: Inbox手動追加を実装

### 変更概要
- `AddInboxItemView` を追加し、あとで記録したい候補をタイトル / URL / カテゴリ候補 / メモで保存できるようにした。
- `HomeView` のツールバーにInbox追加ボタンを追加した。
- HomeのInbox行を、カテゴリ候補・URL有無・作成日・メモプレビューつきの表示にした。
- `favoreco/CLAUDE.md` に現在の画面構成を反映した。

### 変更意図
気になる作品・行きたい場所・飲みたい酒などを、本記録にする前に逃さず保存する入口を作るため。最初から `ExperienceEvent` / `Visit` を作らず、`InboxItem` として軽く受け止める。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/AddInboxItemView.swift（Inbox手動追加フォーム）
- favorecoAPP/favorecoAPP/Views/HomeView.swift（Inbox追加導線・Inbox行表示更新）
- favoreco/CLAUDE.md（実装状態を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- InboxItemから本記録 / 既存対象 / 予定への変換導線は未実装。
- URL正規化・OGP取得・OCR/共有シート取込は未実装。

## 2026-07-09: 対象編集画面を実装

### 変更概要
- `EditEventView` を追加し、対象自体のタイトル、シリーズ、公式URL、対象メモを編集できるようにした。
- `EventDetailView` のツールバーに対象編集ボタンを追加した。
- 対象詳細に対象メモと公式リンクの表示セクションを追加した。
- `favoreco/CLAUDE.md` に現在の画面構成を反映した。

### 変更意図
回ごとの記録編集だけでは、作品名・銘柄名・シリーズ名など対象そのものの修正ができないため。Event/Visit分離に合わせ、対象情報と回情報の編集責務を分ける。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/EventDetailView.swift（対象編集フォームと対象メモ表示追加）
- favoreco/CLAUDE.md（実装状態を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- 対象のアーカイブ、削除、代表アイキャッチ設定は未実装。
- 公式URLの正規化・入力バリデーションは未実装。

## 2026-07-09: 対象詳細画面を実装

### 変更概要
- `EventDetailView` を追加し、対象単位のカテゴリ、シリーズ、記録数、最新日、平均評価、履歴を表示できるようにした。
- 対象詳細から既存対象への回追加 `AddVisitView` を開けるようにした。
- 対象詳細の履歴から各 `ExperienceDetailView` へ遷移できるようにした。
- `CategoryTopView` の対象行を対象詳細へのNavigationLinkにした。
- `favoreco/CLAUDE.md` に現在の画面構成を反映した。

### 変更意図
カテゴリトップだけでは対象ごとの記録履歴を追いづらいため。作品・銘柄・本・施設などの単位で回を重ねる体験を、一覧ではなく詳細画面でも確認・追加できるようにする。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/EventDetailView.swift（対象詳細画面追加）
- favorecoAPP/favorecoAPP/Views/CategoryTopView.swift（対象行から詳細へ遷移）
- favoreco/CLAUDE.md（実装状態を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- 対象自体の編集、アーカイブ、代表アイキャッチ設定は未実装。
- 対象詳細の統計は最小値のみ。ジャンル別の深い集計は未実装。

## 2026-07-09: 既存対象への回追加導線を実装

### 変更概要
- `AddVisitView` を追加し、既存 `ExperienceEvent` に新しい `Visit` だけを追加できるようにした。
- `CategoryTopView` に対象一覧を追加し、各対象から「この対象に回を追加」できるボタンを表示した。
- カテゴリトップの主要導線を、初回は「最初の記録を追加」、記録ありでは「新しい対象を追加」に切り替えた。
- 空状態表示を共通化し、対象0件と記録0件のメッセージを分けた。
- `favoreco/CLAUDE.md` に現在の画面構成と再訪追加ルールを反映した。

### 変更意図
同じ作品を複数回観る、同じ酒をまた飲む、同じ施設へ再訪するなど、favorecoの中心になる「対象に回を重ねる」記録体験を作るため。新規対象の乱立を避け、Event/Visit分離を画面導線にも反映する。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（既存対象への回追加フォーム追加）
- favorecoAPP/favorecoAPP/Views/CategoryTopView.swift（対象一覧と回追加導線追加）
- favoreco/CLAUDE.md（実装状態を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- 対象詳細画面、対象自体の編集、対象のアーカイブは未実装。
- 回追加後に作成したVisitの詳細へ自動遷移する導線は未実装。

## 2026-07-09: 編集画面とカテゴリ別フォーム文言を実装

### 変更概要
- `CategoryRecordTemplate` を追加し、観劇 / 美術展 / ライブ / 映画 / 酒 / おでかけ施設 / 御朱印 / 書籍ごとにフォーム文言を切り替えられるようにした。
- `AddExperienceView` のセクション名、プレースホルダー、日付/場所/評価/メモ文言をカテゴリ別にした。
- `EditExperienceView` を追加し、保存済み `ExperienceEvent` + `Visit` のタイトル、シリーズ、日付、場所、評価、メモを編集保存できるようにした。
- `ExperienceDetailView` に編集ボタンを追加し、詳細画面から編集シートへ遷移できるようにした。
- `favoreco/CLAUDE.md` に現在の画面構成とフォーム文言ルールを反映した。

### 変更意図
1件保存して終わりではなく、あとから記録を直せる基本体験に進めるため。あわせて、同じ最小フォームでもカテゴリごとの言葉に置き換え、観劇・酒・読書などで入力の意味が自然に伝わる状態にする。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Utilities/CategoryRecordTemplate.swift（カテゴリ別フォーム文言定義）
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（追加フォーム文言切替・編集フォーム追加）
- favorecoAPP/favorecoAPP/Views/ExperienceDetailView.swift（編集導線追加・詳細ラベル文言切替）
- favoreco/CLAUDE.md（実装状態を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- テンプレ別の専用入力ユニット、チケット、写真、Map、OCRは未実装。
- 編集対象の削除、アーカイブ、既存Eventへの再訪追加は未実装。

## 2026-07-09: 可変フォント基盤を実装

### 変更概要
- Google Fontsの可変TTFとして `Noto Sans JP` / `Noto Serif JP` / `Cormorant Garamond` をアプリに同梱した。
- `FontRegistrar` を追加し、起動時に同梱フォントをプロセス登録するようにした。
- `FavorecoTypography` を追加し、日本語サンセリフ・日本語セリフ・英字ディスプレイを共通トークンとして使えるようにした。
- ホーム、カテゴリトップ、記録詳細の主要テキストへタイポグラフィを適用した。

### 変更意図
favorecoの文字表現をシステムフォント依存から切り離し、画面ごとに太さや書体を調整できる下地を作るため。日本語は読みやすさと記憶感、英字はブランド感を分けて扱う。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Resources/Fonts/（可変TTFとOFLライセンス追加）
- favorecoAPP/favorecoAPP/Utilities/FontRegistrar.swift（同梱フォント登録）
- favorecoAPP/favorecoAPP/Utilities/FavorecoTypography.swift（タイポグラフィ定義）
- favorecoAPP/favorecoAPP/favorecoAPPApp.swift（起動時フォント登録）
- favorecoAPP/favorecoAPP/Views/HomeView.swift（ホームへ適用）
- favorecoAPP/favorecoAPP/Views/CategoryTopView.swift（カテゴリトップへ適用）
- favorecoAPP/favorecoAPP/Views/ExperienceDetailView.swift（詳細画面へ適用）
- favoreco/CLAUDE.md（実装状態を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- Cormorant SCは未同梱。ロゴ専用・小文字なし表現が必要になった時点で追加判断する。
- 連続的なwght軸スライダーUIは未実装。現状はSwiftUIの `Font.Weight` トークンで太さを切り替える。

## 2026-07-09: 保存済み記録の詳細画面を実装

### 変更概要
- `ExperienceDetailView` を追加し、保存済みVisitのカテゴリ、対象名、シリーズ、日付、場所、評価、メモを表示できるようにした。
- カテゴリトップの最近の記録行から詳細画面へ遷移できるようにした。
- ホームの最近の記録行からも詳細画面へ遷移できるようにした。
- `favoreco/CLAUDE.md` に現在の画面構成を反映した。

### 変更意図
最小登録フローで保存した記録を、保存後に確認できる状態にするため。編集や写真追加に進む前に、Event/Visitの表示解決（カテゴリ・対象・回）を確認できる導線を作る。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/ExperienceDetailView.swift（記録詳細画面追加）
- favorecoAPP/favorecoAPP/Views/CategoryTopView.swift（記録行から詳細へ遷移）
- favorecoAPP/favorecoAPP/Views/HomeView.swift（最近の記録から詳細へ遷移）
- favoreco/CLAUDE.md（実装状態を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- 詳細画面から編集する導線は未実装。
- 写真、タグ、チケット、テンプレ別ユニットは未表示。

## 2026-07-09: カテゴリトップと最小記録追加フローを実装

### 変更概要
- ホームのカテゴリカードをタップ可能にし、カテゴリ別トップ `CategoryTopView` へ遷移するようにした。
- `CategoryTopView` でカテゴリ名、記録数、対象数、ユニット数、最近の記録を表示するようにした。
- `AddExperienceView` を追加し、タイトル / シリーズ名 / 日付 / 場所 / 評価 / メモだけで `ExperienceEvent` + `Visit` を保存できる最小登録フローを実装した。
- 入力中は `AddExperienceDraft` に保持し、保存ボタン押下時だけ SwiftData に書き込むようにした。
- `Color(hex:)` を共通ユーティリティへ移動した。

### 変更意図
カテゴリプリセットが見えるだけの状態から、実際に1件目の記録を作れる状態へ進めるため。今後テンプレ別フォームを足す前に、Event/Visit分離とDraftState→Save→Modelの基本導線を確認できるようにする。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/HomeView.swift（カテゴリカードを遷移化）
- favorecoAPP/favorecoAPP/Views/CategoryTopView.swift（カテゴリトップ追加）
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（最小記録追加フォーム追加）
- favorecoAPP/favorecoAPP/Utilities/Color+Hex.swift（色変換ユーティリティ追加）
- favoreco/CLAUDE.md（実装状態を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/favorecoDerived build` が成功。

### 残課題
- 次スライスで保存後の詳細表示、またはカテゴリ別テンプレに応じた入力項目の出し分けを実装する。
- 既存Eventへの再訪/再飲としてVisitを追加する導線は未実装。

## 2026-07-08: 標準カテゴリプリセットの初回注入を実装

### 変更概要
- `CategoryPresetSeeder` を追加し、初回起動時に標準カテゴリ8種（観劇 / 美術展 / ライブ / 映画 / 酒 / おでかけ施設 / 御朱印 / 書籍）を `RecordCategory` として注入するようにした。
- 注入は `templateKey` + `isBuiltIn` で既存カテゴリを探して更新し、重複作成しないfetch-first方式にした。
- `HomeView` のカテゴリカードを、色バー・SF Symbol・標準チップ・ユニット数表示つきに更新した。
- `favorecoAPPApp` で `ModelContainer.mainContext` へ起動時seedを接続した。

### 変更意図
最初のホームを空の器ではなく、favorecoの主要ジャンルが見える状態にするため。プリセットは固定enumではなく保存済み `RecordCategory` として扱い、将来ユーザー編集やテンプレ更新に耐える構造にする。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Services/CategoryPresetSeeder.swift（標準カテゴリ注入）
- favorecoAPP/favorecoAPP/favorecoAPPApp.swift（起動時seed接続）
- favorecoAPP/favorecoAPP/Views/HomeView.swift（カテゴリカード表示更新）
- favoreco/CLAUDE.md（実装状態を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/favorecoDerived build` が成功。

### 残課題
- 次スライスでカテゴリカードから登録フローまたはジャンル別トップへ遷移させる。
- プリセットの `enabledUnitsRaw` は仕様キーの初期接続のみ。各ユニットの実UIは未実装。

## 2026-07-08: Xcodeプロジェクト作成と最小SwiftDataモデル実装

### 変更概要
- Xcodeで `favorecoAPP` プロジェクトを作成し、SwiftUI / SwiftData のアプリ本体を開始。
- Xcodeテンプレートの `Item` モデルを削除し、`RecordCategory` / `ExperienceEvent` / `Visit` / `InboxItem` / `PhotoBlob` の最小モデルを追加。
- `ContentView` を初期 `HomeView` へ差し替え、空データでもカテゴリ・最近の記録・Inboxが見えるホームを実装。
- Bundle Identifier を `com.nori.favoreco` に調整し、共有schemeと `.gitignore` を追加。
- Xcode個人状態ファイルと `.DS_Store` はGit管理対象から外す方針にした。

### 変更意図
実装フェーズの最初の安全な足場として、仕様正本の中核である Event/Visit 分離と RecordCategory 一般化を、ビルド可能なSwiftDataモデルとして置く。チケット・酒詳細・登録フローに進む前に、CloudKit互換ルールを満たす最小スキーマと起動可能なホームを確定する。

### 主な変更ファイル
- favorecoAPP/favorecoAPP.xcodeproj（Xcodeプロジェクト）
- favorecoAPP/favorecoAPP/Models/CoreModels.swift（最小SwiftDataモデル）
- favorecoAPP/favorecoAPP/Views/HomeView.swift（初期ホーム）
- favorecoAPP/favorecoAPP/ContentView.swift（HomeView入口へ変更）
- favorecoAPP/favorecoAPP/favorecoAPPApp.swift（ModelContainer接続）
- .gitignore（Xcode個人状態・.DS_Store・ビルド成果物除外）
- favoreco/CLAUDE.md（実装状態・構成を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/favorecoDerived build` が成功。
- 初回のサンドボックス内ビルドは SwiftData macro 実行権限で失敗したため、外側権限で再実行して成功を確認。

### 残課題
- アプリ/ターゲット/フォルダ名 `favorecoAPP` を後で `favoreco` 系に整理するか判断する。
- 次スライスでカテゴリプリセット注入と、最初の登録導線を実装する。

## 2026-07-08: Designテーマをジャンル別選択式に更新

### 変更概要
- `DESIGN.md` のジャンル色を固定パレットではなく、ジャンルごとに選択できるテーマ方式に変更。
- 無料版は `Free Light` / `Free Dark` の2種、有料版は追加テーマをジャンルごとに適用できる方針にした。
- 生成モック由来のテーマとして、Velvet Curtain / Stage Bloom / Aqua Nocturne / Daydream Lake / Amber Cellar / Museum Haze / Tour Teal を保存。
- オフホワイト基調の `Porcelain Ivory` と各Ivory variantを追加。
- 追加要望テーマとして、Sakura Mist（桜色系）、Moegi Glass（萌葱色）、Pale Blue Air（ペールブルー）、Mono Vivid Yellow（モノクロ＋ビビットイエロー）、Mono Soft Magenta（モノクロ＋薄めマゼンタ）を追加。
- Mono Vivid Yellow / Mono Soft Magenta は白黒反転版も持つ方針にした。
- テーマ比較用の `docs/design-theme-variants.html` を新規作成。
- `design-theme-variants.html` に、ペール系、Mono系、白黒反転Mono系、生成画像由来パレットのサンプルカードを追加。

### 変更意図
ジャンルごとに固定色を押し付けるのではなく、ユーザーが自分の好みやジャンルの使い方に合わせてテーマカラーを選べるようにする。無料版はシンプルにし、有料版の価値としてカラー拡張を置く。

### 主な変更ファイル
- docs/DESIGN.md（テーマ選択方式、無料/有料テーマ、追加パレットを記録）
- docs/design-theme-variants.html（テーマの見た目を確認するプレビュー）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
ドキュメント/HTMLプレビューのみ。ビルド対象なし。`DESIGN.md` にテーマトークンと本文説明が入り、`design-theme-variants.html` で無料/有料/ペール/モノクロ/白黒反転/生成画像由来テーマを視覚確認できる状態にした。

### 残課題
- 実装時に、ジャンルごとの `selectedThemeId` と課金状態によるテーマロック/プレビュー導線を設計する。

## 2026-07-08: ライブトップと公演系のグッズ/遠征/スケジュール扱いを更新

### 変更概要
- ライブトップの構成を `Hero → チケット要対応 → 参戦予定 → ライブライブラリ → データ` 方向に整理。
- ライブライブラリは横スクロールではなく縦スタックを主役にし、カード内に `4回参戦` `セトリあり` `写真6枚` `グッズ2件` などのバッジを表示する方針にした。
- `セトリ・思い出` は独立セクション既定OFFにし、必要な人だけトップセクションとして表示できるようにした。
- Heroの `次のアクション` 文言は出しすぎず、ステータスチップの色と日付（例: `6/12 当落発表`）で状態が読めるようにした。
- グッズ/コレクションは写真＋名前/コメント＋タグ（銀テ/Tシャツ/会場看板/チケット画像等）＋金額任意に拡張。
- 観劇/ライブなど公演系で、グッズ代・旅費・交通費・宿泊費・遠征費を詳細画面の任意項目として扱う方針にした。
- 宿・移動・集合・物販待ちなどを軽く組める `スケジュール/旅程` ユニットを追加。詳細画面とグローバルカレンダーの両方から追加/変更できる。

### 変更意図
ライブトップはセトリ管理アプリではなく、自分の参戦履歴が積み上がるライブラリを主役にする。セトリやグッズは熱量のある人には重要だが、全員のトップに常設すると重いため、カードバッジと任意セクションで扱う。遠征は体験の一部なので、費用だけでなく宿・移動予定も記録とカレンダーにつながる形にする。

### 主な変更ファイル
- docs/spec-B1-ライブラリ画面.md（ライブトップ、Hero、セトリ/思い出、詳細項目を更新）
- docs/08-テンプレユニット設計.md（U18スケジュール/旅程、U11/U12拡張を追加）
- docs/spec-A3-ユニット別フィールド.md（コレクション明細と金額明細を拡張）
- docs/spec-A4-テンプレ別プリセット.md（観劇/ライブのコレクション・金額方針を更新）
- docs/spec-A5-集計カレンダー地図.md（U11金額をU12集計に接続）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
ドキュメントのみ。ビルド対象なし。ライブトップ、コレクション明細、金額集計、スケジュール/旅程の方針が仕様へ反映されていることを確認。

### 残課題
- `spec-A7` に、ライブ/観劇詳細からのグッズ追加、旅費明細追加、スケジュール追加、カレンダーからの編集フローを反映する。

## 2026-07-08: 観劇トップの見せ方を確定

### 変更概要
- 観劇トップの構成を `Hero → チケット要対応 → 申込・観劇予定 → 観劇ライブラリ → データ` に確定。
- Heroは、次に観る公演、要対応がある公演、最近観た公演、手動固定の順で選ぶ。
- チケット要対応は1列または2列で、トップには最大2〜3件だけ表示し、`もっと見る`でチケット一覧へ遷移する。
- 複数申込はFC先行/カード枠/プレイガイド等を行ごとに扱う。
- 申込・観劇予定は未完了の未来/進行中の公演回だけを表示し、観劇済みは観劇ライブラリ/観劇履歴へ移す。
- 観劇ライブラリは横スクロールではなく縦スタックにし、作品カード内に `3回観劇` などのリピート回数を表示する。リピート観劇の独立セクションは作らない。
- データは `今年の観劇回数` をマストにし、`申込中/要対応チケット数`、`最多リピート作品/回数` をトップ候補にした。劇場数・マチソワ・当選率などは詳細統計側を基本にする。
- トップに出しすぎないものとして、アカウント情報、パスワード、全申込履歴、落選一覧、名義別当選率、長文感想、キャスト詳細を詳細/統計/設定へ逃がす方針にした。

### 変更意図
観劇トップは管理画面ではなく、チケットの危険信号と観劇の積み上がりを同時に見る画面にする。リピートは独立欄にせず作品カードのメタ情報に溶かすことで、トップの視線を散らさない。

### 主な変更ファイル
- docs/spec-B1-ライブラリ画面.md（観劇トップ構成を確定）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
ドキュメントのみ。ビルド対象なし。観劇トップの構成、Hero、チケット要対応、申込・観劇予定、縦スタックの観劇ライブラリ、データの優先度が仕様へ反映されていることを確認。

### 残課題
- 観劇トップのデータタイルは、実装時に設定で表示項目を差し替えられるようにする。

## 2026-07-08: 観劇のVisit単位とキャスト管理/OCR方針を確定

### 変更概要
- 観劇回数は `Visit` 数で数える方針にした。同じ日のマチソワはVisit 2件。
- キャスト管理は、作品/Eventのキャスト候補と、自分が観た回/Visitの実キャストを分ける方針にした。
- 実キャストはVisitにスナップショットとして残し、公式情報が変わっても自分が観た回の記録を保持する。
- 入力補助として、公式キャスト候補から選ぶ、前回キャストをコピー、手入力、当日キャスト表/プログラム画像OCRを採用。
- キャスト取り込みは画像OCRだけでなく、URLとテキストペーストからも候補化する方針にした。
- キャストOCR/URL/テキスト取り込みは精度重視とし、前処理・列解析・Person辞書補正・精査画面を必須にした。役名と人物名のペアを崩さず、勝手に確定しない。
- 精査後、保存先を作品全体のキャスト候補(Event)、自分が観た回の実キャスト(Visit)、または両方から選べるようにした。

### 変更意図
観劇ではWキャスト、日替わり、代役があり、誰で観たかが記録価値と統計価値を持つ。必須入力にすると重くなるため任意にしつつ、記録したい人には高精度に残せる導線を用意する。

### 主な変更ファイル
- docs/spec-A3-ユニット別フィールド.md（Eventキャスト候補/Visit実キャスト、OCR精度要件を追加）
- docs/spec-A4-テンプレ別プリセット.md（観劇プリセットにキャスト管理/OCRを追加）
- docs/08-テンプレユニット設計.md（観劇回数=Visit数、キャスト管理方針を追加）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
ドキュメントのみ。ビルド対象なし。Visit数、Event/Visitキャスト分離、OCR精度要件が仕様へ入っていることを確認。

### 残課題
- `spec-A5` に俳優別観劇回数、役別キャスト、作品別キャスト違い、推し俳優の出演作一覧を反映する。
- `spec-A7` にキャスト表OCRの登録フローとプレビュー編集UIを反映する。

## 2026-07-08: 観劇チケットの要対応表示・複数申込・FC/チケットアカウント管理を設計

### 変更概要
- 観劇トップのチケット表示は、チケット管理画面を主役にせず、要対応だけを出す方針にした。
- トップに出す対象を、申込開始（特に当日）/ 申込締切 / 当落発表 / 入金締切 / 発券開始・発券待ち / 公演当日に限定した。
- チケット申込は `Visit` 直持ちではなく、申込1件ごとの `TicketAttempt` として独立管理する方針に更新。同じ公演にFC先行/カード枠/ぴあ先行/一般など複数申込を持てる。
- FC管理を、FC/プレイガイド/劇場会員/カード枠を含む「FC・チケットアカウント管理」に拡張。サイトURL、ログインID、会員番号、名義、有効期限、年会費、色を一元管理する。
- パスワードはSwiftData/CloudKitに保存せず、必要な場合のみKeychainへ保存し、表示/コピー/編集時はFace ID/Touch ID/端末パスコード認証を必須にする。
- 要対応カードから申込ページを開けるようにし、アカウント情報を開く場合は生体認証後にID/パスワードコピーを行う方針にした。

### 変更意図
観劇の価値はチラシ/記録/思い出だが、申込開始・申込締切・入金締切を逃すと体験自体を失う。チケット管理をトップの主役にはせず、通知と要対応レイヤーを堅牢な資産として設計する。複数先行・複数名義・複数チケットサイトに耐えるため、TicketAttemptとアカウント管理を最初から分離する。

### 主な変更ファイル
- CLAUDE.md（チケット/ライブ管理の正本ルールを更新）
- docs/spec-A8-チケット管理・通知.md（TicketAttempt独立、Account管理、Keychain/生体認証方針へ更新）
- docs/spec-B1-ライブラリ画面.md（観劇トップの要対応表示範囲を更新）
- docs/spec-A3-ユニット別フィールド.md（Account/TicketAttempt/Visitの所属を更新）
- docs/spec-A5-集計カレンダー地図.md（当選率/名義別集計の源をTicketAttempt/Accountへ更新）
- docs/08-テンプレユニット設計.md（観劇チケットユニットの方針更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
ドキュメントのみ。ビルド対象なし。観劇トップの要対応、TicketAttempt独立、FC・チケットアカウント管理、パスワードKeychain＋生体認証方針が仕様へ反映されていることを確認。

### 残課題
- `spec-A7` にチケット申込登録・スクショ/OCR・アカウント選択・通知設定の登録フローを反映する。
- 実装時はKeychain項目の移行/削除/端末変更時の扱いを別途詰める。

## 2026-07-08: 酒トップの一覧単位・データ・写真・場所扱いを確定

### 変更概要
- 酒の飲んだ一覧は、飲んだ回単位ではなく**銘柄単位**で並べる方針にした。同じ酒は1カードにまとめ、再飲はVisitとして積む。
- 気になる酒を飲んだ時は、同じ銘柄のEventへ昇格し、飲んだ回(Visit)を追加する。気になるメモ・写真・URLは引き継ぐ。
- データ表示は、酒種別タブに応じて変化する。基本項目は酒種別比率、今月飲んだ種類数、年間飲んだ種類数、よく飲む地域、生産者/酒蔵、評価。
- 代表写真はボトル/グラス/ラベルのどれでも可。ラベル表/裏はLv2詳細で保存する。
- 場所は「どこで飲んだ」をトップ/Lv1の主役にし、「買った場所」はLv2任意欄にした。

### 変更意図
お酒トップはボトル棚として眺める体験を優先するため、一覧は銘柄単位が合う。飲んだ回の履歴は詳細側へ積み、トップは軽く美しく保つ。気になる酒から飲んだ記録への昇格導線を決めることで、クイック登録から正式記録へ自然に移れる。

### 主な変更ファイル
- docs/spec-B1-ライブラリ画面.md（酒トップの一覧単位・気になる昇格・データ・写真扱いを更新）
- docs/spec-A4-テンプレ別プリセット.md（酒プリセットの一覧単位・写真・データ方針を追記）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
ドキュメントのみ。ビルド対象なし。酒トップの残決定事項が仕様へ反映されていることを確認。

### 残課題
- `spec-A5` に酒種別タブ別のデータ算出、銘柄数/Visit数/再飲数の扱いを反映する。

## 2026-07-08: 酒トップの表示順と全ジャンルのセクション順カスタムを整理

### 変更概要
- 酒種別タブを `すべて / 日本酒 / ビール / ワイン / ウィスキー / 焼酎 / その他` を初期案とし、並び替え・表示/非表示をユーザー設定で変更できるようにした。
- Heroは最近飲んだ/お気に入りランダムを中心にし、`気になる酒` はHero候補に含めない方針にした。
- 酒トップの順番を `酒種別タブ → Hero → 気になる酒 → 飲んだ一覧 → データ` に整理。
- `気になる酒` は買いたい/飲みたいを分けず、まとめて扱う。店で見た/すすめられた/SNSで見た等はタグ・メモで表現する。
- 飲んだ一覧の既定表示は、ボトル/ラベル写真が主役のグリッドにした。
- 全ジャンル共通で、トップ内セクションの並び替え・表示/非表示を持つ方針を追加。ただし完全自由レイアウトはやらない。

### 変更意図
酒トップは入口を軽くし、Heroで思い出、気になる酒で未来、飲んだ一覧で記録、データで傾向を見る構成にする。セクション順はジャンルやユーザーの使い方で重要度が変わるため、全カテゴリ共通で軽いカスタムを許可する。

### 主な変更ファイル
- docs/spec-B1-ライブラリ画面.md（酒トップ順、気になる酒、飲んだ一覧、全ジャンルセクション順カスタムを更新）
- docs/spec-A4-テンプレ別プリセット.md（酒種別タブの並び替え/表示設定を追記）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
ドキュメントのみ。ビルド対象なし。酒トップと共通見せ方機能に今回の決定が反映されていることを確認。

### 残課題
- 酒の「飲んだ一覧」を銘柄単位にするか、飲んだ回単位にするかを決める。
- `spec-A5` にセクション順設定、酒データ表示、気になる酒数などの集計を反映する。

## 2026-07-08: 酒詳細を3段階開示に変更

### 変更概要
- 酒詳細画面の入力・表示を、Lv1「みんな使う」/ Lv2「詳しく記録」/ Lv3「専門スペック」の3段階に整理。
- Lv1は名前・酒種別・写真・飲んだ日・場所・評価・ひとことメモだけで成立する軽い記録にした。
- Lv2は度数・生産者・地域・飲み方・価格・同行者・ラベル写真・タグ。
- Lv3は日本酒の精米歩合/日本酒度/酸度/使用米/酵母/製造年月など、酒種別プリセットの詳細値。初期は閉じる。

### 変更意図
お酒はライト層と詳しい層の差が大きい。最初から網羅的なフォームを見せると登録が重くなるため、入口は軽くし、必要な人だけ深く記録できる段階開示にする。

### 主な変更ファイル
- docs/spec-B1-ライブラリ画面.md（酒詳細の3段階開示を追加）
- docs/spec-A4-テンプレ別プリセット.md（酒プリセットの段階開示を追加）
- docs/08-テンプレユニット設計.md（酒テンプレの入力負荷方針を追加）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
ドキュメントのみ。ビルド対象なし。酒詳細がLv1/Lv2/Lv3の3段階で記載されていることを確認。

### 残課題
- `spec-A7` の酒登録フローで、クイック登録/ちゃんと登録/専門スペック展開の導線を詰める。

## 2026-07-08: Liveのペイン・思い出保管/統計方針・横断マスター方針を記録

### 変更概要
- `spec-B1` のライブ・フェス section を更新。Liveは後で詳細を詰める前提で、方向性メモとして「思い出保管＋統計」を主軸にした。
- Live Rock等のレビューから見えたペインを整理。フェス/対バン/KPOP/アイドル/声優/2.5D系は、出演者・公演回・セトリ・チケット・費用・同行者の管理が重くなりやすい。
- フェス/対バンの出演者は、画像OCR・コピペ一括登録・手入力追加に対応する方針を追加。出演者一覧と実際に観た出演者を分ける。
- Liveと観劇はUI上は別ジャンルだが、内部ではチケット・公演回・出演者・座席・ProgramItem・写真/グッズ/費用を共通部品として扱う方針を追加。
- 推しは独立ジャンルではなく、Person/Artist等のマスターにFavoを付ける横断軸として整理。同行者は絵文字/色/イニシャル/写真チップ付きのCompanionマスターとして扱う。
- 予定共有はv1では共有カード・カレンダー出力・メッセージ送信用テンプレを優先し、アプリ内友達機能/共同編集はv2以降とした。

### 変更意図
favorecoのLiveの勝ち筋は、チケット販売やライブ発見ではなく、参戦した思い出を保管し、自分の音楽/推し活データを統計で見返せること。フェス/対バン/アイドル系の実利用では、複数出演者・複数公演・セトリ・費用・同行者・推し別集計が絡むため、早い段階で構造だけ切っておく。

### 主な変更ファイル
- docs/spec-B1-ライブラリ画面.md（ライブ・フェス方向性メモ追加）
- docs/spec-A3-ユニット別フィールド.md（Person/Favo、Companionアイコン方針を追記）
- docs/spec-A4-テンプレ別プリセット.md（ライブ形態・出演者一括登録・ProgramItem・共有方針を追記）
- docs/08-テンプレユニット設計.md（ライブテンプレに同内容を追記）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
ドキュメントのみ。ビルド対象なし。Liveの方向性、フェス/対バン出演者登録、観劇との共通部品、Favo横断軸、同行者アイコン、予定共有の段階案が仕様へ入っていることを確認。

### 残課題
- Liveの詳細UI、トップデザイン、統計項目、チケット進捗の見せ方は後で詰める。
- `spec-A5` にFavo別/同行者別/曲別/会場別/費用集計を反映する。
- `spec-A7` にLiveのクイック登録、OCR、コピペ一括登録、共有カード生成を反映する。
- 次は酒ジャンルへ戻る。

## 2026-07-08: 酒ジャンルの共通ベースと酒種別プリセット構造を整理

### 変更概要
- `spec-B1` の酒セクションを更新。Heroを「最近飲んだお酒」または「お気に入りからランダム」にし、ボトル写真・名前・酒種別・度数・飲んだ日・飲んだ場所を表示する方針にした。
- 全酒種共通情報を整理。酒そのものは `Event`（名前 / 酒種別 / 度数 / 代表写真）、飲んだ体験は `Visit`（飲んだ日 / どこで飲んだ / 評価 / メモ / 写真）に分ける。
- 酒種別タブ `すべて / 日本酒 / ビール / ウィスキー / ワイン / 焼酎 / その他` をトップの軸に追加。
- 日本酒・ウィスキー・ワイン・ビール・焼酎の固有情報は、共通ベースの上に酒種別プリセットとして足す方針を明文化。

### 変更意図
酒は種類ごとに記録したい情報が違うが、名前・飲んだ日・酒種別・度数・飲んだ場所は横断して使う。最初から共通ベースと酒種別固有プリセットを分けることで、後からウィスキーやワインを追加してもスキーマを壊さないようにする。

### 主な変更ファイル
- docs/spec-B1-ライブラリ画面.md（酒トップ構成更新）
- docs/spec-A3-ユニット別フィールド.md（酒のEvent/Visit分離を追記）
- docs/spec-A4-テンプレ別プリセット.md（全酒種共通ベースを追加）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
ドキュメントのみ。ビルド対象なし。酒トップにHero、酒種別タブ、ボトルライブラリ、最近のテイスティング、気になる酒、味覚マップ、酒蔵/産地マップ、データの構成が入っていることを確認。

### 残課題
- `spec-A5` に酒のHero候補、味覚マップ、酒蔵/産地マップ、再飲集計の算出ルールを反映する。
- `spec-A7` に酒のクイック登録（名前＋酒種、写真＋酒種、URL保存、ラベルOCR）を反映する。
- ウィスキー/ワイン/ビール/焼酎の詳細プリセットは、実装前に入力負荷を見て最小化する。

## 2026-07-08: 御朱印ジャンルトップを印種別タブ＋最近いただいた印Heroに更新

### 変更概要
- `spec-B1` の御朱印セクションを更新。印種別タブ `すべて / 御朱印 / 御城印 / 御船印` をトップの軸にした。
- Heroを「最新の御朱印帳」ではなく、**最近いただいた印そのもの**に変更。御朱印/御城印/御船印の写真を大きく出し、場所名・日付・都道府県・帳面名を表示する。
- 帳面は主役ではなく整理単位として扱う。最新帳だけ少し大きめ、帳面一覧は小さめカード。収録数・最新記録・表紙写真を表示する。
- 地図、気になる場所、データの役割を整理。気になる場所は印種別に応じて「行きたい寺社 / 行きたい城 / 行きたい港・船」と文言を切り替える。

### 変更意図
御朱印ジャンルでユーザーが見返したい主役は帳面の表紙ではなく、いただいた印そのもの。御城印・御船印も同じ器で受けるが、UIでは種別タブで切り替えて散らからないようにする。

### 主な変更ファイル
- docs/spec-B1-ライブラリ画面.md（御朱印セクション更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
ドキュメントのみ。ビルド対象なし。御朱印セクションに印種別タブ、最近いただいた印Hero、帳面/地図/気になる場所/データのトップ構成が反映されていることを確認。

### 残課題
- `spec-A3` / `spec-A5` に印種別タブの集計・地図・Hero候補・気になる場所を反映する。
- 次は酒ジャンルのベースを整理する。

## 2026-07-08: おでかけ施設・美術展トップと動画/MediaAsset方針を反映

### 変更概要
- `spec-B1` のおでかけ施設を確定記述に更新。テーマパーク/水族館/動物園/植物園を共通の `OutingFacilityGenreTop` として扱い、予定がある日はToday/Next Plan Card、予定がない日は思い出Heroを主役にする構造を明文化。
- おでかけ施設のトップ構成を確定：予定カード内のGoogleカレンダー1日表示風タイムライン、思い出Hero、訪問日アルバム、写真ギャラリー、動画、コレクション、データ。
- 水族館/動物園/植物園は写真メインとし、写真ごとに生きもの名/動物名/植物名/展示名を `caption` で入れられる方針を追加。種名板OCRは入力補助、AI種同定はv1対象外。
- `spec-B1` 美術展に、会期・予定Attentionの**ミニガントバー型**を追加。会期終了間近/日時指定/チケット済みをHero下に最大3件表示する。
- `spec-A3` と `09` を更新し、PhotoBlobを写真専用にしすぎず、将来の動画/iPad同期を見据えた `MediaAsset` 方針を追加。動画はデフォルトPhotos参照＋サムネ＋メタ、アプリ内コピー/動画Cloud同期は明示ONにした。
- 今後の進行順を、御朱印 → 観劇 → ライブ後回しとする方針を確認。

### 変更意図
テーマパークは頻繁な予定管理より思い出写真が主役だが、当日/直近予定がある日は実用的に動ける画面が必要。水族館・動物園・植物園では写真とcaptionが中心になる。動画は需要が高い一方、アプリ内コピーや自動同期は容量圧迫につながるため、最初から保存モードと同期状態を分ける。

### 主な変更ファイル
- docs/spec-B1-ライブラリ画面.md（おでかけ施設・美術展更新）
- docs/spec-A3-ユニット別フィールド.md（U4タイムライン、MediaAsset/caption/video方針）
- docs/09-CloudKit写真ストレージ仕様.md（MediaAsset・動画保存/同期方針）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
ドキュメントのみ。ビルド対象なし。おでかけ施設の共通トップ、美術展ミニガントバー、動画のPhotos参照/明示保存/将来同期の方針が仕様へ入っていることを確認。

### 残課題
- `spec-A5` におでかけ施設の訪問回数/写真枚数/よく行く月/同行者、及び美術展の会期Attention算出・ミニガント表示ルールを反映する。
- `spec-A7` におでかけ施設のGoogle/Appleカレンダー候補取り込み、写真時刻候補、種名板OCRの登録フローを反映する。
- 次は御朱印ジャンルトップを見直し、その後に観劇へ進む。ライブは優先度を下げる。

## 2026-07-08: 映画ジャンルトップをHero Carousel＋ポスター主役に更新

### 変更概要
- `spec-B1` 映画セクションに、ファーストビューの **Hero Carousel** を追記。最近観た映画固定ではなく、次に観る映画・もうすぐ公開・最近観た映画・手動で「トップに出す」映画を横スワイプで切り替える構造にした。
- 映画一覧は **ポスターグリッド既定** と明記。テキストは最小限にし、監督・出演者・あらすじ・登録元・劇場/座席は詳細画面へ逃がす。
- 表示モードを追加：ポスターのみ（既定）／ポスター＋最小情報／情報カード／リスト。列数は2列/3列/4列で切替可能にする。
- 予定はグローバルのプラン/カレンダーで横断表示しつつ、映画トップでは7日以内の鑑賞予定・公開日が近い観たい映画・舞台挨拶/抽選等の要対応がある時だけHero/小Attentionに出す方針にした。

### 変更意図
映画は言葉よりポスターで思い出すジャンルのため、トップを管理表にせず、ポスターが並ぶ私的コレクションとして見せる。一方でfavorecoの差別化である「予定でワクワクする」体験も残すため、Heroだけは動的に次の予定・手動候補を出せる構造にする。

### 主な変更ファイル
- docs/spec-B1-ライブラリ画面.md（映画セクション更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
ドキュメントのみ。ビルド対象なし。映画セクションにHero Carousel、ポスター主役、表示モード、列数切替、予定の条件付き表示が反映されていることを確認。

### 残課題
- `spec-A3` / `spec-A5` に `isHeroCandidate` / `heroSortOrder` / `heroAddedAt` 相当と、映画Hero候補の算出ルールを反映する。
- 映画のクイック登録・TMDb/URL画像のローカル保存方針を `spec-A7` / 写真仕様へ反映する。

## 2026-07-08: 書籍ジャンルのメインページ・状態設計を確定

### 変更概要
- `spec-B1` の書籍ライブラリを確定記述に更新。棚板/木目の古い本棚表現を避け、表紙主役の現代的なカード/グリッド型にする方針を明文化。
- 書籍トップ構成を確定：最近買った本／読書データ／気になる本／購入済み一覧（ジャンルタブ＋もっと見る）／読書メモ／写真・コレクション／シリーズ。
- 書籍タイルに表示モードを追加：**書影グリッド（既定）**／情報カード／リスト。書影だけで眺めるモードを選べるようにした。
- 書籍状態を単一の「読了/積読」から、**共通興味ステータス（気になる/欲しい）＋書籍固有の入手状態（未入手/購入済み）＋購入済み後の任意読書状態（未読/読書中/読了/中断/再読中/再読了）**に分離。
- ISBN/URL由来の書影は外部URL依存にせず、アイキャッチ用にローカル保存/キャッシュする方針に更新。写真欄へは自動追加せず、ユーザーが「写真にも保存」を選んだ場合のみPhotoBlobへ追加。

### 変更意図
「買ったか忘れる」「書店で気になった本をISBNで放り込む」という実用性を保ちつつ、読書管理アプリの重い進捗管理に寄せすぎないため。トップでは表紙を主役にし、著者/訳者/出版社/ISBN/登録元などの詳細は詳細画面へ逃がして、登録と閲覧を軽くする。

### 主な変更ファイル
- docs/spec-B1-ライブラリ画面.md（書籍ライブラリ確定）
- docs/08-テンプレユニット設計.md（書籍テンプレの状態・購入情報・書影/写真方針を更新）
- docs/spec-A4-テンプレ別プリセット.md（書籍プリセット状態を3レイヤーへ更新）
- docs/spec-A3-ユニット別フィールド.md（書籍フィールド定義を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
ドキュメントのみ。ビルド対象なし。書籍の古い「読了/積読」単一状態記述を主要仕様から3レイヤー状態へ置き換え、書影グリッド表示モード・購入情報折りたたみ・書影ローカル保存方針が反映されていることを確認。

### 残課題
- `spec-A5` に書籍の購入冊数/読了冊数/月別推移/ジャンル比率/カレンダー表示（購入日・読始日・読了日・メモ日）を反映する。
- `spec-A7` にクイック登録（ISBN/URL/写真/タイトル）から書籍 `InboxItem` → `Event` 昇格の具体フローを反映する。

## 2026-07-08: Mystorium再発防止の実装アーキテクチャ・性能ルールを正本化

### 変更概要
- Mystoriumで重かったリファクタ・性能改善の教訓を、favorecoの実装前ルールとして `docs/14-実装アーキテクチャ・性能ルール.md` に新設。
- `favoreco/CLAUDE.md` §5 に、最重要4原則（入力中にDBを書かない／一覧で原寸画像を使わない／bodyで全件処理しない／巨大Viewを作らない）と、DraftState・Snapshot/DTO・画像3段階・background/batch save・Apple Kit境界の必須化を追記。
- ライフサイクル状態の責務分離を明文化：`InboxItem` / `Event` / `Plan`・`Performance` / `TicketAttempt` / `Visit` / `MemoryDraft`。複数先行・落選履歴・名義別当選率・通知更新に耐えるため、チケット状態を `Visit` に直持ちしない方針を正本化。
- 将来Androidを完全に捨てないため、SwiftUI/SwiftData/CloudKit/MapKit/WeatherKit/EventKit/Vision/StoreKit はiOS実装で使いつつ、ドメインモデル・状態遷移・Smart Add解析結果・Provider境界はApple APIへ直結させない方針を追加。

### 変更意図
Mystoriumで後から直して高コストだった問題（巨大View、SwiftData直接更新、body内全件処理、原寸画像デコード、MainActor上のI/O、1件ごとのsave）を、favorecoでは実装初日から避ける。ジャンル数・画像数・チケット状態がMystoriumより増えるため、最初から責務分離と性能予算を仕様化する。

### 主な変更ファイル
- favoreco/CLAUDE.md（重要な実装ルールに追記）
- docs/14-実装アーキテクチャ・性能ルール.md（新規）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
ドキュメントのみ。ビルド対象なし。`CLAUDE.md` から新規doc14への参照があること、doc14内でDraftState/Snapshot/DTO/TicketAttempt/Apple Kit境界のルールが一通り明文化されていることを確認。

### 残課題
- 既存の `spec-A8` はまだ「Visitにチケット状態を持たせる」記述が残るため、次に `TicketAttempt` 独立モデル前提へ改訂する。
- `spec-A1` / `spec-A3` / `spec-A5` / `spec-A7` に `InboxItem`・`Plan/Performance`・`MemoryDraft`・Snapshot/DTO・Provider境界を反映する。

## 2026-07-07: mystoriumbase の設計正本をマージ＋doc12/13を正本に突き合わせ

### 変更概要
- `claude/mystoriumbase-generic-app-pkvkzt`（main未マージ）の設計確定を app-ui-design-inspiration ブランチへ**マージ**：DESIGN.md（デザイン正本）・design-preview.html・spec-A4/A5/A6/A8・spec-B1 等が全部入りに。コンフリクトは project-log のみ（両エントリ保持で解消）。
- **doc13 §9 チケット管理**を spec-A8 のリサーチに差し替え：参考にしていたプレイガイド（ぴあ/e+/tixeebox/MOALA）に加え、**実際の直接競合＝LiveSoul／TheaterRecords／Cherie Log／Live Rock・relight・Tickemo**、チケコレ=更新停止を明記。9-A（管理アプリ＝競合）/9-B（プレイガイド＝参考）に再構成し spec-A8 を正本参照に。
- **doc12（ホーム画面デザイン）を DESIGN.md に突き合わせ**：トークンの正本を DESIGN.md に委譲し、本書は差分だけ保持。**重大な対立を明示**＝3案/モックは「暖色クリーム＋金でホーム全体」、DESIGN.md 憲法#4は「ホーム＝ニュートラル白＋青・色はライブラリだけ」。§5-0に色の要決定、§5-1にナビ（spec-B1の5タブ＝プラン廃止/マイページ追加）を追加。YOUR JOURNEY の発生源を spec-A8 状態pipelineに接続。
- モック（home-mock.html）に「色・ナビ未反映／DESIGN.md・spec-B1が正」の注記を追加。

### 変更意図
別セッションで進んだ設計正本（DESIGN.md/spec-A8/spec-B1）と、本セッションで作ったホームモック・ライバル一覧を1ブランチに統合し、矛盾（暖色ホーム vs ニュートラル憲法・ナビ4/5タブ・チケット競合の顔ぶれ）を可視化してユーザー判断に載せる。

### 主な変更ファイル
- （マージ取り込み）docs/DESIGN.md・design-preview.html・spec-A4/A5/A6/A8・spec-B1 ほか
- docs/13-ジャンル別ライバル一覧.md（§9 再構成・spec-A8準拠）
- docs/12-ホーム画面デザイン.md（DESIGN.md委譲・色/ナビの要決定を明示）
- docs/mock/home-mock.html（未反映注記）
- docs/project-log.md（本記録・マージ）

### 確認結果（実機 / ビルド）
ドキュメント/HTMLのみ。マージ後コンフリクトマーカー無しをgrepで確認。

### 要決定（ユーザー）
- **ホームの色**：DESIGN.md 憲法維持（ホーム=白+青）か、ホームだけ暖色+金を例外化して DESIGN.md 改訂か（doc12 §5-0）。
- 決定後：モックを DESIGN.md/spec-B1（5タブ）に合わせて修正 → spec-B2 ホーム画面を新設。

## 2026-07-07: ホーム画面デザイン言語の確定作業＋ジャンル別ライバル一覧

### 変更概要
- **ホーム画面モック（`docs/mock/home-mock.html`）新規**: ChatGPT提供の3案（＋ジャンル別5案）からデザイン言語を抽出・統合した、Safariでそのまま開ける自己完結モック。白カード on クリーム地・写真主役・真鍮ゴールド差し色・セリフ見出し・浮遊ガラスタブバー。目玉は**YOUR JOURNEY**（発見→抽選→当選→体験→記録の体験ライフサイクルをタイムライン化）。
- **ホーム画面デザイン仕様（`docs/12-ホーム画面デザイン.md`）新規**: concept §6で「別途デザイン仕様で確定」と保留していたデザイン言語（カラートークン・タイポ・素材）とホーム構成を草案化。§5に要選択事項5点（集計の重複/JOURNEYの対象/ヒーローの明暗/書体/サブコピー）。
- **ジャンル別ライバル一覧（`docs/13-ジャンル別ライバル一覧.md`）新規**: 実装予定8ジャンル＋横断機能（チケット管理・スケジュール管理）ごとにライバル・参考サービスを台帳化。01（戦略総論）を補完するジャンル別の実務台帳。酒・御朱印・おでかけ施設・チケット・スケジュールはWeb検索で裏取り。

### 変更意図
- ブランチ`app-ui-design-inspiration`の宿題＝3案からデザイン言語を確定しホーム構成に落とすこと。ユーザーが「テンション爆上がる構成」と評価した密度・物語性（YOUR JOURNEY）を中核に据えた統合案をモックで提示し、react可能にした。
- ライバル一覧はユーザー依頼（実装予定ジャンルごと＋チケット/スケジュール参考元）。01は7カテゴリを戦略視点で扱うが、新規テンプレ（酒/おでかけ施設/御朱印）と横断機能が未カバーだったため補完。

### 主な変更ファイル
- docs/mock/home-mock.html（新規）
- docs/12-ホーム画面デザイン.md（新規・草案）
- docs/13-ジャンル別ライバル一覧.md（新規）

### 確認結果（実機 / ビルド）
ドキュメント＋HTMLモックのみ。モックは外部リソースなしの自己完結（Safariでそのまま表示）。数値・料金・提供状況（特にVinicaの終了情報）はMac側で最終確認が必要。

### 要選択・残課題
- 12 §5の5点（ユーザー判断）を決めてデザイン言語を「確定」に上げ、concept §6の保留を解消
- ジャンル別5案（映画=暗色/ライブ/観劇=劇場赤/美術展=青/酒）を12のデザイン言語と統合し、ジャンル別スキンのルール化
- ②-A続き A4〜A6（既存の残課題）

## 2026-07-07: デザインの正本 DESIGN.md を新設＋プレビュー（同骨格×別色世界を実証）

### 変更概要
- ユーザー参照（google-labs-code/design.md／VoltAgent/awesome-design-md）を踏まえ、**favorecoのデザイン正本 `docs/DESIGN.md` を新設**。形式はawesome-design-md流（プレーンMD＋軽量トークン）。理由＝厳密YAML＋CLI版はexport先がCSS/TailwindでSwiftUIに無駄、散文＋パレット＋ガードレールの軽い形が実装時に最も効く。
- 内容：空気感／**共存の憲法（ガードレール）**／共通スケルトン色＋**ジャンル8色世界**（観劇ワインレッド+ゴールド・酒琥珀・映画チャコール・美術展ブルー・ライブコーラル・御朱印朱×墨×金・おでかけグリーン・書籍タン）／タイポ（既定sans・格調ジャンルはserif）／8pxグリッド余白／コンポーネント／ダーク／アンチパターン／SwiftUI写経メモ。
- **`docs/design-preview.html`**：パレット・タイポ・コンポーネント＋**同じ骨格×別色世界のライブラリ4例（映画/観劇/酒/美術展）**。ステータス/ヘッダー/フィルタ/セクション/ナビは同一構造、色・書体・中身のレイアウトだけジャンルで替わる＝共存の憲法を視覚実証。

### 変更意図
口伝だとセッションをまたいで薄れる（実際ロスト経験あり）色・寸法・佇まいを1枚の正本に固定し、実装（SwiftUI）とモックのブレを防ぐ。仕様正本=spec-*、意思決定=project-log、見た目トークン=DESIGN.md の三分担を確立。

### 主な変更ファイル
- docs/DESIGN.md（新規・デザイン正本）
- docs/design-preview.html（新規・プレビュー）

### 確認結果（実機 / ビルド）
ドキュメント/HTMLのみ。ブラウザでプレビュー確認（絵文字は仮・実装はSF Symbols）。

### 残課題
- DESIGN.md のトークンをSwiftUI（Asset Catalog/定数/Material）へ写経（実装フェーズ）
- 残ジャンルのライブラリ確定（ライブ・おでかけ・書籍）後にプレビューへ追加
- ダーク版プレビュー（preview-dark）の要否

## 2026-07-07: 酒ライブラリ／酒カードの表示方向を確定（spec-B1 §5）

### 変更概要
- ユーザーのスケッチ2枚（IMG_6312 フルカード／IMG_6313 2列コンパクト）とモック確認を経て、**酒の見せ方を確定**（「デザインはダサいけどそういうこと」＝構造・振る舞いは合意・ビジュアルの磨きはデザインフェーズ）。
- **カード構造＝名前バンド＋全体写真（ボトル）＋ラベル表・裏＋下部情報**。裏ラベルが無い時は右枠を味わいレーダー（さけのわ6軸）に自動差し替え。
- **密度3段（表示サイズ切替）**＝最小3列アイコン（名前＋ボトルのみ）／コンパクト2列（＋産地・★・既定）／フル1列（＋ラベル・スペック・レーダー）。同一カードが密度で伸縮。
- **タップで詳細**＝スペック個別列＋6軸レーダー×味覚マップ2軸＋官能メモ＋評価＋酒蔵ハブ横断リンク。酒キラー＝酒蔵所在県マップ・味覚マップ（A5連動）。

### 変更意図
酒の「一覧（棚）→カード→詳細」を確定し、ライブラリ残ジャンルの1つを埋める。SNSは作らずさけのわ集計を借りる方針（02勝ち筋#4）と整合。

### 主な変更ファイル
- docs/spec-B1-ライブラリ画面.md（§5 酒 を確定記述で追記）

### 確認結果（実機 / ビルド）
ドキュメントのみ。モックで構造をユーザー確認済み（ビジュアルは仮）。

### 残課題
- ホーム（モジュール式）の「Record」と「最近のアクティビティ」の切り分け（要ユーザー判断）→ 確定後 spec-B2 ホーム画面を新設
- ライブラリ残ジャンル：ライブ・おでかけ施設・書籍
- 酒カードの実写真反映・最小アイコンに★/産地を出すかの微調整はデザインフェーズ

## 2026-07-07: SNS（公開型レーティング・口コミ）非採用を決定 → シェアカードで代替

### 変更概要
- ユーザー質問「SNS機能（レーティング・口コミ）をつけると大変か」への検討の結論として、**公開型SNSは非採用**を決定。「自分の評価・感想（private・★/メモ）」は既に実装済みで軽いが、**公開UGC（他人と共有する口コミ・フォロー）は別プロダクト級の負担**。
- 非採用の理由：①サーバ/共有DB ②アカウント/プロフィール ③**モデレーション＋App Store Guideline 1.2（UGC義務）** ④コールドスタート ⑤**プライバシー方針（自分の・私的な記録）との矛盾**。加えてネットワーク効果を持つ既存勢（Letterboxd/食べログ/Untappd）と最も勝ちにくい土俵になる。
- **代替＝シェアカード**（既存SNSへ吐き出す・バックエンド/モデレーション不要）。これがfavorecoの唯一の"社交"手段。
- **コミュニティ集計は"借りる"**を明文化：さけのわ（日本酒版Untappd＝本格バックエンド運用）の公開API（さけのわData・読み取り専用）で集計フレーバー/ランキングを参考値として取得。映画=TMDb、書籍=openBD/NDLも同型。個々の口コミ文の転載は規約・権利上しない（集計値の参考表示に留める）。

### 変更意図
「大変なバックエンドは他社が運用済み、favorecoはその出力だけ読み取りで使う」パターンを戦略として確定し、favoreco本体を「自分の記録 × 横断 × 登録の楽さ」に集中させる。SNS化の誘惑に対する明文の歯止め。

### 主な変更ファイル
- docs/02-コンセプトと勝ち筋.md（勝ち筋#4にSNS非採用決定を追記）
- docs/spec-A8-チケット管理・通知.md（§6 シェアカードを唯一の社交手段と明記）

### 確認結果（実機 / ビルド）
ドキュメントのみ。ビルド対象なし。

### 残課題
- シェアカードの具体設計（テンプレ・背景透過ステッカー・年間ベスト）＝Mystorium RESONANCEカード資産の流用
- 将来サブスクの目玉として限定的共有機能を検討する余地は残す（当面は非採用）

## 2026-07-07: U4リスト画像OCR取込（汎用）＋FC管理を登録情報・連携ハブへ

### 変更概要
- **U4「リスト」ユニットに📷画像OCR取込を追加（汎用・A3 §5-2 新設）**：ユーザー指摘「セトリ記録はOCRで写真から入れたい／博物・美術展でも使えそう」を受け、**セトリ専用でなく U4 を使う全種別の共通機能**に一般化。写真→撮影補正（feasibility §4-2）→Vision `VNRecognizeTextRequest`→縦位置ソートで順序化→プレビューで訂正/並び替え→U4 unitFieldsRaw。呼び名は種別切替（ライブ=セトリ／観劇=演目／美術展=出品目録・作品リスト／おでかけ=見たもの）。外部ライブラリゼロ。
- **美術展での住み分けを明記**：U4出品目録OCR＝観たもののチェックリスト／U11コレクション＝自分で撮った個別作品の写真＋キャプション。曲名/作品名は名寄せ正規化で A5 演奏回数・再訪集計に接続。複数列/縦書き/番号なしのパース注意と、複雑レイアウトの行単位フォールバック（失敗しない設計）を実装メモに記載。
- **FC管理の置き場所を「マイ/設定 > 登録情報・連携」ハブに確定（A8 §3.4 新設）**：ユーザー指摘「ユーザー登録情報にFC管理を／Googleカレンダー連動でどうせアカウントを入れる」を反映。FCアカウント/名義は個々のチケットに埋めず**ユーザー登録情報として一元管理**（1回登録・全チケットから参照＝Cherie Log同型）。同ハブに**外部カレンダー連携（EventKit＝Apple/iOS上のGoogleアカウント経由・読み取りのみ）**を同居させ「アカウントを入れる場所」を1箇所に集約。パスワードは平文保存しない方針を維持。

### 変更意図
OCRリスト取込を最初からU4汎用として設計し、ジャンル追加のたびに作り直さない。FC名義を record内蔵からユーザー登録情報（マスター）へ引き上げ、外部アカウント連携と同じ「連携」面にまとめることで、掛け持ち運用と設定導線を自然にする。

### 主な変更ファイル
- docs/spec-A3-ユニット別フィールド.md（§5-2 リスト画像OCR取込 新設）
- docs/spec-A8-チケット管理・通知.md（§3.4 登録情報・連携ハブ 新設・setlist/v1スコープに画像OCR追記）
- docs/spec-A7-登録フロー.md（U4リストOCRの入力補助を観察に追記）
- docs/08-テンプレユニット設計.md（美術展リスト＝出品目録OCR・U11住み分けを追記）
- favoreco/CLAUDE.md（U4リストOCR汎用・FC登録情報ハブを追記）

### 確認結果（実機 / ビルド）
ドキュメントのみ。A3/A7/A8/08/CLAUDE.md の相互参照が矛盾しないことを読み直しで確認。

### 残課題
- リストOCRの精度チューニング（種別辞書＝曲名/作品名の表記ゆれ・複数列パース）
- 外部カレンダー連携の実装範囲（EventKit読み取り・Google経由の確認）はfeasibility §4-3準拠で継続
- FC/名義の名寄せ（同一FC重複統合）＝A6

## 2026-07-07: 推し活/チケット/ライブ管理アプリのリサーチ → spec-A8（チケット管理・通知）新設・v1徹底作り込み確定

### 変更概要
- **競合リサーチ（推し活/チケット/ライブ管理）**：ユーザー指摘「チケコレは更新停止・レビュー無し＝参考にしない」を受け、クラスタを調査。実質の王者は **LiveSoul**（抽選管理＝当選率追跡/締切リマインダー/座席一部3D/遠征マップ・★4.5/1273件）・**TheaterRecords**（チケットOCR自動認識/分析）・**Cherie Log**（複数名義・掛け持ち管理）。ビジュアル派＝**Live Rock/relight/Tickemo**（セトリOCR/シェアカード/カウントダウン）。
- **戦略の確定**：競合は全て単一ジャンル専門アプリ。favorecoの勝ち筋は①**横断**（観劇/ライブ/映画を1アプリ・統一統計）②**登録の楽さ**。Live Rockの★4レビュー2件が競合の最大共通不満＝「初期設定・全手動入力が面倒／既存公演は外部連携で引きたい／会場・アーティスト検索が弱い」を名指し → favorecoのA7（OCR/URL取込/参照DB連携/名寄せ）が直接刺さることを確認。
- **v1スコープ確定（ユーザー：「V1を徹底的に作り込む、通知機能なども含めて」）**：チケット/ライブ管理を **A寄り＝v1でフル装備**。状態pipeline・通知全タイプ・FCアカウント/名義管理・OCRスキャン・座席テキスト・セトリ（並び替え可）・当選率/名義別/座席傾向分析・カウントダウンを v1。**3D座席のみ v2**（スコープ判断でなくデータ制約＝会場別座席図が要る／LiveSoulも対応会場のみ）。シェアカード・セトリ外部連携・認証情報キーチェーンも v2。
- **新規 spec-A8 作成**：チケット状態pipeline（気になる→申込前→当落待ち→当選/落選→入金待ち→発券待ち→参戦済/見送り）・先行区分・期限フィールド・通知設計（UserNotifications・タイプ別/オフセット・ScheduleResultで失敗可視化）・**FCAccountエンティティ**（会員番号/有効期限アラート/年会費/掛け持ち色分け・パスワードは平文保存しない方針）・OCR取込・集計連携を1本に集約。

### 変更意図
チケコレを基準にした旧設計を、現行の実質王者（LiveSoul/TheaterRecords/Cherie Log）基準に更新し、「記録も管理も一番」を v1 から成立させる。分量が多いため独立分冊（A8）に切り出し、A3/A5/08 からは参照させて重複を避ける。

### 主な変更ファイル
- docs/spec-A8-チケット管理・通知.md（新規・正本）
- docs/spec-A3-ユニット別フィールド.md（FCAccountマスター追加・チケット行をpipeline/先行区分/セトリ/名義参照に拡張・CloudKit関係にfcAccount追加）
- docs/spec-A5-集計カレンダー地図.md（当選率/セトリ演奏回数/名義別/座席傾向を統計表に追加）
- docs/08-テンプレユニット設計.md（チケットユニットをA8参照に更新・通知v1前倒しを明記・FC名義/セトリ追記）
- favoreco/CLAUDE.md（チケット/ライブ管理v1徹底作り込みの1項追加）

### 確認結果（実機 / ビルド）
ドキュメントのみ。ビルド対象なし。A3/A5/08/CLAUDE.md の記述が spec-A8 と矛盾しないことを読み直しで確認。

### 残課題
- 認証情報（パスワード）のキーチェーン/パスワード連携の要否（v1はloginHintのみ・平文非保存を確定）
- セトリの外部DB連携（Livefans等）の可否・規約
- 3D座席の対応会場データ源
- FCAccountの名寄せ（同一FC重複統合）詳細＝A6準拠
- 通知設定UI・カウントダウン表示のデザインフェーズ確定
- ライブラリ（spec-B1）の残ジャンル（ライブ/酒/おでかけ/書籍）と、観劇ライブラリへのFC名義・当選率の反映

## 2026-07-06: 書籍テンプレ確定（消失分の復元）＋参照DBシード元一覧を追加

### 変更概要
- **書籍テンプレ確定（08 §4-11）**：作品DB・バーコード・ソーシャルでは戦わない方針の上で復元。ISBN取得＝**openBD**（無料・和書に強い・入力補助のみ）＋**奥付OCR○**（洋書/同人/古書=openBD穴埋めフォールバック）。対象=本(1冊/1巻)・回=読んだ回。成果=読了/積読/中断/再読。
- **シリーズ・続巻機能★**：seriesName＋巻数でグルーピング。**最新刊登録(add-next)**（最新巻から属性引き継ぎ＋巻数+1で登録）・**巻スクロール**（シリーズビュー）・**一覧のスタック表示**（シリーズを重ねた1タイルに畳む）。v1はseriesNameグルーピング（派生・ハードなSeriesエンティティなし）。
- **書籍種別サブレイヤーは通さない**：ユーザーの読書（漫画・技術・デザイン）では形態(U14)1つで十分。A2のsubType nil特例＋後付け可なので将来も痛い作り直しなし。
- **参照DBシード元一覧（docs/11 新規）**：各カテゴリのデータ取得元をカタログ化（実取得はWeb取得可能な環境に依頼する前提・当環境は403多発）。

### 決定ログ
- openBD vs 奥付OCR＝相補（openBDが持てば構造化で精度上・無ければOCR/手動。洋書はopenBD弱くOCRが効く）。
- 場所（読んだ場所）・評価軸レーダーは書籍では低価値→○オフ開始。座席等＝–。
- テンプレ第1弾が全確定（観劇/美術展/ライブ/映画/酒/おでかけ施設/御朱印/書籍）。テーマパークはおでかけ施設に統合。
- **登録フローの入り口を精緻化（spec-A7）**：書籍＝**NDL Searchでタイトル検索**（openBDはISBN引きのみ）＋バーコードは**「ISBN(978〜)」と明示・価格コード(192〜)は自動リジェクト**（マイクロコピー原則＝生活語＋誤操作防止語だけ明示・司書資格者のユーザー指摘）。奥付OCRは**洋書対策として残す**（稀）。酒の「銘柄で探す」＝**さけのわデータAPI採用**（無料・商用可・帰属のみ・2500超銘柄＋フレーバー数値）。御朱印＝地図/名前/現在地から選ぶ（Apple POIが本物のDB）。"探す"が言えるのは裏に本物のDB/APIがある時だけ（映画TMDb・書籍NDL・酒さけのわ・場所Apple POI）。
- **観劇・美術展・ライブ＝URL(OGP)を主フックに格上げ**（2026-07-06 ユーザー指示）：公開DBが無いこれらは、公演/展覧会/ツアーのURL（公式・チケサイト・公式X）を貼ると**OGPで最低限（公演名 og:title・キービジュアル og:image・概要 og:description）を自動取得**。映画のURLフォールバックと同じ仕組みを主役化。構造化データ（キャスト/セトリ）は手動、チラシ写真をアイキャッチにする副フックも。

### 映画テンプレ拡充（2026-07-06 確定）
- 原題/製作年/製作国/上映時間/ジャンル/あらすじ/監督/脚本/出演者/ポスターを **TMDb（無料API・日本語・映画版openBD）** で自動取得。**登録フロー＝タイトル入力→サジェスト→選択で自動フィル→自分の記録を足す**。**URL(OGP)フォールバック**（映画.com/公式・単館やTMDb未収録の穴埋め・全文スクレイピングはしない）＋手動。
- **あらすじは「続きを読む」で畳む**・あらすじ(取得)とメモ(感想)は別欄。**出演者を○→●昇格**（人物マスター→「この監督/俳優の映画n本」＝自分のフィルモグラフィ統計）。映画.com/Filmarks/IMDbはAPI無し/複製不可で使わず、開かれたTMDbのみ。08 §4-5・docs/11 §5b。

### 残課題
- カード系（ご当地カード）テンプレの項目別ヒアリング（将来）
- **②-A（データモデル仕様 A1〜A7）一巡完了（2026-07-06）**。A6＝同一対象判定（正規化＋fetch-first upsert・リピートはタイトル正規化＋候補提示でユーザー確定）・スナップショット（生きた参照＋値コピー・削除/参照DB消滅に耐える）・共有マスター横断リンク（酒蔵ハブ実装）・PhotoBlob role/caption拡張（09 §11に追記）。08 §5の持ち越し5項目も全解消（A6 §6）。**次は Xcodeプロジェクト作成＋PoC（実装①）**。

## 2026-07-06: おでかけ施設・御朱印テンプレ確定＋天気自動付与＋参照DB配信方針

### 変更概要
- **おでかけ施設テンプレ確定**（08 §4-7）: テーマパーク／水族館／動物園を**1テンプレ＋施設種別サブレイヤー**（案A）に統合。施設マスターDB・会計独立ユニット・見たもの記録は(a)回ごとのみ。
- **御朱印カテゴリ確定**（08 §4-8）: 軽量・体験/旅と併存。印種別サブレイヤー（御朱印/御城印/御船印）・位置情報必須・直書き/書き置き・由緒書き写真=コレクション・都道府県マップ。
- **天気アイコン自動付与**（08 §4-9）: 出かける系共通（観劇/美術展/ライブ/おでかけ施設・酒店書籍映画は除外）。WeatherKitで訪問日経過後に履歴天気を取得しSF Symbolsで表示。取得範囲2021/8〜。
- **参照DBの配信方針転換**（08 §4-10）: 場所DB（御朱印/城/船/施設）を同梱プリセットではなく**テンプレONでダウンロード（CloudKit公開DB）**。ここを課金の柱にする意向。
- 水族館・動物園の記録フィールドリサーチ（docs/10）を追加済み。

### 変更意図
- テーマパークのヒアリング中に水族館・動物園も同種と判明→施設種別サブレイヤーで統合（A2の2例目・下地の再利用）。御朱印もリサーチの結果「王者はDBと探すに振りデザインが弱い」＝体験の美しさが空白と確認、軽量カテゴリとして参入。
- 天気は「日付が過ぎたら自動でアイコン」というユーザー発案を土台機能化。Yahoo天気は終了/外部契約のためWeatherKit（Apple純正・方針適合）を採用。
- DB配信は「同梱せずDLで増やし課金の柱に」というユーザー意向。純ローカル原則の例外としてCloudKit公開DBで実装。

### 主な変更ファイル
- docs/08-テンプレユニット設計.md（§4-7〜§4-10 追記）
- docs/10-水族館・動物園リサーチ.md（別コミット9dfe06dで追加済み）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
ドキュメントのみ。実機・ビルド対象なし。

### 決定ログ・要確認
- **AI生き物ライフリスト**: favorecoには入れない（体験ファーストのコンセプト外）。姉妹アプリ構想として温存。※ユーザー補足「作る気はあまりないが、AIを低ランニングコストで簡単に乗せられるならやる」→ 実装容易性の調査は将来課題。
- **参照DBの課金枠＝(A)＋(B)併用で確定**（2026-07-06 追記）: (A)サブスクに参照DBアクセス＋更新を含める／(B)カテゴリDBパック単体販売（アドオン買い切り）。(C)買い切り込みは不採用（増えるDBを一度の買い切りで賄えない）。守る線=「記録は無料（Apple POIでどこでも可）、課金はDBの便利さのみ」。
- **参照DBは記録の正本にしない＝スナップショット**（2026-07-06 追記）: 記録時に場所の名称/住所/座標をVisitへ焼き付け。DBやスポットが消えても記録は無傷（spec-A1 §6）。閉業＝「もう行けない場所の記録」としてむしろ価値。
- **コストは"深さ"でなく"幅"**（2026-07-06 ユーザー指摘で修正）: 寺社/城/船は半有限で安定〜微減、増え続けない。継続コストは「一度作る＋軽い保守」。成長は新しい収集ドメイン追加で作る＝御酒印（場所=既存Breweryマスター流用）/ダムカード（国交省）/マンホールカード（GKP）/道の駅きっぷ/インフラカード…各々が新(B)パック。
- WeatherKit履歴の取得範囲2021/8/1〜は要出典確認済み（Apple Developer Forums）。それ以前・海外はアイコンなし。

### 決定ログ・追記（2026-07-06）
- **収集系の括り方＝案ii＝印系とカード系を別カテゴリで確定**。理由（ユーザー）：御朱印は「スタンプラリーと揶揄されるが参拝・訪問の"証"」であり、ダムカード等の配布収集品とは行為の意味が違うので切り分けたい。印系＝御朱印カテゴリ（御朱印/御城印/御船印/将来 御酒印＝酒蔵はBrewery流用）・カード系＝別カテゴリ「ご当地カード」（ダム/マンホール/道の駅/インフラ）。仕組みは共通・フレーミング（証 vs 収集）で分ける。
- **共有マスターによる横断リンク（酒蔵ハブで御酒印↔酒）**（ユーザー要望）：御酒印と酒が同じBrewery(酒蔵)を参照し、御酒印記録に「この酒蔵で飲んだお酒一覧」を出す・御酒印から酒蔵プリセット済みで酒を登録できる。成立条件＝同一酒蔵エンティティ参照（酒蔵DBから選ぶ／手入力は名寄せ）。横断は生きた参照を使いスナップショットとは別。**Breweryを共有マスターとして設計する下地はv1から**（御酒印パックはv1圏外）。一般則＝共有マスターを持つ記録は横断でつながる（Venue↔飲食店も同型）。feasibility §4-1f・08 §4-8。

### 残課題
- カード系テンプレ（ご当地カード）の項目別ヒアリング（v1圏外・将来）
- 書籍テンプレの復元（前セッションで議論・未保存）
- ②-A続き A3〜A7

## 2026-07-06: ②-A spec-A1/A2 を清書（消失したレビュー確定分の復元）

### 変更概要
- `docs/spec-A1-データモデル基盤.md`（新規）: RecordCategory / Event / Visit の中核モデル、Event/Visit境界ルール、CloudKit互換3条件、アイキャッチ二段構え、削除・退避、PhotoBlob、ユニット値の格納（個別プロパティ＋unitFieldsRaw JSON）を定義
- `docs/spec-A2-種別サブレイヤー.md`（新規）: 2階層マスター〈カテゴリ→SubType→軸/スペック/OCR〉、1階層=subType nil特例、解決ルール（categoryKeyでfetch→Swift側でOR判定）、key/displayName分離、v1は日本酒のみ、PoC検証項目

### 変更意図
- 前セッションで作成・ユーザーレビュー済みだった②-A分割（A1/A2）が、ツール不調で**保存されず消失**していた（GitHub・project-log のいずれにも記録なし）ことを、GitHub API直接確認で特定。確定内容は引き継ぎに残っていたため清書として復元した
- あわせて main へマージ実施（作業ブランチ全コミットをfast-forward・af04217→29a7d05）

### 主な変更ファイル
- docs/spec-A1-データモデル基盤.md（新規）
- docs/spec-A2-種別サブレイヤー.md（新規）

### 確認結果（実機 / ビルド）
ドキュメントのみ。ファイル実在をls/wc/git statusで検証済み（前セッションの偽装成功を踏まえ二重確認）。

### 決定ログ（2026-07-06 ユーザー再確認で全決着）
- **Event/Visit境界**: 会場・総合評価・座席・写真・成果・タグ・同行者・金額を Visit 側に置く。理由=ツアー公演/再飲で「1対象=1評価・1会場」前提が破綻するため。→ **確定（そのまま）**
- **ツアーの扱い**: 東京公演と大阪公演は「同じ対象（1 Event）＋別の回（2 Visit）」。別Eventにはしない。→ **確定**（ユーザー選択）
- **アイキャッチ**: **回ごとに個別**（Visit.eyecatchPath）。リピート登録時は直前の回のアイキャッチを初期値として引き継ぎ、その回だけ個別変更も可。対象単位のまとめ表示（リピートグループ・統計）用に Event 代表（既定=初回Visit・独立指定も可）を併せ持つ。※一度「v1は1段」と誤記→ユーザー訂正「Visit毎に個別で選べる／リピートは前回引き継ぎ／個別でも変えられる」で確定。→ **確定**
- **スペック格納の二本立て**: U9自由ペアは unitFieldsRaw の JSON のまま。ただし**日本酒の定番数値（精米歩合/日本酒度/酸度/アルコール分）は検索・グラフ用に Event 側の専用数値列へ昇格**（ユーザー「グラフ・ソート出したい」）。OCRはこの2系統へ振り分け。→ **確定**

### 残課題
- ②-A 続き: A3（ユニット別フィールド）/ A4（テンプレ別プリセット具体リスト・種別別の数値列振り分け含む）/ A5（集計・カレンダー・地図）/ A6（周辺）/ A7（登録フロー）
- 書籍・テーマパークのテンプレ確定（08 §4-7/§4-8 未着手）は前セッションのチャットで議論済みだが未保存 → 別途復元が必要

## 2026-07-05: 酒の種別サブレイヤー下地を設計要件化＋URL複数化・SNSトグル

### 変更概要
- **酒種別サブレイヤーの下地をv1必須の設計要件に格上げ**（ユーザー強調「ちゃんと下地作らないと後で後悔する」）。〈カテゴリ→酒種別→軸/スペック/OCR辞書〉の2階層マスターで、種別（日本酒/ビール/ウィスキー…）を選ぶとプリセットが切り替わる仕組み。v1で下地を通し中身は日本酒のみ実装
- URL欄を「＋で複数」に、SNS（X/Instagram/Threads）を各サービス別トグルに一般化——全テンプレ共通の土台項目へ

### 変更意図
種別ごとに味覚軸・スペック・OCR辞書が違う。後付けすると既存記録の移行が発生し、Mystoriumの「enum rawValue変更→デコード不能クラッシュ」「後から重いリファクタ」の二の舞になるため、種別フィールドと種別キー引きの仕組みを最初から通す。

### 主な変更ファイル
- docs/08-テンプレユニット設計.md（§4-6★★下地設計要件・土台にURL複数/SNSトグル）
- docs/favoreco-feasibility.md（PoCに2階層マスター検証を追加）
- favoreco/CLAUDE.md（§5にサブ種別レイヤー下地ルール）

### 確認結果（実機 / ビルド）
ドキュメントのみ。

### 残課題
- 残り1テンプレ（書籍）。テーマパークは未着手
- ②-A: 2階層マスターの具体設計・種別別プリセットのデータ構造

## 2026-07-05: 酒テンプレ確定（5/7）＋味覚マップ・ラベルOCR・酒蔵マップ

### 変更概要
酒テンプレを日本酒ベース・銘柄単位で確定（08 §4-6）。新ユニット2つ（U16ラベルOCR・U17味覚2軸マップ）と新マスター（Brewery=酒蔵・所在県付き）、酒蔵所在県マップ（v1）を追加。

### 決定ログ
- 記録単位=銘柄単位（Untappd/さけのわ型）／日本酒ベース1テンプレ／アイキャッチ3:4縦
- **味の評価＝U17味覚2軸マップ（甘辛×濃淡）を基本**（業界標準・軽い）。6軸レーダー(U7)・官能メモ(U10)は両方オンオフ可のオプション（「そこまで味分かる人いない」ため基本オフ）
- スペック表プリセットに使用米・酵母を追加／ラベルOCR●（Vision標準）
- **酒蔵をDB化（Breweryマスター・所在県付き）**、URLは酒蔵EC対応／**酒蔵所在県マップをv1に**（好きな産地を地図で一覧・MapKit資産）
- 場所○・金額○・コレクション○・リピート●・タグ●・成果●・同行者○
- 飲食店記録との連動は将来構想として記録（②-A以降）
- アイキャッチ比率＝プリセットは対象物比率のまま維持（「スマホは3:4」指摘に対し、トリミングで対応する運用で決着）

### 主な変更ファイル
- docs/08-テンプレユニット設計.md（§4-6・U16/U17・マトリクス）
- docs/favoreco-feasibility.md（Brewery エンティティ・§4-1c 所在県マップ）

### 確認結果（実機 / ビルド）
ドキュメントのみ。

### 残課題
- 残り2テンプレ（テーマパーク・書籍）
- ②-A: 飲食店テンプレ（第1弾外）と酒の連動設計・Breweryと銘柄の紐付け


## 2026-07-05: 映画テンプレ確定（4/7・Filmarks流）

### 変更概要
「大手のマネでいい」方針により、Filmarksの設計（スコア一本評価・鑑賞方法の構造化）に寄せて確定。08 §4-5に記録。

### 決定ログ
- レーダー○（スコア一本文化＝総合評価が担う）／イベント回（舞台挨拶・応援上映）は専用欄なしのタグ運用／形態●=鑑賞方式（劇場/IMAX/4DX/ドルビー/配信）
- アイキャッチ2:3縦・参加日=開映時刻+上映時間15分刻み・コレクションに入場者特典明記・他は提案どおり

### 主な変更ファイル
- docs/08-テンプレユニット設計.md（§4-5新設・マトリクス更新）

### 確認結果（実機 / ビルド）
ドキュメントのみ。

### 残課題
- 残り3テンプレ（酒・テーマパーク・書籍）


## 2026-07-05: ライブ・フェス参戦テンプレ確定（3/7）

### 変更概要
リサーチ根拠付きの完成案提示＋好み判断のみのヒアリングで確定（ユーザーの知見が薄い領域のため方式を変更）。08 §4-4に記録。

### 決定ログ
- アイキャッチ=1:1正方形（ジャケ写文化）／レーダー○（セトリ・感想中心文化）／**金額=独立ユニット●**（グッズ代・遠征費の推し活会計。チケ代はチケットユニットと分担）
- 開場・開演の2段時刻＋公演時間30分刻みセレクト／座席=「座席・整理番号」／コレクションに銀テープ明記
- 他は提案どおり（出演者●・セトリ●・リピート●・形態●等）

### 主な変更ファイル
- docs/08-テンプレユニット設計.md（§4-4新設・アイキャッチプリセット・マトリクス更新）

### 確認結果（実機 / ビルド）
ドキュメントのみ。

### 残課題
- 残り4テンプレ（映画・酒・テーマパーク・書籍）


## 2026-07-05: 美術展・博物展テンプレ確定（項目別ヒアリング2件目）

### 変更概要
美術展テンプレを項目別ヒアリングで確定し、08 §4-3に記録。会期専用フィールド（●・カレンダー会期バーの元データ）を新設。

### 決定ログ
- 基本情報=観劇と同構成／会期●／参加日=訪問日+入場時刻(任意)+滞在時間セレクト／チケット●（観劇と同構成）
- 形態●に昇格（企画展/常設/芸術祭/巡回）／レーダーは○に降格（「基本オフでカスタムできれば十分」ユーザー判断）
- 作家○（出演者ユニット転用）／リスト○（心に残った作品）／他は提案どおり
- **UI設計原則を追加: 日付・期間の入力はカレンダー式ピッカー（日付ホイール禁止）。期間は開始→終了をタップで範囲選択**（08 設計原則5）

### 主な変更ファイル
- docs/08-テンプレユニット設計.md（§4-3新設・設計原則5・マトリクス更新）

### 確認結果（実機 / ビルド）
ドキュメントのみ。

### 残課題
- 残り5テンプレ（ライブ・映画・酒・テーマパーク・書籍）のヒアリング


## 2026-07-05: カレンダーの終日・期間表示の描き分けルール確定（モックv3）

### 変更概要
Googleカレンダーの「終日帯が積み上がる」表示への不満を起点に、モック3版の往復で描き分けルールを確定。feasibility §4-3に正式記録。

### 決定ログ（モックv3で合意）
1. 期間もの（販売期間・会期）＝セル下部の**期間バー**（太め・バー内白抜きタイトル・重なりは2段まで＋n）。背景ベタ塗り案は「重なりに弱い」というユーザー指摘で廃止
2. 発売日＝販売期間と同一データの開始点を枠線チップで強調（点と線の関係）
3. 通常イベントチップ＝タイトル2行まで・あふれ「+n」
4. 終日体験＝月はグレー枠線1行チップ／週は折りたたみピル（ユーザー指定）
5. 済み記録＝薄めチップ（参加済みの意）
6. 月グリッドは7列完全均等・iPhone縦比率で検証
- デザインベース＝リキッドグラス（アプリ全体・コンセプト§6に記録済み）

### 主な変更ファイル
- docs/favoreco-feasibility.md（§4-3に描き分けルール6項を追記）
- モック: Artifact（calendar-mock v3.1・白基調）

### 確認結果（実機 / ビルド）
ドキュメント＋HTMLモックのみ。

### 残課題
- 残り6テンプレの項目別ヒアリング（美術展から）

## 2026-07-05: CloudKit写真ストレージ仕様（PhotoBlob方式）を正本として採用

### 変更概要
Mystorium V10で当日実装・実機検証された写真ストレージ仕様（PhotoBlob＋externalStorage）を `docs/09-CloudKit写真ストレージ仕様.md` として取り込み、favorecoのデフォルト構造に採用。07・feasibility・実装仕様正本の「写真はファイルパス正本」記述をPhotoBlob方式に更新。

### 変更意図
CloudKit自動同期はSwiftDataストアの中身しか同期せず、ファイル直置きの写真は同期に載らないことがMystorium実装で確定したため。externalStorageならDB肥大化を回避しつつ同期対象にできる（実績: 4,808枚・1,201.9MB移行・失敗0件）。favorecoは最初からblob方式で作れば移行コード自体が不要——「新規開発の利点を取り切る」方針の具体化。

### 主な変更ファイル
- docs/09-CloudKit写真ストレージ仕様.md（新規・Mystorium発の仕様書）
- docs/07-CloudKit同期設計リファレンス.md（旧記述「externalStorageに依存しない」を撤回・修正）
- docs/favoreco-feasibility.md（§2保存方針を更新）
- favoreco/CLAUDE.md（§5実装ルールにPhotoBlob・Swift 6 nonisolated等を追加）

### 確認結果（実機 / ビルド）
ドキュメントのみ（仕様の実機検証はMystorium側で完了済み）。

### 残課題
- 残り6テンプレのヒアリング／カレンダー終日表示の描き分け方式のユーザー確認（モック提示中）

## 2026-07-05: カレンダー機能の範囲・時期確定、観劇テンプレ全項目確定

### 変更概要
- カレンダー: **A（Google式の体験特化カレンダー）＋B（EventKit外部予定重ね表示）を両方v1に投入**。週/日は時間軸グリッドのGoogle式完全再現（ユーザーのGoogleカレンダー実スクショを仕様の参照に）。C（汎用予定作成）は「やらないこと」に明記
- 観劇テンプレ: 上演時間セレクト式を採用し**全項目確定**

### 変更意図
ユーザーの実際のカレンダー（体験の予定と生活の予定が1つに混在）を見ると、外部予定の重ね表示がないと乗り換え価値が半減するため、Bをv1に含める。汎用予定の作成はGoogle/Appleカレンダーの土俵なので戦わない。

### 主な変更ファイル
- docs/favoreco-feasibility.md（§4-3をA+B確定仕様に更新：ビュー・レイヤー構成）
- docs/favoreco-mvp.md（カレンダーをv1主役機能として詳記）
- docs/favoreco-concept.md（やらないことに汎用予定作成を追加）
- docs/08-テンプレユニット設計.md（上演時間セレクト式確定・観劇テンプレ完了宣言）

### 確認結果（実機 / ビルド）
ドキュメントのみ。

### 残課題
- 残り6テンプレの項目別ヒアリング（次は美術展）
- v1実装量が増えた（時間グリッド新規・EventKit）——実装フェーズの分割計画で吸収する

## 2026-07-05: 地図・場所入力3系統とカレンダー連携（EventKit）の方針決定

### 変更概要
- 場所入力を3系統に確定: アプリ内検索（MapKit）／Google共有URL／Apple共有URL（ユーザー提案）。Google Places APIは不採用
- カレンダー連携はEventKit読み取りでApple/Google両カレンダーの予定をfavorecoカレンダーに薄く重ね表示する方針を決定（投入時期・カレンダー機能全体の範囲A/B/Cは保留）

### 変更意図
- Places APIの規約（取得データの永続保存不可・30日キャッシュ・Place IDのみ永続）が「一生残す記録アプリ」と根本非互換のため。「特定はGoogleの精度・保存はAppleデータ＋リンク」の分業で、精度ニーズと規約・運営費ゼロ構造を両立する
- GoogleカレンダーはiOS標準カレンダー経由でEventKitから読めるため、Google API直接連携は不要と判断

### 主な変更ファイル
- docs/favoreco-feasibility.md（§4-2 地図・場所入力 / §4-3 カレンダー連携を新設）

### 確認結果（実機 / ビルド）
ドキュメントのみ。

### 残課題
- カレンダー機能の範囲（体験特化A／連携B／汎用C）と投入時期の決定（ユーザー保留中）
- 観劇テンプレ: 上演時間セレクト式の採否確認
- 残り6テンプレの項目別ヒアリング

## 2026-07-05: 観劇テンプレの項目別ヒアリング完了（1点のみ確認継続）

### 変更概要
観劇テンプレを1項目ずつヒアリングし、08 §4-2 に確定構成を記録。基本公演情報（アイキャッチ/タイトル+サブタイトル/URL+X+insta/会場/主催/メモ+総合評価）・参加日（開演・開場・上演時間）・チケット（発売日時・アラーム・チケットサイト・入手経路・支払/発券・チケ代）のグループ構成はユーザー定義。

### 決定ログ
- 座席●・キャスト●・同行者●・タグ●・レーダー●・成果●・コレクション●・リピート●・形態●（現地/配信/LV）・作品ジャンル●（マチソワは開演時刻から自動判定）・リスト–・官能–
- 金額は独立ユニットにせずチケットに統合（観劇の場合）
- スペック表＝OFF開始の任意ON。プリセットチップ: 作/脚本・原作・演出・翻訳（企画製作は外す・上演時間は参加日へ移管）
- 「会場時間」＝開場時間（任意欄）
- **チケット発売リマインド通知をv1に昇格**（MVP更新済み。Mystoriumで後付け実装が面倒だった教訓）
- 上演時間はセレクト式（入力はセレクト・保存は終演を自動導出）を推奨提示中——採否のみ確認待ち

### 主な変更ファイル
- docs/08-テンプレユニット設計.md（§4-2 観劇確定構成）
- docs/favoreco-mvp.md（発売リマインドのv1昇格）

### 確認結果（実機 / ビルド）
ドキュメントのみ。画面モックはArtifactで提示（スペック表・観劇詳細・トグル設定）。

### 残課題
- 上演時間セレクト式の採否確認
- 残り6テンプレ（美術展・ライブ・映画・酒・テーマパーク・書籍）の項目別ヒアリング

## 2026-07-05: アイキャッチ全カテゴリ標準化・書籍テンプレ昇格・作品ジャンルユニット追加

### 変更概要
- アイキャッチを全カテゴリの土台項目に追加。**縦横比はカテゴリごとに設定**（テンプレプリセット案: 観劇/美術展=A4縦、映画/書籍=2:3縦、酒=3:4縦、ライブ=16:9横、テーマパーク=4:3横）
- **書籍をテンプレ第1弾に昇格**（6種→7種）。形態プリセット=マンガ/小説/参考書/技術書/電子書籍/紙
- **U15作品ジャンル**ユニット新設（SF/推理/恋愛等。映画・書籍で標準ON。タグと違いカテゴリ内管理の分類）

### 変更意図
ユーザー指示（2026-07-05）。書籍は「受け皿」から器付きテンプレへ格上げするが、作品DB・バーコード・ソーシャルで読書メーターと戦わない方針は不変（コンセプト§5の表現を更新）。

### 主な変更ファイル
- docs/08-テンプレユニット設計.md（土台にアイキャッチ・U15追加・マトリクス7列化）
- docs/favoreco-concept.md（§7テンプレ7種・§5やらないこと表現更新）
- docs/favoreco-mvp.md（テンプレ7種）
- favoreco/CLAUDE.md（§7更新）

### 確認結果（実機 / ビルド）
ドキュメントのみ。

### 残課題
- アイキャッチ縦横比プリセット案のユーザー確認
- 08マトリクスの残レビュー（●○–の過不足・コレクション標準ONの是非）

## 2026-07-05: テンプレユニット設計の草案作成

### 変更概要
「テンプレは項目ユニットの組み合わせ・カスタムも同じユニットを再利用」というユーザー方針を `docs/08-テンプレユニット設計.md` として設計草案化。土台5項目＋ユニット14種＋テンプレ6種×ユニットのマトリクスを定義。

### 変更意図
「美しく記録する」の実装面の担保として「使わないユニットは表示に出ない」原則を採用。スキーマはスーパーセット固定（動的スキーマ禁止・CloudKit互換維持）とし、テンプレ6種は「保存済みプリセット」にすぎない構造にすることで、テンプレとカスタムの二重実装を避ける。

### 主な変更ファイル
- docs/08-テンプレユニット設計.md（新規・草案）

### 確認結果（実機 / ビルド）
ドキュメントのみ。

### 残課題
- ユニットの過不足・名称のユーザーレビュー
- ②-A持ち越し事項（U3/U14統合・スペック表のCloudKit表現・リピート判定・プリセット具体リスト）

## 2026-07-05: CloudKit同期設計をデフォルト構造として採用

### 変更概要
MystoriumのiCloud同期設計（ON/OFF図解・Artifact PDF）を `docs/07-CloudKit同期設計リファレンス.md` として取り込み、favorecoのデフォルト構造に採用。feasibility・MVP・実装仕様の正本に「v1スキーマはCloudKit互換制約で設計する」ルールを反映。

### 変更意図
同期機能の公開はv2（サブスク）だが、CloudKit互換制約（リレーション全optional・unique制約なし等）は後付けできない。favorecoは新規開発なので、Mystoriumで必要になる「ストレージ移行バッチ」を最初から不要にできる——この利点を確実に取るため、v1のスキーマ・写真保存形式を同期前提で固定する。

### 主な変更ファイル
- docs/07-CloudKit同期設計リファレンス.md（新規・PDF内容の転記＋favoreco適用方針）
- docs/favoreco-feasibility.md（§2 保存方針にCloudKit互換要件を追加）
- docs/favoreco-mvp.md（v2項目に構造準備の注記）
- favoreco/CLAUDE.md（§5 重要実装ルールに追加）

### 確認結果（実機 / ビルド）
ドキュメントのみ。

### 決定ログ
- 同期の大原則を踏襲: デフォルトOFF・opt-inトグル／CloudKitプライベートDB（開発者から見えない・サーバー費ゼロ維持）／端末内データは絶対に消えない／動画本体は同期に載せない／zipバックアップ併用
- ②-A（データモデル仕様）のレビュー観点に「CloudKit互換か」を必ず入れる

### 残課題
- レビュー観点.md への「CloudKit互換」チェック項目の追記（②-A仕様書を書く段階で）

## 2026-07-04: 商標クリア確認、実現性メモ・MVP定義の草案作成（フェーズ4・5）

### 変更概要
- ユーザーによる商標・アプリ名調査の結果を記録: **favorecoは商標登録もアプリも存在せずクリア**（oshireco=終了済みサービス、推しレコ=I-O DATA商標だが録画系で役務非重複）。J-PlatPat確認の残課題を解消
- `docs/favoreco-feasibility.md` 草案作成（フェーズ4）: エンティティ素描・保存方針・山場・**致命リスク=RecordCategory化のPoC検証**を定義
- `docs/favoreco-mvp.md` 草案作成（フェーズ5）: v1に入れる9項目／入れない8項目／検証可能な成功条件5つ／粗ロードマップ

### 変更意図
立ち上げガイドの全フェーズを文書として揃え、実装着手前の合意対象を明確にする。

### 主な変更ファイル
- docs/favoreco-feasibility.md（新規・草案）
- docs/favoreco-mvp.md（新規・草案）

### 確認結果（実機 / ビルド）
ドキュメントのみ。

### 決定ログ
- 商標・名前被りクリア（2026-07-04 ユーザー確認）

### 残課題（ユーザー確認待ちの提案）
- コード共有方式: フォークでPoC→後で共有コア切り出し（推奨として記載・要承認）
- サブスクはv2導入・年間まとめはv1.x（年末）というロードマップの承認
- 無料層の制限設計（件数制限等）

## 2026-07-04: アプリ名「favoreco」正式決定

### 変更概要
アプリ名を favoreco（favorite + record）で正式決定。`APP_NAME/` を `favoreco/` にリネームし、実装仕様の正本（favoreco/CLAUDE.md）に確定済みプロダクト方針を転記。ルートCLAUDE.md §6・コンセプトシートの「仮称」表記を削除。

### 変更意図
名前の被り・商標をユーザーが下調べ（oshireco=終了済みサービス、推しレコ=I-O DATA商標だが録画系で役務が異なる）した上で採用判断。「ファボ」の響きが初期市場（観劇・推し活クラスタのX文化圏）と地続きである点も採用理由。

### 主な変更ファイル
- APP_NAME/ → favoreco/（リネーム）
- favoreco/CLAUDE.md（正本の初期化：コンセプト・スタック・確定方針を転記）
- CLAUDE.md §6（仮称削除・参照先更新）
- docs/favoreco-concept.md（仮称削除）

### 確認結果（実機 / ビルド）
ドキュメントのみ。

### 決定ログ
- アプリ名＝favoreco（2026-07-04 ユーザー決定）。対抗馬: 余韻/Yoin・Favorium・綴
- Bundle ID 案: `com.<開発者ID>.favoreco`（Mystoriumの規約に合わせて最終決定）

### 残課題
- J-PlatPatで「ファボレコ」「favoreco」の称呼検索（リリース前まで・Mac側で5分）
- README.md はスターターキットの説明のまま（Xcodeプロジェクト作成時にアプリ用READMEへ書き換え）

## 2026-07-04: キャッチの字句修正（「味わった」→「体験した」）

### 変更概要
確定キャッチを「観た・行った・**体験した**を、美しく一生残す。」に変更（ユーザー指示）。

### 変更意図
「味わった」は食に寄って聞こえるため、雑食＝あらゆる体験を受け止める言葉に広げた。

### 主な変更ファイル
- docs/favoreco-concept.md（§1）

### 確認結果（実機 / ビルド）
ドキュメントのみ。過去ログ・02資料内の旧表現は履歴として残置。

## 2026-07-04: コンセプトシート確定（フェーズ3完了）

### 変更概要
一言キャッチを「観た・行った・味わったを、美しく一生残す。」（1文完結・課金訴求なし）で確定し、コンセプトシートのステータスを「確定」に更新。

### 変更意図
「記録は買い切りで全部入り。」は俗っぽいというユーザー判断により、キャッチは世界観だけに専念させ、買い切り訴求はストア説明文・LPへ分離する。

### 主な変更ファイル
- docs/favoreco-concept.md（キャッチ確定・ステータス確定）

### 確認結果（実機 / ビルド）
ドキュメントのみ。

### 決定ログ
- キャッチ＝「観た・行った・味わったを、美しく一生残す。」（2026-07-04 ユーザー確定）。没案: 買い切り併記型・「柱」前面型
- これで立ち上げフェーズ3（コンセプト確定）完了。確定事項: コア体験／差別化（柱の横断×買い切り全部入り）／やらないこと／テンプレ第1弾6種＋横断フィールド／課金3層／デザイン方向性

### 残課題
- フェーズ4の残り: 致命リスクの特定・検証方法（実現性メモの正式化）
- フェーズ5: MVP定義表（機能レベルのin/out・v1成功条件）
- アプリ名の正式決定・共有コアorフォーク・具体価格

## 2026-07-04: 課金方針（3層）をコンセプトシートに反映

### 変更概要
コンセプトシートv2に §8 課金方針を新設。無料／買い切り（記録・自作カテゴリ・統計・年間まとめ・エクスポート）／サブスク（同期・自動バックアップ・思い出再提示・月次リキャップ・限定デザイン）の3層構造を明文化。キャッチ案Aと「やらないこと」のサブスク表現も整合するよう修正。

### 変更意図
「サブスクの線を残したい」というユーザー意向と、「統計・記録を人質にしない」という差別化の両立。統計は"見る能力=買い切り／自動で届ける=サブスク"で分離した。

### 主な変更ファイル
- docs/favoreco-concept.md（§8 課金方針追加・§1/§5修正）

### 確認結果（実機 / ビルド）
ドキュメントのみ。

### 決定ログ
- 統計の詳細化はサブスクに**入れない**（Filmarks対抗軸の維持。2026-07-04 提案採用）
- 自作カテゴリは買い切り側（キログが記録カスタマイズ無料のため、サブスク化は競合比較で不利）
- エクスポートは買い切りに含める（キログのCSV有料への対抗軸）
- 思い出の再提示（On This Day型）はオンオフ可のopt-in。通知型より「選んだ体験の写真ランダム表示」型を主に（2026-07-04 ユーザー意向：勝手に届くのは好みでない）
- 月次リキャップはfavoreco新規機能とし、Mystoriumには入れない（見せ方含め構造から必要なため。2026-07-04 ユーザー判断）
- 年間まとめは買い切り側（バイラル装置を課金壁に入れない）

### 残課題
- キャッチ3案の選択（A/B/C）→コンセプトシート確定
- 無料層の体験版制限設計（件数制限等）
- サブスク・買い切りの具体価格

## 2026-07-04: テンプレート第1弾の確定とコンセプトシートv2練り直し

### 変更概要
- テンプレート第1弾を6種＋横断フィールドで**確定**（観劇/美術展/ライブ参戦/映画/酒/テーマパーク＋「半券・印・カード写真＋メモ」共通フィールド）
- コンセプトシートをv2に練り直し（ユーザーの「練り直し」指示による。差別化を「柱の横断」主語に再構成、キャッチ3案併記、やらないことにゲーミフィケーション排除を追加）

### 変更意図
リサーチ（05/06）の結論をコンセプトに反映し、フェーズ5（MVP範囲確定）に進む前提を整える。

### 主な変更ファイル
- docs/favoreco-concept.md（v2草案へ全面改稿）
- CLAUDE.md（§6/§7 実環境反映・前コミット）

### 確認結果（実機 / ビルド）
ドキュメントのみ。Mac側のクローン・プル導線は確認済み（Already up to date）。

### 決定ログ
- テンプレート第1弾＝6種＋横断フィールド（2026-07-04 ユーザー確定）。サウナ・御朱印は王者アプリ存在によりテンプレ化見送り
- コンセプトシートv1の差別化・やらないことは確定に至らず「練り直し」判断（2026-07-04）

### 残課題
- コンセプトシートv2のレビュー（キャッチ3案の選択・差別化の言い回し・やらないことの範囲）
- フェーズ5: MVP定義表の作成（機能レベルのin/out）
- アプリ名の正式決定

## 2026-07-04: ジャンル別リサーチ2本の完了（05・06）

### 変更概要
- `docs/05-ジャンル別記録フィールドリサーチ.md` — リスト済み12ジャンルの記録フィールド表と横断設計パターン5つ
- `docs/06-追加ジャンル発掘リサーチ.md` — リスト外ジャンルの発掘と「記録文化×アプリ空白度」ランキング

### 変更意図
テンプレート第1弾の範囲決定（MVPスコープ）とフィールド設計（②-A）の素材とするため。

### 主な変更ファイル
- docs/05-ジャンル別記録フィールドリサーチ.md（新規）
- docs/06-追加ジャンル発掘リサーチ.md（新規）

### 確認結果（実機 / ビルド）
ドキュメントのみ。

### 決定ログ・知見
- 検証済みまで到達したのは観劇（シアティ実例・3-0票）のみ。他は検索ベース——実行環境のネットワーク制限（外部サイト403）により本文検証が不能だったため。②-A仕様化時に個別出典を確認する
- 御朱印は当初「手薄」想定だったが専用アプリの王者複数と判明 → テンプレ優先度を下げ「印」汎用フィールドで対応する方針に転換
- 「〇〇印」制度の増殖・半券分類ノート文化から、ジャンルテンプレとは別の横断仕様（半券/印/カード写真＋メモ）の必要性を確認
- リサーチ実行の運用知見: セッション休止でバックグラウンドのワークフローが停止する。再開時はスクリプトパス＋resumeFromRunId＋args再指定が必要

### 残課題
- テンプレート第1弾の範囲確定（フェーズ5 MVP：観劇・美術展・ライブ/推し活・映画・酒＋テーマパーク昇格の判断）
- コンセプトシートの差別化・やらないことの確定

## 2026-07-04: Mystorium構造リファレンス追加＋コンセプトシート草案（フェーズ3着手）

### 変更概要
- `docs/04-Mystorium構造リファレンス.md` を追加（Mystoriumの技術スタック・9モデル・設計原則・流用資産・SwiftData/SwiftUIの罠のまとめ。favoreco のベース参照用）
- `docs/favoreco-concept.md` を新規作成（立ち上げガイド フェーズ3のコンセプトシート）。コア体験を「記録が美しい思い出になる」の1つに確定

### 変更意図
- 04はimmersiveApp `docs/favoreco-handoff` 由来の資料（リモート未プッシュのためアップロード経由で持ち込み）。技術設計の出発点として正本化する
- コンセプトシートは 01/02 の検討結果を台本のフォーマットに落とし、コア体験の一本化をユーザーと合意した記録

### 主な変更ファイル
- docs/04-Mystorium構造リファレンス.md（新規）
- docs/favoreco-concept.md（新規・ステータス検討中）

### 確認結果（実機 / ビルド）
ドキュメントのみ。ビルド対象なし。

### 決定ログ
- コア体験＝「記録が美しい思い出になる」に一本化（2026-07-04 ユーザー選択）。統計・シェアカードは付加価値の位置づけ。理由: 「機能ではNotionに勝てず、勝てるのは体験の質だけ」という競合分析の結論との整合

### 残課題
- コンセプトシートの差別化・やらないこと（草案）のユーザー確認 → ステータスを「確定」へ
- アプリ名の正式決定（現状「favoreco」仮称）・Bundle ID・デザイン言語
- フェーズ4以降: 共有コア or フォーク、MVPテンプレート数、価格、CloudKit

## 2026-07-04: Mystorium派生・汎用「体験」記録アプリの検討資料を持ち込み

### 変更概要
別セッション（Mystoriumプロジェクト）で実施した検討の正本3点を `docs/` に配置した。
- `docs/01-競合分析.md` — 書籍/映画/美術館/観劇/食べ歩き/汎用記録/推し活の競合調査
- `docs/02-コンセプトと勝ち筋.md` — 「作品DBが要らない"体験"の記録アプリ」に絞る戦略仮説
- `docs/03-Mystoriumからの技術移行メモ.md` — EventCategory enum をユーザー定義 Category モデルへ一般化する技術方針

### 変更意図
このリポジトリ（favoreco）を Mystorium 派生の汎用記録アプリの開発拠点とするため、前段の意思決定（フェーズ1〜2 相当：言語化・精査）の成果物を正本として引き継ぐ。

### 主な変更ファイル
- docs/01-競合分析.md（新規）
- docs/02-コンセプトと勝ち筋.md（新規）
- docs/03-Mystoriumからの技術移行メモ.md（新規）

### 確認結果（実機 / ビルド）
ドキュメントのみの変更。ビルド対象なし。

### 残課題
- コンセプトシート正式版の作成（`docs/新規アプリ立ち上げ.md` フェーズ3）
- アプリ名・Bundle ID・デザイン言語の決定
- コード共有方式（共有コア or フォーク）の決定
- MVPテンプレート数・カテゴリ横断統計の初期スコープ確定
- 価格（買い切り主役は確定・具体額未定）・CloudKit 初期導入可否

## 2026-07-10: FAVORECOアプリアイコン初版作成

### 変更概要
- 高級感あるSNS寄りのFAVORECOアプリアイコン初版を作成
- Fモノグラム＋しおり/記録カードを主モチーフにし、淡いピンク、オフホワイト、薄いブルー差し色で構成
- 比較用にシンボル案2種も保存

### 変更意図
App Store向けおよび既存アプリ組み込み前提の1024pxアイコンを用意するため。FAVORECOの「体験を美しく残す」方向性と、白ベース/リキッドグラス基調のデザイン方針に合わせた。

### 主な変更ファイル
- favoreco/assets/app-icon/favoreco-app-icon-1024.png（完成候補の1024pxアイコン）
- favoreco/assets/app-icon/favoreco-app-icon-final-source.png（生成元サイズの完成候補）
- favoreco/assets/app-icon/favoreco-app-icon-symbol-heart.png（比較用シンボル案）
- favoreco/assets/app-icon/favoreco-app-icon-symbol-abstract.png（比較用抽象シンボル案）
- favorecoAPP/favorecoAPP/Assets.xcassets/AppIcon.appiconset/favoreco-app-icon-1024.png（Xcode AppIcon用PNG）
- favorecoAPP/favorecoAPP/Assets.xcassets/AppIcon.appiconset/Contents.json（AppIconのfilename設定）

### 確認結果（実機 / ビルド）
- 生成画像を目視確認済み
- 完成候補が1024x1024pxであることを確認済み
- ビルド/実機確認は未実施

### 残課題
- 実機ホーム画面とApp Store Connect表示で小サイズ視認性を確認する
- 必要に応じてダーク/ティント用の別アイコンを作成する

## 2026-07-10: FAVORECOアプリアイコン色違い比較案追加

### 変更概要
- 既存FAVORECOアイコンの形状を維持した色違い案を3種追加
- ヴァイオレット系、黒系、ネイビー系を1024x1024pxで保存

### 変更意図
App Store向けアイコンの最終トーン比較を行うため。淡色ピンク案に加え、高級感・SNS感・小サイズ視認性を比較できる色展開を用意した。

### 主な変更ファイル
- favoreco/assets/app-icon/favoreco-app-icon-violet-1024.png（ヴァイオレット系）
- favoreco/assets/app-icon/favoreco-app-icon-black-1024.png（黒系）
- favoreco/assets/app-icon/favoreco-app-icon-navy-1024.png（ネイビー系）

### 確認結果（実機 / ビルド）
- 生成画像を目視確認済み
- 3案すべて1024x1024pxであることを確認済み
- AppIcon本体の差し替えとビルド/実機確認は未実施

### 残課題
- 採用色を決めた後、AppIcon.appiconsetへ反映する
- 実機ホーム画面で小サイズ視認性を確認する

## 2026-07-10: Fなしアプリアイコン比較案追加

### 変更概要
- F文字を使わないFAVORECOアプリアイコン比較案を3種追加
- SNSカード、ハートカード、しおりの3モチーフを1024x1024pxで保存

### 変更意図
Fモノグラム案以外の方向性を比較するため。文字に依存せず、体験記録・お気に入り・SNS感が伝わるアイコン候補を用意した。

### 主な変更ファイル
- favoreco/assets/app-icon/favoreco-app-icon-no-f-social-card-1024.png（抽象SNSカード案）
- favoreco/assets/app-icon/favoreco-app-icon-no-f-heart-card-1024.png（ハート＋記録カード案）
- favoreco/assets/app-icon/favoreco-app-icon-no-f-bookmark-1024.png（しおり＋記録カード案）

### 確認結果（実機 / ビルド）
- 生成画像を目視確認済み
- 3案すべて1024x1024pxに正規化済み
- AppIcon本体の差し替えとビルド/実機確認は未実施

### 残課題
- Fあり案とFなし案を並べて採用方針を決める
- 採用案決定後、AppIcon.appiconsetへ反映する

## 2026-07-10: ワインレッド系アプリアイコン比較案追加

### 変更概要
- FAVORECOアイコンのワインレッド系比較案を2種追加
- Fモノグラム版とFなししおり版を1024x1024pxで保存

### 変更意図
男女問わず使いやすい高級感のある色味を比較するため。ワインレッドを主色にしつつ、アイボリー、シャンパン、薄いブルー差し色で重くなりすぎない構成にした。

### 主な変更ファイル
- favoreco/assets/app-icon/favoreco-app-icon-wine-f-1024.png（ワインレッド系Fあり案）
- favoreco/assets/app-icon/favoreco-app-icon-wine-bookmark-1024.png（ワインレッド系Fなししおり案）

### 確認結果（実機 / ビルド）
- 生成画像を目視確認済み
- 2案とも1024x1024pxに正規化済み
- AppIcon本体の差し替えとビルド/実機確認は未実施

### 残課題
- 男女問わず合う最終案を選定し、AppIcon.appiconsetへ反映する
- 実機ホーム画面で小サイズ視認性を確認する

## 2026-07-10: Fなしアイボリー案をAppIconへ設定

### 変更概要
- Fなしのアイボリー系しおりアイコンをアプリ本体のAppIconに設定
- 通常/ダーク/ティントの3枠すべてに同じ1024px PNGを指定

### 変更意図
Fモノグラムではなく、男女問わず使いやすい中性的な記録/しおりモチーフを暫定採用して、実機で見え方を確認できる状態にするため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Assets.xcassets/AppIcon.appiconset/favoreco-app-icon-no-f-bookmark-1024.png（AppIcon用PNG）
- favorecoAPP/favorecoAPP/Assets.xcassets/AppIcon.appiconset/Contents.json（AppIcon参照先をFなしアイボリー案へ変更）

### 確認結果（実機 / ビルド）
- AppIconのfilenameが通常/ダーク/ティントすべて favoreco-app-icon-no-f-bookmark-1024.png になっていることを確認
- AppIcon用PNGが1024x1024pxであることを確認
- ビルド/実機確認は未実施

### 残課題
- 実機ホーム画面で小サイズ視認性を確認する
- 必要に応じてダーク/ティント用の専用アイコンを作成する

## 2026-07-10: AppIconをFなしワインレッド案へ修正

### 変更概要
- 暫定設定していたFなしアイボリー案から、Fなしワインレッドしおり案へAppIconを差し替え
- 通常/ダーク/ティントの3枠すべてに同じ1024px PNGを指定

### 変更意図
ユーザー指定の採用色がアイボリーではなくワインレッドだったため、アプリ本体のAppIcon参照を正しい候補に修正するため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Assets.xcassets/AppIcon.appiconset/favoreco-app-icon-wine-bookmark-1024.png（AppIcon用PNG）
- favorecoAPP/favorecoAPP/Assets.xcassets/AppIcon.appiconset/Contents.json（AppIcon参照先をFなしワインレッド案へ変更）

### 確認結果（実機 / ビルド）
- AppIconのfilenameが通常/ダーク/ティントすべて favoreco-app-icon-wine-bookmark-1024.png になっていることを確認
- AppIcon用PNGが1024x1024pxであることを確認
- ビルド/実機確認は未実施

### 残課題
- 実機ホーム画面で小サイズ視認性を確認する
- 必要に応じてダーク/ティント用の専用アイコンを作成する

## 2026-07-10: AppIconダーク表示を黒系案へ変更

### 変更概要
- AppIconのダーク表示枠のみ黒系アイコンへ変更
- 通常表示とティント表示はFなしワインレッドしおり案のまま維持

### 変更意図
ダークモード時に黒系の高級感あるアイコンを使い、通常表示との差分を確認できる状態にするため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Assets.xcassets/AppIcon.appiconset/favoreco-app-icon-black-1024.png（ダーク表示用AppIcon PNG）
- favorecoAPP/favorecoAPP/Assets.xcassets/AppIcon.appiconset/Contents.json（dark luminosity枠のみ黒系案へ変更）

### 確認結果（実機 / ビルド）
- 通常/ティントは favoreco-app-icon-wine-bookmark-1024.png、ダークは favoreco-app-icon-black-1024.png を参照していることを確認
- 黒系AppIcon用PNGが1024x1024pxであることを確認
- ビルド/実機確認は未実施

### 残課題
- 実機でライト/ダーク切替時のホーム画面アイコン表示を確認する

## 2026-07-10: 現状画面ラフボード作成

### 変更概要
- 現在実装されている主要画面の見え方を一覧できるラフボードを作成
- 初期設定、Home、記録一覧、カレンダー/統計、記録追加、記録詳細、カテゴリトップ、設定、表示設定、プロフィール、データ管理、ジャンル管理を1枚に整理

### 変更意図
実装済み範囲の画面構成を視覚的に確認し、今後のUI調整や不足画面の洗い出しに使うため。

### 主な変更ファイル
- favoreco/assets/mockups/current-pages-overview.svg（編集用ラフボード）
- favoreco/assets/mockups/current-pages-overview.png（確認用PNG）

### 確認結果（実機 / ビルド）
- PNGが2400x1780pxで生成されていることを確認
- 目視で12画面の配置とラベルを確認
- 実機スクリーンショットではなく、コード参照ベースの構造ラフ

### 残課題
- 実機またはシミュレータで実際のSwiftUI表示を確認する
- 必要に応じて各画面を個別の高精度モックへ分解する

## 2026-07-10: 初回オンボーディング流れ整理ラフ作成

### 変更概要
- 初回登録時に出す説明オンボーディングの流れを6画面で整理
- 価値訴求、記録内容、横断ジャンル、安心材料、ジャンル選択、開始確認の順に構成

### 変更意図
現行のジャンル選択だけでは初回ユーザーに「何のアプリか」「なぜジャンルを選ぶのか」が伝わりにくいため、登録前説明の見せ方を検討できる形にするため。

### 主な変更ファイル
- favoreco/assets/mockups/onboarding-flow-proposal.svg（編集用オンボーディング流れラフ）
- favoreco/assets/mockups/onboarding-flow-proposal.png（確認用PNG）

### 確認結果（実機 / ビルド）
- PNGが2200x1280pxで生成されていることを確認
- 目視で6画面の流れと推奨方針を確認
- 実装は未変更

### 残課題
- 文言を最終調整する
- 採用後、現行GenreOnboardingViewの前段として説明オンボーディングを実装する

## 2026-07-10: 初回導入＋登録手順チュートリアルラフ作成

### 変更概要
- FAVORECO初回導入の文言トーンを反映したラフを作成
- ようこそ、ジャンル選択、プロフィール、できること、開始の5画面に整理
- 「思い出を記録する」後に、Home上で中央＋、追加メニュー、入力ユニットを順に案内するチュートリアル案を追加

### 変更意図
Siriのように聞いてくれる導入演出と、初回ユーザーが実際に記録を始めるまでの流れを視覚化するため。

### 主な変更ファイル
- favoreco/assets/mockups/onboarding-guided-tour-rough.svg（編集用ラフ）
- favoreco/assets/mockups/onboarding-guided-tour-rough.png（確認用PNG）

### 確認結果（実機 / ビルド）
- PNGが2400x1500pxで生成されていることを確認
- 目視でオンボーディング5画面と登録手順チュートリアル5画面の流れを確認
- 実装は未変更

### 残課題
- ジャンル選択画面など文字量が多い箇所の文言を実装前に短く調整する
- 採用後、オンボーディング状態管理とHome初回チュートリアルを実装する

## 2026-07-10: 初回オンボーディング文言案整理

### 変更概要
- 初回オンボーディングとHome初回チュートリアルの文言を1ファイルに整理
- プロフィール入力画面に、ニックネームとアイコンはスキップ可能である旨を追加

### 変更意図
初回導入のシナリオを実装前に確定しやすくするため。Siri風に聞いてくれるニュアンスを残しつつ、FAVORECOらしいワクワク感と記録開始までの導線を整理した。

### 主な変更ファイル
- favoreco/assets/mockups/onboarding-text.md（オンボーディング文言案）

### 確認結果（実機 / ビルド）
- テキスト整理のみ。ビルド未実施

### 残課題
- 実装時に画面幅に合わせて文言量を再確認する
- プロフィール入力のスキップ時の表示名扱いを決める

## 2026-07-10: アイキャッチ比率と御朱印帳サイズ登録を実装

### 変更概要
- 映画、美術展/博物展/観劇、書籍、御朱印などのジャンル別にアイキャッチ推奨比率を定義
- 写真ユニットにカバー比率の選択を追加し、一覧/詳細/ギャラリー表示へ反映
- 御朱印ジャンルに「御朱印帳」ユニットを追加し、標準/大判/見開き・横向きのサイズ選択を保存

### 変更意図
ポスター、チラシ、書影、御朱印など、実物の縦横比が大きく異なるアイキャッチを正しく見せるため。御朱印は御朱印帳のサイズを先に決め、そのサイズに合わせて御朱印画像を登録できる導線にするため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Utilities/EyecatchAspectRatio.swift（比率候補と御朱印帳サイズ定義）
- favorecoAPP/favorecoAPP/Utilities/VisitUnitFields.swift（比率キー/御朱印帳サイズキーを保存）
- favorecoAPP/favorecoAPP/Utilities/RecordUnitDefinition.swift（御朱印帳ユニット追加）
- favorecoAPP/favorecoAPP/Services/CategoryPresetSeeder.swift（御朱印ジャンルの初期ユニットに御朱印帳を追加）
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（登録/編集/訪問追加フォームに比率選択と御朱印帳サイズ選択を追加）
- favorecoAPP/favorecoAPP/Views/HomeView.swift、VisitSummaryRow.swift、ExperienceDetailView.swift（保存済み比率でアイキャッチ表示）
- favoreco/CLAUDE.md（現在仕様として追記）

### 確認結果（実機 / ビルド）
- `xcodebuild -project /Users/doublefake/Documents/favoreco/favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /tmp/favoreco_aspect_continue_device_build_escalated CODE_SIGNING_ALLOWED=NO build` が成功
- サンドボックス内のシミュレータ向けビルドはCoreSimulatorServiceへ接続できず、asset catalog処理で失敗。権限付き実機SDKビルドではSwiftコンパイルとリンクまで成功

### 残課題
- 現時点では御朱印帳のサイズ情報は各記録/訪問に保存する。複数の御朱印を1冊の御朱印帳に紐付けるマスター管理は未実装
- 実機またはシミュレータで、各ジャンルの写真サムネイルが意図した比率で見えるか目視確認する

## 2026-07-11: デバッグ仮データを各ジャンル10件に拡充

### 変更概要
- 設定 > 開発の「写真付き仮データを追加」から、各ジャンル10件ずつ写真付き記録を生成するように変更
- 仮データ画像をジャンル別の推奨アイキャッチ比率に合わせてアプリ内生成
- 御朱印サンプルには御朱印帳サイズ、チケット系サンプルには申込/入金/発券系ステータスや座席を含めるようにした
- 設定 > 開発の「仮データを削除」から、デバッグ用プレフィックスを持つ仮データだけを削除し、通常データは対象外にした

### 変更意図
Home、一覧、詳細、写真比率、御朱印帳サイズ、チケット状態などの表示を、実データ投入前にまとまった件数で確認できるようにするため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Services/DebugDataSeeder.swift（各ジャンル10件生成、画像生成、削除条件、サンプル内容を拡充）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（投入/削除件数をデバッグメッセージに表示）

### 確認結果（実機 / ビルド）
- `xcodebuild -project /Users/doublefake/Documents/favoreco/favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /tmp/favoreco_debug_seed_build CODE_SIGNING_ALLOWED=NO build` が成功

### 残課題
- 実機またはシミュレータで「仮データを追加」後、各ジャンル10件ずつ表示されることと削除後に通常データが残ることを目視確認する

## 2026-07-11: デバッグ仮データ画像を生成画像に差し替え

### 変更概要
- 観劇、美術展、ライブ、映画、酒、おでかけ施設、御朱印、書籍の8ジャンルに各3枚、合計24枚の生成画像を追加
- デバッグ仮データ生成時は、内蔵した生成画像をジャンルごとにローテーションして使うように変更
- Bundle画像が読めない場合だけ、従来のアプリ内生成PNGへフォールバックするようにした

### 変更意図
単色ベースの仮画像ではHome、一覧、詳細、アイキャッチ比率の見え方を評価しにくいため。ジャンルらしい雰囲気の画像を入れ、実データに近い状態でUIの密度・色味・カード表示を確認できるようにするため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Resources/DebugSampleImages/*.png（ジャンル別デバッグ画像24枚）
- favorecoAPP/favorecoAPP/Services/DebugDataSeeder.swift（Bundle画像の読み込みとフォールバックを追加）

### 確認結果（実機 / ビルド）
- `xcodebuild -project /Users/doublefake/Documents/favoreco/favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /tmp/favoreco_debug_images_build CODE_SIGNING_ALLOWED=NO build` が成功
- ビルドログで `Resources/DebugSampleImages` 配下のPNGが `CopyPNGFile` 対象になることを確認
- 追加画像が24枚あることを確認

### 残課題
- 実機またはシミュレータで「写真付き仮データを追加」を実行し、Home/一覧/詳細で生成画像が表示されることを目視確認する

## 2026-07-11: 記録入力へApple Maps会場検索を接続

### 変更概要
- 設定 > 記録・入力補助の「Map検索」を、新規記録・記録編集・回追加の会場欄へ接続
- 会場名または住所でApple Maps候補を検索し、名称・住所を確認して選択できるシートを追加
- 選択した会場の名称・住所・座標をDraftで保持し、VisitとPlaceMasterへ保存
- 同名・同住所または同座標のPlaceMasterを再利用し、手入力で会場名を変更した場合は古い住所・座標を解除

### 変更意図
会場入力を毎回の手入力だけにせず、正確な住所と座標を補助候補から登録できるようにするため。場所マスターを記録と同時に育て、後続の地図表示・会場別集計・重複統合へつなげるため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Services/PlaceSearchService.swift（MapKit検索と移植可能な候補DTOへの変換）
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（3つの入力経路、候補UI、Draft、Visit/PlaceMaster保存を接続）
- favoreco/CLAUDE.md（現在仕様を追記）

### 確認結果（実機 / ビルド）
- `xcrun swiftc -frontend -parse` による変更Swiftファイルの構文確認が成功
- `xcodebuild -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /tmp/favoreco_map_search_build CODE_SIGNING_ALLOWED=NO build` が成功
- iOS 26で非推奨の旧MKPlacemark APIを使用せず、MKMapItemのlocation/address APIで警告なくコンパイルできることを確認

### 残課題
- 実機で会場名検索、住所検索、候補選択、保存後の編集再表示を確認する
- 設定でMap検索をOFFにした際、検索ボタンが消えて会場名を手入力できることを確認する
- PlaceMaster管理画面で、同名候補の統合UIを後続実装する

## 2026-07-11: 地図表示を登録住所優先へ変更

### 変更概要
- 記録入力の会場欄へ住所の手入力欄を追加
- Apple Maps候補検索の初期値を、住所登録済みなら住所、未登録なら施設名に変更
- 詳細画面に住所表示と「地図で見る」を追加
- 地図URLの解決順を登録住所、保存座標、施設名の順に固定
- iOSカレンダーへ追加する場所も、登録住所があれば住所を優先

### 変更意図
同名施設や検索精度の影響で施設名検索が誤った地点を示す場合でも、利用者が登録した住所を正本として正しい地図を開けるようにするため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Services/PlaceSearchService.swift（住所優先のApple Maps URL生成）
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（住所入力と住所優先検索）
- favorecoAPP/favorecoAPP/Views/ExperienceDetailView.swift（住所表示、地図導線、カレンダー住所優先）
- favoreco/CLAUDE.md（場所解決順を現在仕様として明記）

### 確認結果（実機 / ビルド）
- `xcrun swiftc -frontend -parse` による変更Swiftファイルの構文確認が成功
- `xcodebuild -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /tmp/favoreco_address_priority_build CODE_SIGNING_ALLOWED=NO build` が成功

### 残課題
- 実機で、施設名と異なる住所を登録した記録から「地図で見る」を押し、住所地点が開くことを確認する
- iOSカレンダー追加後の場所欄が登録住所になり、カレンダーから正しい地点を開けることを確認する

## 2026-07-11: 住所検索時も施設名を保持

### 変更概要
- 施設名と住所が入力済みの状態でMap候補を選んだ場合、施設名を維持して住所・座標だけを更新するよう変更
- 施設名を表示名、住所・座標を位置特定情報として分離する仕様を正本へ明記

### 変更意図
施設名では適切な地点が見つからず住所で検索した場合に、検索候補側の名称で利用者が登録した施設名が消えたり置き換わったりしないようにするため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（住所検索時の施設名保持）
- favoreco/CLAUDE.md（施設名と住所の責務を明記）

### 確認結果（実機 / ビルド）
- `xcrun swiftc -frontend -parse favorecoAPP/favorecoAPP/Views/AddExperienceView.swift` が成功
- `xcodebuild -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /tmp/favoreco_address_name_build CODE_SIGNING_ALLOWED=NO build` が成功

### 残課題
- 実機で任意の施設名と住所を入力し、住所候補選択後も施設名が変わらないことを確認する

## 2026-07-11: 入力補助辞書を人物・場所マスターへ接続

### 変更概要
- 記録の会場名入力中に、保存済みPlaceMasterから最大4件の候補を表示
- 名称・よみ・別名の部分一致に対応し、候補選択時に施設名・住所・座標をまとめて反映
- 既存の人物・団体候補と場所候補を、設定 > 記録・入力補助の「入力補助辞書」ON/OFFへ接続

### 変更意図
同じ劇場、ライブ会場、美術館、寺社、酒蔵などを毎回Map検索や手入力せず、利用者自身が育てた横断マスターから正確に再利用できるようにするため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（場所候補UI、Draft反映、人物候補の設定接続）
- favoreco/CLAUDE.md（ローカル入力補助辞書の現在仕様を追記）

### 確認結果（実機 / ビルド）
- `xcrun swiftc -frontend -parse favorecoAPP/favorecoAPP/Views/AddExperienceView.swift` が成功
- `xcodebuild -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /tmp/favoreco_input_dictionary_build CODE_SIGNING_ALLOWED=NO build` が成功

### 残課題
- 実機で同じ会場を2件目の記録へ再利用し、住所・座標が引き継がれることを確認する
- 入力補助辞書OFF時に人物・場所候補が出ず、手入力とMap検索は利用できることを確認する

## 2026-07-11: URLからページタイトル候補を取得

### 変更概要
- 公式情報ユニットのURLからLinkPresentationでページタイトル候補を取得
- 取得したタイトルを確認後、「タイトルに反映」「シリーズ名に反映」から選択可能にした
- 設定 > 記録・入力補助の「URL取込候補」ON/OFFへ接続
- URLのスキーム省略時は候補取得時だけhttpsとして解釈し、http/https以外はエラー表示

### 変更意図
公式ページから最低限のタイトル候補を安全に再利用しつつ、ジャンルごとに意味が異なる項目へ勝手に自動入力しないため。既存入力を保護し、候補を利用するか利用者が決められる導線にするため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Services/URLMetadataService.swift（URL正規化とLinkPresentationメタデータ取得）
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（URL候補取得・確認・反映先選択UI）
- favoreco/CLAUDE.md（基本URL補助と高度取込の境界を追記）

### 確認結果（実機 / ビルド）
- `xcrun swiftc -frontend -parse favorecoAPP/favorecoAPP/Services/URLMetadataService.swift favorecoAPP/favorecoAPP/Views/AddExperienceView.swift` が成功
- `xcodebuild -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /tmp/favoreco_url_metadata_build CODE_SIGNING_ALLOWED=NO build` が成功

### 残課題
- 実機ネットワークで公式サイト、SNS投稿、タイトル未設定ページ、無効URLの表示を確認する
- 日時・人物・会場・画像候補の抽出と項目別レビューは高度URL取込として後続検討する

## 2026-07-11: 記録保存後に詳細を開く設定を接続

### 変更概要
- 新規記録と回追加の保存成功後、保存したVisitの詳細画面へ遷移
- 保存後詳細では戻る操作を隠し、「完了」で追加シート全体を閉じる導線を追加
- 設定 > 記録・入力補助の「記録追加後」に「一覧に戻る」を追加
- 編集保存は設定対象外とし、従来どおり編集シートを閉じる動作を維持

### 変更意図
favorecoの初期値として決めた「保存後は編集画面ではなく情報を詳しく見る画面へ戻る」を実動作にし、保存内容をすぐ確認できるようにするため。入力フォームへ戻って二重保存する誤操作も避けるため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（保存成功後の詳細遷移と完了導線）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（一覧に戻る選択肢）
- favoreco/CLAUDE.md（接続済み入力設定と保存後動作を更新）

### 確認結果（実機 / ビルド）
- `xcrun swiftc -frontend -parse favorecoAPP/favorecoAPP/Views/AddExperienceView.swift favorecoAPP/favorecoAPP/Views/SettingsView.swift` が成功
- `xcodebuild -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /tmp/favoreco_after_save_build CODE_SIGNING_ALLOWED=NO build` が成功

### 残課題
- 実機で「詳細を開く」「一覧に戻る」の両設定を、新規記録と回追加から確認する
- 保存後詳細から編集、カレンダー追加、削除を行った際のシート挙動を実機確認する

## 2026-07-11: デフォルトジャンル設定を中央＋へ接続

### 変更概要
- 記録保存成功時に「最後に使ったジャンル」を保存
- Homeから開いたジャンル画面とジャンル切替先を「Homeで選択中のジャンル」として保存
- 中央＋のジャンル候補で、設定に応じた既定ジャンルを先頭に「デフォルト」と明示
- 保存済みジャンルが非表示/不在の場合は、先頭の有効ジャンルへフォールバック

### 変更意図
中央＋から記録するたびにジャンル一覧を探し直さず、利用状況または現在見ているジャンルへ1タップで記録を追加できるようにするため。Inboxや予定・チケットの入口は残し、中央＋から自動遷移しない構成を維持するため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Utilities/AppStorageKeys.swift（最終使用/選択中ジャンルキー）
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（保存成功時の最終使用ジャンル更新）
- favorecoAPP/favorecoAPP/Views/CategoryTopView.swift（表示中ジャンル更新）
- favorecoAPP/favorecoAPP/Views/MainTabView.swift（既定ジャンルの解決・並び替え・フォールバック）
- favoreco/CLAUDE.md（デフォルトジャンルの現在仕様を更新）

### 確認結果（実機 / ビルド）
- `xcrun swiftc -frontend -parse` による変更Swiftファイル4件の構文確認が成功
- `xcodebuild -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /tmp/favoreco_default_genre_build CODE_SIGNING_ALLOWED=NO build` が成功

### 残課題
- 実機で両設定を切り替え、中央＋の先頭ジャンルが切り替わることを確認する
- 既定ジャンルを非表示にした後、別の有効ジャンルへ安全にフォールバックすることを確認する

## 2026-07-12: 写真追加の初期動作をカメラ/ライブラリへ接続

### 変更概要
- 設定 > 記録・入力補助の「写真追加」に応じ、カメラまたは写真ライブラリを主要ボタンとして表示
- 主要設定と異なる追加元も補助ボタンから常に選択可能
- UIImagePickerControllerをSwiftUIへ閉じ込めるカメラ撮影ラッパーを追加
- 撮影画像を既存の圧縮、メタデータ除去、10枚上限、カバー設定へ接続
- カメラ非搭載環境ではクラッシュせず、写真ライブラリ利用を案内
- Debug/Release両構成へカメラ利用目的文言を追加

### 変更意図
設定で決めた初期動作を写真ユニットへ反映しつつ、撮影と既存写真選択を状況に応じて切り替えられるようにするため。追加元によって保存品質やプライバシー処理が変わらないよう共通経路へ通すため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Services/CameraImagePicker.swift（カメラ撮影のUIKit境界）
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（追加元ボタン、撮影画像の共通保存処理）
- favorecoAPP/favorecoAPP.xcodeproj/project.pbxproj（カメラ利用目的）
- favoreco/CLAUDE.md（写真追加設定の現在仕様を更新）

### 確認結果（実機 / ビルド）
- `xcrun swiftc -frontend -parse favorecoAPP/favorecoAPP/Services/CameraImagePicker.swift favorecoAPP/favorecoAPP/Views/AddExperienceView.swift` が成功
- `xcodebuild -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /tmp/favoreco_photo_source_build CODE_SIGNING_ALLOWED=NO build` が成功
- 生成されたInfo.plistに `NSCameraUsageDescription` が含まれることを確認

### 残課題
- 実機で初回カメラ権限、撮影、キャンセル、ライブラリ複数選択を確認する
- カメラ/ライブラリ両方から追加した写真が設定品質とカバー比率で表示されることを確認する

## 2026-07-12: WeatherKit履歴天気の自動付与を接続

### 変更概要
- 観劇、美術展、ライブ、おでかけ施設の過去記録へWeatherKitの日別履歴天気を自動取得
- 天気SF Symbols名、最高/最低気温、取得日時、Apple Weather法的情報URLをVisit補助フィールドへキャッシュ
- 保存時と詳細表示時に未取得データを補完し、一覧の日付アイコンと詳細の天気欄へ反映
- 日付/座標を変更した編集では古い天気を破棄し、変更がない編集では保持
- アプリターゲットへWeatherKit entitlementを追加

### 変更意図
出かけた日の記憶を、利用者の手入力を増やさず天気と一緒に残すため。WeatherKitや通信の失敗は補助情報の欠落に留め、記録そのものの保存を止めないため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Services/VisitWeatherService.swift（対象判定、WeatherKit境界、自動補完）
- favorecoAPP/favorecoAPP/Utilities/VisitUnitFields.swift（天気キャッシュと旧JSON互換）
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（保存/編集/回追加からの補完）
- favorecoAPP/favorecoAPP/Views/ExperienceDetailView.swift（天気、気温、帰属リンク表示）
- favorecoAPP/favorecoAPP/Views/VisitSummaryRow.swift（日付横の天気アイコン）
- favorecoAPP/favorecoAPP/favorecoAPP.entitlements / project.pbxproj（WeatherKit capability）
- favoreco/CLAUDE.md（現在仕様）

### 確認結果（実機 / ビルド）
- 変更Swiftファイルの構文解析が成功
- xcodebuildによるiPhoneOS向け署名なしビルドが成功

### 残課題
- Apple DeveloperのApp IDでWeatherKit capabilityを有効化し、実機で2021年8月以降の対象/対象外ジャンル、設定OFF、座標なし、日付/場所変更を確認する
- Apple Weather帰属表示の最終デザインは配布前にWeatherKit利用要件と照合する

## 2026-07-12: アプリ内文字サイズ設定を接続

### 変更概要
- 表示設定の文字サイズを専用画面へ接続
- 初期値はiOSの文字サイズ・アクセシビリティ設定に追従
- 追従をOFFにした場合は小さめ/標準/大きめ/特大の4段階を選択可能
- Noto Sans JP、Noto Serif JP、Cormorantを確認できるプレビューを追加
- ContentViewのDynamic Type環境からアプリ全体へ反映

### 変更意図
独自フォントの世界観を保ちながら、端末のアクセシビリティ設定と利用者が選ぶ読みやすさの両方へ対応するため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Utilities/AppStorageKeys.swift（文字サイズ設定キー）
- favorecoAPP/favorecoAPP/Utilities/FavorecoTypography.swift（サイズ定義と全体適用Modifier）
- favorecoAPP/favorecoAPP/ContentView.swift（アプリルートへの適用）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（設定UIとプレビュー）
- favoreco/CLAUDE.md（現在仕様）

### 確認結果（実機 / ビルド）
- 変更Swiftファイルの構文解析が成功
- 既存DerivedDataを使ったiPhoneOS向け署名なしビルドが成功

### 残課題
- 実機で端末文字サイズ追従と4段階を切り替え、Home、設定、記録入力、詳細の折返しとボタン高さを確認する
- 外観モードは引き続き端末設定追従のみ。ライト/ダーク固定は別作業で検討する

## 2026-07-12: 外観モードをライト/ダークへ接続

### 変更概要
- 表示設定の外観モードを、端末設定に従う/ライト/ダークの選択UIへ変更
- 選択したColorSchemeをContentViewからアプリ全体へ即時反映
- 選択値をAppStorageへ保存し、再起動後も維持

### 変更意図
端末設定追従を標準に保ちつつ、写真やジャンル画面を明るい表示または暗い表示へ固定したい利用者へ選択肢を提供するため。ジャンルテーマ色とは役割を分け、外観モードは明暗だけを担う。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Utilities/AppStorageKeys.swift（外観モード設定キー）
- favorecoAPP/favorecoAPP/Utilities/FavorecoTypography.swift（外観モード定義）
- favorecoAPP/favorecoAPP/ContentView.swift（ColorScheme全体適用）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（外観モードPicker）
- favoreco/CLAUDE.md（現在仕様）

### 確認結果（実機 / ビルド）
- 変更Swiftファイルの構文解析が成功
- iPhoneOS向け署名なしビルドが成功

### 残課題
- 実機で端末追従、ライト、ダークを切り替え、Home、写真、フォーム、モーダル、ジャンル色のコントラストを確認する
- 全体テーマ/ジャンル別高度テーマと課金境界は別機能として後続検討する

## 2026-07-12: プロフィール表示名と写真を接続

### 変更概要
- プロフィール画面で任意の表示名を編集・保存可能に変更
- 写真ライブラリからプロフィール写真を選択、変更、削除できるUIを追加
- 選択写真を320px正方形へ中央トリミングし、JPEG再描画でメタデータを除去
- Home右上のマイ・設定入口へプロフィール写真を反映
- 写真未設定または読込不能時は標準人物アイコンへフォールバック

### 変更意図
プロフィールを写真とSNS中心の軽い構成に保ちながら、右上の共通マイ入口を利用者自身の目印として使えるようにするため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Utilities/AppStorageKeys.swift（表示名/写真設定キー）
- favorecoAPP/favorecoAPP/Views/ProfileSettingsView.swift（編集UI、画像再描画、共通Avatar）
- favorecoAPP/favorecoAPP/Views/HomeView.swift（右上プロフィール写真）
- favoreco/CLAUDE.md（現在仕様）

### 確認結果（実機 / ビルド）
- 変更Swiftファイルの構文解析が成功
- sandbox外のXcode通常権限でiPhoneOS向け署名なしクリーンビルドが成功

### 残課題
- 実機で写真選択、変更、削除、縦長/横長画像の中央トリミング、再起動後の保持を確認する
- 現在の表示名/写真は端末内AppStorage。iCloud同期/JSONバックアップ対象へ含める時にプロフィールDTOへ移行する

## 2026-07-12: SwiftData CloudKit同期基盤を接続

### 変更概要
- 同期OFF時は従来の完全ローカル、ON時はSwiftDataのCloudKit automatic構成で起動するブートストラップを追加
- CloudKit構成の初期化に失敗した場合、同じローカルストアへ安全にフォールバック
- 設定画面へ同期ON/OFF、現在の保存先、Apple Account、iCloud Drive、写真同期、起動エラー表示を追加
- iCloud container、CloudKit service、ubiquity key-value storeのentitlementを追加
- 同期設定変更は次回起動から反映し、初回同期はWi-Fiを推奨する説明を追加

### 変更意図
保存を常に端末内で先に確定しながら、同じApple Accountの端末間で記録とexternalStorage写真を同期できる完全版の基盤を作るため。iCloud未サインイン、容量不足、設定不備があってもローカル記録を失わない構造を守るため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Services/CloudSyncService.swift（コンテナ構築、ローカルフォールバック、iCloud診断）
- favorecoAPP/favorecoAPP/Utilities/AppStorageKeys.swift（同期設定/起動状態/エラーキー）
- favorecoAPP/favorecoAPP/favorecoAPPApp.swift（共通ブートストラップ）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（同期設定と診断UI）
- favorecoAPP/favorecoAPP/favorecoAPP.entitlements（CloudKit/iCloud capability）
- favoreco/CLAUDE.md（現在仕様）

### 確認結果（実機 / ビルド）
- entitlementsのplist検証が成功
- iPhoneOS向け署名なしクリーンビルドが成功
- 同期OFFの既定構成が従来どおりローカルModelConfigurationを生成することをコード確認

### 残課題
- Apple DeveloperでApp IDとiCloud.com.nori.favorecoのCloudKit capabilityを有効化し、署名付き実機ビルドを行う
- 2台の実機で既存ローカル記録の初回アップロード、追加/編集/削除、写真、オフライン復帰、同期OFF後のローカル保持を確認する
- SwiftData automaticは強制同期APIや正確な最終同期時刻を提供しないため、設定画面は環境/接続状態を診断し、同期タイミングはOS管理とする

## 2026-07-12: 写真付き完全バックアップと復元を接続

### 変更概要
- JSON manifestと写真本体を含む`.favorecobackup`パッケージの作成/Files書き出しを追加
- パッケージ復元前にモデル件数、写真件数、写真容量を検査して表示
- 既存JSONのUUIDマージ復元後、PhotoBlobをUUIDで追加/更新しVisitへ再紐付け
- 写真を1枚ずつ一時パッケージへ書き、全写真を単一Dataへまとめない構成を採用
- データ管理と同期・バックアップの両方から完全バックアップ画面へ遷移
- 一時パッケージを再作成時/画面終了時に削除

### 変更意図
同期OFF利用者にも写真を含む端末外の安全網を無料で提供し、機種変更やアプリ再導入時に記録と写真をまとめて戻せるようにするため。復元は既存データを消さず、失敗時に壊れにくいUUIDマージ方式を維持するため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Services/FullBackupService.swift（パッケージ作成、検査、写真復元）
- favorecoAPP/favorecoAPP/Views/FullBackupView.swift（書き出し/復元UI、Files連携）
- favorecoAPP/favorecoAPP/Services/JSONBackupExportService.swift（完全バックアップmanifest対応）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（完全バックアップ入口）
- favoreco/CLAUDE.md（現在仕様）

### 確認結果（実機 / ビルド）
- git diffの空白/構文チェックが成功
- iPhoneOS向け署名なしクリーンビルドが成功

### 残課題
- 実機で写真0枚/1枚/多数、同一端末への再取込、別端末への復元、Files/iCloud Drive/ローカル保存先を確認する
- 1GB級バックアップの時間、空き容量不足、中断時の一時ファイル掃除を実測する
- プロフィール表示名/写真や表示設定などAppStorage設定は今回のSwiftData完全バックアップ対象外。設定DTOは自動バックアップ工程で追加する

## 2026-07-12: 同期OFF時の起動失敗を修正

### 変更概要
- 同期OFFおよびCloudKit初期化失敗時の`ModelConfiguration`へ`cloudKitDatabase: .none`を明示
- iCloud entitlement追加後も、従来のローカルSwiftDataストアをCloudKit検証なしで開くよう修正

### 変更意図
iCloud capabilityがある環境では省略したCloudKit設定がautomaticとして解釈され得るため、同期OFFのローカル構成を明示し、CloudKitスキーマ検証エラーによる起動時クラッシュを防ぐため。既存データの削除やストア移行は行わない。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Services/CloudSyncService.swift（ローカル構成をCloudKit非使用へ固定）

### 確認結果（実機 / ビルド）
- iPhoneOS向け署名なしクリーンビルドを実施

### 残課題
- 実機またはシミュレータで既存ローカルデータを保持したまま起動できることを確認する
- 同期ON側のCloudKitスキーマ互換性を別途検証する

## 2026-07-12: SwiftDataリレーションをCloudKit互換化

### 変更概要
- PersonMasterとEventPersonLinkのinverseを追加
- ExperienceEvent/VisitとEventPersonLinkのinverseを追加
- PlaceMasterとPlan/Visitのinverseを追加
- VisitとPlanのinverseを追加
- 追加した全to-manyリレーションをoptional配列として定義

### 変更意図
CloudKitが要求する「全リレーションにinverseがあること」を満たし、同期ON時のSwiftDataコンテナを実際に生成できるようにするため。既存の参照先、削除ルール、画面からの保存方法は変えず、欠けていた逆参照だけを補った。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Models/CoreModels.swift（CloudKit互換inverse）
- favoreco/CLAUDE.md（現在仕様）

### 確認結果（実機 / ビルド）
- iOS Simulator向け署名なしクリーンビルドが成功
- iOS 26.5シミュレータへインストールし、同期ONで起動継続することを確認
- `iCloudSyncActiveAtLaunch = true`、`iCloudSyncStartupError = ""`をアプリコンテナ内UserDefaultsで確認
- 既存シミュレータデータを削除せず起動し、SwiftData/CloudKitのrelationship/inverseエラーがないことをログ確認

### 残課題
- Apple Accountへサインインした2台の実機で追加/編集/削除/写真の相互反映を確認する
- 仮データ画像の一部でPNG CRCエラーが出るため、仮画像生成を次工程で修正する

## 2026-07-12: 写真付き仮データの画像読込を修正

### 変更概要
- Xcodeがアプリバンドル直下へコピーするDebugSampleImagesを正しいパスから取得
- 旧配置との互換用に従来のサブディレクトリ検索もフォールバックとして維持
- バンドルPNGを読み込んだ後、scale 1のJPEGへ再描画してPhotoBlobへ保存
- 代替生成画像も同じJPEG形式へ統一し、仮データのパスとファイル名を`.jpg`へ変更

### 変更意図
各標準ジャンルの実写真素材が存在していたにもかかわらず、誤ったバンドルパスにより常に代替画像が使われていた問題を直すため。また、古い仮PNGのCRCエラーを再発させず、仮データを入れ直すだけで正常な写真へ置き換えられるようにするため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Services/DebugDataSeeder.swift（画像探索、JPEG再描画、保存拡張子）

### 確認結果（実機 / ビルド）
- theater/museum/live/movie/sake/outing_facility/goshuin/bookの8ジャンルに画像3種ずつ存在することを確認
- 24個のバンドルPNGすべてをsipsで画像検査し、幅/高さを取得できることを確認
- iOS Simulator向け署名なしクリーンビルドが成功

### 残課題
- 設定 > 開発で「写真付き仮データを追加」を押し直し、8ジャンルのHome/一覧/詳細で写真表示を実機確認する

## 2026-07-12: 写真付き自動バックアップの世代管理を追加

### 変更概要
- アプリ起動時に24時間間隔で写真付き完全バックアップを作成
- Application Support内へ最大5世代を保存し、古い世代を自動削除
- 設定から今すぐ作成、世代一覧、容量表示、UUIDマージ復元、個別削除を追加
- 製品版の課金接続前はDEBUGビルドでのみ自動バックアップのON/OFFを許可
- 完全バックアップmanifestの写真Base64同梱を止め、`media/`との二重保存を解消
- JSONエクスポート画面の古い「写真付きは後続」説明を現状へ更新

### 変更意図
CloudKit同期とは別系統の復元点を持ち、誤編集や削除から過去5世代へ戻せる基盤を作るため。写真本体の二重格納を解消し、大量写真でもバックアップ容量が不要に倍増しないようにした。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Services/AutomaticBackupService.swift（24時間判定、作成、5世代管理）
- favorecoAPP/favorecoAPP/Views/AutomaticBackupView.swift（世代一覧、作成、復元、削除）
- favorecoAPP/favorecoAPP/Services/JSONBackupExportService.swift（完全バックアップmanifest種別）
- favorecoAPP/favorecoAPP/Views/FullBackupView.swift（写真本体の二重保存解消）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（自動バックアップ導線と説明更新）
- favorecoAPP/favorecoAPP/favorecoAPPApp.swift（起動時作成）
- favorecoAPP/favorecoAPP/Utilities/AppStorageKeys.swift（有効状態、最終作成日時）
- favoreco/CLAUDE.md（現在仕様）

### 確認結果（実機 / ビルド）
- iOS Simulator向け署名なしクリーンビルドが成功
- 新規コードのactor境界警告を解消
- 復元が既存データを一括削除せず、既存のUUIDマージ処理を再利用することをコード確認

### 残課題
- 実機で手動作成、24時間スキップ、6世代目作成時の最古削除、復元、個別削除を確認する
- Premium権利判定をStoreKitへ接続後、製品版の自動バックアップトグルを解放する
- iCloud Driveへ世代パッケージを複製する自動バックアップ先は次工程で接続する

## 2026-07-12: 自動バックアップをiCloud Driveへ複製

### 変更概要
- 自動バックアップに「iCloud Driveにも保存」を追加
- 端末内バックアップ成功後、同じパッケージを`Documents/Favoreco/AutomaticBackups`へ複製
- 端末内/iCloud Driveそれぞれ最大5世代を保持
- 管理画面を保存先別の世代一覧へ分け、どちらからも復元/削除可能にした
- iCloud Driveの最終成功日時と直近エラーを表示
- CloudDocumentsとubiquity container entitlementを追加

### 変更意図
端末紛失やアプリ削除でも写真付き復元点を残せるようにしながら、iCloud未サインイン、容量不足、一時障害でローカルバックアップまで失敗扱いにしないため。CloudKitの端末間同期と、iCloud Drive上の世代バックアップを別の安全網として扱う。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Services/AutomaticBackupService.swift（保存先種別、iCloud複製、保存先別5世代管理）
- favorecoAPP/favorecoAPP/Views/AutomaticBackupView.swift（端末/iCloud別一覧、復元、削除、エラー表示）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（iCloud Drive保存設定）
- favorecoAPP/favorecoAPP/Utilities/AppStorageKeys.swift（iCloud保存設定、最終成功、エラー）
- favorecoAPP/favorecoAPP/favorecoAPP.entitlements（CloudDocuments/ubiquity container）
- favoreco/CLAUDE.md（現在仕様）

### 確認結果（実機 / ビルド）
- entitlementsのplist検証が成功
- iPhoneOS向け署名なしクリーンビルドが成功
- iCloud複製失敗を捕捉し、ローカル作成結果を維持することをコード確認

### 残課題
- Apple AccountとiCloud Driveが有効な実機で作成、Files表示、別端末からの一覧/復元、削除反映を確認する
- Apple DeveloperのApp IDでiCloud Documentsと`iCloud.com.nori.favoreco` containerが有効な署名になっていることを確認する
- Premium権利判定をStoreKitへ接続後、製品版トグルを解放する

## 2026-07-12: StoreKit 2で4プランの権利判定を接続

### 変更概要
- 無料/ライト買い切り/同期サブスク/フル買い切りの4利用状態を実装
- ライト、同期月額、同期年額、同期永久追加、直接フルの5商品IDを定義
- StoreKitの商品取得、購入、保留、キャンセル、verified transaction検証、購入復元を追加
- currentEntitlementsとTransaction.updatesから現在プランを継続更新
- ライト+同期永久追加と直接フルを同じフル権利として扱う頭金方式を実装
- 課金画面へApp Store価格、購入ボタン、復元、現在プラン、処理状況を接続
- 製品版では同期権利がない時にCloudKit同期/自動バックアップをUIと起動処理の両方で停止
- DEBUGビルドは同期/バックアップの開発検証を継続できるよう解放

### 変更意図
価格表示だけだった設定を実際のApp Store権利へ接続し、サブスク失効や返金後に有料同期が動き続けないようにするため。画面だけでなく起動時のModelContainerと自動バックアップでもキャッシュ済み権利を確認する。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Services/PurchaseManager.swift（商品ID、購入、復元、権利判定、更新監視）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（購入UI、現在プラン、有料機能ゲート）
- favorecoAPP/favorecoAPP/Services/CloudSyncService.swift（起動時同期権利ガード）
- favorecoAPP/favorecoAPP/Services/AutomaticBackupService.swift（起動時バックアップ権利ガード）
- favorecoAPP/favorecoAPP/Utilities/AppStorageKeys.swift（プランキャッシュ）
- favorecoAPP/favorecoAPP/favorecoAPPApp.swift（PurchaseManager注入）
- favoreco/CLAUDE.md（現在仕様と商品ID）

### 確認結果（実機 / ビルド）
- iPhoneOS向け署名なしビルドが成功
- StoreKit verified transaction以外を権利へ採用しないことをコード確認
- 商品未取得時に無料プランを維持し、画面へ設定待ちを表示することをコード確認

### 残課題
- App Store Connectへ5商品を登録し、月額/年額を同じサブスクリプショングループへ設定する
- StoreKit ConfigurationまたはSandboxで購入、キャンセル、保留、更新、失効、返金、復元、ライトからフル追加を確認する
- 創設メンバー特典の対象判定と締切日を確定し、権利付与方式を実装する
- ライト/同期/フルによる詳細統計、OCR高度化、テーマ等の個別機能ゲートを順次接続する

## 2026-07-12: ローカルStoreKitテスト環境を追加

### 変更概要
- Xcode用`Favoreco.storekit`へ買い切り3商品と自動更新サブスク2商品を定義
- 月額¥250/年額¥1,500を同じサブスクリプショングループへ配置
- ライト¥1,500、同期永久追加¥4,500、フル¥6,000を非消耗型として定義
- 共有schemeのRun OptionsへStoreKit Configurationを接続
- 自動バックアップをメイン画面と別の短命ModelContextで作成し、写真Dataを処理後に解放しやすくした
- 写真書き出し時に`photo.data`へ二度アクセスしていた処理を1回へ修正

### 変更意図
App Store Connect登録前でも購入、更新、失効、返金、復元、Ask to BuyなどをXcodeだけで検証できるようにするため。また、起動時自動バックアップが写真Dataを画面用ModelContextへ残し続け、メモリ圧迫につながる可能性を下げるため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Configuration/Favoreco.storekit（ローカル商品/価格/サブスクグループ）
- favorecoAPP/favorecoAPP.xcodeproj/xcshareddata/xcschemes/favorecoAPP.xcscheme（Run時StoreKit設定）
- favorecoAPP/favorecoAPP/Services/AutomaticBackupService.swift（短命ModelContext）
- favorecoAPP/favorecoAPP/Services/FullBackupService.swift（写真Dataの単一読込）
- favoreco/CLAUDE.md（現在仕様）

### 確認結果（実機 / ビルド）
- Xcode StoreKit Configuration Editorで5商品を正常認識
- 月額/年額が同じAuto-Renewable Subscriptionグループに表示されることを確認
- Scheme > Run > Optionsで`Favoreco.storekit`が選択済みであることを確認
- StoreKit JSONの構文とPurchaseManagerの商品ID完全一致を確認
- iPhoneOS向け署名なしクリーンビルドが成功

### 残課題
- Xcodeの購入シートで5商品の購入、月額/年額切替、失効、返金、復元、ライト+同期永久追加を実操作確認する
- 大量写真で自動バックアップ前後のメモリ使用量をInstrumentsで実測する

## 2026-07-12: 統計と思い出レポートをStoreKit権利へ接続

### 変更概要
- 基本4指標と目隠し付き金額表示を無料機能として維持
- ジャンル別詳細統計と手動の月刊/年間Favorecoをライト以上へ接続
- 同期込み自動レポート候補を同期プラン以上として表示
- 未購入時は数値をぼかさず、機能内容と必要プランを明示
- ローカルStoreKit購入状態が画面へ即時反映されるようにした

### 変更意図
無料ユーザーへ実在しない数値を見せず、買い切りのローカル価値と同期プランの継続価値を区別して伝えるため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/MainTabView.swift（統計・レポートの権利ゲート）
- favoreco/CLAUDE.md（統計の無料/有料境界）

### 確認結果（実機 / ビルド）
- iPhoneOS向け署名なしクリーンビルドが成功
- 無料時は基本統計を残し、有料対象だけ説明カードへ置き換わることをコード確認
- 狭い画面でも必要プラン表示がタイトルを圧迫しない縦配置へ調整

### 残課題
- StoreKit Configurationで無料、ライト、同期、フル各状態の表示切替を実機またはシミュレータ確認する
- 同期プラン向け自動レポート生成・通知は準備中

## 2026-07-12: 高度OCRの項目候補をライト以上へ接続

### 変更概要
- Visionによる画像文字読み取りとテキスト保存は無料の基本OCRとして維持
- OCR文字列から日付、円表記の金額、ラベル付きタイトル、ラベル付き会場を候補化
- 記録追加、記録編集、既存イベントへの回追加で候補を各入力欄へ反映可能にした
- 候補は自動適用せず、ユーザーが押した項目だけ反映
- 高度OCR候補をライト買い切り・同期プラン・フル買い切りへ接続
- 設定画面へ現在プランに応じた利用可否を表示

### 変更意図
OCR誤認識で既存入力を勝手に上書きせず、入力負荷を下げる有料機能として安全に提供するため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（候補解析、候補UI、選択反映）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（権利状態表示）
- favoreco/CLAUDE.md（基本OCRと高度OCRの現在仕様）

### 確認結果（実機 / ビルド）
- iPhoneOS向け署名なしビルドが成功
- 基本OCRの画像選択・文字保存経路を無料状態でも維持していることをコード確認
- 高度候補はライト以上でだけ解析・表示し、タップ前に入力値を変更しないことをコード確認
- 会場候補反映時は古い住所・座標を解除し、異なる施設との誤紐付きを防ぐことをコード確認
- 既存イベントへの回追加では反映先のないタイトル候補を表示しないことをコード確認

### 残課題
- 実際の半券、チケット、レシート画像でVision認識と候補精度を確認する
- 時刻、座席、人物・団体、複数金額の用途判定は後続候補

## 2026-07-12: テーマ設定の第1段階を実装

### 変更概要
- 表示設定へ無料の標準ジャンル色と、ライト以上の全体統一テーマを追加
- 全体統一用に8色のアクセントプリセットを追加
- 選択色をアプリルートのボタン、リンク、選択状態などのtintへ反映
- 無料状態では有料設定値が保存済みでも標準アクセントへフォールバック
- StoreKit購入状態の変更を表示設定とルート配色へ即時反映

### 変更意図
標準のジャンル色を無料で守りながら、買い切り機能として全体配色を段階的に実装するため。購入失効後も有料配色が残り続けないよう、表示時の権利判定を正本にする。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Utilities/AppStorageKeys.swift（テーマ保存キー）
- favorecoAPP/favorecoAPP/Utilities/Color+Hex.swift（テーマモードと色プリセット）
- favorecoAPP/favorecoAPP/ContentView.swift（権利判定とルートtint）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（テーマ設定UI）
- favoreco/CLAUDE.md（現在仕様）

### 確認結果（実機 / ビルド）
- iPhoneOS向け署名なしビルドが成功
- 無料状態では保存済みテーマ値にかかわらず標準tintを返すことをコード確認
- ライト以上ではテーマモードと8色の変更がルートへ即時反映されることをコード確認

### 残課題
- 各画面のジャンル色直接指定を共通ThemeResolverへ段階的に集約する
- 背景、カード、フォントまで切り替える高度テーマとジャンル別テーマは後続

## 2026-07-12: 共通ThemeResolverを主要画面へ適用

### 変更概要
- `FavorecoThemePalette`をEnvironmentでアプリ全体へ配布
- 標準モードでは保存済みジャンル色、全体統一モードでは購入済み統一色を返す共通Resolverを追加
- Homeの予定、記録ギャラリー、ジャンルカードへ適用
- ジャンルトップのHero、追加ボタン、空状態へ適用
- 記録詳細のアクセントへ適用
- SNSアカウント色、警告色、統計の意味色は意図的に統一対象外とした

### 変更意図
各画面が課金状態やテーマ設定を個別に読む構造を避け、全体統一テーマを一貫して即時反映できるようにするため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Utilities/Color+Hex.swift（ThemePaletteとEnvironmentKey）
- favorecoAPP/favorecoAPP/ContentView.swift（Palette配布）
- favorecoAPP/favorecoAPP/Views/HomeView.swift（主要Home要素）
- favorecoAPP/favorecoAPP/Views/CategoryTopView.swift（ジャンルトップ）
- favorecoAPP/favorecoAPP/Views/ExperienceDetailView.swift（記録詳細）
- favoreco/CLAUDE.md（現在仕様）

### 確認結果（実機 / ビルド）
- iPhoneOS向け署名なしビルドが成功
- 標準モードでは従来のジャンル色、全体統一モードでは選択色を返すことをコード確認
- Environment経由のため購入状態・テーマ変更時に主要画面が再評価されることをコード確認

### 残課題
- EventDetail、PlanDetail、TicketOverview、VisitSummaryRowなど残る画面へ適用する
- 全体統一テーマの実機見た目をライト/ダーク双方で確認する

## 2026-07-12: ThemeResolverを予定・チケット・一覧・統計へ適用

### 変更概要
- 対象詳細と予定詳細のジャンルアクセントへ適用
- チケット一覧行とカレンダー予定行へ適用
- 共通の記録一覧行へ適用
- 統計のジャンル行へ適用
- 月刊/年間Favorecoの共有画像へResolver済みHexを渡すよう変更

### 変更意図
全体統一テーマを主要導線と共有成果物まで一貫させ、画面ごとに元のジャンル色が混ざる状態をなくすため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Utilities/Color+Hex.swift（Resolver済みHex取得）
- favorecoAPP/favorecoAPP/Views/EventDetailView.swift（対象詳細）
- favorecoAPP/favorecoAPP/Views/PlanDetailView.swift（予定詳細）
- favorecoAPP/favorecoAPP/Views/TicketOverviewView.swift（チケット一覧）
- favorecoAPP/favorecoAPP/Views/VisitSummaryRow.swift（記録一覧行）
- favorecoAPP/favorecoAPP/Views/MainTabView.swift（カレンダー・統計・共有画像）
- favoreco/CLAUDE.md（現在仕様）

### 確認結果（実機 / ビルド）
- iPhoneOS向け署名なしビルドが成功
- 画面表示と共有画像の両方へResolver済みジャンル色が渡ることをコード確認
- SNS色、状態色、警告色を誤って統一色へ置換していないことを差分確認

### 残課題
- 全体統一テーマをライト/ダーク双方で実機確認する
- 背景、カード、フォントまで切り替える高度テーマは後続

## 2026-07-12: 写真枚数の無料/ライト境界を保存処理へ接続

### 変更概要
- 無料プランは1記録10枚、ライト以上は30枚へ変更
- 写真ライブラリの最大選択数を残り枠へ連動
- カメラ撮影とライブラリ取込の両方で上限を再検証
- プラン失効後に10枚を超える既存写真は保持し、新規追加だけ停止
- 課金・プラン画面へライト以上の30枚上限を明記

### 変更意図
画面上の説明だけでなく実際の取込処理へ無料境界を接続し、購入失効時にもユーザーデータを削除しないため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（写真上限、選択数、失効時表示）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（プラン説明）
- favoreco/CLAUDE.md（写真上限の現在仕様）

### 確認結果（実機 / ビルド）
- iPhoneOS向け署名なしビルドが成功
- PhotosPickerの選択上限と取込ループの両方が残り枠を参照することをコード確認
- カメラ追加も残り枠0ではPhotoBlob候補を作らないことをコード確認
- 権利変更時に保存済みPhotoBlobを削除する処理がないことをコード確認

### 残課題
- 無料10枚目、ライト30枚目、複数選択、プラン失効後の追加停止を実機確認する
- 同期プランで大量写真を扱う際の容量表示と最適化は後続

## 2026-07-12: URL構造化イベント候補をライト以上へ追加

### 変更概要
- 無料のLinkPresentationページタイトル候補を維持
- ライト以上では公式ページのJSON-LDから`Event`を構造解析
- `startDate`、`location.name`、`location.address`を候補表示
- 日時・会場はユーザーがタップした時だけ反映し、自動上書きしない
- JSON-LDがないページや解析失敗時はタイトル候補だけを維持
- 5MB以下のHTMLだけを解析対象とし、http/https以外は従来どおり拒否
- 設定と課金画面へ利用境界を表示

### 変更意図
公式サイトに明示された構造化データだけを安全に利用し、曖昧な本文推測で誤った日時・会場を自動登録しないため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Services/URLMetadataService.swift（JSON-LD Event解析）
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（候補表示・選択反映）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（権利境界表示）
- favoreco/CLAUDE.md（URL取込の現在仕様）

### 確認結果（実機 / ビルド）
- iPhoneOS向け署名なしビルドが成功
- 無料状態ではLinkPresentationだけを呼び、構造化HTML取得を行わないことをコード確認
- JSON-LD取得/解析失敗をタイトル候補取得の失敗へ波及させないことをコード確認
- 日時・会場候補はボタン操作前にDraftを変更しないことをコード確認

### 残課題
- JSON-LD Eventを持つ複数の公式サイトで日時・会場候補を実機確認する
- `Event`以外の作品、書籍、映画メタデータ対応は後続

## 2026-07-12: バックアップ処理のSwift 6 Actor警告を解消

### 変更概要
- フルバックアップのプレビュー解析とJSONデコードをMainActorへ統一
- JSONバックアップのプレビュー解析もMainActorへ統一
- パッケージ内の固定ファイル名を`nonisolated`定数として明示
- 復元中に再代入しない訪問辞書を`let`へ変更

### 変更意図
SwiftDataモデルを含むCodable処理のActor隔離を呼び出し元と一致させ、Swift 6で警告がコンパイルエラーへ変わる前に解消するため。バックアップ形式と復元内容は変更しない。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Services/FullBackupService.swift（隔離指定と不変値整理）
- favorecoAPP/favorecoAPP/Services/JSONBackupImportService.swift（プレビュー解析の隔離指定）

### 確認結果（実機 / ビルド）
- iPhoneOS向け署名なしビルドが成功
- FullBackupServiceで発生していたActor隔離警告が消えたことを確認
- バックアップファイル名、JSON形式、復元処理の分岐に変更がないことを差分確認

### 残課題
- 大容量バックアップで待ち時間が問題になる場合は、SwiftDataモデルを含まないSendable DTOへ分離してバックグラウンド解析する
- JSON/フルバックアップの書き出し・プレビュー・復元を実機で通し確認する

## 2026-07-12: URL構造化候補を映画・本・人物へ拡張

### 変更概要
- JSON-LD解析対象へ`Book`と`Movie`を追加
- 本は発売日、著者、翻訳、出版社を候補化
- 映画は公開日、監督、出演、脚本を候補化
- `Event`にも出演/主催候補を追加
- 発売日/公開日は鑑賞日・読了日へ入れず、詳細オプションへ項目名つきで反映
- 人物・団体候補は役割つきで追加し、同名同役割の重複追加を停止

### 変更意図
ライブ・観劇だけでなく映画・本でも公式ページの構造化情報を入力補助に使いながら、作品の公開日とユーザーの体験日を混同しないため。候補は従来どおり明示操作でだけ反映する。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Services/URLMetadataService.swift（Book/Movie/人物候補解析）
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（候補の選択反映と重複防止）
- favoreco/CLAUDE.md（現在仕様）

### 確認結果（実機 / ビルド）
- URLMetadataServiceのiPhoneOS向け単体型チェックが成功
- AddExperienceViewとURLMetadataServiceのSwift構文解析が成功
- iPhoneOS向け署名なし全体ビルドが成功
- 発売日/公開日が`visitedAt`を変更しないこと、候補がタップ前にDraftを変更しないことをコード確認

### 残課題
- 実際のJSON-LDを持つ書籍、映画、イベント公式ページで候補精度を確認する
- ISBN/TMDb/Wikidata等の外部DB候補と画像取得はPremium/V2候補

## 2026-07-12: 自作ジャンルの複製と安全な削除を実装

### 変更概要
- 組み込み/自作ジャンルの設定を新しい自作ジャンルとして複製可能にした
- 複製名は「コピー」「コピー 2」のように既存名との重複を回避
- 自作ジャンルに記録・予定・SNS紐付けがなければ確認後に完全削除
- 関連データがある自作ジャンルは完全削除せず非表示へ切り替え
- 組み込みジャンルは複製可能、削除不可
- 最後の表示ジャンルは非表示/削除を停止

### 変更意図
よく似たジャンル設定を一から作り直す負担を減らしつつ、ジャンル削除によって記録や予定の分類参照が失われる事故を防ぐため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/GenreManagementView.swift（複製、削除判定、確認UI）
- favoreco/CLAUDE.md（現在仕様）

### 確認結果（実機 / ビルド）
- iPhoneOS向け署名なし全体ビルドが成功
- 複製先が新しいUUID/templateKeyを持ち、元ジャンルの記録リレーションを引き継がないことをコード確認
- 関連データあり、組み込み、最後の表示ジャンルで物理削除されないことをコード確認

### 残課題
- 複製、未使用ジャンル削除、使用中ジャンル非表示、再表示を実機確認する

## 2026-07-12: 自作ジャンル作成・複製をStoreKit権利へ接続

### 変更概要
- 自作ジャンルの新規作成と既存設定の複製をライト以上へ接続
- 無料時は追加ボタンをロック表示にし、押すと課金・プラン画面を表示
- ジャンル詳細の複製も無料時は課金・プラン画面へ誘導
- UIだけでなく作成/複製処理の直前にも権利を再検証
- 購入失効後も既存自作ジャンルの閲覧、編集、表示切替、削除は維持

### 変更意図
自作ジャンルをローカル全機能の買い切り価値へ接続しながら、失効や返金を理由に既存ジャンルや記録を利用不能・削除扱いにしないため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/GenreManagementView.swift（権利ゲート、課金画面導線、処理前再検証）
- favoreco/CLAUDE.md（現在仕様と無料/有料境界）

### 確認結果（実機 / ビルド）
- iPhoneOS向け署名なし全体ビルドが成功
- 無料時は追加/複製処理へ到達せず、課金画面を表示することをコード確認
- 既存自作ジャンルの詳細画面、保存、表示切替、削除に権利ゲートを追加していないことをコード確認

### 残課題
- StoreKit Configurationで無料→ライト購入→失効の順に追加/複製ボタンと既存ジャンル操作を実確認する

## 2026-07-12: 同期プラン向け月刊Favoreco自動提案を実装

### 変更概要
- 同期プラン以上の統計画面へ「先月の月刊Favoreco」自動提案カードを追加
- 既存の月刊レポートへ前月を初期表示する入口を追加
- 通知設定へ「毎月1日に月刊Favorecoを通知」を追加
- 毎月1日9時の繰り返しローカル通知を予約
- 通知タップで統計タブへ切り替え、前月レポートを開く導線を追加
- 通知マスターOFF、個別OFF、同期権利失効時は予約/配信済み通知を削除
- コールド起動でも永続フラグから遷移要求を復元

### 変更意図
サブスクの継続価値を、単なる詳細統計ではなく「毎月届く思い出」にするため。バックグラウンドで写真入り画像を事前生成せず、通知と前月選択だけを自動化してメモリ・電池・失敗リスクを抑える。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Services/MonthlyReportNotificationScheduler.swift（毎月通知の予約/解除）
- favorecoAPP/favorecoAPP/Services/PurchaseManager.swift（権利更新時の予約再評価）
- favorecoAPP/favorecoAPP/AppDelegate.swift（通知タップの遷移要求）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（通知設定と権利表示）
- favorecoAPP/favorecoAPP/Views/MainTabView.swift（統計タブ遷移、自動提案、前月レポート）
- favorecoAPP/favorecoAPP/Utilities/AppStorageKeys.swift（通知/遷移フラグ）
- favoreco/CLAUDE.md（現在仕様）

### 確認結果（実機 / ビルド）
- iPhoneOS向け署名なし全体ビルドが成功
- 無料/ライトでは自動提案をロック表示し、同期プラン以上で前月カードへ置換することをコード確認
- 通知マスター、個別設定、同期権利の3条件が揃わない限り予約しないことをコード確認
- 通知タップの永続フラグを、統計タブがアクティブになってから消費することをコード確認

### 残課題
- StoreKit Configurationと実機通知で、予約、毎月通知、前月表示、失効時キャンセルを確認する
- 年間Favorecoの自動提案時期と、予定/申込を含める集計仕様は後続

## 2026-07-12: 人物・場所マスターの重複統合を実装

### 変更概要
- データ管理へ人物・団体マスター、場所マスターの管理入口を追加
- 一覧へ紐付け/利用件数を表示
- 人物は名称、よみ、別名から類似候補を表示
- 場所は同名、同住所、150m以内の座標から類似候補を表示
- ユーザーが統合先を選択し、確認後にリンクを付け替える
- 人物の同一作品/回/役割リンクだけをアーカイブし、異なる役割は保持
- 場所のVisit/Plan参照を付け替え、記録側の名称・住所・座標スナップショットは維持
- 統合元マスターは物理削除せずアーカイブ
- 統合先の空欄だけを統合元情報で補い、別名/タグは重複排除して結合

### 変更意図
入力の揺れで増えた人物・会場を利用者判断で横断マスターへまとめながら、過去記録の表示名や場所情報を勝手に書き換えないため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Services/MasterMergeService.swift（人物/場所の安全な統合）
- favorecoAPP/favorecoAPP/Views/MasterManagementView.swift（一覧、候補、確認UI）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（データ管理の入口）
- favoreco/CLAUDE.md（現在仕様）

### 確認結果（実機 / ビルド）
- iPhoneOS向け署名なし全体ビルドが成功
- PersonMasterの全リンク、PlaceMasterのVisit/Plan参照を統合先へ付け替えることをコード確認
- Visitの`venueNameSnapshot`、座標、EventPersonLinkの`nameSnapshot`を変更しないことをコード確認
- 統合元を直接削除せず、失敗時はModelContextをロールバックすることをコード確認

### 残課題
- 人物の同名/別名、場所の同住所/近接座標を含む仮データで統合とバックアップ復元を実機確認する
- 類似候補がない場合に全マスターから統合先を検索するUIは後続候補

## 2026-07-12: 外部カレンダーの片方向自動更新を実装

### 変更概要
- 手動の「カレンダーに追加」保存完了時にEventKitイベントIDを取得
- EventKit IDをPlan UUIDとの端末ローカル対応表へ保存
- 既存Planに残る旧イベントIDは初回利用時にローカル対応表へ移し、SwiftData側をクリア
- 同期・バックアップ設定へ「favorecoの予定変更を自動反映」を追加
- 同期プラン以上かつ設定ONで、予定編集時に同じ外部イベントを更新
- タイトル、日時、登録住所優先の場所、状態/座席/メモ/公式URLを反映
- 予定削除時は設定ONなら外部イベントも削除、OFFなら外部イベントを残して紐付けだけ解除
- 外部イベントが見つからない場合は新規作成せずローカル紐付けを解除

### 変更意図
無料の手動追加を維持しながら、同期プランではfavorecoを予定の正本として外部カレンダーの重複作成を避けて追従させるため。端末固有のEventKit IDをCloudKitへ流さず、別端末で誤ったイベントを更新しないようにする。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Services/CalendarEventEditSheet.swift（保存イベントIDの通知）
- favorecoAPP/favorecoAPP/Services/ExternalCalendarSyncService.swift（更新/削除、端末ローカル紐付け）
- favorecoAPP/favorecoAPP/Views/PlanDetailView.swift（手動追加ID保存、削除連動）
- favorecoAPP/favorecoAPP/Views/AddTicketPlanView.swift（予定編集後の自動更新）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（Premium設定）
- favorecoAPP/favorecoAPP/Utilities/AppStorageKeys.swift（設定キー）
- favoreco/CLAUDE.md（現在仕様）

### 確認結果（実機 / ビルド）
- iPhoneOS向け署名なし全体ビルドが成功
- 新規予定作成時は外部イベントを自動作成せず、既存予定編集時だけ更新することをコード確認
- 外部イベントIDがSwiftData/CloudKitではなくUserDefaultsの端末ローカル対応表へ保存されることをコード確認
- 外部イベント未検出、権利なし、設定OFFで誤って新規イベントを作らないことをコード確認

### 残課題
- AppleカレンダーとiOSへ登録したGoogleカレンダーの両方で、手動追加、編集追従、削除、権限拒否を実機確認する
- 外部側の編集追従、双方向同期、一括追加はv2以降候補

## 2026-07-12: 人物・場所マスターの編集と検索を実装

### 変更概要
- 人物・団体一覧を表示名、よみ、別名で検索可能にした
- 場所一覧を名称、よみ、住所、別名で検索可能にした
- 人物は表示名、よみ、別名、タグを基本情報として編集可能にした
- 人物の公式URL、SNS/参考リンク、メモを任意アコーディオンへ追加
- 場所は名称、よみ、住所、別名、タグを基本情報として編集可能にした
- 場所の公式URL、メモ、保存座標を任意アコーディオンへ追加
- 保存必須は人物の表示名、場所の名称だけに限定
- 保存失敗時はModelContextをロールバックし、Draftを保存状態へ戻す

### 変更意図
個人用横断DBを入力候補だけでなく利用者が育てられる管理対象にしつつ、補足情報を必須にして記録入力を重くしないため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/MasterManagementView.swift（検索、編集、任意アコーディオン）
- favoreco/CLAUDE.md（現在仕様）

### 確認結果（実機 / ビルド）
- iPhoneOS向け署名なし全体ビルドが成功
- マスター編集がPersonMaster/PlaceMasterだけを更新し、EventPersonLink/Visitのスナップショットを変更しないことをコード確認
- 空の表示名/名称では保存できないこと、任意項目が空でも保存できることをコード確認

### 残課題
- 大量マスターで検索、編集、統合を連続操作した時の表示更新を実機確認する
- 人物画像の変更、場所座標の再検索は既存の記録入力候補や外部候補と合わせて後続検討する

## 2026-07-12: ライト以上のフォント切り替えを実装

### 変更概要
- 表示設定に独立したフォント設定画面を追加
- 無料のスタンダード、ライト以上のゴシック中心/明朝中心を追加
- 選択肢ごとの日本語プレビューと説明を表示
- 英字見出しは全設定でCormorant Garamondを維持
- 有料権利がない場合は保存した選択を削除せず、表示だけスタンダードへ戻す

### 変更意図
既に同梱している可変フォントを、標準の読みやすさを保ちながらライト買い切り以上のローカルカスタマイズ価値として提供するため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Utilities/FavorecoTypography.swift（フォントスタイルと全体解決）
- favorecoAPP/favorecoAPP/Utilities/AppStorageKeys.swift（選択保存キー）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（設定入口、選択、プレビュー、権利表示）
- favorecoAPP/favorecoAPP/ContentView.swift（設定変更の全体再評価）
- favoreco/CLAUDE.md（現在仕様）

### 確認結果（実機 / ビルド）
- コード変更後にiPhoneOS向け署名なし全体ビルドを実施
- スタンダードが従来の本文ゴシック/情緒見出し明朝を維持することをコード確認
- 権利なしでは追加フォントを選べず、保存済み有料設定も表示へ適用しないことをコード確認

### 残課題
- ライト以上のStoreKitテスト状態で、設定変更直後のHome/詳細/編集画面への反映を実機確認する
- 長い日本語、Dynamic Type特大、ダークモードでゴシック/明朝それぞれの折返しを確認する

## 2026-07-12: 可変フォントの太さ設定を追加

### 変更概要
- ライト買い切り以上のフォント設定へ、細め/標準/太めの3段階を追加
- 本文、強調本文、見出しの相対的な強弱を保ったまま全体のウェイトを調整
- 日本語2書体とCormorant Garamondの双方へ同じ調整方針を適用
- 権利がない場合は保存値を残したまま標準ウェイトへフォールバック
- 選択変更をフォント設定画面のプレビューへ即時反映

### 変更意図
可変フォントの連続軸をそのまま露出して読みにくい組み合わせを作るのではなく、利用者が迷わず文字の印象を調整できる安全な選択肢として提供するため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Utilities/FavorecoTypography.swift（ウェイト段階と相対調整）
- favorecoAPP/favorecoAPP/Utilities/AppStorageKeys.swift（太さ保存キー）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（太さ選択、権利制御、プレビュー）
- favorecoAPP/favorecoAPP/ContentView.swift（設定変更の全体再評価）
- favoreco/CLAUDE.md（現在仕様）

### 確認結果（実機 / ビルド）
- iPhoneOS向け署名なし全体ビルドが成功
- 無料状態では太さ選択が無効かつ標準表示になることをコード確認
- 細めでも見出しが本文より太く、太めでも本文と見出しが同一ウェイトへ潰れないことをコード確認

### 残課題
- ライト以上のStoreKitテスト状態で、細め/太めを切り替えた直後の全画面反映を実機確認する
- Dynamic Type特大と明朝中心+太めの組み合わせで、ボタンやフォーム行の収まりを実機確認する

## 2026-07-12: 対象の代表写真表示と選択を実装

### 変更概要
- 対象詳細のHeroに代表写真を表示
- 対象メニューから、紐づく全記録の写真を代表写真として選択可能にした
- `自動`へ戻す操作を追加
- 明示選択なし、または選択写真が削除済みの場合は、最新記録のカバー/先頭写真へ自動フォールバック
- ジャンル内の対象一覧にも同じ代表写真を縮小表示
- 一覧と選択画面はImageIOサムネイル生成とNSCacheを利用

### 変更意図
同じ作品、銘柄、施設などへ記録を重ねる対象構造を写真でも識別しやすくし、初回写真に固定せず利用者が対象の顔を選べるようにするため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/EventDetailView.swift（代表写真解決、表示、選択画面、サムネイル）
- favorecoAPP/favorecoAPP/Views/CategoryTopView.swift（対象一覧サムネイル）
- favoreco/CLAUDE.md（現在仕様）

### 確認結果（実機 / ビルド）
- iPhoneOS向け署名なし全体ビルドが成功
- 選択パスが存在しない場合に最新記録の写真へ戻ることをコード確認
- 写真なし対象では代表写真メニューと空の画像枠を表示しないことをコード確認
- SwiftDataモデルをバックグラウンドへ渡さず、値型のDataだけでサムネイル生成することをコード確認

### 残課題
- 複数記録/複数写真での選択、`自動`復帰、選択写真削除後のフォールバックを実機確認する
- 対象アーカイブは復元一覧と同時に後続実装する

## 2026-07-12: 対象の非表示と復元を実装

### 変更概要
- 対象詳細メニューに「対象を非表示」を追加
- 非表示前に、履歴と写真を残すことを確認ダイアログで明示
- データ管理に「非表示の対象」一覧を追加
- 対象名、ジャンル、履歴件数を確認してボタン/スワイプから再表示可能にした
- 非表示対象のVisitをHome、記録一覧、カレンダー、統計、月刊/年間レポートから除外
- 復元後は同じVisitが各画面と集計へ戻る
- 対象の非表示/復元では紐づく履歴、写真、予定、通知を変更しない

### 変更意図
不要になった対象を即削除せず通常画面から整理でき、誤操作時にもデータ管理から安全に戻せるようにするため。非表示と完全削除の役割を明確に分ける。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/EventDetailView.swift（非表示操作と確認）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（非表示対象一覧と復元）
- favorecoAPP/favorecoAPP/Views/HomeView.swift（非表示Visit除外）
- favorecoAPP/favorecoAPP/Views/MainTabView.swift（記録/カレンダー/統計/レポート除外）
- favoreco/CLAUDE.md（現在仕様）

### 確認結果（実機 / ビルド）
- iPhoneOS向け署名なし全体ビルドが成功
- 非表示ではExperienceEventとupdatedAt以外を変更しないことをコード確認
- 復元ではisArchivedとupdatedAt以外を変更しないことをコード確認
- 非表示対象のVisitが主要4タブとレポート入力から除外されることをコード確認

### 残課題
- 写真/履歴/予定を持つ対象で、非表示、各タブからの消失、復元、再表示を実機確認する
- 非表示対象を含むJSON/写真付きバックアップの書き出し・復元を実機確認する

## 2026-07-12: Inboxから既存対象への回追加を実装

### 変更概要
- Inbox詳細の変換を「新しい対象」と「既存対象に回を追加」へ分離
- 選択カテゴリ内の未アーカイブ対象を追加先として選択可能にした
- 既存対象への回追加ではInboxのメモとURLをVisitメモの下書きへ引き継ぐ
- 既存対象のタイトル、シリーズ、公式URLは上書きしない
- `AddVisitView`へ初期Draftと保存コールバックを渡せるよう拡張
- Visit保存と同じトランザクションでInboxを`resolved`へ更新
- 新規対象/既存対象の両変換で保存失敗時にInbox状態もロールバック
- Inbox詳細に未整理/変換済みの状態表示を追加

### 変更意図
同じ作品、公演、施設、銘柄をInboxから記録するたびに対象が重複するのを防ぎ、既存対象へ履歴を自然に積み重ねられるようにするため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/InboxDetailView.swift（変換先選択、既存対象候補、状態表示）
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（AddVisit初期Draft、保存コールバック、ロールバック）
- favoreco/CLAUDE.md（現在仕様）

### 確認結果（実機 / ビルド）
- iPhoneOS向け署名なし全体ビルドが成功
- 候補が選択カテゴリ内かつ未アーカイブ対象だけになることをコード確認
- 既存対象のフィールドを変更せずVisitだけ追加することをコード確認
- VisitとInbox状態が同じModelContext保存/ロールバック境界にあることをコード確認

### 残課題
- 同名対象、対象0件、変換済みInbox、保存後に詳細を開く/閉じる設定の各ケースを実機確認する
- Inboxから予定・チケットへの変換は後続実装する

## 2026-07-12: 1万枚規模の写真保存・表示・バックアップを最適化

### 変更概要
- PhotoBlobの存在確認を`data.isEmpty`から`byteCount`へ変更
- Home、記録一覧、対象代表写真、記録詳細で、一覧判定時にexternalStorage本体を読み込まないよう統一
- 記録詳細の1枚表示/複数グリッドをImageIOサムネイルの非同期生成へ変更
- 写真編集画面の保存済み写真もオンデマンド縮小表示へ変更
- 写真選択/カメラ追加時の長辺1600px変換とJPEG再生成をバックグラウンド化
- Data管理へ写真実容量、1枚平均、1万枚時の推定容量を追加
- 同期設定へ現在の写真データ容量を追加
- 自動バックアップ保持数を写真容量に応じて5/3/2世代へ調整
- 自動バックアップ前に必要容量+500MB以上の安全余白を検査
- 永続モデルの保存フィールドとCloudKit schemaは変更していない

### 変更意図
1公演20枚×500公演=1万枚でも、一覧表示や容量確認だけで写真本体をフォールトさせず、画像追加/表示のCPU・メモリ負荷と写真付きバックアップの容量増幅を抑えるため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Models/CoreModels.swift（byteCountベースの存在判定）
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（バックグラウンド圧縮、編集サムネイル）
- favorecoAPP/favorecoAPP/Views/ExperienceDetailView.swift（詳細サムネイル）
- favorecoAPP/favorecoAPP/Views/HomeView.swift / VisitSummaryRow.swift / EventDetailView.swift（本体非フォールト化）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（容量表示）
- favorecoAPP/favorecoAPP/Services/AutomaticBackupService.swift（動的保持数、空き容量検査）
- favorecoAPP/favorecoAPP/Views/AutomaticBackupView.swift（実容量と保持数表示）
- favoreco/CLAUDE.md（現在仕様）

### 確認結果（実機 / ビルド）
- iPhoneOS向け署名なし全体ビルドが成功
- 通常一覧/集計経路で`PhotoBlob.data.isEmpty`を使用していないことをコード確認
- 写真追加のImageIO処理と一覧サムネイル生成がメインスレッド外で動くことをコード確認
- 完全バックアップは従来どおり1枚ずつ逐次書き出しし、全写真Dataを同時保持しないことをコード確認
- SwiftDataの永続プロパティとCloudKit構成に変更がないことを確認

### 残課題
- 85%設定で20枚一括追加、500枚以上の一覧スクロール、メモリ警告後の再表示を実機確認する
- 1万枚のCloudKit初回同期は通信量/iCloud容量に比例するため、Wi-Fi・充電中での長時間実機試験が必要
- 将来、写真だけ同期対象外/段階ダウンロードを提供する場合はSwiftData automatic単一ストアからMediaAsset専用同期層への移行設計が必要

## 2026-07-12: Inboxから予定・チケットへの変換を実装

### 変更概要
- Inbox詳細に「予定・チケットに変換」を追加
- Inboxのタイトル、URL、メモ、選択カテゴリを予定フォームの初期値へ反映
- 日時はフォーム上で利用者が確認できる現在日時ベースの初期値を使用
- チケット申込情報は初期OFFにし、必要な場合だけ利用者がONにする
- Plan保存と同じModelContextトランザクションでInboxを`resolved`へ更新
- 保存失敗時はPlan/TicketAttemptとInbox状態をまとめてロールバック

### 変更意図
あとで調べる公演やイベントを再入力せず予定へ移しつつ、未確認の情報を自動でチケット申込として確定しないため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/InboxDetailView.swift（予定変換入口）
- favorecoAPP/favorecoAPP/Views/AddTicketPlanView.swift（Inbox初期Draft、保存コールバック、ロールバック）
- favoreco/CLAUDE.md（現在仕様）

### 確認結果（実機 / ビルド）
- iPhoneOS向け署名なし全体ビルドが成功
- 初期状態で申込情報を作らないことをコード確認
- 選択カテゴリとInboxのタイトル/URL/メモがDraftへ入ることをコード確認
- Plan保存とInbox状態が同じ保存/ロールバック境界にあることをコード確認

### 残課題
- 日時未確認、申込情報ON/OFF、変換済みInboxの再操作防止を実機確認する

## 2026-07-12: 予定・チケット詳細統計を実装

### 変更概要
- 統計タブへライト以上の「予定・チケット」セクションを追加
- 今年開催される未アーカイブ予定数を集計
- 当落待ち以降を「申込済み」として集計
- 当選、入金待ち、発券待ち、発券済み、参加済みを「取得」として集計
- 参加済み件数を独立表示
- 当選系と落選が確定した申込だけを分母に当選率を算出
- 無料状態では数値をぼかさず、ライト以上の機能説明を表示

### 変更意図
単純な記録回数だけでなく、予定から申込、取得、参加までの活動を振り返れるようにしつつ、結果待ちを当選率の分母へ混ぜない正確な集計にするため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/MainTabView.swift（予定・チケット集計と表示）
- favoreco/CLAUDE.md（現在仕様）

### 確認結果（実機 / ビルド）
- iPhoneOS向け署名なし全体ビルドが成功
- アーカイブ済みPlan/TicketAttemptを集計から除外することをコード確認
- 気になる/申込前/発売前/見送りを申込済み件数へ含めないことをコード確認
- 当落待ちを当選率の分母へ含めないことをコード確認

### 残課題
- 複数先行、当落待ち、当選、落選、参加済みを混在させた仮データで数値を実機確認する
- 名義別/プレイガイド別/ジャンル別の深いチケット分析は後続候補

## 2026-07-12: 実機確認フィードバック第1弾を反映

### 変更概要
- 複数写真を順次取り込みし、件数付きプログレス表示と縮小サムネイルへ変更
- 記録入力からカバー表示比率の選択UIを撤去
- URLタイトル取得にHTML titleの予備経路を追加
- 住所/保存座標を優先する会場Mapプレビューを基本情報へ追加
- 仮データのVisitを明示削除し、ジャンル別件数の残留を防止
- 中央+を「思い出を記録 / クイック記録」の二段階導線へ整理し、チケット入口を記録/カレンダー右上へ移動
- 人物・団体マスター管理画面から新規登録可能に変更
- カレンダー月見出しを日本語年月表記へ固定
- DEBUG権利切替と全データ削除テスト入口を設定 > 開発へ追加
- チケット入力を予定基本情報、申込状況、締切・発券、金額・座席、メモへ整理

### 変更意図
実機で発生した写真10枚選択時のメモリ負荷、仮データ削除後の件数残留、URL候補取得失敗を解消し、記録とチケットの追加入口を役割ごとに分けるため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift
- favorecoAPP/favorecoAPP/Services/URLMetadataService.swift
- favorecoAPP/favorecoAPP/Services/DebugDataSeeder.swift
- favorecoAPP/favorecoAPP/Views/MainTabView.swift
- favorecoAPP/favorecoAPP/Views/AddTicketPlanView.swift
- favorecoAPP/favorecoAPP/Views/MasterManagementView.swift
- favorecoAPP/favorecoAPP/Views/SettingsView.swift
- favorecoAPP/favorecoAPP/Services/PurchaseManager.swift
- favoreco/CLAUDE.md

### 確認結果（実機 / ビルド）
- iOS 18.0ターゲットのDebug Simulator向け全体ビルド、およびRelease iPhoneOS向け署名なしビルド成功
- 共有SchemeのRunにFavoreco.storekitが設定済みであることを確認
- 実機での写真10枚取込、URL取得、Map表示、仮データ削除、権利切替は次回確認

### 残課題
- 実機で写真10枚を一括選択し、進捗完了後に保存できることを確認する
- JavaScript必須・認証必須ページなど、HTML titleも取得できないURLのエラー表示を確認する
- テスト権利をStoreKit購入結果へ戻した時、ローカル購入状態へ復帰することを確認する
- チケットフォームの各フローで不要な期限が表示されないことを確認する

## 2026-07-13: 全画面の情報設計を確定

### 変更概要
- Mystoriumを参考に、デザインではなく画面責務の分離原則を採用
- Home、ジャンルトップ、記録一覧、対象詳細、記録詳細、予定詳細、登録、編集の役割を定義
- ExperienceEvent、Visit、Plan、TicketAttemptの表示/編集境界を明文化
- 対象編集、記録編集、予定・チケット編集を別画面として扱う方針を確定
- 登録を既存対象選択/新規対象作成から始め、必須情報と任意アコーディオンを分離する方針を確定

### 変更意図
Homeだけでなく登録、詳細、ジャンルトップ、編集の情報が混在している状態を解消し、各画面のデザインと実装を同じ判断基準で整理できるようにするため。

### 主な変更ファイル
- docs/15-画面情報設計.md
- favoreco/CLAUDE.md
- docs/project-log.md

### 確認結果（実機 / ビルド）
- ドキュメントのみ更新。アプリコード、保存モデル、既存データへの変更なし
- Mystoriumの閲覧専用詳細、別編集画面、Draft保存方式との整合を確認

### 残課題
- 思い出の登録、記録詳細、記録編集の3画面から順にデザインラフを作る
- 現行Viewを責務単位に分割する実装計画と既存データ影響を精査する

### 追加決定: 登録入口
- 中央+は `記録する / クイック登録` の2択だけを表示
- クイック登録はジャンル/タイトル必須、アイキャッチ/URL任意で「気になる」へ保存
- 記録する画面は新規対象登録を主操作、登録済み対象へのVisit追加を補助操作にする
- 登録済み対象を選ぶと対象情報を参照し、今回固有のVisit情報だけを入力する
- 既存対象への記録追加とシリーズ連結は分け、シリーズは新規対象の任意項目として検索・連結する

### 追加決定: 御朱印
- 御朱印登録は使用中の御朱印帳選択から開始し、同時に新しい御朱印帳も登録できる
- 御朱印帳のページ数/容量/使用ページを管理せず、御朱印の登録件数だけを集計する
- 御朱印帳は利用者が手動で閉じ、自動満了判定を行わない
- 閉じた御朱印帳は新規追加だけを停止し、帳面と既存御朱印の編集は許可する
- 寺社名だけを必須とし、住所/Map/URL/御祭神/日時/写真/同行者/メモ等は任意
- 初穂料・納経料は300円/500円/その他を選べ、未入力も許可する
- 保存後は完了または同じ寺社で続けて登録を選べる

## 2026-07-14: ジャンル別登録フローと共通入力ルールを整理

### 変更概要
- 映画、観劇、ライブ、本、美術展、おでかけ、お酒の対象/記録境界と登録入口を整理
- 映画と本へ複数コレクション所属、記録回ごとの0.5刻み5段階評価を定義
- 観劇を公演/観劇回、ライブをライブ・イベント/参加回、本を本/読書記録、美術展を展覧会/鑑賞記録として整理
- URL/OCR候補確認、人物名の空白無視重複候補、全ジャンルSNSタグを共通ルール化
- 美術展作品、おでかけ体験は写真を二重保存せず、共通写真へ任意情報を付与する方針を定義
- チケットを抽選、発売・予約、取得済みの3入口へ整理し、取得後はフォーム列挙ではなくメモ/リンク中心に変更
- 会場は施設/ホールの二段階選択を見せず、住所優先Mapの単一検索/自由入力欄へ統一

### 変更意図
ジャンルごとに必要な情報量を保ちながら、通常登録では対象名と今回の記録へ集中できるようにし、専用管理アプリのような過剰入力を避けるため。チケットは現在主流の公式サイト/アプリ上のQR表示へ戻れることを優先し、転記負担を減らすため。

### 主な変更ファイル
- docs/15-画面情報設計.md
- docs/project-log.md

### 確認結果（実機 / ビルド）
- ドキュメントのみ更新。アプリコード、SwiftDataモデル、既存データへの変更なし
- ExperienceEventを対象、Visitを記録回、Plan/TicketAttemptを予定/チケットとする既存方針との整合を読み直し確認
- 同一情報の対象/記録間コピー、写真の二重保存、開催日時のチケット重複保存を行わない方針を確認

### 残課題
- コレクション多対多、御朱印帳、写真注釈、ジャンル別状態/種別/タグを既存モデルへ追加する移行設計
- 思い出登録、対象詳細、記録詳細、ジャンルトップ、編集画面のデザインラフ作成
- 主要都市の映画館、劇場、美術館等の初期PlaceMasterデータについて、権利と更新方法を確認した上で収録範囲を確定

## 2026-07-14: Home優先順位と追加入口を再整理

### 変更概要
- Homeのファーストビューを横断統計ではなく直近の予定中心へ変更
- お知らせ・アテンション欄を常設し、0件時も対応事項がないことをコンパクトに明示する方針を確定
- お知らせを横長の一覧行で最大2件表示し、ジャンル入口を小さな1段横スクロールにする方針を確定
- 次の予定を開催日時順のページ式カルーセルとし、左右スワイプで1件ずつ切り替える方針を確定
- Homeの`予定一覧`からカレンダータブの一覧モードへ直接移動し、独立した重複画面を作らない方針を確定
- 最近の思い出は保存済みアイキャッチ比率を維持してタイル幅へ合わせ、タイル詳細は後続デザインで決める方針を確定
- 中央`+`を`予定を立てる / 体験済みを記録 / クイック登録 / チケットスケジュールを追加`の4入口へ変更
- 予定起点を初期値とし、予定完了後は情報を引き継いでVisitを作成する方針を明文化
- チケットスケジュールは独立記録にせず、検索または最小作成したイベントのPlanへ紐付ける方針を確定

### 変更意図
Favorecoを開いた時に次の体験への期待を最初に見せ、統計より予定と要対応を優先するため。対応事項がない場合もお知らせ欄を消さず、通知がないことやしばらく予定がないことを利用者が確認できるようにする。また、予定を立ててから記録する基本利用と、御朱印・お酒・過去履歴などの体験済み直接登録を両立するため。

### 主な変更ファイル
- docs/15-画面情報設計.md
- docs/project-log.md

### 確認結果（実機 / ビルド）
- ドキュメントのみ更新。アプリコード、SwiftDataモデル、既存データへの変更なし
- Plan、TicketAttempt、Visitを分離する既存の画面責務と矛盾しないことを読み直し確認

### 残課題
- 採用可能性を残したHomeショートカット帯について、中央`+`と重複しない内容を確定する
- 最近の思い出で異なる画像比率が混在する場合のタイルサイズと整列方法を確定する
- PlanからVisitを作成する際の引き継ぎ項目と完了状態をモデル/画面実装へ反映する
- Homeの通常時/要対応時モックをSwiftUIレイアウトへ落とし込む

## 2026-07-14: OCR共通化と追加導線の軽量整理

### 変更概要
- 正式記録画面の画像OCRを`QuickCaptureImageService`へ統合し、重複していたVision処理と画像方向変換を削除
- HomeのA/B比較導入後に未使用となった旧`CategoryTile`を削除
- Inboxの画面上の呼称を`気になる`、登録方式を`クイック登録`へ統一
- Inboxからの操作文言を`体験済みを記録`と`予定を立てる`へ合わせ、中央`+`の読み上げを`追加メニューを開く`へ変更

### 変更意図
OCRの挙動差と修正漏れを防ぎ、現在の4つの追加入口と画面上の文言を一致させるため。未使用UIを残さず、今後のHome再構成で古いタイルが誤って再利用されることも防ぐ。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift
- favorecoAPP/favorecoAPP/Views/HomeView.swift
- favorecoAPP/favorecoAPP/Views/InboxDetailView.swift
- favorecoAPP/favorecoAPP/Views/MainTabView.swift
- docs/project-log.md

### 確認結果（実機 / ビルド）
- OCRの呼び出しが共通サービス1系統だけであることを静的確認
- 旧`CategoryTile`の参照・宣言が残っていないことを静的確認
- iOS Simulator汎用ビルド（iOS 18最低対象、コード署名なし）成功
- 実機確認は未実施

### 残課題
- Homeの次の予定を0件/1件/複数件で表示分岐し、複数時はカード単位のページ式カルーセルへ変更する
- `気になる`から予定を立てる際、InboxItemからExperienceEventを作成または再利用してPlanへ明示的に紐付ける
- クイック登録のアイキャッチを正式記録へ引き継ぐ処理を実装する

## 2026-07-14: クイック登録を通常の対象構造へ統合

### 変更概要
- クイック登録の保存先を別構造のInboxItemから通常と同じExperienceEventへ変更
- ExperienceEventへ`気になる`状態、全ジャンル共通の読み取りメモ、外部ストレージ型アイキャッチを追加
- クイック登録はジャンル/タイトル必須、アイキャッチ/URL/読み取りメモ/通常メモ任意の簡易フォームとして維持
- Homeの`気になる`をExperienceEventから取得し、行から通常の対象詳細を直接開くよう変更
- 対象詳細から同じ対象へ`予定を立てる`または`記録を追加`できる導線を追加
- 対象から作ったPlanへExperienceEventを明示的に関連付け、予定または記録作成時に`気になる`状態を通常へ移すよう変更
- 旧InboxItemは新規作成を停止し、既存の未整理データだけを同じIDのExperienceEventへ一度移行する互換処理を追加
- JSON/完全バックアップへ状態と読み取りメモを追加し、クイックアイキャッチは写真付き完全バックアップ時だけ含めるよう変更
- 写真付き仮データの`気になる`候補もExperienceEventで作成するよう更新

### 変更意図
クイック登録を別データから正式データへ変換する負担をなくし、通常登録と同じ対象を入力項目だけ絞って作れるようにするため。OCR全文は自動振り分けで失わず、共通の読み取りメモへ保持する。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Models/CoreModels.swift
- favorecoAPP/favorecoAPP/Services/LegacyInboxMigrationService.swift
- favorecoAPP/favorecoAPP/Services/JSONBackupExportService.swift
- favorecoAPP/favorecoAPP/Services/JSONBackupImportService.swift
- favorecoAPP/favorecoAPP/Services/DebugDataSeeder.swift
- favorecoAPP/favorecoAPP/Views/AddInboxItemView.swift
- favorecoAPP/favorecoAPP/Views/HomeView.swift
- favorecoAPP/favorecoAPP/Views/EventDetailView.swift
- favorecoAPP/favorecoAPP/Views/CategoryTopView.swift
- favorecoAPP/favorecoAPP/Views/AddTicketPlanView.swift
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift
- favorecoAPP/favorecoAPP/Views/MainTabView.swift
- favorecoAPP/favorecoAPP/Views/SettingsView.swift
- favorecoAPP/favorecoAPP/Views/JSONImportView.swift
- docs/15-画面情報設計.md
- docs/project-log.md

### 確認結果（実機 / ビルド）
- iOS Simulator汎用ビルド（iOS 18最低対象、コード署名なし）成功
- 新しいクイック登録からInboxItemを作成するコードが残っていないことを静的確認
- 旧InboxItemのモデル/復元処理は既存ストアと旧バックアップ互換のため意図的に保持
- 実機確認は未実施

### 残課題
- 既存端末で旧InboxItemが`気になる`対象へ移行し、画像/URL/メモ/OCRが保持されることを実機確認する
- クイック登録、Homeの気になる、対象詳細、予定追加、記録追加の一連フローを実機確認する
- 対象アイキャッチを通常編集画面から変更/削除する操作を追加する

## 2026-07-14: 対応OSの優先順位を確定

### 変更概要
- 最低対応OSをiOS 18、主対象とUI品質基準をiOS 26以上とする方針を明文化
- iOS 26の新しいSwiftUI表現と操作性を優先し、iOS 18は`#available`による機能維持型フォールバックとする
- デザインの最終確認はiOS 26、iOS 18は互換性と主要機能の確認を中心にする

### 変更意図
iOS 18対応のためにUI全体を古い表現へ固定せず、主な利用環境であるiOS 26以上ではより快適で自然な操作感を提供するため。

### 主な変更ファイル
- docs/15-画面情報設計.md
- docs/project-log.md

### 確認結果（実機 / ビルド）
- 方針文書のみ更新。アプリコード、保存モデル、最低Deployment Targetへの変更なし

### 残課題
- 各画面の再設計時にiOS 26専用改善候補とiOS 18フォールバックを対で記録する
- iOS 26実機を基準にHome、追加導線、カルーセル、シート、タブ操作を確認する

## 2026-07-14: 予定作成で対象とPlanの関連を必須化

### 変更概要
- 中央`+`からの予定作成に`新しく登録 / 気になるから選ぶ`の対象選択を追加
- 新規予定ではExperienceEventとPlanを同じ保存操作で作成し、既存選択では`気になる`対象へPlanを追加
- 対象詳細からの予定追加は表示中のExperienceEventへ直接紐付け
- 新規・既存・旧Plan編集の全経路でPlanにExperienceEventがない状態を補正し、Plan単独保存を防止
- Plan作成後は対象を`気になる`から通常状態へ移行

### 変更意図
作品・施設などの対象と、利用者がいつどこへ行くかという予定を分離しながら、画面上は1回の入力と保存で完結させるため。Home、カレンダー、対象詳細が同じPlanを一貫して参照できるようにする。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/AddTicketPlanView.swift
- docs/15-画面情報設計.md
- docs/project-log.md

### 確認結果（実機 / ビルド）
- iOS 18最低対象、iOS 26.5 SDKの汎用Simulatorビルド成功
- Planの新規作成箇所が`AddTicketPlanView`へ集約され、作成時に必ずEventを解決または新規作成することを静的確認
- 実機確認は未実施

### 残課題
- 実機で新規対象、気になる対象、対象詳細、旧Plan編集の4経路を保存確認する
- `気になるから選ぶ`の件数が増えた段階で、Pickerを検索式選択画面へ拡張する
- 次の段階としてHomeの次の予定を0件/1件/複数件で表示分岐する

## 2026-07-14: Homeの次の予定とカレンダー予定一覧を実装

### 変更概要
- Home最上段へ開始日時が近い順の`次の予定`を配置
- 0件は空状態と`予定を立てる`、1件は固定カード、2件以上は自動切替なしのページ式スワイプと`1 / N`を表示
- `予定一覧`からカレンダータブへ移動し、`カレンダー / 予定一覧`の表示切替を追加
- 予定一覧では今後のPlanを年月単位、日時順で表示
- 通常の予定をアテンションから除外し、アテンションを締切・当落・発券・会員期限へ限定
- アテンション0件でも1行の正常状態を常設し、3件以上は専用一覧シートへ集約
- 大きなブランドメッセージをHome通常表示から外し、横断統計を下部へ移動

### 変更意図
アプリを開いた直後に次の体験予定を確認できるようにし、予定と対応必須のお知らせを混同しないため。Homeとカレンダーに重複した一覧を作らず、同じPlanデータへ直接移動できるようにする。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/HomeView.swift
- favorecoAPP/favorecoAPP/Views/MainTabView.swift
- docs/15-画面情報設計.md
- docs/project-log.md

### 確認結果（実機 / ビルド）
- iOS 18最低対象、iOS 26.5 SDKの汎用Simulatorビルド成功
- 0件/1件/複数件の条件分岐、選択位置の件数変動補正、日付順ソートを静的確認
- 実機確認は未実施

### 残課題
- 実機で縦スクロールと予定カードの横スワイプが競合しないことを確認する
- 長いタイトル、長い会場名、Dynamic Typeでカード高さと文字切れを確認する
- iOS 26実機でページ操作とシート遷移の見た目を調整する

## 2026-07-14: 体験済み記録の対象選択と予定からの入力を実装

### 変更概要
- 中央`+`の`体験済みを記録`に、コンパクトなジャンル選択と`新しい作品・対象を登録 / 登録済み作品・対象に記録を追加`の2経路を追加
- 既存対象は選択ジャンル内をタイトル・シリーズ名で検索でき、未検索時は最近更新した5件を表示
- 新規対象はExperienceEventとVisitをまとめて保存し、既存対象は選択したExperienceEventへVisitだけを追加する既存処理へ接続
- 予定詳細の参加記録を即時作成から入力フォーム式へ変更
- 予定日時、終了日時、会場、座席、金額、メモ、公式URL/購入URLを記録フォームへ初期入力
- 記録保存成功時だけPlanと代表TicketAttemptを参加済みに更新し、予定通知を解除
- AddVisitViewの完了コールバックを保存成功後へ移動

### 変更意図
対象情報を重複登録せず再鑑賞・再訪・再読を追加できるようにし、予定から実績へ移す際も内容を確認・修正してから確定できるようにするため。入力をキャンセルしただけで参加済みになる誤操作も防ぐ。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/MainTabView.swift
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift
- favorecoAPP/favorecoAPP/Views/PlanDetailView.swift
- docs/15-画面情報設計.md
- docs/project-log.md

### 確認結果（実機 / ビルド）
- iOS 18最低対象、iOS 26.5 SDKの汎用Simulatorビルド成功
- 新規対象ではExperienceEventとVisit、既存対象では選択EventとVisitが関連することをコードで確認
- 予定経由では入力フォーム保存前にVisitを作らず、保存処理内でPlan/Visit/TicketAttemptをまとめて更新することを確認
- 実機確認は未実施

### 残課題
- 実機で中央`+`から新規対象、既存対象、検索0件、ジャンル切替の各経路を確認する
- 予定詳細から記録フォームを開き、引継値、キャンセル時の未変更、保存後の参加済み表示を確認する
- 既存対象が大量になった場合の検索速度と、長いタイトル・シリーズ名の表示を確認する

## 2026-07-14: 対象アイキャッチの編集と表示優先順位を実装

### 変更概要
- 対象詳細のメニューを`対象情報・画像を編集`へ変更
- 対象編集画面でアイキャッチの追加、差し替え、解除を可能にした
- 選択画像をクイック登録と同じ長辺1600px以内、JPEG品質85%へ圧縮して保存
- 対象画像を解除しても各記録の写真は残す
- 代表画像の優先順位を`明示指定した記録写真 > 対象アイキャッチ > 記録写真の自動候補`へ統一
- 画像処理中の進捗と読込・保存失敗時のメッセージを追加

### 変更意図
クイック登録した`気になる`対象の表紙を後から整えられるようにしつつ、利用者が記録側で選んだ代表写真や保存済み写真を誤って上書き・削除しないため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/EventDetailView.swift
- docs/15-画面情報設計.md
- docs/project-log.md

### 確認結果（実機 / ビルド）
- iOS 18最低対象、iOS 26.5 SDKの汎用Simulatorビルド成功
- 対象画像がある場合も明示指定した記録写真が優先され、対象画像がない場合は従来の自動候補へ戻ることをコードで確認
- 実機確認は未実施

### 残課題
- 実機で対象画像の追加、差し替え、解除、編集キャンセルを確認する
- Homeの`気になる`、対象詳細、ジャンルトップで保存直後に画像が更新されることを確認する
- 大容量写真の選択時に進捗表示が維持され、メモリ警告や強制終了が起きないことを確認する
