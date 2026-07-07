# ②-A / spec-A3 ユニット別フィールド定義

> ステータス: 清書（2026-07-06）
> 位置づけ: ②-A のユニット分冊。土台＋17ユニット＋テンプレ拡充フィールドを、**Event/Visit振り分け・格納方式（個別プロパティ or unitFieldsRaw）・マスター参照**まで定める正本。具体的なプリセット中身（軸名・成果選択肢・形態選択肢）は A4。
> 関連: A1（Event/Visit境界・格納・スナップショット）／ A2（種別サブレイヤー）／ 08（ユニット一覧U1-U17・テンプレ確定§4-2〜§4-11）／ A7（登録フロー）

---

## 1. 振り分けの原則（A1の適用）

1. **対象の同一性＝Event／回ごと＝Visit**（A1 §2）。判定に迷うユニットは§4の注記で個別確定。
2. **クエリ/集計/カレンダー/地図で使う値＝個別プロパティ**、**表示専用＝unitFieldsRaw（JSON）**（A1 §8）。
3. **マスターは参照＋記録時スナップショット**（A1 §6）。全リレーションoptional・全プロパティ既定値・unique禁止（CloudKit互換・A1 §4）。
4. **横断の一般ルール（Event/Visit判定の要）**：
   - **対象の客観属性/メタ（不変）→ Event**：タイトル・原題・著者・出版社・シリーズ/巻・銘柄スペック・作品ジャンル・書籍の種類・映画のキャスト/スタッフ・種別(subType)・主催・酒蔵・施設・URL・代表アイキャッチ。
   - **主観評価＋その回の文脈 → Visit**：総合評価・評価軸スコア・味覚/官能・成果・鑑賞方法(形態)・座席・同行者・タグ・金額・写真・日付・天気・回別アイキャッチ・見たものリスト。

---

## 2. 土台フィールド（全カテゴリ共通・08 §2）

| フィールド | 所属 | 型 | 格納 | 備考 |
|---|---|---|---|---|
| title | Event | String="" | 個別（検索） | |
| subtitle | Event | String="" | 個別 | オンオフ |
| seriesName | Event | String="" | 個別（グルーピング） | 書籍シリーズ/ツアー名（A5スタック） |
| dateStart / dateEnd（訪問日/回） | Visit | Date? | 個別（カレンダー） | 日跨ぎ対応 |
| periodStart / periodEnd（会期/販売期間） | Event | Date? | 個別（カレンダー期間バー） | 美術展会期・チケット販売期間 |
| photos（写真） | Visit | →PhotoBlob(多) role=photo | relativePath | "とりあえず入れる"データ・キャプション不要。**後からコレクションへ移動可**（roleをcollectionに変更・実体移動なし） |
| eyecatchPath（代表） | Event | String? | relativePath | A1 §5 |
| eyecatchPath（回別） | Visit | String? | relativePath | A1 §5・リピートは前回引き継ぎ |
| urls | Event | [String] | 個別 | ＋で複数 |
| snsX / snsInsta / snsThreads | Event | String? | 個別 | トグル |
| note（感想/メモ） | Visit | String="" | 個別（全文検索） | 文字数無制限 |
| overallRating（総合評価） | Visit | Int/Double=0 | 個別（統計） | RESONANCE型の仕様はA4 |
| categoryRef | Event | →RecordCategory? | 参照 | A1 §3 |
| subTypeKey | Event | String="" | 個別 | A2 |

---

## 3. マスター一覧（参照＋スナップショット）

| マスター | 主フィールド | 参照元 | 備考 |
|---|---|---|---|
| **PlaceMaster（場所・種別付き）** | 名称・種別（会場/店/施設[テーマパーク/水族館/動物園]/寺社/城/港）・地域・住所・座標・AppleMapリンク・GoogleMapリンク | **Event**（対象=場所の時：施設/寺社/城/港）／**Visit**（会場/店） | 参照DB(DL)＋Apple POI＋手動ピン（feasibility §4-2b）。地図集計元 |
| **Brewery（酒蔵）** | 酒蔵名・所在県・URL・スナップ | Event（銘柄）／御酒印 | 共有マスター(A6)・所在県マップ・さけのわでエンリッチ |
| **GoshuinBook（御朱印帳）★新規・御朱印カテゴリ専用** | 縦横比タイプ（通常16×11cm／大判18×12cm／**横長182×257mm**）・表紙写真・裏表紙写真・購入場所（PlaceMaster）・購入日・限定メモ | Visit(御朱印)が所属参照 | 「帳面を保存する体験」の入れ物。Visit(御朱印)は **GoshuinBook＋寺社(Event)** の両方を参照。1帳に複数寺社の御朱印が入る。最新帳を既定選択（spec-B1 §7） |
| Organizer（主催） | 名称・スナップ | Event | |
| **Person（人物）★新規** | 氏名・スナップ | Event↔Person credits（役割:監督/脚本/出演/作家 等） | 映画/観劇/美術展。「この人の作品n本」統計 |
| SubType（種別） | key・displayName・category | Event.subTypeKey で解決 | A2（酒/施設/印。中身は種別別プリセット） |
| AxisDefinition / AxisScore | 軸名・値 | AxisScore→**Visit** | U7。軸セットは種別別プリセット(A4) |
| OutcomeOption（成果） | 選択肢 | Visit.outcomeKey | U8。選択肢は種別別(A4) |
| FormatMaster（形態） | 選択肢 | 用途で2系統（§4 U14） | 鑑賞方法=Visit／書籍種類=Event |
| GenreOption（作品ジャンル） | 選択肢（複数選択） | **Event**.genres | U15。カテゴリ内管理の分類 |
| Tag | 名称 | Visit.tags[String]＋master upsert | U6 |
| Companion（同行者） | 名称 | Visit.companions[String]＋master upsert | U5 |

---

## 4. ユニット別フィールド（U1〜U17）

●=デフォルトON ○=1タップON –=非表示（08マトリクス§4）。所属・格納は下記に確定。

| # | ユニット | 主フィールド | 所属 | 格納 |
|---|---|---|---|---|
| U1 | 場所 | PlaceMaster参照＋名称スナップ | Event(対象=場所) or Visit(会場/店) | 参照＋スナップ。座標は個別（地図） |
| U2 | 座席 | 座席番号・階/列（自由1行） | Visit | 個別（軽量String） |
| U3 | 公演情報 | 開演時刻・マチネ/ソワレ・上演時間・当日変更メモ | Visit | 開演/終演=個別（カレンダー）、メモ等=unitFieldsRaw |
| U4 | リスト（セトリ/見たもの/アトラク） | 順序付き項目[ ] | Visit | unitFieldsRaw（JSON配列）。呼び名は種別で切替 |
| U5 | 同行者 | [String]＋Companion upsert | Visit | 個別[String] |
| U6 | タグ | [String]＋Tag upsert | Visit | 個別[String]（横断検索） |
| U7 | 評価軸レーダー | AxisScore（軸×値） | **Visit** | AxisScore別モデル（個別・統計）。軸定義は種別別プリセット |
| U8 | ~~成果~~ **廃止（2026-07-06）** | — | — | 全ジャンルで廃止（総合評価で代替・A4 §1）。書籍のみ「読書状態」として存続（§5） |
| U9 | スペック表 | ラベル＋値ペア配列 | Event（対象のスペック） | **unitFieldsRaw JSON**（A1 §8-2）。※定番数値は§5で個別列へ昇格 |
| U10 | 官能メモ | 香→味→余韻の3欄 | Visit | unitFieldsRaw（表示専用） |
| U11 | コレクション | モノ写真＋**キャプション（任意・空可）**[ ] | Visit | PhotoBlob role=collection＋**caption**（絵画の作品名等・空でOK）。写真(role=photo)から移動して作れる |
| U12 | 金額 | 金額・内訳（チケット/グッズ/遠征） | Visit | 個別（集計）。内訳の明細はunitFieldsRaw |
| U13 | リピート | 通算回数・回ごと比較 | 派生（Event配下Visitの集計） | 保存せず算出（A5）。同一対象判定はA6 |
| U14 | 形態 | ①鑑賞方法（劇場/配信/現地）②書籍種類（マンガ/技術書） | ①Visit ②Event | 個別（statistics）。選択肢はFormatMaster/種別別 |
| U15 | 作品ジャンル | 分類（複数選択） | **Event** | 個別[String]（「SF作品n本」統計） |
| U16 | ラベル表裏＋OCR | 表/裏写真＋OCR読取テキスト | Event（銘柄のラベル） | 写真=PhotoBlob、OCR結果→U9/§5個別列へ流し込み |
| U17 | 味覚マップ2軸 | 甘辛×濃淡の座標(x,y) | **Visit**（その回の感じ方） | 個別（Double x2）。さけのわ値を参考デフォルト表示 |

> **判定の注記**：
> - U7/U17/U10（評価・味覚・官能）＝**Visit**（主観・回ごと。A1のoverallRating=Visitと一貫）。さけのわ等の外部値は"参考デフォルト"として提示、保存はユーザーの入力。
> - U9スペック表＝Event（対象の客観スペック）。ただし**検索/グラフする値は§5で個別列へ昇格**（自由ペアはunitFieldsRaw）。
> - U14形態＝**2系統**：鑑賞方法(Visit)と書籍種類(Event)を別フィールドに分ける（混同しない）。
> - U13リピート＝保存フィールドではなく**Event配下のVisit群の集計**（通算n回）。同一対象の判定はA6。
>
> **★PhotoBlob拡張（2026-07-06 ユーザー要望）**：PhotoBlobに `role`（photo / collection / label / eyecatch）＋ `caption: String=""`（任意）を追加。
> - **写真(role=photo)**＝とりあえず入れるデータ・キャプション不要。
> - **コレクション(role=collection)**＝モノの記録＋キャプション（空でも可・例：観た絵画の作品名）。
> - **ラベル(role=label)**＝U16。**代表アイキャッチ**は Event.eyecatchPath（別）。
> - **写真→コレクションへの移動＝roleをcollectionに変えるだけ**（実体の再保存なし・caption付与可）。逆も可。
> - 09（写真ストレージ仕様）に role/caption を追記（要更新）。

---

## 5. テンプレ由来の拡充フィールド（08 §4-5〜§4-11）

| テンプレ | 追加フィールド | 所属 | 格納 | 由来 |
|---|---|---|---|---|
| 映画 | 原題・製作年・製作国・上映時間・あらすじ | Event | 年/尺=個別、あらすじ/国=unitFieldsRaw（あらすじは「続きを読む」で畳む・感想と別） | TMDb |
| 映画 | 監督・脚本・出演者 | Event↔Person credits | 参照（役割付き）＋名称スナップ。「この人の映画n本」統計 | TMDb |
| 映画 | 観たい状態（観たい/観た）・公開日 | Event | watchStatus（積読と同型・A5）／releaseDate（個別・Coming Up/カレンダーへ） | TMDb。観たいは未公開作の公開予定バッジ・私的watchlist |
| 書籍 | 著者・出版社 | Event | 個別 | openBD/NDL |
| 書籍 | volumeNumber（巻数） | Event | 個別（シリーズ順・A5スタック/巻スクロール） | |
| 書籍 | 読書状態=読了/積読/中断/再読 | **Event**（本の現在状態） | 個別（readingStatus・積読管理） | 成果廃止に伴い"状態"として存続。**積読＝読んだ回(Visit)が無い状態なのでEvent側**（A5 §8で修正確定） |
| 御朱印 | 直書き/書き置き | Visit | 個別（U14形態の御朱印プリセット） | |
| 御朱印 | 由緒書き・リーフレット写真 | Visit | PhotoBlob（U11コレクション所属） | |
| 御朱印 | 初穂料/納経料 | Visit | 個別（U12金額） | |
| 観劇/ライブ | チケット状態・各期限（発売/申込/当選/入金）・名義/枚数/手数料/購入URL | Visit | **状態＋期限=個別**（要対応ストリップ・アラームの源）／名義/枚数/手数料/URL=unitFieldsRaw | チケコレ級（08 §4-2）。状態=申込前/当落待ち/入金待ち/発券待ち/発券済 |
| 酒 | 精米歩合・日本酒度・酸度・アルコール分 | **Event** | **個別（数値列・検索/グラフ）** | ラベルOCR/さけのわ（A1 §8-1 昇格） |
| 酒 | 銘柄・使用米・酵母・蔵元コメント | Event | unitFieldsRaw（U9自由ペア） | |
| おでかけ施設 | 施設種別・年パス種別 | Event(種別)/Visit(パス=形態) | 個別 | A2/U14 |
| おでかけ施設 | 見たもの（生き物/動物/アトラク） | Visit | unitFieldsRaw（U4リスト・呼び名種別切替） | |
| 出かける系共通 | weatherSymbol・気温 | Visit | 個別（軽くキャッシュ・SF Symbol名） | WeatherKit（08 §4-9） |

---

## 6. CloudKit互換チェック（全フィールド機械適用）

- 全プロパティに既定値（String=""/Int=0/Bool=false/Optional=nil）。
- `@Attribute(.unique)` なし。マスター重複は fetch-first upsert（name正規化）。
- リレーション（categoryRef/venue/brewery/facility/organizer/person credits/axisScore/photoBlob）は全て optional・多くは cascade or nullify（A1 §6）。
- `[String]`（tags/companions/urls）と unitFieldsRaw（String JSON）はCloudKitで安全。

---

## 7. 持ち越し（A4以降）

- **A4**：各種別プリセットの中身（U7軸名・U8成果選択肢・U14形態選択肢・U15ジャンル選択肢・U9スペックチップ・OCR辞書・味覚軸ラベル）。RESONANCE型の総合評価仕様。
- **A5**：U13リピート集計・シリーズ(seriesName)グルーピング/巻スクロール/スタック・カレンダー/地図/フィルモグラフィ統計・味覚マップ集計。
- **A6**：同一対象判定（名寄せ）・共有マスター横断リンク（酒蔵ハブ）・スナップショットの実装詳細。
- Person credits の関係モデル（役割の持ち方）の最終形はA6で確定（暫定：Event↔Person＋role文字列＋名称スナップ）。
