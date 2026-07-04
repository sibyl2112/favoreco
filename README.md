# app-starter-kit

新規アプリを Claude と一緒に立ち上げるための**スターターキット**。
運用ルール・開発プロセス・各種テンプレートをまとめてある。

このリポジトリを GitHub の **Template repository** に設定しておくと、
`Use this template` から新アプリ用リポジトリを骨組みごと一発生成できる。

---

## 含まれるもの

```
CLAUDE.md                    ← 横断運用ルール（プロジェクト非依存）
README.md                    ← このファイル
docs/
  新規アプリ立ち上げ.md       ← アイデア精査→コンセプト確定→MVP範囲確定（前段）
  開発プロセス.md             ← 要件→仕様→指示書→実装→レビュー→記録（進め方）
  レビュー観点.md             ← 事前レビューのチェックリスト
  project-log.md             ← 変更・意思決定ログ（見出しだけの空ファイル）
  _templates/                ← コピーして使う雛形
    concept.md               ← コンセプトシート
    feasibility.md           ← 実現性メモ
    mvp.md                   ← MVP定義表
    spec.md                  ← ロジック・データ仕様書
    design.md                ← デザイン仕様書
    brief-for-claude.md      ← 実装指示書
    project-log-entry.md     ← project-log 追記スニペット
APP_NAME/
  CLAUDE.md                  ← 実装仕様の正本プレースホルダ（アプリ名にリネーム）
```

---

## 新規アプリの始め方

1. このテンプレから新リポジトリを作る（`Use this template` または中身をコピー）
2. `APP_NAME/` を実際のアプリ名にリネームする
3. ルート `CLAUDE.md` の §6 プロジェクト一覧・§7 作業環境を埋める
4. `docs/新規アプリ立ち上げ.md` の §1 対話台本を Claude と回し、
   `docs/_templates/concept.md` → `docs/APP_NAME-concept.md` のように
   コピーして埋めていく（feasibility / mvp も同様）
5. コンセプトとMVPが固まったら `docs/開発プロセス.md` の ① 要件メモへ進む
6. 機能ごとに `_templates/spec.md` `design.md` `brief-for-claude.md` を
   コピーして使い、実装する
7. 変更のたびに `docs/project-log.md` に追記する

---

## キット自体の更新

テンプレートを改善したくなったら、このリポジトリを更新する。
**既存のアプリリポジトリには自動反映されない**（複製方式のため）ので、
改善は「次に作るアプリ」から効く。
