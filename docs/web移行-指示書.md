# Web(Next.js)版テンプレへの移行指示書

> **用途**: このキット（`app-starter-kit`／iOS・汎用寄り）から複製して作った Web 用リポジトリ
> （例: `app-starter-kit-web`）を、新しいセッションで **Webアプリ用テンプレ**に書き換えるための指示書。
> **使い方**: 複製先リポジトリを接続した新セッションの最初のメッセージに、下の「指示書本体」を貼る。
> **前提スタック**: Next.js (App Router) + TypeScript + Tailwind CSS、認証あり、DBはマネージドPostgres想定。
> **主用途**: 個人情報（PII）を扱う会員制Webサイト。

---

## 指示書本体（ここから下をコピーして新セッションへ）

```markdown
# 実装指示書: iOS版テンプレを Web(Next.js)版テンプレへ書き換え

## 目的
このリポジトリは `app-starter-kit`（アプリ開発プロセスの汎用テンプレ）から複製した。
中身の例示・作業環境が iOS/Swift 寄りなので、これを Webアプリ用テンプレに書き換える。
想定する主用途は「個人情報（PII）を扱う会員制Webサイト」。
スタックは Next.js (App Router) + TypeScript + Tailwind CSS、認証あり、DBはマネージドPostgres想定。
※これは「テンプレ（雛形）」の書き換えであって、特定アプリの実装ではない。汎用表現を保つこと。

## 現状の前提（複製直後のファイル構成）
- `CLAUDE.md` … 横断運用ルール（§6 プロジェクト一覧・§7 作業環境が iOS/Mac前提）
- `README.md` … キットの使い方（"Use this template" 運用）
- `APP_NAME/CLAUDE.md` … 実装仕様の正本プレースホルダ（フォルダ名 APP_NAME を実アプリ名にリネームして使う）
- `docs/新規アプリ立ち上げ.md` … 立ち上げ前段（§1 対話台本5フェーズ）
- `docs/開発プロセス.md` … ①要件→②仕様(②-A ロジック/②-B デザイン/②-C 構造設計)→③指示書→④実装→⑤レビュー→⑥記録
- `docs/レビュー観点.md` … 事前精査チェックリスト A〜G（F=データ安全性 / G=性能 は「スタックに合わせ調整」と明記済み）
- `docs/_templates/` … concept / feasibility / mvp / spec / design / brief-for-claude / project-log-entry
- `docs/project-log.md` … 空ログ
- プレースホルダ規約: アプリ名は APP_NAME、機能名は <機能名>、種別は <種別>、Macユーザー名は <ユーザー>（<ユーザー> はWebでは原則不要）

## 今回の必須方針
1. 進め方（メソッド）は壊さない。工程の流れ・②-A/②-B/②-C の分割思想・「実装と検証の分離」「やらないことを同密度で書く」等の原則は維持する。書き換えるのは"例示"と"作業環境"と"レビュー観点の技術依存部分"だけ。
2. iOS/Swift/Mac の記述を残さない。SwiftUI / SwiftData / MapKit / Xcode / 実機 / 「ClaudeはビルドできずMacでビルド」等を Web 用に置換。
3. Webの優位点を反映する。この実行環境内で Claude が dev server / lint / test / build を直接実行できる。iOS版にあった「Mac往復」前提を削除し、「環境内で検証まで完結」に書き換える。
4. PII/会員サイト前提のセキュリティを最初から組み込む。レビュー観点に認証・認可・個人情報・Webセキュリティの章を新設する。
5. プレースホルダ規約（APP_NAME / <機能名> / <種別>）を踏襲。新たな表記ゆれを作らない。

## 対象としてよいファイル
- `CLAUDE.md`（§6 例示・§7 作業環境）
- `README.md`（セットアップ手順を npm/pnpm 系へ）
- `APP_NAME/CLAUDE.md`（Web実装仕様の章立てへ）
- `docs/開発プロセス.md`（②-A/B/C の例示、④のテスト記述）
- `docs/レビュー観点.md`（B/C/E/F/G の技術依存部 + セキュリティ章追加）
- `docs/_templates/spec.md` `design.md` `brief-for-claude.md`（Web向け項目へ）
- `docs/新規アプリ立ち上げ.md`（フェーズ4 技術の例示のみ）
- `docs/project-log.md`（最初の移行エントリを1件追記）

## 今回やらないこと
- 工程の構造や章番号の大改造（流れは保つ）
- 立ち上げ台本（§1 フェーズ1〜3＝アイデア/精査/コンセプト）の中身変更（スタック非依存なので触らない）
- 実アプリのコード実装（あくまでテンプレ文書の書き換え。Next.jsアプリの雛形scaffoldは下記「任意の追加フェーズ」扱い）
- concept / feasibility / mvp テンプレの本質的変更（feasibility の技術例だけ最小限調整可）

## 各ファイルの書き換え指針（具体）
- CLAUDE.md §6 プロジェクト一覧: 技術スタック例を `Next.js (App Router) / TypeScript / Tailwind / Prisma / PostgreSQL / Auth.js` に。
- CLAUDE.md §7 作業環境: 「Claudeはこの実行環境で `pnpm dev` / `pnpm test` / `pnpm build` を直接実行し検証まで行う」に。Mac固有のpull手順は「ローカルで `pnpm dev` で確認」に置換。`<ユーザー>` のMacパスは削除可。
- 開発プロセス ②-A/②-B/②-C: 「View(SwiftUI)」→「component / route / server action」。②-A ロジックは「Server Component / Route Handler / Server Action でのデータ取得・検証・認可」を明記。②-B デザインは Tailwind デザイントークン・レスポンシブ・a11y。②-C は「肥大化するUIは component 分割、ロジックは hooks / lib / server へ。RSCとClient Componentの境界を最初に引く」。④のテストは「Vitest/Jest（ユニット）+ Playwright（E2E）」。閾値の例（500〜600行）はそのまま流用可。
- レビュー観点:
  - B(デザイン): デザイントークン参照・レスポンシブ・WCAGコントラスト/キーボード操作/フォーカスへ。
  - E(テスト): 実機→「Playwrightで検証 / RSC・Client境界 / SSR時の状態」。
  - F→データ安全性＆プライバシー(PII): 保存/通信の暗号化、最小収集、保持期間、ログにPIIを残さない、削除導線、同意取得、個人情報保護法の観点。
  - G→Webセキュリティ＆性能: 認証(セッション/JWT/Cookie属性 HttpOnly/Secure/SameSite)、認可チェックの抜け(IDOR)、入力検証(zod等)、XSS/CSRF/SQLi対策、秘密情報のサーバ閉じ込め(クライアントに出さない)、レート制限、N+1、バンドルサイズ、画像最適化。
  - 「意見が割れたらlogに残す」節は維持。
- APP_NAME/CLAUDE.md: 章を Web 用に →「1.コンセプト / 2.技術スタック / 3.データモデル(Prismaスキーマの正本) / 4.ルート・画面構成(App Router) / 5.認証・認可方針 / 6.重要な実装ルール(RSC/Client境界・秘密情報の扱い) / 7.ディレクトリ構成」。
- spec.md(②-A): 「Server/Client どちらで動くか」「データ取得方法」「入力検証(zod)」「認可条件」の項目を追加。
- design.md(②-B): レスポンシブ・ブレークポイント・Tailwindトークン・a11y・loading/empty/error 状態。
- brief-for-claude.md: 「対象ファイル」例を Web パス（`app/`, `components/`, `lib/`）に。受け入れ条件に「lint/type-check/test/build が通る」を明示。
- README.md: セットアップを `pnpm install` → `pnpm dev`、Node前提、`.env.example` 言及。冒頭を「Web(Next.js)アプリ用スターターキット」に。

## 受け入れ条件
1. リポジトリ全体に Swift/SwiftUI/SwiftData/MapKit/Xcode/「Mac でビルド」等の iOS固有語が残っていない（`grep -ri` で確認）。
2. CLAUDE.md §7 が「環境内で dev/test/build 完結」に置き換わっている。
3. レビュー観点に 認証・認可・PII・Webセキュリティ の章が存在し、IDOR/XSS/CSRF/秘密情報/最小収集/同意 を含む。
4. APP_NAME/CLAUDE.md に 技術スタック/データモデル/ルート構成/認証認可/ディレクトリ構成 の章がある。
5. プレースホルダが APP_NAME / <機能名> / <種別> で統一され、新たな表記ゆれがない。
6. ドキュメント間の相互参照（ファイル名・章番号）が実在し整合している。
7. `docs/project-log.md` に移行エントリ（変更概要/意図/主な変更ファイル/確認結果/残課題）を1件追記。

## 確認してほしいポイント
- 「進め方の思想」を薄めていないか（書き換えで原則が抜け落ちていないか）。
- セキュリティ観点が"飾り"でなく、レビューで実際になぞれる粒度か。
- スタック非依存のはずの立ち上げ台本フェーズ1〜3を不必要に触っていないか。

## 期待する進め方
1. まず全ファイルを読み、iOS固有語と作業環境記述の箇所を棚卸しして一覧で出す（着手前に提示）。
2. ファイル単位で小さく書き換え、都度差分を見せる。3ファイル以上跨ぐ変更は先に影響範囲を出す。
3. 最後に受け入れ条件1〜7をなぞって自己点検し、`project-log` を更新する。
4. （任意の追加フェーズ・別途合意の上で）`APP_NAME/` に最小構成の Next.js 雛形（App Router + TS + Tailwind + Auth + Prisma の空スキーマ）を scaffold する。テンプレ文書の書き換えが終わってから別タスクとして提案すること。
```

---

## 補足（このファイルの位置づけ）
- これは **iOS版テンプレ(`app-starter-kit`)に置いた移行用メモ**。Web版リポジトリ側には不要なので、
  書き換え完了後に Web版リポジトリへ持ち込む必要はない。
- スタックや認証の前提を変えたい場合（npm指定 / Clerk / Supabase 等）は、指示書本体の該当行を差し替えてから渡す。
