# favoreco 実現性メモ

> 作成日: 2026-07-04
> 最終更新: 2026-07-04
> 参照: docs/新規アプリ立ち上げ.md §2 フェーズ4 / docs/03-Mystoriumからの技術移行メモ.md / docs/04-Mystorium構造リファレンス.md

---

## 1. 主要エンティティ（素描）

| エンティティ | 持つ情報 | 主な関係 |
|------------|---------|---------|
| **RecordCategory** ★新規 | 名前・アイコン（SF Symbol）・カラー・並び順・テンプレート由来フラグ | 各マスターとEventの親。**Mystoriumの固定enumをこのモデルに置き換えるのが本質的な仕事** |
| Event（体験） | タイトル・カテゴリ参照・会場スナップショット・ステータス（日付から自動推測） | RecordCategory / Venue(nullify) / Visit(cascade) |
| Visit（回） | 日時・写真パス[String]・感想・成果・座席等のテンプレ別項目・タグ/同行者[String] | Event / AxisScore(cascade) |
| Venue / Organizer | 場所・主催のマスター（削除時nullify＋スナップショット表示） | Event |
| マスター群 | AxisDefinition（評価軸）/ OutcomeOption（成果）/ FormatMaster（形態）/ Tag / Companion | 親を enum → RecordCategory 参照に差し替えて流用 |
| **横断コレクション項目** ★新規 | 半券・印・カード・スタンプの写真＋メモ（Visit配下 or 独立） | Visit（設計は②-Aで確定） |

## 2. データ保存方針

- **ローカルファースト**（SwiftData正本・サーバーなし・運営コストゼロ）。Mystorium踏襲
- 写真はファイルパス正本（`PhotoStorage` 流用・DBにblobを持たない）
- v1はローカルのみ＋zipバックアップ（`DataExporter` 流用）。**CloudKit同期はv2のサブスク機能**（Mystorium Phase 2の実装を先行例にする）
- スキーマバージョニングはMystoriumのVersionedSchema＋lightweight migration運用をV1から採用

## 3. 技術的な山場

1. **カテゴリのデータ駆動化**: EventCategory（固定enum）→ RecordCategory（SwiftDataモデル）。カテゴリ別マスター4系統（形態・評価軸・成果・ticker設定）の親付け替え
2. テンプレートのプリセット注入（6種×評価軸・成果・形態のデフォルト一括生成。`SampleDataSeeder`/version-gated reconciliation が参考）
3. カテゴリ横断統計（「今年の全体験」ビュー。Mystoriumはカテゴリ内統計のみ）
4. 買い切りIAP（StoreKit 2。Mystorium Phase 2 実装を先行例に）

## 4. 技術スタック（選定理由）

- SwiftUI / SwiftData / MapKit / ImageIO / UserNotifications・外部ライブラリゼロ（Mystorium準拠）
- 既存資産に寄せた点: 画像パイプライン・シェアカード・統計・検索・カレンダー・エクスポート・マイグレーション運用をそのまま流用（docs/04 §5）
- 新規に増やす技術: なし（山場はすべて既存スタック内の設計問題）

## 5. コード共有方式（要決定）

- 推奨（03の現実解）: **まずフォークでPoC → コンセプト検証後に共有コア（Swift Package）切り出しを判断**
- 理由: 共有コアの設計を最初にやると初速が落ちる。RecordCategory化という構造変更を試す段階では、Mystoriumのコードを自由に壊せるフォークが速い

## 6. 致命リスク（1つ）と検証方法

- **リスク**: RecordCategory化（enum→モデル参照）が、SwiftDataのリレーション・マイグレーション・既存UIパターン（ホームのカテゴリタブ・カテゴリ別マスター管理）と噛み合わない場合、Mystorium資産の流用前提が崩れ企画の工数見積りが崩壊する
- **検証方法（実装の最初のステップ＝PoC）**:
  1. RecordCategory＋Event＋マスター1系統（評価軸）だけの最小スキーマを組む
  2. テンプレ6種のプリセット注入 → ホームのカテゴリタブが動的に生える → 自作カテゴリの追加/リネーム/削除（nullify・記録は消さない）が破綻しないことを確認
  3. カテゴリ削除時の既存記録の扱い（「未分類」へ退避 等）をこの段階で設計確定
- **判定**: PoCで上記が素直に組めれば企画続行。組めなければ共有方式・スキーマ設計を再検討
