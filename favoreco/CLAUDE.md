# favoreco 実装仕様（正本）

> **役割**: このアプリの「現在どうなっているか」の正本。横断ルールは ルート `CLAUDE.md` を参照。
> **最終更新**: 2026-07-09（対象編集画面実装）

---

## 1. コンセプト

**観た・行った・体験したを、美しく一生残す。**（詳細: `docs/favoreco-concept.md`＝確定）

- コア体験: 記録が、美しい思い出になる
- 人間観: 人は雑食、ただし個人ごとに「柱」が2〜3本ある

## 2. 技術スタック

SwiftUI / SwiftData / MapKit / ImageIO / UserNotifications（Mystorium準拠・外部ライブラリゼロ方針。`docs/04-Mystorium構造リファレンス.md` 参照）

## 3. データモデル（正本）

実装開始済み。正本仕様は `docs/spec-A1-データモデル基盤.md`。初期実装は [CoreModels.swift](../favorecoAPP/favorecoAPP/Models/CoreModels.swift)。

- `RecordCategory`: ユーザー定義カテゴリ。テンプレも保存済みカテゴリとして扱う。初回起動時に `CategoryPresetSeeder` が標準カテゴリをfetch-first方式で注入/更新する。
- `ExperienceEvent`: 対象（作品・公演・銘柄など）。Swift標準/API名との衝突を避けるため、実装名は `Event` ではなく `ExperienceEvent` とする。
- `Visit`: 体験した各回。会場・評価・座席・写真・金額など回ごとの値を持つ。
- `InboxItem`: 気になるもの・あとで記録するものの一時保存。
- `PhotoBlob`: 写真/動画バイナリ。`@Attribute(.externalStorage)` を使う。

CloudKit互換のため、全モデルで「デフォルト値あり」「uniqueなし」「リレーションoptional」を守る。

## 4. 画面構成

初期実装は [HomeView.swift](../favorecoAPP/favorecoAPP/Views/HomeView.swift)。

- `ContentView`: `HomeView` への入口。
- `HomeView`: カテゴリ、最近の記録、Inboxの3セクションを表示。カテゴリカードからカテゴリトップへ遷移。
- `CategoryTopView`: カテゴリ単位の簡易トップ。対象数・記録数・対象一覧・最近の記録を表示。対象一覧から対象詳細へ遷移でき、同じ対象に回を追加できる。
- `AddExperienceView`: 最小記録追加フォーム。入力中は `AddExperienceDraft` に保持し、保存時だけ `ExperienceEvent` + `Visit` を作成する。カテゴリ別にフォーム文言を切り替える。
- `AddVisitView`: 既存 `ExperienceEvent` に新しい `Visit` だけを追加するフォーム。
- `EventDetailView`: 対象詳細。対象のカテゴリ、シリーズ、対象メモ、公式URL、記録数、最新日、平均評価、履歴を表示し、対象編集・回追加・各Visit詳細へ遷移できる。
- `EditEventView`: 対象自体のタイトル、シリーズ、公式URL、対象メモを編集するフォーム。
- `EditExperienceView`: 保存済み記録の最小編集フォーム。既存 `ExperienceEvent` + `Visit` を更新する。
- `ExperienceDetailView`: 保存済みVisitの詳細表示。カテゴリ、対象名、シリーズ、日付、場所、評価、メモを表示し、編集へ遷移できる。

テンプレ別の専用入力ユニット、チケット/写真/Map/OCR、対象のアーカイブは未実装。

## 5. 重要な実装ルール
<!-- 壊すと怖い部分・触る前に必ず読むべき前提 -->
- タイポグラフィは `FavorecoTypography` を通して指定する。日本語UI本文は `Noto Sans JP`、思い出感のある見出しは `Noto Serif JP`、英字表示は `Cormorant Garamond` を使う。いずれもGoogle Fontsの可変TTFを `Resources/Fonts` に同梱し、`FontRegistrar` で起動時登録する。
- 記録追加/編集フォームのカテゴリ別文言は `CategoryRecordTemplate` を通す。フォーム内では入力中にSwiftDataを書かず、DraftState→Save→Modelを守る。
- 既存対象への再訪/再鑑賞/再飲は `AddVisitView` で `Visit` のみ追加し、`ExperienceEvent` を重複作成しない。
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
      ├─ Services/CategoryPresetSeeder.swift
      ├─ Resources/Fonts/
      ├─ Utilities/CategoryRecordTemplate.swift
      ├─ Utilities/Color+Hex.swift
      ├─ Utilities/FavorecoTypography.swift
      ├─ Utilities/FontRegistrar.swift
      └─ Views/
         ├─ AddExperienceView.swift
         ├─ CategoryTopView.swift
         ├─ EventDetailView.swift
         ├─ ExperienceDetailView.swift
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
