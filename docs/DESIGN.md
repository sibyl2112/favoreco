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

# ---- ジャンル既定テーマ（固定ではない。ユーザーがジャンルごとにテーマを選ぶ） ----
genres:
  theater:  { name: 観劇,   default_theme: velvet_curtain, title_font: serif, layout: "縦長3列ギャラリー・ゆったり" }
  sake:     { name: 酒,     default_theme: amber_cellar, title_font: serif, layout: "2列ボトルカード・密度3段" }
  movie:    { name: 映画,   default_theme: free_dark, title_font: sans, layout: "ポスターウォール3列・白ベース・見たい/見た" }
  art:      { name: 美術展, default_theme: museum_haze, title_font: serif, layout: "縦長1〜2列＋作品ギャラリー" }
  live:     { name: ライブ, default_theme: stage_bloom, title_font: sans, layout: "1:1ジャケ・チケット管理" }
  goshuin:  { name: 御朱印, default_theme: sakura_mist, title_font: serif, layout: "御朱印帳（表紙）→展開" }
  outing:   { name: おでかけ, default_theme: moegi_glass, title_font: sans, layout: "訪問マップ＋4:3横カード" }
  book:     { name: 書籍,   default_theme: porcelain_ivory, title_font: serif, layout: "本棚＋シリーズ束ね・スタック" }

theme_access:
  free: [free_light, free_dark]
  paid_unlocks: [porcelain_ivory, velvet_curtain, stage_bloom, aqua_nocturne, daydream_lake, amber_cellar, museum_haze, tour_teal, sakura_mist, moegi_glass, pale_blue_air, mono_vivid_yellow, mono_soft_magenta]
  rule: "無料版はLight/Darkの2種のみ。サブスク/買い切りで、ジャンルごとに追加テーマカラーを選べる。"

# ---- 生成画像由来の拡張パレット（2026-07-08） ----
# dark_* はジャンルライブラリの色世界、ivory_* はオフホワイト基調の同系統。
palette_sets:
  free_light:
    name: Free Light
    access: free
    light: { canvas: "#f5f6f9", surface: "#ffffff", primary: "#3a6df0", accent: "#8b93a3", ink: "#232833", muted: "#8b93a3", tint: "#edf2ff" }
  free_dark:
    name: Free Dark
    access: free
    dark: { canvas: "#14161b", surface: "#1e222a", primary: "#5b86f5", accent: "#9aa4b5", ink: "#eef1f6", muted: "#8b93a3", glow: "#3a6df0" }
  porcelain_ivory:
    name: Porcelain Ivory
    access: paid
    canvas: "#f7f5ef"
    surface: "#fffcf5"
    surface_glass: "rgba(255,252,245,0.82)"
    ink: "#252833"
    sub: "#757b86"
    hairline: "#ded8cc"
  theater_velvet_curtain:
    name: Velvet Curtain
    access: paid
    dark:  { canvas: "#100b0e", surface: "#211016", primary: "#8b2438", accent: "#c49458", ink: "#f7eadb", muted: "#b79a86", status: "#d85662" }
    ivory: { canvas: "#f8f1ec", surface: "#fffaf4", primary: "#8b2438", accent: "#b8894b", ink: "#2c2022", muted: "#7d6562", tint: "#f3d9d7" }
  live_stage_bloom:
    name: Stage Bloom
    access: paid
    dark:  { canvas: "#090d12", surface: "#151820", primary: "#d85b73", accent: "#f0a36c", ink: "#f8edf2", muted: "#a995a2", glow: "#b34d8a" }
    ivory: { canvas: "#fbf3f5", surface: "#fffafb", primary: "#c94f67", accent: "#e58f6f", ink: "#2c2428", muted: "#806970", tint: "#f8dde4" }
  aqua_nocturne:
    name: Aqua Nocturne
    access: paid
    dark:  { canvas: "#061b20", surface: "#0b343a", primary: "#1f8a93", accent: "#d7a45d", ink: "#f3f7f6", muted: "#8eaab0", glow: "#2cb6c5" }
    ivory: { canvas: "#eef8f7", surface: "#fbfffe", primary: "#247c84", accent: "#c99b55", ink: "#1d3237", muted: "#6b858a", tint: "#d8eeee" }
  daydream_lake:
    name: Daydream Lake
    access: paid
    light: { canvas: "#f7fafd", surface: "#ffffff", primary: "#2b74b8", accent: "#d6a44a", ink: "#1c3451", muted: "#6d85a0", tint: "#eaf4ff" }
    ivory: { canvas: "#f8f7f1", surface: "#fffdf8", primary: "#2d70ad", accent: "#d2a14f", ink: "#23364d", muted: "#748391", tint: "#e8f1f7" }
  amber_cellar:
    name: Amber Cellar
    access: paid
    dark:  { canvas: "#120c08", surface: "#24170d", primary: "#9b6426", accent: "#e0b261", ink: "#f6e8cf", muted: "#b58a5a", glow: "#d88a32" }
    ivory: { canvas: "#f7f0e5", surface: "#fffaf1", primary: "#9b6426", accent: "#d8aa59", ink: "#30261b", muted: "#806b50", tint: "#f0dfc4" }
  museum_haze:
    name: Museum Haze
    access: paid
    dark:  { canvas: "#081c30", surface: "#102b44", primary: "#416c99", accent: "#a7c6df", ink: "#eff5fa", muted: "#8aa8bf", glow: "#6ea0c8" }
    ivory: { canvas: "#f3f7fa", surface: "#ffffff", primary: "#416c99", accent: "#8ab4d1", ink: "#213142", muted: "#6f8292", tint: "#e5eef5" }
  tour_teal:
    name: Tour Teal
    access: paid
    dark:  { canvas: "#06191b", surface: "#10282b", primary: "#66cacc", accent: "#c9a15b", ink: "#edf7f7", muted: "#8ca6a8", glow: "#55bfc2" }
    ivory: { canvas: "#eff8f8", surface: "#fbffff", primary: "#3b9ea0", accent: "#c09a55", ink: "#203638", muted: "#6d8789", tint: "#d7eeee" }
  sakura_mist:
    name: Sakura Mist
    access: paid
    light: { canvas: "#fff6f8", surface: "#fffdfc", primary: "#d9899c", accent: "#c7a46a", ink: "#34282d", muted: "#8a7078", tint: "#f8dfe6" }
    dark:  { canvas: "#1b1015", surface: "#27171d", primary: "#e6a1b0", accent: "#d4b06f", ink: "#fff0f4", muted: "#b8909a", glow: "#d9899c" }
  moegi_glass:
    name: Moegi Glass
    access: paid
    light: { canvas: "#f3faf3", surface: "#fcfffb", primary: "#6ca36f", accent: "#d0a85a", ink: "#24362a", muted: "#6f8672", tint: "#dcefdc" }
    dark:  { canvas: "#0f1a12", surface: "#18271b", primary: "#85bd88", accent: "#d2af62", ink: "#eef8ef", muted: "#8ca891", glow: "#6ca36f" }
  pale_blue_air:
    name: Pale Blue Air
    access: paid
    light: { canvas: "#f4f9fd", surface: "#ffffff", primary: "#78a9d6", accent: "#b9cfe3", ink: "#243747", muted: "#758b9d", tint: "#e3f1fb" }
    dark:  { canvas: "#101820", surface: "#182631", primary: "#8bbce4", accent: "#a8c5dc", ink: "#edf6fc", muted: "#8da6b8", glow: "#78a9d6" }
  mono_vivid_yellow:
    name: Mono Vivid Yellow
    access: paid
    light: { canvas: "#f7f7f4", surface: "#ffffff", primary: "#1f1f1f", accent: "#ffd400", ink: "#171717", muted: "#737373", tint: "#fff3a6" }
    dark:  { canvas: "#090909", surface: "#171717", primary: "#f2f2f2", accent: "#ffd400", ink: "#f5f5f5", muted: "#9a9a9a", glow: "#ffd400" }
    inverted_light: { canvas: "#0f0f0f", surface: "#1b1b1b", primary: "#f7f7f4", accent: "#ffd400", ink: "#f7f7f4", muted: "#a2a2a2", glow: "#ffd400" }
    inverted_dark:  { canvas: "#fbfbf8", surface: "#ffffff", primary: "#171717", accent: "#ffd400", ink: "#171717", muted: "#747474", tint: "#fff5ad" }
  mono_soft_magenta:
    name: Mono Soft Magenta
    access: paid
    light: { canvas: "#f7f5f7", surface: "#ffffff", primary: "#202020", accent: "#d86aa4", ink: "#181818", muted: "#747077", tint: "#f4d7e6" }
    dark:  { canvas: "#0a0a0c", surface: "#18171b", primary: "#eeeeee", accent: "#d86aa4", ink: "#f4f1f4", muted: "#9b949c", glow: "#d86aa4" }
    inverted_light: { canvas: "#0d0c0e", surface: "#1b191d", primary: "#f4f1f4", accent: "#d86aa4", ink: "#f4f1f4", muted: "#a198a2", glow: "#d86aa4" }
    inverted_dark:  { canvas: "#faf8fa", surface: "#ffffff", primary: "#202020", accent: "#d86aa4", ink: "#181818", muted: "#747077", tint: "#f4d7e6" }
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
2. **テーマ色はアクセントだけ**：ヘッダーのタイトル・セクション見出し・状態バッジ・active タブ・フィルタON。ジャンルごとにテーマを選べるが、**面を塗りつぶさない**。
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

### テーマカラー（ジャンルごとに選択）

ジャンル色は固定しない。各ジャンルは `default_theme` を持つが、ユーザーはジャンルごとに別テーマへ差し替えられる。

- **無料版**：`Free Light` / `Free Dark` の2種のみ。
- **有料版（サブスク or 買い切り）**：追加カラーテーマを解放し、ジャンルごとにテーマを選べる。
- primary＝ヘッダー/見出し/activeに。accent＝副次強調（★評価・境界・金差し）。tint/glow＝薄い背景・グラフ・選択中の淡色面。
- **1画面に濃いテーマ色は原則1つ**（横断リマインド等の一覧では小さな色ドットで複数可）。

| ジャンル | 既定テーマ | タイトル書体 | 備考 |
|---|---|---|---|
| 観劇 | Velvet Curtain | serif | ユーザー変更可 |
| 酒 | Amber Cellar | serif | ユーザー変更可 |
| 映画 | Free Dark | sans | ユーザー変更可 |
| 美術展 | Museum Haze | serif | ユーザー変更可 |
| ライブ | Stage Bloom | sans | ユーザー変更可 |
| 御朱印 | Sakura Mist | serif | ユーザー変更可 |
| おでかけ | Moegi Glass | sans | ユーザー変更可 |
| 書籍 | Porcelain Ivory | serif | ユーザー変更可 |

### 生成画像由来パレット（Named Palettes）

2026-07-08時点の生成モックから抽出・整色したパレット。`dark` はジャンルライブラリ内の没入表示、`ivory` は同じ世界観を白〜オフホワイト基調へ落とした表示に使う。骨格は共通スケルトンを優先し、これらは**ジャンル面・カード内・見出し・状態バッジ・グラフ**の色差しとして使う。

| Palette | 想定ジャンル | Base | Primary | Accent | Tint/Glow | 用途 |
|---|---|---:|---:|---:|---:|---|
| **Velvet Curtain** | 観劇 | `#100b0e` | `#8b2438` | `#c49458` | `#d85662` | 緞帳、当落/チケット、劇場カード |
| **Stage Bloom** | ライブ | `#090d12` | `#d85b73` | `#f0a36c` | `#b34d8a` | ライブHero、参戦予定、ステータス |
| **Aqua Nocturne** | 水族館/動物園 | `#061b20` | `#1f8a93` | `#d7a45d` | `#2cb6c5` | 水槽、写真ギャラリー、施設データ |
| **Daydream Lake** | テーマパーク/おでかけLight | `#f7fafd` | `#2b74b8` | `#d6a44a` | `#eaf4ff` | 白基調の予定カード、青空系Hero |
| **Amber Cellar** | 酒 | `#120c08` | `#9b6426` | `#e0b261` | `#d88a32` | ボトル棚、味覚マップ、テイスティング |
| **Museum Haze** | 美術展 | `#081c30` | `#416c99` | `#a7c6df` | `#6ea0c8` | 展示Hero、会期Attention、作品ギャラリー |
| **Tour Teal** | ライブ旧案/音楽旅 | `#06191b` | `#66cacc` | `#c9a15b` | `#55bfc2` | ツアーJourney、遠征・旅感のある音楽画面 |

### Off-White Variants

白系ベースで使う場合の共通名は **Porcelain Ivory**。全体キャンバスは `#f7f5ef`、カードは `#fffcf5`、インクは `#252833`。ジャンルごとに `ivory` variant を使い、暗色版の世界観を保ったまま日常の白画面に馴染ませる。

| Palette | Canvas | Surface | Primary | Accent | Tint |
|---|---:|---:|---:|---:|---:|
| **Porcelain Ivory** | `#f7f5ef` | `#fffcf5` | `#3a6df0` | `#d2a14f` | `#eee8dc` |
| **Velvet Ivory** | `#f8f1ec` | `#fffaf4` | `#8b2438` | `#b8894b` | `#f3d9d7` |
| **Stage Ivory** | `#fbf3f5` | `#fffafb` | `#c94f67` | `#e58f6f` | `#f8dde4` |
| **Aqua Ivory** | `#eef8f7` | `#fbfffe` | `#247c84` | `#c99b55` | `#d8eeee` |
| **Daydream Ivory** | `#f8f7f1` | `#fffdf8` | `#2d70ad` | `#d2a14f` | `#e8f1f7` |
| **Amber Ivory** | `#f7f0e5` | `#fffaf1` | `#9b6426` | `#d8aa59` | `#f0dfc4` |
| **Museum Ivory** | `#f3f7fa` | `#ffffff` | `#416c99` | `#8ab4d1` | `#e5eef5` |
| **Tour Ivory** | `#eff8f8` | `#fbffff` | `#3b9ea0` | `#c09a55` | `#d7eeee` |

- **命名ルール**：暗色は情緒名（Velvet Curtain / Stage Bloom）、白系は `◯◯ Ivory`。SwiftUIのAsset名は `Palette.StageBloom.primary` / `Palette.StageIvory.primary` 形式を推奨。
- **白系での注意**：ジャンル色は大面積に敷かず、activeタブ・見出し・チップ・細いボーダー・小グラフに限定する。Surfaceは必ずPorcelain Ivory系を優先し、色の塗り面はTintまで。

### 追加有料テーマ（Pale / Monochrome）

ユーザー要望の追加テーマ。どのジャンルにも適用できる。ペール系は白基調との相性を優先し、モノクロ系は写真を邪魔せずアクセントだけ強くする。

| Theme | Canvas | Surface | Primary | Accent | Tint/Glow | 説明 |
|---|---:|---:|---:|---:|---:|---|
| **Sakura Mist** | `#fff6f8` | `#fffdfc` | `#d9899c` | `#c7a46a` | `#f8dfe6` | 桜色系。御朱印/書籍/美術展にも合う淡いピンク |
| **Moegi Glass** | `#f3faf3` | `#fcfffb` | `#6ca36f` | `#d0a85a` | `#dcefdc` | 萌葱色。おでかけ/植物園/水族館にも使える淡い緑 |
| **Pale Blue Air** | `#f4f9fd` | `#ffffff` | `#78a9d6` | `#b9cfe3` | `#e3f1fb` | ペールブルー。美術展/水族館/テーマパークの白系に合う |
| **Mono Vivid Yellow** | `#f7f7f4` | `#ffffff` | `#1f1f1f` | `#ffd400` | `#fff3a6` | モノクロ＋ビビットイエロー。情報整理・チケット警告に強い |
| **Mono Soft Magenta** | `#f7f5f7` | `#ffffff` | `#202020` | `#d86aa4` | `#f4d7e6` | モノクロ＋少し薄めのマゼンタ。ライブ/映画/推し系にも使える |

暗色版もトークンに持つ。ユーザーがDark表示を選んだ場合、同じテーマ名の `dark` variant を使う。Mono系は白黒の入れ替え差が大きいので、`inverted_light` / `inverted_dark` も持つ。

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

## 5-2. Liquid Glass 素材（Apple iOS 26 準拠）★2026-07-07 追記

favorecoの面は**Apple の Liquid Glass** に寄せる（[Apple Newsroom 2025-06](https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/)）。安っぽいベタ塗り・カラー絵文字は禁止。

- **半透明ですりガラス越しに背景が透ける**：面は不透明にしない。`background: rgba(255,255,255,.5〜.65)`（dark: `rgba(28,32,40,.5)`）＋ `backdrop-filter: blur(24px) saturate(180%)`。背後の壁紙/写真がぼけて透ける＝コンテキストを失わせない。
- **スペキュラ・ハイライト（上端の光）**：`box-shadow: inset 0 1px 0 rgba(255,255,255,.7)`＋淡いトップ→透明のシーン。縁で光を拾う。
- **屈折する縁（レンジング）**：1pxの明るいリム（`border: 1px solid rgba(255,255,255,.5)`）＋外側にソフトな浮き影 `0 12px 30px -12px rgba(30,40,70,.25)`。
- **浮いて層になる**：ナビ・主要コントロールは**面に貼らず浮かせる**（frosted な**フローティング・タブバー**＝画面幅いっぱいの帯でなく、左右に余白を持つ角丸ピル）。スクロールで下の内容が透けて動く。
- **同心の角丸（concentric）**：外側の角丸の中に、内側要素を一回り小さい角丸で入れ子に。角丸は連続的に。
- **彩度を抑える**：ガラス自体はほぼ無彩色。色はジャンルの**アクセント**として少量。壁紙/写真が色を供給し、ガラスがそれを透かす。
- **可読性の担保**：NN/g がコントラスト低下を指摘。テキスト/アイコンの背後は**必要ならガラスをわずかに濃く**し、本文コントラストを確保（透明感より可読性優先）。

## 5-3. アイコン規則 ★2026-07-07

- **カラー絵文字は使わない（チープ）**。実装＝**SF Symbols**（monochrome/hierarchical・細線）。モック＝**インラインSVGの細線アイコン**（stroke 1.6〜1.75・`currentColor`・角丸linecap）。
- アイコンは原則**単色**（ink または sub、activeはジャンルprimary）。塗りつぶしの多色アイコンにしない。
- 写真タイル・サムネはガラスの下の"コンテンツ"＝絵文字を置かず**写真（無ければ淡いグラデ面）**で埋める。

## 6. コンポーネント（Components）

- **カード（Liquid Glass）**：§5-2の素材（半透明＋blur＋スペキュラ＋リム＋浮き影）＋角丸16。写真は上、テキストは下。ベタ塗り白カードにしない。
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
