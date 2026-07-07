---
# favoreco design tokens (machine-readable core)
# 形式は VoltAgent/awesome-design-md 流（プレーンMD＋軽量トークン）。
# 実装は SwiftUI。トークンは Color/CGFloat 定数へ手写経する（CSS export は使わない）。
meta:
  name: favoreco
  voice: "静かで上質・写真が主役・Liquid Glass。Mystorium（金/Cinzel・荘厳）とは別人格＝澄んだ日常の美。"
  platform: SwiftUI / iOS

# ---- 共通スケルトン（全ジャンル不変・app chrome） ----
skeleton:
  canvas_light: "#f5f6f9"
  canvas_dark: "#14161b"
  surface_light: "rgba(255,255,255,0.85)"   # Liquid Glass（blur 20）
  surface_dark: "rgba(30,34,42,0.70)"
  ink_light: "#232833"
  ink_dark: "#eef1f6"
  sub: "#8b93a3"
  hairline_light: "rgba(180,190,210,0.40)"
  hairline_dark: "rgba(120,132,150,0.30)"
  app_accent: "#3a6df0"     # ニュートラル面のリンク/選択（ホーム・設定・通知）
  semantic: { red: "#e0533a", amber: "#e0a12a", blue: "#3a6df0", green: "#1f8a5a" }

radius: { card: 16, tile: 12, chip: 11, pill: 999, sheet: 26 }
space:  { xs: 4, s: 8, m: 12, l: 16, xl: 24 }     # 8pxグリッド
elevation:
  card: "0 8px 20px -15px rgba(40,60,110,0.35)"    # 軽い。Liquid Glassは浮かせすぎない
  float: "0 26px 56px -28px rgba(40,60,110,0.45)"

type:
  family_sans: "-apple-system, Hiragino Sans, Yu Gothic UI, system-ui"
  family_serif: "Georgia, Yu Mincho, serif"        # ジャンルタイトルの格調用（観劇/酒/美術展/御朱印/書籍）
  scale:
    h1:      { size: 22, weight: 800 }
    genre_title: { size: 24, weight: 800 }          # ライブラリ見出し（ジャンルでserif/sans切替）
    section: { size: 14, weight: 700 }
    body:    { size: 13, weight: 400 }
    caption: { size: 11, weight: 400 }
    micro:   { size: 9.5, weight: 700 }

# ---- ジャンル色世界（アクセントとしてのみ使用・骨格は共通） ----
genres:
  theater:  { name: 観劇,   primary: "#7c2d43", accent: "#b8894b", tone: wine-gold,   title_font: serif, layout: "縦長3列ギャラリー・ゆったり" }
  sake:     { name: 酒,     primary: "#b07a2e", accent: "#e7c77a", tone: amber-honey, title_font: serif, layout: "2列ボトルカード・密度3段" }
  movie:    { name: 映画,   primary: "#2e3440", accent: "#c8a24a", tone: cinematic-charcoal, title_font: sans, layout: "ポスターウォール3列・白ベース・見たい/見た" }
  art:      { name: 美術展, primary: "#3b6ea5", accent: "#c8862e", tone: museum-blue, title_font: serif, layout: "縦長1〜2列＋作品ギャラリー" }
  live:     { name: ライブ, primary: "#d6455d", accent: "#f0b24a", tone: stage-coral, title_font: sans, layout: "1:1ジャケ・チケット管理" }
  goshuin:  { name: 御朱印, primary: "#c0392b", accent: "#b8894b", ink: "#2a2420", tone: vermilion-sumi-gold, title_font: serif, layout: "御朱印帳（表紙）→展開" }
  outing:   { name: おでかけ, primary: "#2e8b6f", accent: "#e0a12a", tone: park-green, title_font: sans, layout: "訪問マップ＋4:3横カード" }
  book:     { name: 書籍,   primary: "#8a6d3b", accent: "#c8a24a", tone: shelf-tan, title_font: serif, layout: "本棚＋シリーズ束ね・スタック" }
---

# favoreco — DESIGN.md

> このファイルはデザインの**正本**。「今どの色・寸法・佇まいか」を1枚で保持し、実装（SwiftUI）とモックのブレを防ぐ。仕様の正本は `docs/spec-*`、意思決定は `docs/project-log.md`、**見た目のトークンはここ**。

## 1. 空気感（Overview）

- **静かで上質・写真が主役。** 装飾より余白。色面より写真。Mystorium（金/Cinzel・荘厳・謎めき）とは**別人格**＝澄んだ日常の美。
- **Liquid Glass 基調・白ベース。** すりガラスの面がふわりと重なる。影は軽く、浮かせすぎない。
- **ゆったり。** 情報密度を上げすぎない。質は密度でなく余白・タイポ・色で出す（観劇の"縦長ゆったり"が基準の佇まい）。

## 2. 共存の憲法（Guardrails）★最重要

favorecoは1アプリで多ジャンルを抱える。**バラバラに見せない**ための憲法：

1. **骨格は全ジャンル共通**：ステータスバー／ナビ（ホーム・暦・ライブラリ・マイ）／カード素材（Liquid Glass）／タイポ／余白（8pxグリッド）／角丸は**不変**。
2. **ジャンル色はアクセントだけ**：ヘッダーのタイトル・セクション見出し・状態バッジ・active タブ・フィルタON。**面を塗りつぶさない**。
3. **ジャンル固有レイアウトはコンテンツエリア内だけ**：棚の並べ方・カードの形（映画=ポスターウォール／酒=ボトル2列／観劇=縦長3列）は中身の話。枠は共通。
4. **app chrome はニュートラル**：ホーム・設定・通知・登録情報ハブは**白ベース＋app_accent(青)**。色世界は**ライブラリの中だけ**にまとう。
5. **写真が主役**：色やアイコンは脇役。実装アイコンは絵文字でなく **SF Symbols**（モックの絵文字は仮）。

## 3. 色（Colors）

### 共通スケルトン
| 用途 | Light | Dark |
|---|---|---|
| キャンバス | `#f5f6f9` | `#14161b` |
| サーフェス（Glass） | `rgba(255,255,255,.85)` +blur | `rgba(30,34,42,.70)` +blur |
| インク（本文） | `#232833` | `#eef1f6` |
| サブ（補助） | `#8b93a3` | `#8b93a3` |
| ヘアライン | `rgba(180,190,210,.4)` | `rgba(120,132,150,.3)` |
| appアクセント | `#3a6df0` | `#5b86f5` |

意味色：赤 `#e0533a`（緊急・締切）／琥珀 `#e0a12a`（注意・機会損失）／青 `#3a6df0`（情報）／緑 `#1f8a5a`（完了）。

### ジャンル・パレット（色世界）
| ジャンル | primary | accent | トーン | タイトル書体 |
|---|---|---|---|---|
| 観劇 | `#7c2d43` | `#b8894b` | ワインレッド×ゴールド | serif |
| 酒 | `#b07a2e` | `#e7c77a` | 琥珀×蜂蜜 | serif |
| 映画 | `#2e3440` | `#c8a24a` | シネマ・チャコール（白ベース） | sans |
| 美術展 | `#3b6ea5` | `#c8862e` | ミュージアム・ブルー | serif |
| ライブ | `#d6455d` | `#f0b24a` | ステージ・コーラル | sans |
| 御朱印 | `#c0392b` | `#b8894b` | 朱×墨(`#2a2420`)×金 | serif |
| おでかけ | `#2e8b6f` | `#e0a12a` | パーク・グリーン | sans |
| 書籍 | `#8a6d3b` | `#c8a24a` | 本棚・タン | serif |

- primary＝ヘッダー/見出し/activeに。accent＝副次強調（★評価・境界・金差し）。
- **1画面に濃いジャンル色は原則1つ**（横断リマインド等の一覧では小さな色ドットで複数可）。

## 4. タイポグラフィ（Typography）

- 既定＝サンセリフ（`-apple-system` / Hiragino）。
- **ジャンルタイトルのみ**、格調ジャンル（観劇・酒・美術展・御朱印・書籍）は **serif（Georgia/Yu Mincho）**、モダンジャンル（映画・ライブ・おでかけ）は sans。
- 階層：H1 22/800 ・ ジャンル見出し 24/800 ・ セクション 14/700 ・ 本文 13 ・ キャプション 11 ・ マイクロ 9.5/700。
- 詰めすぎない。行間は本文で 1.4 前後。

## 5. レイアウト・余白（Layout & Spacing）

- **8pxグリッド**（4/8/12/16/24）。画面左右マージン＝14〜16。
- カード角丸 16／タイル 12／チップ 11／シート 26。
- グリッド：映画=3列ポスター／酒=2列（密度で1/2/3切替）／観劇・美術展=縦長1〜3列ゆったり。
- 影は `elevation.card`（軽い）を既定。フロートは通知シート等のみ。

## 6. コンポーネント（Components）

- **カード（Liquid Glass）**：surface＋1pxヘアライン＋軽い影＋角丸16。写真は上、テキストは下。
- **ナビバー**：frosted glass・4タブ。activeはニュートラル面で青、**ライブラリ内ではそのジャンルのprimary**。
- **セクション見出し**：ジャンルprimaryのタイトル（書体はジャンル指定）＋件数（accent）＋ヘアライン。
- **フィルタチップ**：pill・既定outline、ON＝ジャンルprimary塗り。
- **状態バッジ**：小pill・意味色塗り（入金待ち=赤・当落待ち=青・発券待ち=琥珀・参戦済=緑）。
- **密度トグル**：1列/2列/3列（酒・書籍等）。
- **モジュール（ホーム）**：見出し＋Glass内容。オン/オフ＋並び替え＋一部ジャンル別絞り込み（spec-B2）。
- **通知シート**：下からのbottom sheet・グラブハンドル・時間軸グルーピング。

## 7. ダークモード

- theme-aware。キャンバス/サーフェス/インク/ヘアラインをダーク値へ。
- ジャンルprimaryは**やや明度を上げて**使う（暗背景で沈まないよう +10〜15%）。写真主役は不変。

## 8. アンチパターン（やらないこと）

- ✗ ナビ全体・画面全体をジャンル色で塗る（骨格を壊す）。
- ✗ 1画面に濃いジャンル色を3つ以上同時に。
- ✗ 情報密度を詰めて"アプリ感"を出す（favorecoは余白で質を出す）。
- ✗ 強い影・過剰なグラデ・多色（Liquid Glassは軽く淡く）。
- ✗ 絵文字アイコンの実装採用（→ SF Symbols）。装飾絵文字の乱用。
- ✗ app chrome（ホーム/設定/通知）にジャンル色世界を持ち込む。

## 9. SwiftUI への写経メモ

- 色＝Asset Catalog（Light/Dark）＋ `Color.Genre.theaterPrimary` 等の名前空間。
- 余白＝`enum Space { static let m: CGFloat = 12 }` 等の定数。
- Glass＝`.background(.ultraThinMaterial)` ＋ヘアライン `.overlay(RoundedRectangle...stroke)`。
- 影＝`.shadow` は控えめ1段。角丸＝`RoundedRectangle(cornerRadius: Radius.card)`。
- このファイルのトークンが唯一の正。値を変えるときは**まずここ**を直し、モック→実装へ反映。

## 10. プレビュー

`docs/design-preview.html`（スウォッチ・タイポ・コンポーネント・4ジャンルのライブラリ縮小見本）。ブラウザで開いて確認。実装はSwiftUI。
