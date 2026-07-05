# CloudKit対応の写真ストレージ仕様（PhotoBlob / externalStorage 方式）

> 2026-07-05 作成。Mystorium V10 で実装・実機検証済み（4,808枚・1,201.9MB を移行、失敗0件）の方式を、favoreco が最初から採用するための仕様書。
> Mystorium 側の正本：`Models/MystoriumSchema.swift`（PhotoBlob モデル）/ `Models/PhotoBlobStore.swift` / `Models/PhotoBlobMigration.swift` / `Models/PhotoStorage.swift` / `Models/DataExporter.swift`

---

## 1. 目的と設計判断

### なぜファイル直置きではなく SwiftData blob に入れるか

CloudKit 自動同期（`ModelConfiguration(cloudKitDatabase: .automatic)`）が同期するのは **SwiftData ストアの中身だけ**。`Documents/images/` に直接置いたファイルは同期されない。写真を将来 iPad 等と同期するには、写真本体を SwiftData モデルのプロパティとして持つ必要がある。

### なぜ `@Attribute(.externalStorage)` か

- 写真バイナリを SQLite 本体に入れると DB が肥大化しクエリ全体が遅くなる
- `.externalStorage` を付けると、SwiftData が大きい Data を自動的にストア隣の `_SUPPORT` ディレクトリへファイルとして逃がし、DB にはポインタだけ残す
- **CloudKit 同期対象のまま**、DB 肥大化を回避できる（いいとこ取り）

### 新規アプリ（favoreco）への適用方針

Mystorium は「ファイル保存 → blob」の**移行**が必要だったが、favoreco は最初から blob 方式で実装すれば移行コード（§6）は不要。ただし §6 の教訓（バッチコミット等）は他のバックフィル処理にもそのまま効く。

---

## 2. データモデル：PhotoBlob

```swift
@Model
final class PhotoBlob {
    var id: UUID = UUID()
    var relativePath: String = ""
    var byteCount: Int = 0
    var createdAt: Date = Date()
    @Attribute(.externalStorage) var data: Data = Data()

    init(relativePath: String, data: Data) {
        self.id = UUID()
        self.relativePath = relativePath
        self.byteCount = data.count
        self.createdAt = Date()
        self.data = data
    }
}
```

### CloudKit 互換の3条件（全モデル共通・厳守）

CloudKit を後から有効化するとき、スキーマがこの条件を満たしていないとコンテナ生成が失敗する。**後から直すとマイグレーションが必要になるので、最初から守る**：

1. **全プロパティにデフォルト値**（`= UUID()` / `= ""` / `= 0` / `= Date()` / `= Data()`）
2. **`@Attribute(.unique)` を使わない** — 一意性は保存時の fetch-first upsert で担保（§4 の `save`）
3. **リレーションを持たない**（PhotoBlob は完全に独立。他モデルとは `relativePath` 文字列で疎結合）
   - リレーションを持つモデルは「全リレーションが optional」が条件。PhotoBlob はそもそも持たないのが最も安全

### byteCount を別プロパティに持つ理由

`data` は externalStorage なので、プロパティに触れた瞬間ファイル読み込み（フォールト）が走る。存在チェック・容量集計・オーファン掃除では `byteCount` だけ見て **`data` に触れない**（§4 の `exists` / `totalByteCount` / `allEntries`）。

---

## 3. アーキテクチャ：ストレージ API を凍結してバックエンドだけ差し替える

```
UI・保存処理（画面側は保存方式を知らない）
   │  save / data / remove（relativePath 文字列で参照）
   ▼
PhotoStorage（API 凍結・relativePath 形式も不変）
   │
   ├─ 写真・アイキャッチ → PhotoBlobStore（SwiftData / externalStorage）
   └─ 動画ファイル（video_* プレフィックス）→ 従来通りファイル保存
```

- **relativePath 形式**：`{eventID}/eyecatch.jpg` / `{eventID}/visits/{visitID}/{photoID}.jpg` のような相対パス文字列。Event/Visit 側は今まで通りこの文字列を保持するだけ（モデル変更ゼロ）
- **振り分けルール**は関数1つ：

```swift
nonisolated static func isBlobBacked(_ relativePath: String) -> Bool {
    let fileName = (relativePath as NSString).lastPathComponent
    return !fileName.hasPrefix("video_")
}
```

- **動画をファイルに残す理由**：AVPlayer 再生に fileURL が必要。blob に入れると再生のたびに一時ファイルへ書き出すことになる。動画は CloudKit 同期の v1 対象外（リンク・サムネイルのみ同期）とする設計判断とも整合
- **読み出しは dual-read**（blob 優先 → ファイルにフォールバック）。移行期間・中断時も表示が途切れない。最初から blob 方式の favoreco でも、このフォールバックは入れておくと後の柔軟性が高い：

```swift
nonisolated private static func resolveData(for reference: PhotoStorageReference, ...) throws -> Data {
    if isBlobBacked(reference.relativePath),
       let blobData = PhotoBlobStore.data(relativePath: reference.relativePath) {
        return blobData
    }
    return try Data(contentsOf: absoluteURL(for: reference))  // フォールバック
}
```

この構造のおかげで、Mystorium では**画面側のファイルを1つも変更せず**にストレージ方式を入れ替えられた。

---

## 4. PhotoBlobStore（読み書きの実体・全文 90 行）

設計ポイント：

```swift
nonisolated enum PhotoBlobStore {

    /// 起動時（App.init）に1回だけ設定。以後は読み取りのみ
    nonisolated(unsafe) static var container: ModelContainer?

    /// 各操作は呼び出しスレッド上で使い捨ての ModelContext を生成
    /// （ModelContainer は Sendable。バックグラウンドの Task.detached からも安全）
    nonisolated private static func makeContext() -> ModelContext? {
        guard let container else { return nil }
        return ModelContext(container)
    }

    /// 保存（同じ relativePath があれば上書き）— unique 制約の代わりの fetch-first upsert
    nonisolated static func save(_ data: Data, relativePath: String) throws {
        guard let context = makeContext() else { throw StorageError.blobStoreUnavailable }
        if let existing = fetchBlob(relativePath: relativePath, context: context) {
            existing.data = data
            existing.byteCount = data.count
        } else {
            context.insert(PhotoBlob(relativePath: relativePath, data: data))
        }
        try context.save()
    }

    nonisolated static func data(relativePath: String) -> Data? { ... }

    /// 存在チェックは byteCount のみ参照（data をフォールトさせない）
    nonisolated static func exists(relativePath: String) -> Bool { ... }

    nonisolated static func remove(relativePath: String) { ... }

    /// prefix（例: "{eventID}/"）配下をまとめて削除（イベント削除時）
    nonisolated static func removeAll(pathPrefix: String) {
        // #Predicate { $0.relativePath.starts(with: pathPrefix) }
    }

    /// 容量集計・オーファン掃除用（byteCount 集計・data 非フォールト）
    nonisolated static func totalByteCount() -> Int64 { ... }
    nonisolated static func allEntries() -> [(relativePath: String, byteCount: Int)] { ... }
}
```

- **UI 用の mainContext を使い回さない**。写真保存はバックグラウンドから呼ばれるため、per-operation の使い捨て `ModelContext(container)` が最も単純で安全
- `container` は `MystoriumApp.init` で `PhotoBlobStore.container = bootstrap.container` の1行（UI 表示前・書き込み1箇所なので `nonisolated(unsafe)` が許容できる）
- イベント削除時は `PhotoBlobStore.removeAll(pathPrefix: "\(eventID.uuidString)/")` ＋ 動画用ディレクトリの物理削除の**両方**を行う

---

## 5. Swift 6 の注意（ハマった教訓・favoreco でも必ず踏む）

プロジェクトが **default MainActor isolation**（Xcode 16 の Swift 6 モード推奨設定）の場合、**新設する static ユーティリティはすべて `nonisolated` を明示**しないと MainActor に縛られる：

- 付け忘れると「バックグラウンドで動かしているつもりが全部メインスレッド」になり、UI が固まる／8個の並行性警告が出る
- 型ごと `nonisolated enum PhotoBlobStore { ... }` と宣言し、さらにメンバーにも付ける（型レベルだけだと拾えないケースがある）
- `FileManager.DirectoryEnumerator` は async コンテキストで直接イテレートできない → 列挙は**同期ヘルパー関数に分離**してから async 側で使う（§6 の `collectPhotoFiles`）

---

## 6. 既存データの移行（Mystorium 実績・favoreco では原則不要）

favoreco が最初から blob 方式なら不要。ただし「起動時に数千件を書き換えるバックフィル」一般の教訓として記録する。

### 方式（PhotoBlobMigration・全文 127 行）

- **StatusBackfill と同じ UserDefaults 完了フラグ方式**（`photoBlobMigration_v1`）。インポート（データ復元）時はフラグをリセットして再実行
- App の `.task` から `Task.detached` でバックグラウンド実行。dual-read（§3）のおかげで移行中・中断時も表示は途切れない
- 処理順とバッチング：

```
対象列挙（video_* 以外の通常ファイル・同期ヘルパーで確定）
  ↓ 1ファイルずつ
既に blob 化済み？ → ファイルだけ削除して次へ（前回中断の続きに対応）
  ↓ 未移行なら
context.insert(PhotoBlob(...)) して pendingFiles に積む
  ↓ 12件たまったら
commitBatch(): context.save() 成功 → その時だけ元ファイル削除
               失敗 → context.rollback() して failed に計上（ファイルは残る＝次回再試行）
  ↓ バッチ間
40ms の息継ぎ（Task.sleep）— UI・メインコンテキストのマージ処理に譲る
  ↓ 完走後
failed == 0 の時だけ完了フラグを立てる
```

### 教訓（重要度順）

1. **1件ごとに `context.save()` してはいけない**。数千回の書き込みトランザクション＋変更通知で WAL チェックポイントが多発し、アプリ全体が重くなる。→ バッチ（12件）でまとめて save ＋ バッチ間に短い sleep
2. **「保存成功 → 元データ削除」の順を厳守**。逆にするとデータ喪失の可能性が生まれる。失敗バッチは rollback してファイルを残し、次回起動で再試行
3. **冪等にする**（blob 既存チェック）。中断・再実行が前提の設計にする
4. 実績：4,808枚・1,201.9MB・失敗0件。移行後、tmp 掃除込みで「書類とデータ」2.61GB → 1.41GB

---

## 7. バックアップ（zip エクスポート/インポート）への影響

externalStorage の写真本体は **SQLite 本体（default.store）ではなく `_SUPPORT` ディレクトリ**に置かれる。store ファイルだけ zip に入れると**写真が全部消えたバックアップ**になる。

### エクスポート

Application Support 直下の以下の候補を実在チェックして**全部 zip に含める**（SwiftData のバージョン・構成で名前が揺れるため候補列挙方式）：

```swift
static var storeSupportDirectoryNames: [String] {
    [".default_SUPPORT", "default.store_SUPPORT", ".default.store_SUPPORT"]
}
```

（store 名を変えている場合は `<store名>_SUPPORT` / `.<store名>_SUPPORT` に読み替え）

### インポート

- 既存の `_SUPPORT` をバックアップ退避 → zip の内容で差し替え → 失敗時は復元、の3段構え
- store 差し替え後はプロセス内の ModelContainer が古いストアを掴んだままなので、**アプリ再起動を必須にする**（Mystorium は全操作ブロックの RestartRequiredOverlay 表示）
- 旧形式 zip（ファイル直置き時代）を読んだ場合に備え、移行フラグをリセットして再移行させる

### 検証ロジックの罠（2回連続でハマった）

- zip は**空ディレクトリを含まない**。マニフェストの「ファイル数」にディレクトリを数えていると、展開後の突合が必ずズレる → 枚数の厳密一致検証はしない。「期待>0 なのに展開0」のみ失敗とする
- サンプル存在チェックも「拡張子を持つファイルらしいパス」に限定する
- **教訓**：件数ベースの整合性検証は「数え方の定義」が両側で完全一致していない限り誤検知する。存在ベース（サンプル実在＋ゼロ件検知）に留める

---

## 8. クリーンアップ

- **オーファン blob 掃除**：全モデルから参照中の relativePath 集合（アイキャッチ＋全 Visit の photoPaths）を作り、`PhotoBlobStore.allEntries()` との差分を削除。`byteCount` 集計なので data 非フォールトで高速
- **一時ファイル掃除**：エクスポート zip・インポート作業ディレクトリは (a) 共有シート dismiss 直後に削除、(b) 起動時に prefix 一致（`○○Export_*` 等）で一掃、の二重防御。これを怠ると「書類とデータ」が実データの倍に膨れる（Mystorium で 1.2GB 分発覚）

---

## 9. CloudKit 本有効化への残作業（この仕様の到達点）

この仕様までで「CloudKit を ON にできる形式」が完成。実際の同期 ON は別バッチ：

1. Xcode で iCloud capability（CloudKit）＋ Background Modes（Remote notifications）を追加（entitlement はユーザーの Mac 作業）
2. `ModelConfiguration(cloudKitDatabase: .automatic)` へ切り替え（新スキーマバージョンとして）
3. **opt-in トグル**（設定画面）。ログイン UI は不要（iCloud アカウントは OS 任せ）
4. iCloud 容量不足時は同期が止まるだけでローカルは無傷 — エラー UI は「同期停止中」表示程度に留める
5. 通信量配慮：OS 設定（モバイルデータ通信 OFF）への誘導で対応（アプリ内 Wi-Fi 判定は作らない）
6. 動画は v1 では同期対象外（リンク・サムネイルのみ）。有効化前に概算容量（写真合計 = `totalByteCount()`）を表示する

---

## 10. favoreco 実装チェックリスト

- [ ] PhotoBlob モデルを初版スキーマに含める（§2 の3条件を全モデルで遵守）
- [ ] PhotoStorage 相当の API 層を作り、画面側は relativePath 文字列だけ扱う（§3）
- [ ] PhotoBlobStore 相当を `nonisolated enum` ＋ per-operation ModelContext で実装（§4・§5）
- [ ] 動画（や再生に fileURL が要るメディア）を扱うなら `video_` プレフィックスでファイル保存に振り分け
- [ ] エクスポート/インポートは `_SUPPORT` ディレクトリ同梱＋再起動必須フロー（§7）
- [ ] オーファン blob 掃除＋一時ファイル掃除（§8）
- [ ] 移行コードは不要（最初から blob）。ただしバックフィル一般の教訓（§6）は他機能で適用
