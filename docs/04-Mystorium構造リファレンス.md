# Mystorium 構造リファレンス（favoreco ベース参照用）

> 2026-07-04 作成。favoreco（汎用「好き」記録アプリ）が Mystorium の構造をベースにするための技術まとめ。
> 正本は immersiveApp リポジトリ：`Mystorium/CLAUDE.md`（機能仕様）/ `Mystorium/ENTITIES.md`（モデル）/ `Mystorium/DESIGN.md`（ビジュアル）

---

## 1. 技術スタック・規模

- **SwiftUI / SwiftData / MapKit / ImageIO / EventKit / UserNotifications**（外部ライブラリゼロ）
- 約35Kライン・103 Swift ファイル・単一ターゲット＋テスト
- ローカルファースト（SwiftData 正本・サーバーなし・運営コストゼロ）
- Xcode プロジェクトは FileSystemSynchronized グループ（ファイル追加は置くだけで認識）

## 2. ディレクトリマップ（主要ファイル）

```
Mystorium/
├── MystoriumApp.swift          # @main・ModelContainer 起動（フォールバック containers 付き）
├── ContentView.swift           # 4タブ+FAB のルート・起動時バックフィル・デフォルトマスター注入
├── PhotoHelpers.swift          # ImageIO 圧縮（compressNormalized）・保存ペイロード・共通アラート
├── Models/
│   ├── MystoriumSchema.swift   # ★全スキーマ V1〜V8 と MigrationPlan・typealias（2400行）
│   ├── Event.swift / Visit.swift / Venue.swift  # extension（computed・表示ヘルパー）
│   ├── DataExporter.swift      # zip エクスポート/インポート（ストア+images+設定）
│   ├── StorageCleanup.swift    # オーファン画像の検出・削除
│   ├── StatusBackfill.swift    # 起動時バックフィル（UserDefaults 完了フラグ式）
│   └── TicketSaleNotificationManager.swift  # opt-in ローカル通知
├── Views/
│   ├── HomeView.swift          # カテゴリタブ（TabView .page）+ CategoryHomeTab（1800行）
│   ├── HomeSectionHelpers.swift # HomeCategoryMetrics（集計）・HomeEventGridView（1/2/3列）
│   ├── EventCardView.swift     # タイル（閲覧UI・折りたたみ/展開・評価するバッジ）
│   ├── EventAddView.swift / EventDetailView.swift  # 追加/編集フォーム（draft+snapshot）
│   ├── EventReadOnlyDetailView.swift  # 詳細（閲覧専用・編集への入口）
│   ├── QuickEvaluateSheet.swift # 評価だけの小シート（成果+RESONANCE+評価軸）
│   ├── VisitEvaluationEditorSections.swift  # ★ResonanceEditorRow / EvaluationAxesSection（Binding駆動・再利用可）
│   ├── GalleryView.swift       # 全画面ギャラリー（masonry・横向き対応）
│   ├── CalendarView.swift      # 月/週/日・チケット販売期間の日展開・日跨ぎ対応
│   ├── HomeSearchOverlayView.swift  # 多フィールドAND検索+フィルタ
│   ├── EventShareCardView.swift # シェアカード（ImageRenderer）
│   ├── AsyncImageDataView.swift # ★ダウンサンプルデコード+NSCache（サイズ別上限）
│   ├── Stats/                  # 統計15ファイル（StatsViewModel + セクション群）
│   └── Settings/               # マスター管理（Organizer/Venue/Category/Outcome/Axis/Tag/Companion）
└── docs/project-log.md         # 変更履歴・意思決定ログ（1万行超）
```

## 3. データモデル（9モデル）

```
Organizer ──nullify──▶ Event ──cascade──▶ Visit ──cascade──▶ AxisScore ◀──nullify── AxisDefinition
Venue ────nullify──▶ Event
Tag / Companion（マスター・Visit とは [String] の正規化比較で紐付く＝リレーションなし）
OutcomeOption（カテゴリ別の成果マスター・Visit.outcome には displayName 文字列を保存）
```

### 設計原則（favoreco でも踏襲価値が高い）
1. **「AxisScore が存在する＝入力済み／存在しない＝未入力」**。score 0 は使わずレコードごと削除。「未評価の抽出」が特別なフラグなしで成立する
2. **削除で消さない**：マスター（Organizer/Venue）削除時は nullify。Event には `venueName/venueAddress` のスナップショットを持ち、参照が切れても表示が壊れない
3. **safeVenue パターン**：`venue?.modelContext != nil` を確認してから返す。SwiftData の dangling reference はアクセスするだけでクラッシュするため必須
4. **タグ・同行者は文字列保持＋マスター upsert**：Visit 側は [String]、マスターは候補管理。リネームは両方を一括更新（正規化比較：空白・#・大文字小文字を吸収）
5. **status は保存せず推測**：最新 Visit の日時から interested/planned/attended を computed で判定（statusRaw は保存整合用）
6. **写真はファイルパス正本**：`Visit.photoPaths: [String]`（PhotoStorage 相対パス）。DB に blob を持たない（レガシー `eyecatchImageData` の inline blob はフォールバックのみ）

### スキーマバージョニング運用
- `MystoriumSchemaV1`〜`V8` を**全モデル丸ごと複製**して enum で保持、`MystoriumMigrationPlan` に `.lightweight` ステージを積む。typealias（`typealias Event = MystoriumSchemaV8.Event`）でアプリコードはバージョン非依存
- フィールド追加は「V(n) を複製 → optional フィールド追加 → ステージ追加 → typealias 付け替え → App の `Schema(versionedSchema:)` 更新」の定型作業
- V8 現在：`Visit.endDate`（日跨ぎ）・`Event.ticketSaleNotifyEnabled`（通知opt-in）まで

### 汎用化の核心（favoreco の本質的な差分）
- `EventCategory` は**固定 enum**（謎解き/Immersive/その他/マダミス/ミステリー/ARG）。これを SwiftData の **`RecordCategory` モデル（ユーザー定義データ）に置き換える**のが favoreco の実質的な仕事
- カテゴリ別マスター（開催形態 FormatMaster / 評価軸 AxisDefinition / 成果 OutcomeOption / Home ticker 設定）は既に「カテゴリをキーに引く」構造なので、キーを enum→モデル参照に差し替えれば流用できる
- 過去の教訓：**enum の rawValue 変更はデコード不能クラッシュを起こした**（旧 rawValue "Other"/"Mystery" 問題）。データ駆動カテゴリにすればこのクラス全体の問題が消える

## 4. 画面アーキテクチャ・UIパターン

- **4タブ＋中央FAB**（ホーム/統計/カレンダー/設定）。タブは遅延生成・opacity 切替（再生成しない）
- **タイル＝閲覧の統一UI**：タップで展開（閲覧専用）→「編集」で別画面（EventDetailView）。閲覧と編集を分離
- **編集は draft + snapshot 方式**：フォームは @State draft に読み込み→保存時に model へ適用（`applyCurrentVisitDraft`）→キャンセル時は `EventEditSnapshot/VisitSnapshot` から復元。dirty 判定も snapshot 比較
- **ナビゲーション**：詳細は fullScreenCover（またはオーバーレイ）・編集/評価は sheet・マスター管理は NavigationStack push
- **状態自動推測**：追加/編集で状態を手動選択させない。日付から自動判定（UX 原則）
- **ホームの集計**：`HomeCategoryMetrics` に集約し body 先頭で1回だけ評価（`let m = homeMetrics`）。@State キャッシュにしないのは SwiftData の observation tracking を維持するため
- **統計**：`@Observable` StatsViewModel＋「同一 runloop tick 内キャッシュ」（入力の didSet で即破棄・tick 終了で必ず破棄）

## 5. そのまま流用できる資産（実績あり）

| 資産 | ファイル | 概要 |
|---|---|---|
| 画像圧縮 | `PhotoHelpers.compressNormalized` | ImageIO 一体処理（フルデコード回避・EXIF焼き込み・長辺1080px） |
| 画像表示 | `Views/AsyncImageDataView.swift` | CGImageSource ダウンサンプル＋NSCache（60/120MB）＋表示サイズ別デコード上限 |
| 写真保存 | PhotoStorage（相対パス正本） | `images/{eventID}/visits/{visitID}/` 構造・動画サムネも同居 |
| シェアカード | `Views/EventShareCardView.swift` | ImageRenderer・RESONANCE/シンプル/統計ランキングの3種 → バイラル装置の土台 |
| 評価UI | `Views/VisitEvaluationEditorSections.swift` | ResonanceEditorRow / EvaluationAxesSection（plain Binding・どこでもホスト可能） |
| クイック評価 | `Views/QuickEvaluateSheet.swift` | 評価だけの小シート（未評価バッジ→2タップ記録） |
| 統計画面 | `Views/Stats/` | Letterboxd 風（月次バー・BEST・成果内訳・レーダー・タグ頻度・シェア） |
| 検索 | `Views/HomeSearchOverlayView.swift` | 多フィールド AND＋フィルタ＋検索コーパスキャッシュ |
| 通知 | `Models/TicketSaleNotificationManager.swift` | opt-in ローカル通知の型（権限リクエスト→理由別 ScheduleResult） |
| バックアップ | `Models/DataExporter.swift` | zip（ストア+images+UserDefaults 設定 manifest）・インポートは全上書き+強制再起動 |
| クリーンアップ | `Models/StorageCleanup.swift` + `Event.deleteWithAssets` | オーファン画像検出・削除（save 失敗時 rollback で部分永続化を防ぐ） |

## 6. SwiftData / SwiftUI の罠（このプロジェクトで実際に踏んだもの）

1. **dangling reference**：削除済みモデルへの optional chaining だけでクラッシュ → `modelContext != nil` ガード（safeVenue/safeOrganizer）
2. **inline Data blob**：`eyecatchImageData` に触るだけで blob がメモリロードされる → 指紋計算・一覧では絶対に触らない。新規データは必ずファイルパスに
3. **enum rawValue の変更**：既存ストアのデコード不能クラッシュ。composite attribute は特に注意
4. **Form(=List) の遅延行生成**：画面外の行は生成されておらず `ScrollViewReader.scrollTo` が届かない → 長いフォーム内の特定セクションへ誘導したい場合は専用シートに分離する方が確実
5. **@Observable＋値スナップショットキャッシュ**：時間による破棄だけだと「初回描画（空）でキャッシュ→同 tick 内で入力代入→空キャッシュを読む」が起きる → **入力の didSet 破棄を必ず併設**
6. **@Query の onChange**：インプレース編集では発火しない（配列要素の参照が同じ）→ 編集反映は observation tracking（body 内で model プロパティを読む）に任せる設計にする
7. **バックフィルのフラグ**：UserDefaults 完了フラグ式にする場合、**インポート（別ストア持ち込み）でフラグをリセット**しないと新ストアが未処理のまま残る

## 7. 開発運用（グローバル CLAUDE.md の要点）

- 実装仕様の正本＝プロジェクトの CLAUDE.md（+ENTITIES/DESIGN）、意思決定ログ＝docs/project-log.md（同一作業内で追記）
- 作る前に完成条件を合意 → 実装と検証を分離 → 3ファイル以上は影響範囲提示・5ファイル以上は分割
- NG時は「原因を特定→報告→修正→同種問題の横展開→再発防止の記録」の順
