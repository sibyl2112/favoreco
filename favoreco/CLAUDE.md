# favoreco 実装仕様（正本）

> **役割**: このアプリの「現在どうなっているか」の正本。横断ルールは ルート `CLAUDE.md` を参照。
> **最終更新**: 2026-07-09（同期/バックアップ境界と削除系設定方針追加）

---

## 1. コンセプト

**観た・行った・体験したを、美しく一生残す。**（詳細: `docs/favoreco-concept.md`＝確定）

- コア体験: 記録が、美しい思い出になる
- 人間観: 人は雑食、ただし個人ごとに「柱」が2〜3本ある

## 2. 技術スタック

SwiftUI / SwiftData / MapKit / ImageIO / UserNotifications（Mystorium準拠・外部ライブラリゼロ方針。`docs/04-Mystorium構造リファレンス.md` 参照）

## 3. データモデル（正本）

実装開始済み。正本仕様は `docs/spec-A1-データモデル基盤.md`。初期実装は [CoreModels.swift](../favorecoAPP/favorecoAPP/Models/CoreModels.swift)。

- `RecordCategory`: ユーザー定義カテゴリ。テンプレも保存済みカテゴリとして扱う。初回起動時に `CategoryPresetSeeder` が標準カテゴリをfetch-first方式で注入/更新する。初回ジャンル選択後は `isArchived` で表示対象を制御し、少なくとも1件は有効になるよう補正する。ジャンルの表示順は `sortOrder`、テーマカラーは `colorHex`、有効ユニットは `enabledUnitsRaw` で管理する。自作ジャンル用に `templateTypeKey`、`targetNameLabel`、`recordUnitName`、`dateLabel` を持つ。
- `ExperienceEvent`: 対象（作品・公演・銘柄など）。Swift標準/API名との衝突を避けるため、実装名は `Event` ではなく `ExperienceEvent` とする。
- `Visit`: 体験した各回。会場・評価・座席・写真・金額など回ごとの値を持つ。
- `InboxItem`: 気になるもの・あとで記録するものの一時保存。
- `PhotoBlob`: 写真/動画バイナリ。`@Attribute(.externalStorage)` を使う。
- `SocialAccount`: プロフィール用SNSアカウント。Instagram / X / Threads / Facebookを複数登録でき、任意で `RecordCategory` に紐付ける。未紐付けは全体プロフィール扱い。

CloudKit互換のため、全モデルで「デフォルト値あり」「uniqueなし」「リレーションoptional」を守る。

## 4. 画面構成

初期実装は [HomeView.swift](../favorecoAPP/favorecoAPP/Views/HomeView.swift)。

- `ContentView`: 初回ジャンル選択が未完了なら `GenreOnboardingView`、完了済みなら `MainTabView` を表示する入口。
- `GenreOnboardingView`: 初回起動時に、記録したい標準ジャンルをチェック選択する画面。開始ボタンは1件以上選択時のみ有効。
- `MainTabView`: 下部4タブ（Home / 記録 / カレンダー / 統計）と中央の大きな `+` 記録開始ボタンを持つルート。中央 `+` はタブではなく、記録追加 / あとで記録のアクション入口。
- `HomeView`: Hero直下に横断ミニ統計（今後の予定 / 今年の記録 / 総記録数）を表示し、その下にアテンション、体験ギャラリー、あとで記録、最近の記録、ジャンル一覧、統計サマリ、お気に入り/ベストの固定順で表示する。各セクションは設定でON/OFF可能。カテゴリカードからカテゴリトップへ遷移し、右上プロフィールアイコンから設定へ遷移できる。
- `RecordsView`: 全ジャンル横断の記録一覧。保存済みVisitから詳細へ遷移する。
- `CalendarView`: カレンダータブのプレースホルダー。予定/申込/訪問済み記録の日付軸を置く想定。
- `StatsView`: 統計タブのプレースホルダー。ジャンル別回数、年間まとめ、支出、評価などを置く想定。
- `SettingsView`: 設定画面。マイ、表示、ジャンル、記録・入力補助、通知、データ管理、同期・バックアップ、課金・プラン、リンク・サポート、開発にセクション整理し、各詳細画面への入口を持つ。
- `DisplaySettingsView`: 表示設定。Home各セクションのON/OFFと、将来の文字サイズ/外観モード設定入口を持つ。
- `RecordInputAssistSettingsView`: 記録・入力補助設定。デフォルト記録日、デフォルトジャンル、記録追加後の動き、写真追加初期動作、写真圧縮、URL/OCR/Map/天気/入力補助辞書のON/OFFを持つ。Apple Music連携はV2以降で検討。
- `NotificationSettingsView`: 通知設定。通知全体、申込開始/締切、当落、入金、発券、公演前日/当日、FC・会員期限、思い出リマインダーの入口を持つ。
- `DataManagementView`: データ管理。保存データ件数、JSON/CSVインポート/エクスポート入口、バックアップ説明、キャッシュ削除/写真キャッシュ削除/全データ削除/アーカイブデータ削除の危険操作入口を持つ。
- `SyncBackupSettingsView`: 同期・バックアップ設定。iCloud同期、自動バックアップ、復元、同期トラブル診断の入口を持つ。JSON/CSVなどローカルへの手動書き出しバックアップは無料、iCloud同期/自動バックアップは有料寄りで扱う。
- `BillingPlanSettingsView`: 課金・プラン設定。現在のプラン、アップグレード、購入復元、Pro機能一覧、DBパック管理の入口を持つ。
- `SupportLinksView`: リンク・サポート。公式サイト、利用規約、プライバシーポリシー、お問い合わせ、レビュー、シェア、公式SNSの入口を持つ。
- `SettingsDocumentView`: 利用規約、プライバシーポリシー、お問い合わせ、インポート/エクスポート説明などの暫定本文表示に使う共通プレースホルダー。
- `ProfileSettingsView`: プロフィール設定。SNSアカウントを複数登録・編集でき、登録済みアカウントはタップで外部URLを開く。
- `EditSocialAccountView`: SNS追加/編集フォーム。SNS種別、メモ/名前、IDまたはURL、ジャンル紐付け、用途メモを保存する。
- `GenreManagementView`: ジャンル管理。ジャンル一覧の表示/非表示切り替え、並び替え、詳細設定への遷移、自作ジャンル追加を行う。最後の1ジャンルは非表示にできない。
- `AddCustomGenreView`: 自作ジャンル追加。表示名、SF Symbolアイコン、テーマカラー、テンプレタイプ（鑑賞系/訪問系/読書系/コレクション系/飲食系/自由）、対象名ラベル、記録単位、日付ラベル、有効ユニットを保存する。
- `GenreDetailSettingsView`: ジャンル詳細設定。表示名、SF Symbolアイコン、テーマカラー、テンプレタイプ、呼び名、紐付けSNS一覧、有効ユニット、表示/非表示を確認・編集する。
- `CategoryTopView`: カテゴリ単位の簡易トップ。対象数・記録数・対象一覧・最近の記録を表示。見出しのジャンル名は `映画 ▼` 形式のスイッチャーで、他の有効ジャンルへ切り替えられる。対象一覧から対象詳細へ遷移でき、同じ対象に回を追加できる。
- `AddInboxItemView`: 気になるもの・あとで記録したいものを、タイトル / URL / カテゴリ候補 / メモで `InboxItem` として保存する手動追加フォーム。
- `InboxDetailView`: InboxItemの詳細表示。カテゴリ候補を選び、InboxItemのタイトル / URL / メモを下書きにして本記録へ変換できる。変換済みのInboxItemは `resolved` にする。
- `AddExperienceView`: 最小記録追加フォーム。入力中は `AddExperienceDraft` に保持し、保存時だけ `ExperienceEvent` + `Visit` を作成する。カテゴリ別にフォーム文言を切り替え、公式URLも保存できる。将来の本入力UIでは、基本情報/写真/チケット/メモなどのユニット単位アコーディオンに移行する。
- `AddVisitView`: 既存 `ExperienceEvent` に新しい `Visit` だけを追加するフォーム。
- `EventDetailView`: 対象詳細。対象のカテゴリ、シリーズ、対象メモ、公式URL、記録数、最新日、平均評価、履歴を表示し、対象編集・回追加・各Visit詳細へ遷移できる。
- `EditEventView`: 対象自体のタイトル、シリーズ、公式URL、対象メモを編集するフォーム。
- `EditExperienceView`: 保存済み記録の最小編集フォーム。既存 `ExperienceEvent` + `Visit` を更新する。将来の本編集UIでは、ジャンルごとの長い入力項目に備えてユニット単位アコーディオンに移行する。
- `ExperienceDetailView`: 保存済みVisitの詳細表示。カテゴリ、対象名、シリーズ、日付、場所、評価、メモを表示し、編集へ遷移できる。

テンプレ別の専用入力ユニット、チケット/写真/Map/OCR、Inboxから既存対象/予定への変換、対象のアーカイブは未実装。

## 5. 重要な実装ルール
<!-- 壊すと怖い部分・触る前に必ず読むべき前提 -->
- タイポグラフィは `FavorecoTypography` を通して指定する。日本語UI本文は `Noto Sans JP`、思い出感のある見出しは `Noto Serif JP`、英字表示は `Cormorant Garamond` を使う。いずれもGoogle Fontsの可変TTFを `Resources/Fonts` に同梱し、`FontRegistrar` で起動時登録する。
- 記録追加/編集フォームのカテゴリ別文言は `CategoryRecordTemplate` を通す。フォーム内では入力中にSwiftDataを書かず、DraftState→Save→Modelを守る。
- 記録追加/編集フォームは、Mystorium同様にユニット単位のアコーディオンUIを基本方針とする。ジャンルによって入力項目が長くなるため、基本情報、写真/半券、チケット、リスト/OCR、場所/天気、金額、メモなどを折りたたみ可能なブロックとして表示し、必須/未入力/入力済み状態が見出しでわかるようにする。保存後は編集画面ではなく記録詳細画面へ戻る。
- 既存対象への再訪/再鑑賞/再飲は `AddVisitView` で `Visit` のみ追加し、`ExperienceEvent` を重複作成しない。
- 主要ナビは4タブ + 中央 `+` + 右上プロフィール入口。下部タブに設定は置かず、設定/マイ領域はプロフィールアイコンから開く。
- 設定画面は `マイ / 表示 / ジャンル / 記録・入力補助 / 通知 / データ管理 / 同期・バックアップ / 課金・プラン / リンク・サポート / 開発` のセクションで整理する。Home表示ON/OFFは `SettingsView` 直下ではなく `DisplaySettingsView` に置く。
- 記録・入力補助の初期値は、デフォルト記録日=今日、デフォルトジャンル=最後に使ったジャンル、記録追加後=詳細を開く、写真追加=カメラを開く、写真圧縮=85%、URL/OCR/Map/天気/入力補助辞書=ONとする。現時点では設定保存までで、各入力画面への実接続は段階的に行う。
- 同期・バックアップの課金境界は、JSON/CSVなどMystorium同様のローカル手動書き出しバックアップを無料、iCloud同期/自動バックアップを有料寄りとする。手動バックアップはユーザーが端末外へ退避できる最低限の安全網として無料を守る。
- データ管理には削除系を置く。対象はキャッシュ削除、写真キャッシュ削除、アーカイブデータ削除、全データ削除。全データ削除など不可逆操作は通常導線から一段深く置き、確認文言入力/二段階確認などの誤操作防止を必須にする。
- Homeのセクション順は固定で、並び替えは実装しない。表示ON/OFFは `AppStorageKeys.showsHome...` で管理する。初期ONはアテンション、体験ギャラリー、あとで記録、最近の記録、ジャンル一覧。初期OFFは統計サマリ、お気に入り/ベスト。
- Home横断ミニ統計は常設表示とし、設定ON/OFF対象にはしない。現時点の「今後の予定」は未来日Visit数、「今年の記録」は今年のVisit数、「総記録数」は全Visit数。Planモデル追加後は「今後の予定」をPlan/TicketAttempt中心へ切り替える。
- Homeのアテンション枠はファーストビュー想定。現状は未来日Visitと未整理Inboxを表示し、将来は申込開始/締切/当落/入金/発券/会員期限/通知リマインダーを同じ枠に集約する。
- Homeの体験ギャラリーはテンションを上げる枠。現状は最近のVisitを横スクロールカードで表示し、将来は写真付き記録、これから参加する予定、年間ベスト候補を混ぜる。
- SNSアカウント入力はID/URLどちらも許容する。外部遷移時は `SocialPlatform` でURLに解決する。ジャンル別SNSは `SocialAccount.category` にoptionalで紐付け、未指定は全体プロフィールとする。
- 初回ジャンル選択とカテゴリseedでは、表示ジャンルが0件にならないよう `CategoryPresetSeeder.ensureAtLeastOneActiveCategory` を必ず通す。すべて非表示になった場合は先頭の標準カテゴリを復帰させる。
- ジャンル管理の非表示は削除ではなく `RecordCategory.isArchived` の切り替えとする。記録済みデータは残し、Home/追加導線/ジャンル切替の入口から外す。最後の1ジャンルはUI上で非表示にできない。
- ジャンルのテーマカラーは `RecordCategory.colorHex` を正本とする。標準ジャンルにも、自作ジャンル追加時にも同じフィールドを使う。
- 自作ジャンルの `templateKey` は `custom_<UUID>` とし、標準プリセットとは衝突させない。作成時は `isBuiltIn = false`、`isArchived = false`。
- 自作ジャンルの記録フォーム文言は `CategoryRecordTemplate` が `targetNameLabel`、`recordUnitName`、`dateLabel` から生成する。標準ジャンルは従来どおり `templateKey` 別の固定文言を優先する。
- ジャンルの有効ユニットは `RecordCategory.enabledUnitsRaw` を正本とし、`RecordUnitDefinition` で表示名/説明に変換する。U1基本情報とU3メモは必須で、詳細画面/自作ジャンル作成画面では外せない。
- デバッグ用の仮データ投入は `DebugDataSeeder` に閉じ込める。写真は `PhotoBlob` に1px PNGデータを入れ、通常の `ExperienceEvent` / `Visit` と同じSwiftData経路で保存する。
- 通知、同期・バックアップ、課金・プラン、JSON/CSVインポート/エクスポート、規約/プライバシー/問い合わせ本文は現時点では入口のみ。実データを変更する処理はまだ接続しない。
- Mystoriumで実証済みの設計原則・SwiftData/SwiftUIの罠は `docs/04-Mystorium構造リファレンス.md` §3設計原則・§6罠 を必ず読んでから触る
- **Mystorium再発防止の性能・構造ルールを最初から守る**（詳細: `docs/14-実装アーキテクチャ・性能ルール.md`）。最重要4原則は **①入力中にDBを書かない ②一覧で原寸画像を使わない ③bodyで全件処理しない ④巨大Viewを作らない**。全登録/編集画面はDraftState→Save→Model、Home/GenreTop/Calendar/Statsは軽量Snapshot/DTO経由、画像はthumbnail/detail/originalの3段階、I/O/画像処理/import/export/migrationはMainActor禁止＋background＋batch save。
- **ライフサイクル状態・予定・申込・記録を混ぜない**。クイック登録は `InboxItem`、対象は `Event`、予定/公演回は `Plan`/`Performance`、申込1件は `TicketAttempt`、実体験は `Visit`、記録下書きは `MemoryDraft`/`VisitDraft` として責務分離する。`Visit` にチケット状態を直持ちしない。複数先行・落選履歴・名義別当選率・通知更新のため `TicketAttempt` を独立モデルにする。
- **Apple Kit依存は境界で閉じ込める**。SwiftUI/SwiftData/CloudKit/MapKit/WeatherKit/EventKit/Vision/StoreKit はiOS実装で使ってよいが、ドメインモデル・状態遷移・Smart Add解析結果・同期DTO・写真/OCR/カレンダー/通知/課金の抽象インターフェースはApple APIへ直結させない。将来Androidを完全に捨てないため、UI/OS連携以外の移植可能性を保つ。
- **スキーマはCloudKit互換3条件で設計する**（①全プロパティにデフォルト値 ②unique禁止・fetch-first upsertで代替 ③リレーション全optional）。同期公開はv2だが構造はv1から `docs/07-CloudKit同期設計リファレンス.md` に従う。違反すると同期導入時にスキーマ再設計になる
- **写真はPhotoBlob（externalStorage）方式**（`docs/09-CloudKit写真ストレージ仕様.md` が正本）。画面はrelativePath文字列だけ扱う・動画は `video_` プレフィックスでファイル保存・zipバックアップは `_SUPPORT` 同梱＋再起動必須・static ユーティリティは `nonisolated` 明示（Swift 6）
- 端末内のデータは絶対に消えない設計を守る（同期・バックアップのどの失敗ケースでも壊れる方向に倒さない）
- **サブ種別レイヤーの下地を最初から通す**（酒の種別=日本酒/ビール/ウィスキー…）。〈カテゴリ→サブ種別→軸/スペック/OCR辞書〉の2階層マスターで、種別ごとにプリセットが切り替わる仕組みをv1で実装（中身は日本酒のみ）。後付けすると既存記録の移行が発生し重いリファクタになる（Mystorium enum変更クラッシュの教訓）。詳細: docs/08 §4-6★★

## 6. ディレクトリ構成

```text
/Users/doublefake/Documents/favoreco
├─ AGENTS.md                         # 横断運用ルール
├─ CLAUDE.md                         # ルート運用メモ
├─ docs/                             # 仕様・ログ・設計資料
├─ favoreco/CLAUDE.md                # このアプリの実装仕様正本
└─ favorecoAPP/                      # Xcodeプロジェクト本体
   ├─ favorecoAPP.xcodeproj
   └─ favorecoAPP/
      ├─ Assets.xcassets
      ├─ ContentView.swift
      ├─ favorecoAPPApp.swift
      ├─ Models/CoreModels.swift
      ├─ Services/DebugDataSeeder.swift
      ├─ Services/CategoryPresetSeeder.swift
      ├─ Resources/Fonts/
      ├─ Utilities/AppStorageKeys.swift
      ├─ Utilities/CategoryRecordTemplate.swift
      ├─ Utilities/Color+Hex.swift
      ├─ Utilities/FavorecoTypography.swift
      ├─ Utilities/FontRegistrar.swift
      ├─ Utilities/RecordUnitDefinition.swift
      ├─ Utilities/SocialPlatform.swift
      └─ Views/
         ├─ AddExperienceView.swift
         ├─ AddInboxItemView.swift
         ├─ CategoryTopView.swift
         ├─ EventDetailView.swift
         ├─ ExperienceDetailView.swift
         ├─ GenreManagementView.swift
         ├─ GenreOnboardingView.swift
         ├─ InboxDetailView.swift
         ├─ MainTabView.swift
         ├─ ProfileSettingsView.swift
         ├─ SettingsView.swift
         └─ HomeView.swift
```

`favorecoAPP` はXcode作成時の一時的なプロジェクト/ターゲット名。Bundle Identifier と product name は `com.nori.favoreco` / `favoreco` に整える。

## 7. 確定済みのプロダクト方針（実装前）

- テンプレート第1弾: 観劇 / 美術展 / ライブ参戦 / 映画（劇場体験） / 酒 / **おでかけ施設**（テーマパーク・水族館・動物園を施設種別サブレイヤーで統合・08 §4-7） / 御朱印（軽量・印種別サブレイヤー=御朱印/御城印/御船印・08 §4-8） / 書籍（DBなし私的記録・ISBN=openBD入力補助＋奥付OCR・シリーズ/巻のadd-next/スタック表示・08 §4-11）
- 全カテゴリ標準のアイキャッチ（縦横比はカテゴリ別設定・テンプレにプリセット付属）。**回ごとに個別・リピートは前回引き継ぎ＋対象の代表**（spec-A1 §5）
- 全テンプレ共通の横断フィールド: 半券・印・カード・スタンプの写真＋メモ
- **チケット/ライブ管理（観劇・ライブ）＝v1で徹底作り込み**（2026-07-07確定・spec-A8が正本）: 状態pipeline（気になる→申込前→当落待ち→当選/落選→入金待ち→発券待ち→参戦済）＋**通知/リマインダー全タイプ**（申込開始/申込締切/当落発表/入金締切/発券開始/公演前日/カウントダウン・オフセット可）＋**FC/チケットアカウント/名義管理**（FC/プレイガイド/劇場会員/カード枠、URL/ログインID/会員番号/有効期限アラート/年会費/掛け持ち色分け。**「マイ/設定>登録情報・連携」ハブで一元管理＝1回登録・全TicketAttemptから参照／外部カレンダー連携(EventKit・Apple/Google読み取り)も同居**）＋チケットOCRスキャン取込＋座席テキスト＋セトリ（並び替え可・画像OCR取込）＋当選率/名義別/座席傾向の分析。基準はチケコレ（更新停止）でなく **LiveSoul/TheaterRecords/Cherie Log**。favorecoの勝ち筋＝横断＋登録の楽さ（競合の最大不満「全手動入力が面倒」をOCR/URL取込で潰す）。3D座席はデータ制約でv2。パスワードはSwiftData/CloudKitへ保存せず、必要な場合のみKeychain＋Face ID/Touch ID/端末パスコードで表示/コピー。
- **U4「リスト」ユニットの📷画像OCR取込（汎用・spec-A3 §5-2）**：写真→撮影補正→Vision OCR→順序化→編集。呼び名は種別で切替（ライブ=セトリ／観劇=演目／**美術展・博物展=出品目録・作品リスト**／おでかけ=見たもの）。外部ライブラリゼロ（Vision）。
- **天気アイコン自動付与**（出かける系＝観劇/美術展/ライブ/おでかけ施設。訪問日経過後にWeatherKit履歴天気→日付横にSF Symbols。2021/8〜・08 §4-9）
- **場所参照DB**（御朱印/城/船/施設）は**同梱せずテンプレONでCloudKit公開DBからDL**（純ローカルの明示的例外）。**記録は参照DBに依存せずスナップショット保存**（DBやスポットが消えても記録は無傷）。記録機能自体は無料（Apple Maps POIで全スポット可）・08 §4-10
- 課金3層: 無料 / 買い切り（記録・自作カテゴリ・統計・年間まとめ・エクスポート） / サブスク（CloudKit同期・自動バックアップ・思い出再提示(opt-in)・月次リキャップ・限定デザイン・**参照DBアクセス＋更新**）＋**カテゴリDBパック単体販売(B)**（御朱印/100名城/御船印…将来は御酒印/ダムカード/マンホールカード等）。課金するのはDBの便利さのみ・記録は無料を死守
- デザイン: Mystorium（金/Cinzel）とは別人格。シンプル・洗練・写真が主役。**アプリ全体リキッドグラス基調・白ベース**。ただし**各ジャンルのライブラリはカテゴリ色の"色世界"をまとえる**（映画=ダーク基調のガラス／観劇=ワインレッド＋ゴールド／酒=琥珀…）＝共通素材Liquid Glass＋ジャンル別トーン（spec-B1 §0）
