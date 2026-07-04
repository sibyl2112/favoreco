# Mystorium からの技術移行メモ

> 2026-07-04 時点。派生汎用アプリの技術設計の出発点。
> Mystorium 本体: https://github.com/sibyl2112/immersiveApp （SwiftUI / SwiftData / MapKit・スキーマV8）

---

## 核心：「新アプリを作る」のではなく「カテゴリーを enum からデータへ一般化する」

Mystorium は既に**カテゴリー別マスター管理が完全に稼働している**：

| 仕組み | Mystorium での実装 | 汎用化での扱い |
|---|---|---|
| 成果選択肢 | `OutcomeOption`（カテゴリ別・ResultType 3値・ユーザー追加可） | そのまま流用可 |
| 開催形態 | FormatMaster（カテゴリ別マスター管理） | そのまま流用可 |
| 評価軸（レーダー） | `AxisDefinition` / `AxisScore`（カテゴリ別・存在=入力済み設計） | そのまま流用可 |
| タグ / 同行者 | 正規化マスター＋文字列保持 | そのまま流用可 |
| ステータス | interested / planned / attended（日付から自動推測） | そのまま流用可 |

**唯一の本質的な差**：`EventCategory` が固定 enum（謎解き/Immersive/その他/マダミス/ミステリー/ARG）である点。
派生アプリはこれを **ユーザー定義の `Category` モデル（SwiftData）** に置き換える。

```
現在:  enum EventCategory: String, Codable  ← コンパイル時固定
派生:  @Model class RecordCategory {
          var name: String        // 「美術館」「観劇」...
          var icon: String        // SF Symbol
          var colorHex: String
          var sortOrder: Int
          var isTemplate: Bool    // 既製テンプレート由来か
          // 開催形態・評価軸・成果は既存のカテゴリ別マスターの親を
          // enum 値からこのモデルへの参照に差し替える
       }
```

## テンプレート主導 ＋ 自作カテゴリーの両輪（確定方針）

- 既製テンプレート（美術館・観劇・ライブ・食べ歩き・映画等）＝ RecordCategory ＋評価軸＋成果＋形態のプリセット一括生成
- ユーザー自作カテゴリーも**同等の主役**（初心者にも上級者にも開かれた設計）
- Mystorium の `SampleDataSeeder` / デフォルトマスター生成（`ContentView` の version-gated reconciliation）がプリセット注入の実装参考になる

## コード共有方式（要決定・現時点の推奨は共有コア）

| 方式 | 初速 | 長期維持 | 備考 |
|---|---|---|---|
| **共有コア（Swift Package 化）** | △ 設計コスト | ◎ 修正1回で両アプリへ | モデル層・画像パイプライン・シェアカード基盤を Package に。2アプリは薄い皮 |
| フォーク（複製） | ◎ | ✗ 修正二重化の負債 | まず動くものを見たい場合のみ |

- 現実解：**まずフォークで PoC → コンセプト確定後に共有コアへ切り出す**、も可（PoC を捨てる覚悟があるなら）

## Mystorium から流用できる資産（実装済み・実績あり）

- **画像パイプライン**: ImageIO 圧縮（`PhotoHelpers.compressNormalized`・長辺1080px）・`PhotoStorage`（ファイルパス正本）・`AsyncImageDataView`（ダウンサンプル＋NSCache＋サイズ別デコード）
- **シェアカード**: `EventShareCardView` + ImageRenderer（RESONANCE/シンプル/ランキング）→ 汎用アプリのバイラル装置の土台
- **統計画面**: Letterboxd 風の構成（月次バー・BEST・成果内訳・レーダー・タグ頻度）＋ tick 内キャッシュの StatsViewModel
- **カレンダー**: 月/週/日・チケット販売期間の日展開・日跨ぎ対応（V8）
- **検索**: 多フィールド AND 検索＋フィルタ＋検索コーパスキャッシュ
- **通知**: `TicketSaleNotificationManager`（opt-in ローカル通知の型）
- **マイグレーション運用**: V1→V8 の lightweight migration 前例・バックフィルのフラグ管理・インポート時フラグリセット

## 汎用化で新規に必要なもの

1. RecordCategory モデルと、カテゴリ別マスター（形態・評価軸・成果）の親付け替え
2. テンプレートのプリセット定義（最初は5〜7種に絞る）
3. Mystorium と別人格のデザイン言語（金/Cinzel は Mystorium の顔として残す）
4. カテゴリ横断の統計（「今年の全体験」ビュー）— 推し活のジャンル横断ニーズに対応
5. （課金するなら）StoreKit 2 — Mystorium Phase 2 の実装を先行例にする

## 決めごとリスト（着手前）

- [ ] アプリ名・Bundle ID・デザイン言語
- [ ] 共有コア or フォーク
- [ ] MVP テンプレート数とカテゴリ横断統計の初期スコープ
- [ ] 価格（買い切り主役は確定・具体額未定）
- [ ] CloudKit 同期を初期から入れるか（Mystorium は Phase 2 で後入れ予定）
