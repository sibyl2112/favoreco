# APP_NAME Project Log

> 「なぜそうしたか / どう遷移したか」を残すログ。仕様書が「今どうあるか」、ここが「なぜそうなったか」。
> 追記フォーマットは `docs/_templates/project-log-entry.md` を参照。

<!-- 新しい変更を上に追記していく -->

## 2026-07-10: 登録情報の非表示と期限通知キャンセルを追加

### 変更概要
- 登録情報編集画面に、既存 `TicketAccount` を非表示にする管理ボタンを追加した。
- 非表示時は `TicketAccount.isArchived = true`、`renewalNotify = false` にし、FC・会員期限通知をキャンセルするようにした。
- 非表示にした登録情報は、既存申込履歴を残したまま、申込フォーム候補とHome期限アテンションから外れる。

### 変更意図
登録情報を間違って作った場合や使わなくなったFC/会員/カード枠を安全に整理できるようにするため。チケット申込履歴との参照を壊さず、通知だけ残る事故を避ける。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（登録情報非表示導線）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedAccountArchiveNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機で非表示後に、登録情報一覧、申込フォーム候補、Home期限アテンションから消えることを確認する。
- 既存の申込詳細では、履歴として名義/アカウント参照が壊れないことを確認する。

## 2026-07-10: FC・会員期限アテンションと通知を接続

### 変更概要
- `TicketAccountNotificationScheduler` を追加し、FC・会員期限の30日前/7日前/当日朝通知を予約/キャンセルできるようにした。
- 登録情報保存時に、期限通知ONならFC・会員期限通知を再予約し、OFFならキャンセルするようにした。
- 通知設定で「通知を有効化」「FC・会員期限」を切り替えた時、既存登録情報の期限通知を予約/キャンセルするようにした。
- Homeアテンションに、期限通知ONかつ45日以内に期限が来る `TicketAccount` を表示するようにした。
- 実機確認は後回しにするため、確認項目を残課題に明記した。

### 変更意図
チケット周りの残りとして、申込や公演日だけでなく、FC・会員・カード枠などの更新期限を見落とさない導線を作るため。通知とHomeアテンションの両方に出すことで、通知許可をまだ出していないユーザーにも期限が見えるようにした。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Services/TicketAccountNotificationScheduler.swift（FC・会員期限通知）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（登録情報保存/通知設定変更時の予約・キャンセル）
- favorecoAPP/favorecoAPP/Views/HomeView.swift（FC・会員期限アテンション）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedMembershipNoSign CODE_SIGNING_ALLOWED=NO build` 成功。
- 実機通知の到達確認は後回し。

### 残課題
- 実機で通知許可ON後、登録情報の期限通知が30日前/7日前/当日朝に予約されることを確認する。
- 通知設定OFF、登録情報の期限通知OFF、登録情報削除/アーカイブ時に通知が残らないことを確認する。
- Homeアテンションに45日以内のFC・会員期限が表示され、期限切れ/通知OFF/アーカイブ済みは出ないことを確認する。
- チケット予定詳細のカレンダー追加、予定削除後のHome/Calendar非表示、申込通知キャンセルも実機で合わせて確認する。

## 2026-07-10: チケット周りv1を仕上げ

### 変更概要
- `EditTicketAttemptView` を追加し、1つの予定に複数のチケット申込を追加/編集できるようにした。
- `PlanDetailView` のメニューに、予定編集、申込追加、カレンダーに追加、予定削除を追加した。
- 申込カードをタップすると、該当 `TicketAttempt` を編集できるようにした。
- 申込削除は物理削除ではなくアーカイブ＋通知キャンセルにした。
- 予定削除は `Plan` と紐づく申込をアーカイブし、予定/申込の予約済み通知をキャンセルするようにした。
- 予定詳細から `CalendarEventEditSheet` を開き、外部カレンダーへ手動追加できるようにした。

### 変更意図
チケット管理v1として、予定作成、詳細確認、編集、複数申込、申込削除、予定削除、通知再予約/キャンセル、外部カレンダー手動追加まで一連の往復を成立させるため。ユーザーのデータを守るため、削除はまずアーカイブで扱う。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/EditTicketAttemptView.swift（申込単体の追加/編集）
- favorecoAPP/favorecoAPP/Views/PlanDetailView.swift（申込追加/編集、予定削除、カレンダー追加）
- favorecoAPP/favorecoAPP/Views/AddTicketPlanView.swift（共通日付行の可視性調整）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedTicketFinishNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機で通知到達、外部カレンダー追加、削除後のHome/Calendar非表示を確認する。
- 外部カレンダーイベントID保存と自動更新/削除追従は未実装。
- FC・会員期限通知は登録情報側の期限アテンション実装時に接続する。

## 2026-07-10: 予定・チケット編集と通知再予約を追加

### 変更概要
- `AddTicketPlanView` を追加/編集兼用にし、既存 `Plan` と最新 `TicketAttempt` からDraftへ読み込めるようにした。
- `PlanDetailView` に編集ボタンを追加し、予定・チケット詳細から編集シートを開けるようにした。
- 編集保存時に `Plan` / 最新 `TicketAttempt` を更新し、通知予約IDを更新して再予約するようにした。
- 編集時に申込情報をOFFにした場合、既存の最新 `TicketAttempt` を削除せずアーカイブし、該当通知をキャンセルするようにした。
- `TicketNotificationScheduler.cancel` を追加し、予定/チケット通知の明示キャンセルをできるようにした。

### 変更意図
Homeアテンション/Calendar/詳細画面で確認できる予定・チケットを、実際に修正できる状態へ進めるため。通知日時の変更や申込情報の取り消しに合わせて、古い通知が残らないよう再予約/キャンセルの基本動作も同時に接続した。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/AddTicketPlanView.swift（編集モード、既存Plan読み込み、更新保存）
- favorecoAPP/favorecoAPP/Views/PlanDetailView.swift（編集導線）
- favorecoAPP/favorecoAPP/Services/TicketNotificationScheduler.swift（通知キャンセル）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedPlanEditNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機で編集後の通知再予約/キャンセルを確認する。
- 複数TicketAttemptの編集・追加・履歴表示を作る。
- 予定/チケット削除と、外部カレンダー連携済みイベントの扱いを決める。

## 2026-07-10: 予定・チケット詳細画面を追加

### 変更概要
- `PlanDetailView` を追加し、予定の基本情報、公式情報、メモ、紐づくチケット申込を確認できるようにした。
- チケット申込カードで、状態、先行区分、名義/アカウント、申込開始/締切、当落、入金、発券、金額、座席、購入URL、メモを表示するようにした。
- Homeアテンションの予定/チケット行から `PlanDetailView` へ遷移できるようにした。
- Calendarの選択日/直近予定に出るPlan行から `PlanDetailView` へ遷移できるようにした。

### 変更意図
HomeアテンションとCalendarに出した予定・チケットを、タップして詳しく確認できる状態にするため。編集に進む前に、保存済みデータの見え方と情報量を先に固めた。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/PlanDetailView.swift（予定・チケット詳細画面）
- favorecoAPP/favorecoAPP/Views/HomeView.swift（Homeアテンションから予定詳細へ遷移）
- favorecoAPP/favorecoAPP/Views/MainTabView.swift（CalendarのPlan行から予定詳細へ遷移）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedPlanDetailNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 予定・チケット編集画面を作る。
- 編集後に通知再予約/キャンセルを行う。
- Home/Calendarから外部カレンダー追加や申込URLへ進む導線を整理する。

## 2026-07-10: Homeアテンションを予定・チケット中心へ接続

### 変更概要
- `HomeView` に `Plan` / `TicketAttempt` のQueryを追加し、横断ミニ統計の「今後の予定」に未来日Planを含めるようにした。
- Homeアテンションで、申込開始、申込締切、当落発表、入金締切、発券開始、公演予定を日付・優先度順に表示するようにした。
- 落選、参加済み、見送り、アーカイブ済みのチケット/予定はアテンションに出さないようにした。
- チケット系アテンションが足りない場合だけ、未来日Visitと未整理Inboxを補助表示するようにした。

### 変更意図
通知予約まで接続したチケット/予定情報を、アプリ起動直後に確認できる形へ進めるため。ユーザーがまず見るHomeのファーストビューに、締切・当落・入金・発券などの見落としたくない情報を集約する。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/HomeView.swift（Plan/TicketAttemptアテンション接続）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedHomeAttentionNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- Homeアテンションから予定/チケット詳細へ遷移する画面を作る。
- FC・会員期限、外部カレンダー予定、通知リマインダーを同じ枠へ追加する。
- 予定・チケット編集画面を作り、日付変更時の通知再予約とHome表示更新をつなぐ。

## 2026-07-10: チケット通知予約を予定・申込日付へ接続

### 変更概要
- `TicketNotificationScheduler` を追加し、`Plan` / `TicketAttempt` の日付からiOS通知を予約できるようにした。
- `AddTicketPlanView` の保存後に、通知設定とiOS通知許可状態を確認して、申込開始、申込締切、当落、入金締切、発券開始、公演前日/当日通知を予約するようにした。
- 通知予約IDを `TicketAttempt.notificationSettingsRaw` に保存し、再予約時は古い候補IDを削除してから追加するようにした。
- 締切系通知は前日と1時間前、公演通知は前日20:00と当日9:00を初期仕様にした。

### 変更意図
通知設定とチケット日付モデルをつなぎ、予定・申込を保存した時点で実際にリマインドできる状態へ進めるため。Homeアテンションやチケット編集画面へ進む前に、通知IDの命名と再予約の基本動作を先に固めた。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Services/TicketNotificationScheduler.swift（予定・申込通知予約サービス）
- favorecoAPP/favorecoAPP/Views/AddTicketPlanView.swift（保存後の通知予約接続）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedTicketNotificationsNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機で通知許可、予定保存後の通知予約、実通知到達を確認する。
- 予定・チケット編集画面で日付変更時の再予約/キャンセルを接続する。
- 通知設定を後からONにした時、既存予定へ一括再予約する導線を作る。
- Homeアテンションを `Plan` / `TicketAttempt` の締切・当落中心へ切り替える。

## 2026-07-10: 予定・チケット追加UIとカレンダー表示を接続

### 変更概要
- `AddTicketPlanView` を追加し、中央 `+` から「予定・チケットを追加」を開けるようにした。
- 予定のジャンル、タイトル、日時、開場、会場、公式URLを `Plan` として保存できるようにした。
- チケット申込を同時作成する場合、状態、先行区分、名義/アカウント、申込開始/締切、当落、入金、発券、金額、枚数、座席、購入URLを `TicketAttempt` として保存できるようにした。
- 登録情報・連携ハブで作った `TicketAccount` を申込の名義/アカウントとして選べるようにした。
- Calendarに `Plan` を表示し、月グリッド/選択日/直近予定で予定・チケットを確認できるようにした。

### 変更意図
前回追加した `Plan` / `TicketAttempt` / `TicketAccount` を、実際にユーザーが入力できる状態へ進めるため。まず保存と確認の往復を作り、次に通知予約やHomeアテンションへ接続できるようにした。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/AddTicketPlanView.swift（予定・チケット追加フォーム）
- favorecoAPP/favorecoAPP/Views/MainTabView.swift（中央+導線、CalendarのPlan表示）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedTicketPlanInputNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- `Plan` / `TicketAttempt` の編集画面を作る。
- 通知予約を申込開始/締切、当落、入金、発券、公演前日/当日へ接続する。
- Homeアテンションを `Plan` / `TicketAttempt` 中心へ切り替える。
- チケット申込一覧、当選率/名義別統計は後続。

## 2026-07-10: チケット予定モデルと登録情報ハブを追加

### 変更概要
- `Plan` / `TicketAttempt` / `TicketAccount` のSwiftDataモデルを追加し、アプリSchemaへ登録した。
- `Plan` を予定/公演回、`TicketAttempt` を申込1件、`TicketAccount` をFC/プレイガイド/劇場会員/カード枠などの登録情報として分離した。
- `TicketDefinitions` を追加し、チケット状態、先行区分、アカウント種別のキー/表示名を定義した。
- 設定 > マイ に「登録情報・連携」ハブを追加し、`TicketAccount` を登録/編集できるようにした。
- JSONバックアップに `Plan` / `TicketAccount` / `TicketAttempt` のDTOを追加した。Keychainパスワード本体は書き出さず、参照キーの有無だけを出す。
- `Color+Hex` にColorPicker保存用のHEX変換を追加した。

### 変更意図
チケット/予定管理をVisit直持ちから分離し、複数先行、落選履歴、名義別集計、通知更新に耐える土台を作るため。次に申込入力UIと通知予約を実装する前に、予定・申込・登録情報の責務境界を先に固定した。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Models/CoreModels.swift（Plan / TicketAccount / TicketAttempt追加）
- favorecoAPP/favorecoAPP/favorecoAPPApp.swift（Schema登録）
- favorecoAPP/favorecoAPP/Utilities/TicketDefinitions.swift（チケット定義）
- favorecoAPP/favorecoAPP/Utilities/Color+Hex.swift（HEX変換追加）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（登録情報・連携ハブ、JSONエクスポート追従）
- favorecoAPP/favorecoAPP/Services/JSONBackupExportService.swift（バックアップDTO追加）
- favorecoAPP/favorecoAPP/Services/ExternalCalendarOverlayService.swift（EventKit警告対策）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedTicketModelsNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- `Plan` / `TicketAttempt` の追加・編集UIを作る。
- 申込開始/締切、当落、入金、発券、公演前日/当日の通知予約を `TicketAttempt` / `Plan` の日付へ接続する。
- Homeアテンション、Calendar、Statsを未来日Visit中心からPlan/TicketAttempt中心へ切り替える。
- 既存 `Visit.outcomeKey` / `seatText` からTicketAttemptへ移行する導線を検討する。

## 2026-07-10: カレンダー重ね表示と通知設定を接続

### 変更概要
- EventKit読み取り用の `ExternalCalendarOverlayStore` を追加し、iOSカレンダーに登録済みの外部予定をDTOとして取得できるようにした。
- `CalendarView` に「外部カレンダーを重ねる」トグル、権限表示、許可ボタン、再読み込みボタンを追加した。
- 月カレンダーではFavoreco記録の点と外部予定の点を分け、選択日/直近予定に外部カレンダー行を薄く表示するようにした。
- `NotificationSettingsView` をプレースホルダーから、通知全体と通知タイプ別ON/OFFを保存する画面に変更した。
- 通知全体ON時に `UNUserNotificationCenter` の通知許可を求め、iOS通知許可状態を表示するようにした。
- 写真ユニット内のサムネイルプレビューへ選択中のカバー比率を反映し、御朱印ジャンルでは未設定時に標準御朱印帳サイズを補完するようにした。

### 変更意図
チケット/予定モデルに進む前に、カレンダーと通知のOS連携の入口を固めるため。外部カレンダーはFavorecoの正本データに混ぜず、予定把握用の読み取りレイヤーとして扱う。通知は予約対象の日付モデルが揃う前に、まずユーザーが必要な通知タイプを選べる設定を実データとして保持する。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Services/ExternalCalendarOverlayService.swift（EventKit読み取りサービス）
- favorecoAPP/favorecoAPP/Views/MainTabView.swift（外部カレンダー重ね表示）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（通知設定の保存/許可接続）
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（写真比率プレビュー/御朱印帳サイズ補完）
- favorecoAPP/favorecoAPP/Utilities/AppStorageKeys.swift（通知/外部カレンダー設定キー追加）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedCalendarNotificationNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機で外部カレンダー権限ダイアログ、Googleカレンダー予定の表示、外部予定の色/件数表示を確認する。
- 通知の実予約は、次の `Plan` / `TicketAttempt` / 公演日モデル追加後に接続する。

## 2026-07-10: 写真カバー比率と御朱印帳ユニットを接続

### 変更概要
- 写真ユニットにカバー比率Pickerを追加し、正方形、映画ポスター、チラシ/ポスター、書影、横長ラベル、御朱印帳標準から選べるようにした。
- `VisitUnitFields` に `eyecatchAspectRatioKey` と `goshuinBookSizeKey` を追加した。
- 御朱印ジャンル向けに `goshuinBook` ユニットを追加し、御朱印帳サイズを保存できるようにした。
- 御朱印ジャンルの初期有効ユニットに `goshuinBook` を含めた。

### 変更意図
写真/カバー/比率指定まわりを、将来のカード表示・レポート画像化・御朱印帳表示へつなげるため。ジャンルごとに写真の自然な比率が違うため、画像自体を切り抜く前に記録側へ表示意図を保存する。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Utilities/EyecatchAspectRatio.swift（比率/御朱印帳サイズ定義）
- favorecoAPP/favorecoAPP/Utilities/VisitUnitFields.swift（保存項目追加）
- favorecoAPP/favorecoAPP/Utilities/RecordUnitDefinition.swift（御朱印帳ユニット追加）
- favorecoAPP/favorecoAPP/Services/CategoryPresetSeeder.swift（御朱印ジャンルの初期ユニット更新）
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（写真比率/御朱印帳入力UI接続）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedPhotoRatioNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機で写真比率Picker、御朱印帳サイズPicker、既存記録編集時の復元を確認する。
- 選択した比率をHome/一覧/詳細/レポート画像の表示に反映する処理は後続で行う。

## 2026-07-10: 思い出レポートのカードプレビューを追加

### 変更概要
- `月刊Favoreco` / `年間Favoreco` 下書き画面にカードプレビューを追加した。
- カード内に、レポート名、対象期間、記録数、写真数、ジャンル数、最多ジャンル、よく出てきた場所、カード候補を表示した。
- 画像書き出し前の見た目確認として、アクセントカラーの薄いグラデーションを使った。

### 変更意図
共有テキストだけではレポートの完成形が見えにくいため、まず画面内で「思い出カードっぽい」見た目を確認できるようにするため。次の画像化/保存/共有に進む前のUI土台にする。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/MainTabView.swift（カードプレビュー追加）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedReportCardPreviewNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機でカードの情報量、Dynamic Type、長い会場名/タイトルの折り返しを確認する。
- 画像として書き出す処理、保存、SNS向けテンプレは未実装。

## 2026-07-10: 思い出レポートを共有シートから送れるようにした

### 変更概要
- `月刊Favoreco` / `年間Favoreco` 下書き画面に `共有する` ボタンを追加した。
- 共有用テキストを `ShareLink` でiOS共有シートへ渡せるようにした。
- コピー導線は `テキストをコピー` として残した。

### 変更意図
クリップボード経由だけでなく、標準共有シートから直接メッセージやSNSへ送れるようにするため。画像カード化の前に、共有文の内容と共有導線の手触りを確認できる状態にした。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/MainTabView.swift（ShareLink追加）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedReportShareLinkNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機で共有シートの表示、各アプリへの渡り方、共有文の長さを確認する。
- 画像カード生成、保存、SNS向けテンプレは未実装。

## 2026-07-10: 思い出レポートの共有用テキストコピーを実装

### 変更概要
- `月刊Favoreco` / `年間Favoreco` 下書き画面に、共有用テキストをコピーするボタンを追加した。
- コピー内容は、記録数、写真数、ジャンル数、平均評価、最多ジャンル、よく出てきた場所、カード候補、`#Favoreco` を含む要約にした。
- コピー後に確認アラートを表示するようにした。

### 変更意図
画像化の前段として、まずレポートの要約を外へ出せる軽い共有導線を作るため。将来の画像カード生成やShareLink接続に進む前に、どの情報を共有するかの形を固める。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/MainTabView.swift（共有用テキストコピー追加）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedReportCopyNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機でクリップボードコピー、アラート、共有文言の長さを確認する。
- 画像カード生成、ShareLink、保存、SNS向けテンプレは未実装。

## 2026-07-10: 月刊/年間Favorecoの下書き画面を実装

### 変更概要
- 統計タブの `月刊Favoreco` / `年間Favoreco` をタップ可能にした。
- 今月/今年のVisitから、記録数、写真数、ジャンル数、平均評価、最多ジャンル、最多場所、金額、ジャンル傾向、カード候補を表示する下書き画面を追加した。
- 下書き画面でも金額は初期非表示にし、目アイコンで表示/非表示を切り替えるようにした。

### 変更意図
Premium候補の自動思い出レポートを、単なる予告ではなく、まずローカル集計の下書きとして触れる状態にするため。画像化、自動生成、同期込みのレポートへ進む前に、どんな情報がカード化に使えるかを画面で確認できるようにした。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/MainTabView.swift（レポート下書き画面追加）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedReportDraftNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機で月刊/年間カードのタップ感、空データ、多件データ、金額伏せ字、Dynamic Type時の見え方を確認する。
- レポート画像化、共有、通知、自動生成、去年同月比較、同期込み集計は未実装。

## 2026-07-10: 思い出レポートをPremium候補として画面に反映

### 変更概要
- 統計タブに `月刊Favoreco` / `年間Favoreco` の思い出レポート予告枠を追加した。
- 課金・プラン画面の同期プラン候補に `自動思い出レポート` を追加した。
- 正本仕様に、基本統計=無料、詳細統計/年間まとめ=Pro、同期込み自動レポート=Premium候補の境界を追記した。

### 変更意図
サブスクの価値を「同期だけ」ではなく、毎月/毎年、自動で届く思い出カードとして見せる方向に固めるため。Spotify Wrapped、Apple Music Replay、Google Photos Memories、日記アプリの要約系に近い価値を、favorecoでは体験記録・写真・ジャンル横断の文脈で出す。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/MainTabView.swift（思い出レポート予告枠追加）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（同期プラン候補に自動思い出レポート追加）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedReportPreviewNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機で統計タブ下部の情報量、ロック表現の強さ、無料ユーザーへの圧迫感を確認する。
- 実際の月次カード/年間カード生成、通知、自動生成、画像書き出しは未実装。

## 2026-07-10: 統計の金額を初期非表示にした

### 変更概要
- 統計タブの `記録済み金額` カードを、初期状態では伏せ字表示に変更した。
- 目アイコンで金額の表示/非表示を切り替えられるようにした。
- 金額表示に `privacySensitive` を付け、プライバシー情報として扱う意図をコード上にも反映した。

### 変更意図
金額はチケット代、遠征費、購入額など生活情報に近いプライバシー情報なので、統計画面を開いた瞬間に見えないよう配慮するため。無料/有料に関係なく、金額系の統計はユーザー操作で明示的に見る方針にする。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/MainTabView.swift（支出カードの非表示/表示切替）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedStatsPrivacyNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機で目アイコンのタップ領域、Dynamic Type時の金額伏せ字表示、スクリーンショット/画面共有時の見え方を確認する。

## 2026-07-10: 統計タブに簡易集計を実装

### 変更概要
- `StatsView` を準備中表示から、保存済みVisitを集計する簡易統計画面へ変更した。
- 総記録数、今年の記録、今月の記録、平均評価のサマリーカードを追加した。
- ジャンル別回数、記録済み金額、評価概要を表示するセクションを追加した。

### 変更意図
Home横断ミニ統計に続いて、下部タブの「統計」も空の入口ではなく、記録が増えた時にすぐ価値が出る最低限の集計画面にするため。詳細統計や年間まとめは後続で拡張し、まず無料で見られる基本統計を先に固める。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/MainTabView.swift（StatsView実装）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedStatsTabNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機で0件、1件、多件、金額未入力、評価未入力、Dynamic Type時の見え方を確認する。
- 詳細統計、期間切替、年間まとめ、グラフ、Plan/TicketAttempt追加後の予定/申込統計は未実装。

## 2026-07-10: カレンダータブを月表示にした

### 変更概要
- `CalendarView` をプレースホルダーから、Visitの日付を表示する月カレンダーへ変更した。
- 月移動、日付選択、記録がある日のドット表示、選択日の記録一覧、直近予定一覧を追加した。
- カレンダー上の記録から `ExperienceDetailView` へ遷移できるようにした。

### 変更意図
外部カレンダーへ手動追加できるようになったため、アプリ内でも日付軸で記録を見返せる最低限のカレンダーを先に作るため。予定/申込/訪問済みの厳密な分離は後続のPlan/TicketAttemptモデルで拡張する。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/MainTabView.swift（CalendarView実装）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedCalendarTabNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機で月初曜日、縦幅、Dynamic Type、記録件数が多い日の見え方を確認する。
- 外部カレンダー読み取り重ね表示、Plan/TicketAttemptによる予定/申込の分離は未実装。

## 2026-07-10: 記録詳細からカレンダー手動追加を実装

### 変更概要
- `CalendarEventEditSheet` を追加し、EventKitUIのネイティブイベント編集画面をSwiftUIから表示できるようにした。
- `ExperienceDetailView` の基本情報に `カレンダーに追加` ボタンを追加した。
- カレンダー追加時に、記録タイトル、日時、場所、座席、チケット状態、金額、メモ、公式URLをイベント下書きへ入れるようにした。
- 生成Info.plist用にカレンダー利用説明文をDebug/Release両方へ追加した。

### 変更意図
無料機能として決めていた「手動でカレンダーに追加」を、Mystorium同様にユーザー操作で使える状態にするため。ネイティブ編集画面を使うことで、iOSに登録済みのApple/Googleカレンダーをユーザーが選べる余地を残す。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Services/CalendarEventEditSheet.swift（EventKitUIラッパー追加）
- favorecoAPP/favorecoAPP/Views/ExperienceDetailView.swift（カレンダー追加ボタンとイベント下書き作成）
- favorecoAPP/favorecoAPP.xcodeproj/project.pbxproj（カレンダー利用説明文追加）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedCalendarAddNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機で初回権限ダイアログ、保存/キャンセル、Googleカレンダー選択の挙動を確認する。
- 外部カレンダーイベントIDの保存、更新/削除、読み取り重ね表示は未実装。

## 2026-07-10: 初回説明オンボーディングを実装

### 変更概要
- `GenreOnboardingView` をジャンル選択直行から、説明4ステップ + ジャンル選択 + 開始確認の流れに変更した。
- 価値訴求、記録できる内容、ジャンル横断、安心材料を短く見せてからジャンル選択に進むようにした。
- 既存の「1ジャンル以上必須」「最後に有効ジャンル0件にしない」保存ルールは維持した。

### 変更意図
初回ユーザーに、何のアプリか、何を残せるか、なぜジャンルを選ぶのかを先に伝えるため。権限要求や同期案内は初回で重くせず、まずHomeへ入れる軽い導線にする。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/GenreOnboardingView.swift（初回説明ステップとUI部品追加）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedOnboardingFlowNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 実機で縦幅の短い端末やDynamic Type時の見え方を確認する。
- 文言とステップ数は実機確認後に短縮/調整する。

## 2026-07-10: JSONバックアップを書き出せるようにした

### 変更概要
- `JSONBackupExportService` を追加し、復元前提の手動バックアップJSONを生成できるようにした。
- データ管理の `JSONエクスポート` を準備中ページから実際の書き出し画面へ差し替えた。
- JSON書き出し画面で、ジャンル/対象/Visit/人物/人物リンク/場所/Inbox/SNS/写真メタデータの件数を確認できるようにした。

### 変更意図
CSVは表計算向けの見返し用なので、アプリへ戻す将来復元に備えた構造化バックアップも無料の安全網として早めに置くため。写真バイナリは容量と復元設計が重いため、今回は記録本体と紐付けID、写真メタデータまでに限定した。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Services/JSONBackupExportService.swift（バックアップDTOとJSON FileDocument追加）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（JSONエクスポート画面追加）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedJSONExportNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- JSONインポート/復元、写真/動画バイナリを含む完全バックアップ、バックアップ互換性チェックは未実装。
- 将来の復元時は既存データを壊さないマージ方式と、ID衝突時の扱いを設計する。

## 2026-07-10: CSVエクスポートを実装

### 変更概要
- `CSVExportService` を追加し、保存済みVisitをUTF-8 CSVに変換できるようにした。
- データ管理の `CSVエクスポート` を準備中ページから実際の書き出し画面へ差し替えた。
- CSV書き出し画面で対象件数、形式、写真を含めないこと、出力列を確認できるようにした。

### 変更意図
無料で守る手動バックアップ/持ち出し導線の最初の実処理として、表計算アプリで開ける記録一覧CSVを出せるようにするため。JSONバックアップより先に軽いCSVを入れることで、端末内データを確認・退避しやすくする。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Services/CSVExportService.swift（CSV生成とFileDocument追加）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（CSVエクスポート画面追加）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedCSVExportNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- JSONバックアップ、CSVインポート、写真を含むバックアップは未実装。
- 人物・団体、写真、詳細オプションなどの複雑なサブデータをCSVへ展開するかは後続で検討する。

## 2026-07-10: Homeにも人物・団体サマリーを反映

### 変更概要
- Homeの最近の記録を共通 `VisitSummaryRow` へ差し替えた。
- 体験ギャラリーカードにも `EventPersonLink` から人物・団体を最大2件表示するようにした。
- Home内の独自 `VisitRow` / `FlowMetaItem` / `FlowMetaLine` を削除し、一覧表現の重複を減らした。

### 変更意図
Records、カテゴリトップ、対象詳細の履歴で人物・団体が見えるようになったため、Homeでも同じ情報が自然に見えるように揃えるため。Homeはアプリを開いた最初の見返し面なので、写真・場所だけでなく「誰の体験か」も短く出す。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/HomeView.swift（Home最近の記録を共通サマリーへ差し替え、ギャラリーに人物・団体表示追加）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedHomePeopleNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 役割表示やジャンル別の人物ラベル最適化は後続で調整する。
- Homeの体験ギャラリーは現状 `@Query` で人物リンクを参照しているため、件数が増えた段階でSnapshot/DTO化を検討する。

## 2026-07-10: AppIconをワインレッドしおり案へ差し替え

### 変更概要
- XcodeのAppIcon本体を `favoreco-app-icon-wine-bookmark-1024.png` へ差し替えた。
- AppIcon.appiconset内の未参照PNGを削除し、asset catalog警告が出ない状態にした。

### 変更意図
ワインレッド系の高級感と、Fなししおりモチーフのわかりやすさを実機確認できる状態にするため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Assets.xcassets/AppIcon.appiconset/Contents.json（AppIcon参照差し替え）
- favorecoAPP/favorecoAPP/Assets.xcassets/AppIcon.appiconset/favoreco-app-icon-wine-bookmark-1024.png（Xcode AppIcon用PNG）
- favorecoAPP/favorecoAPP/Assets.xcassets/AppIcon.appiconset/favoreco-app-icon-1024.png（未参照旧PNGを削除）
- favorecoAPP/favorecoAPP/Assets.xcassets/AppIcon.appiconset/favoreco-app-icon-no-f-bookmark-1024.png（未参照旧PNGを削除）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `sips` で1024x1024pxであることを確認。
- ビルド確認は下の人物サマリー実装とまとめて実施。

### 残課題
- 実機ホーム画面で小サイズ視認性を確認する。

## 2026-07-10: 人物サマリーと対象履歴行を強化

### 変更概要
- `VisitSummaryRow` に `EventPersonLink` の簡易取得を追加し、人物・団体を最大2件までサマリー表示するようにした。
- `EventDetailView` の履歴行を独自の `EventVisitRow` から `VisitSummaryRow` に差し替えた。
- 未使用になった `EventVisitRow` を削除した。
- AppIcon.appiconset内に残っていた未参照の旧アイコンPNGを削除し、asset catalog警告を解消した。

### 変更意図
人物・団体ユニットを入力できるようになったため、詳細画面を開かなくても一覧で「誰に紐づく記録か」が見えるようにするため。対象詳細の履歴もRecords/カテゴリ内最近の記録と同じ情報密度に揃えた。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/VisitSummaryRow.swift（人物・団体サマリー表示追加）
- favorecoAPP/favorecoAPP/Views/EventDetailView.swift（履歴行を共通サマリー行へ差し替え）
- favorecoAPP/favorecoAPP/Assets.xcassets/AppIcon.appiconset/favoreco-app-icon-1024.png（未参照旧アイコンPNGを削除）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedPersonSummaryIconNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 人物・団体の表示順/役割表示は簡易。ジャンル別サマリーで「主演」「作者」「アーティスト」などの見せ方を後続で調整する。
- Home内の独自サマリーカードにも人物表示を横展開する。

## 2026-07-10: AppIconをFなししおり案へ差し替え

### 変更概要
- XcodeのAppIcon本体を `favoreco-app-icon-no-f-bookmark-1024.png` へ差し替えた。
- ライト/ダーク/ティント用のAppIconエントリすべてで同じ1024px画像を参照するようにした。

### 変更意図
F文字に依存しない、体験記録/しおり感が伝わる案を実機確認できる状態にするため。比較用に作成した候補のうち、まずFなししおり案をアプリ本体へ反映した。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Assets.xcassets/AppIcon.appiconset/Contents.json（AppIcon参照差し替え）
- favorecoAPP/favorecoAPP/Assets.xcassets/AppIcon.appiconset/favoreco-app-icon-no-f-bookmark-1024.png（Xcode AppIcon用PNG）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `sips` で1024x1024pxであることを確認。
- ビルド/実機確認は未実施。

### 残課題
- 実機ホーム画面で小サイズ視認性を確認する。
- 必要なら採用案を再度差し替える。

## 2026-07-10: 記録一覧とカテゴリ内記録にサマリー行を適用

### 変更概要
- `VisitSummaryRow` を追加し、記録一覧で写真、カテゴリ、日付、場所、評価、チケット状態、金額、OCR/詳細オプション有無、短いメモを表示できるようにした。
- `RecordsView` の行表示を `VisitSummaryRow` に差し替え、Listの余白と区切り線を調整した。
- `CategoryTopView` の最近の記録にも同じサマリー行を適用し、カテゴリ内ではカテゴリ名を省略するようにした。

### 変更意図
Homeだけでなく、記録一覧やカテゴリ内でも保存したユニット情報が見えるようにするため。写真、予定状態、支出、OCR/詳細有無が一覧で見えることで、詳細画面を開く前に記録の内容を思い出しやすくする。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/VisitSummaryRow.swift（共通サマリー行追加）
- favorecoAPP/favorecoAPP/Views/MainTabView.swift（RecordsViewに適用）
- favorecoAPP/favorecoAPP/Views/CategoryTopView.swift（カテゴリ内最近の記録に適用）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedVisitSummaryNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- Home側の独自カードと共通サマリー部品の重複整理は後続で行う。
- 人物・団体のサマリー表示、EventDetailView履歴行への横展開は未実装。

## 2026-07-10: Homeサマリーカードの表示情報を強化

### 変更概要
- Homeの体験ギャラリーカードに、カテゴリ、チケット状態、日付、場所、金額、OCR有無、詳細オプション有無を表示するようにした。
- Homeの最近の記録カードに、写真サムネイル、カテゴリ色、日付、場所、評価、チケット状態、金額、OCR/詳細オプション有無、短いメモを表示するようにした。
- 写真がない記録ではジャンルアイコンとテーマカラーを使ったプレースホルダーを表示するようにした。

### 変更意図
標準入力ユニットが一通り保存できるようになったため、Homeで「何を記録したか」が一目でわかる状態に近づけるため。詳細画面まで開かなくても、写真・予定状態・支出・取込有無が見えると、アプリを開いた時の見返し体験が強くなる。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/HomeView.swift（体験ギャラリー/最近の記録カード強化）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedHomeCardsNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 人物・団体のサマリー表示は未接続。`EventPersonLink` の取得方法を整理してから追加する。
- RecordsView / CategoryTopView / EventDetailView の一覧行にも同じサマリー表現を横展開する。

## 2026-07-10: 詳細オプションユニットの実入力を追加

### 変更概要
- `advanced` ユニットを準備中表示から実入力に変更した。
- 新規記録、既存対象への回追加、保存済み記録編集で、ラベル/値の自由項目を複数追加できるようにした。
- 自由項目は `VisitUnitFields.advancedEntries` として `Visit.unitFieldsRaw` にJSON保存する。
- 空の自由項目は保存時に除外し、詳細画面には入力済み項目だけ表示するようにした。
- 記録詳細画面に `詳細オプション` セクションを追加した。

### 変更意図
ジャンルごとに必要な細かい項目は実データを触るまで揺れるため、いきなり専用モデルにせず、まず自由項目として保存できる受け皿を作った。日本酒の精米歩合、美術展の所要時間、御朱印の印種別など、後から検索/統計に昇格したい値の試験場として使う。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（詳細オプション入力、保存、編集、回追加への接続）
- favorecoAPP/favorecoAPP/Views/ExperienceDetailView.swift（詳細オプション表示）
- favorecoAPP/favorecoAPP/Utilities/VisitUnitFields.swift（自由項目配列を追加）
- favorecoAPP/favorecoAPP/Utilities/RecordUnitDefinition.swift（advancedユニットを実装済みに変更）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedAdvancedNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- ジャンル別の詳細項目プリセット、入力型（数値/日付/選択肢）、統計への昇格は後続で行う。
- 自由項目の並び替え、テンプレ保存、重複ラベル補正は未実装。

## 2026-07-10: OCR・取込ユニットの実入力を追加

### 変更概要
- `importOCR` ユニットを準備中表示から実入力に変更した。
- 新規記録、既存対象への回追加、保存済み記録編集で、画像からVision OCRを実行し、読み取りテキストを保存できるようにした。
- 読み取り結果は手入力で修正・追記できるテキスト欄として扱い、`Visit.unitFieldsRaw` にJSON保存するようにした。
- 記録詳細画面に、保存済みOCRテキストを表示する `OCR・取込` セクションを追加した。
- `VisitUnitFields` を追加し、ジャンル別の追加ユニット値を後続で拡張できる保存形式にした。

### 変更意図
半券、チケット、レシート、リスト画像から文字を拾えると入力負荷が下がるため、まずはタイトル/日時/会場への自動振り分けではなく、読み取り結果を安全に保存・編集・詳細確認できる受け皿を作った。後続でURL取込やOCR高度化、項目候補への振り分けを重ねられるよう、`unitFieldsRaw` のJSONに閉じ込めた。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（OCR画像選択、Vision OCR、読み取りテキスト入力/保存）
- favorecoAPP/favorecoAPP/Views/ExperienceDetailView.swift（OCRテキスト表示）
- favorecoAPP/favorecoAPP/Utilities/VisitUnitFields.swift（追加ユニット値のJSON保存形式）
- favorecoAPP/favorecoAPP/Utilities/RecordUnitDefinition.swift（importOCRユニットを実装済みに変更）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedOCRNoSign2 CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- OCR結果をタイトル、日時、会場、金額、人物などへ自動候補化する処理は未実装。
- 複数画像OCR、OCR履歴、チケット写真との紐付け、Pro向け高度OCRは後続で行う。

## 2026-07-10: チケット・予定ユニットの実入力を追加

### 変更概要
- `ticketPlan` ユニットを準備中表示から実入力に変更した。
- 新規記録、既存対象への回追加、保存済み記録編集で、チケット状態と座席・チケットメモを入力できるようにした。
- チケット状態は `Visit.outcomeKey`、座席・チケットメモは `Visit.seatText` に保存する。
- 記録詳細画面の基本情報に、チケット状態と座席・チケットメモが入力されている場合だけ表示するようにした。
- `RecordUnitDefinition` で `ticketPlan` を実装済みユニットとして扱うようにした。

### 変更意図
観劇/ライブ/テーマパーク系で重要な「申込中」「当選」「発券済み」「座席」を、まず既存の `Visit` フィールドに接続して実データを入れられるようにした。申込締切、当落日、入金期限、発券日などの細かい予定管理は後続で専用モデル/通知と合わせて拡張する。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（チケット・予定入力、保存、編集、回追加への接続）
- favorecoAPP/favorecoAPP/Views/ExperienceDetailView.swift（チケット状態/座席メモ表示）
- favorecoAPP/favorecoAPP/Utilities/RecordUnitDefinition.swift（ticketPlanユニットを実装済みに変更）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedTicketPlanNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 申込締切、当落日、入金期限、発券日、公演前日/当日通知への接続は未実装。
- チケット画像/OCRとの連携、席種/座席の構造化、カレンダー反映は後続で行う。

## 2026-07-10: 金額ユニットの実入力を追加

### 変更概要
- `money` ユニットを準備中表示から実入力に変更した。
- 新規記録、既存対象への回追加、保存済み記録編集で、合計金額を入力できるようにした。
- 入力値は `Visit.amount` に `Decimal` として保存し、カンマ、円記号付きの入力も数値化するようにした。
- 記録詳細画面の基本情報に、金額が入力されている場合だけ円表示で出すようにした。
- `RecordUnitDefinition` で `money` を実装済みユニットとして扱うようにした。

### 変更意図
チケット代、購入額、交通費などはジャンル横断の統計や年間まとめで使えるため、まずは内訳管理ではなく「合計金額メモ」として保存できる状態にした。費目別の詳細管理や遠征費分解は、実データの使い方を見ながら後続で追加する。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（金額入力、保存、編集、回追加への接続）
- favorecoAPP/favorecoAPP/Views/ExperienceDetailView.swift（金額表示）
- favorecoAPP/favorecoAPP/Utilities/RecordUnitDefinition.swift（moneyユニットを実装済みに変更）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -quiet -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/favorecoDerivedMoneyUnitNoSign CODE_SIGNING_ALLOWED=NO build` 成功。

### 残課題
- 金額内訳、費目別管理、統計画面への反映は未実装。
- 無料/有料境界に応じた高度な統計表示は後続で行う。

## 2026-07-10: 人物・団体ユニットの実入力を追加

### 変更概要
- `people` ユニットを準備中表示から実入力に変更した。
- 新規記録、既存対象への回追加、保存済み記録編集で、人物・団体名と役割を追加できるようにした。
- 入力された人物・団体は `PersonMaster` を正規化名で再利用し、なければ新規作成するようにした。
- `ExperienceEvent` / `Visit` との紐付けは `EventPersonLink` に保存し、役割はリンク側の `roleKey` / `displayRole` に持たせた。
- 編集画面では保存済みリンクの削除予約と、新規追加予定リンクの削除ができるようにした。
- 入力中の名前に対して、既存 `PersonMaster` から簡易候補を表示するようにした。
- 記録詳細画面に、人物・団体を役割つきで表示するセクションを追加した。
- `RecordUnitDefinition` で `people` を実装済みユニットとして扱うようにした。

### 変更意図
観劇/ライブ/映画/本/美術展などで、人物・団体は記録価値と後続の統計・検索・重複統合に直結するため、早めにマスターとリンクを実際に動かすため。巨大な外部名鑑やApple Music連携はまだ接続せず、まずは手入力で正本データを作り、後から外部候補を入力補助として重ねられる構造にした。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（人物・団体入力、既存候補、PersonMaster再利用、EventPersonLink保存）
- favorecoAPP/favorecoAPP/Views/ExperienceDetailView.swift（人物・団体セクション表示）
- favorecoAPP/favorecoAPP/Utilities/RecordUnitDefinition.swift（peopleユニットを実装済みに変更）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/favorecoDerivedPeopleUnit build` 成功。

### 残課題
- PersonMaster一覧、詳細編集、重複統合UIは未実装。
- Apple Music / MusicBrainz / Wikidata / TMDb等の外部候補は未接続。
- Home/一覧/サマリーカードへの人物・団体表示は未接続。
- 役割プリセットは共通固定。ジャンル別の初期候補最適化は後続で行う。

## 2026-07-10: 写真ユニットの実入力を追加

### 変更概要
- `AddExperienceView` / `AddVisitView` / `EditExperienceView` の `photos` ユニットを準備中表示から実入力に変更した。
- 写真ライブラリから画像を選択し、JPEG 85%・最大幅1600pxに再エンコードして `PhotoBlob.data` に保存するようにした。
- 新規記録、既存対象への回追加、保存済み記録編集のすべてで写真追加を可能にした。
- 編集画面では保存済み写真のサムネイル表示と削除予約、新規追加予定写真の削除ができるようにした。
- 1記録あたり写真10枚までの上限表示を追加した。
- 記録詳細画面で、写真が1枚なら大きく、複数枚ならグリッドで表示するようにした。
- `RecordUnitDefinition` で `photos` と `officialInfo` を実装済みユニットとして扱うようにした。

### 変更意図
仮データだけでなく、実際の記録でも写真付きの体験を残せるようにするため。favorecoは写真が主役の体験記録アプリなので、入力アコーディオンの次に写真ユニットを接続し、Home/詳細で見返す流れを早期に確認できるようにした。写真メタデータ削除方針に合わせ、保存時は元データをそのまま持たず、再エンコードした画像データを保存する。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（写真選択・サムネイル・削除・PhotoBlob保存）
- favorecoAPP/favorecoAPP/Views/ExperienceDetailView.swift（複数写真表示）
- favorecoAPP/favorecoAPP/Utilities/RecordUnitDefinition.swift（写真/公式情報ユニットを実装済みに変更）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/favorecoDerivedPhotoUnit build` 成功。

### 残課題
- カメラ直起動、カバー写真指定、写真の並び替え、動画サムネイル、バックグラウンド画像処理は未実装。
- 写真メタデータ削除は再エンコードで落とす方針の初期実装。今後、ImageIOでの明示的なメタデータ除去確認を追加する。
- 写真上限10枚はUI表示のみ。将来の課金/権利判定と厳密に接続する。

## 2026-07-10: 入力アコーディオン土台と仮データ削除/写真表示を追加

### 変更概要
- `AddExperienceView` / `EditExperienceView` / `AddVisitView` を、ユニット単位の `DisclosureGroup` で入力する土台に変更した。
- `basic`、`officialInfo`、`memo` は既存保存項目に接続し、`people`、`ticketPlan`、`photos`、`importOCR`、`money`、`advanced` は準備中ユニットとして表示するようにした。
- 各ユニットに、必須/入力済み/任意/準備中のステータスを表示した。
- `DebugDataSeeder` の仮データ挿入を、先頭4ジャンルではなく全ジャンルに1件ずつ作るように変更した。
- 仮データ挿入前に既存の仮データを削除し、重複して増え続けないようにした。
- 設定の開発セクションに `仮データを削除` ボタンを追加した。
- 仮データ写真を1px PNGではなく、ジャンル色のPNGとして生成して `PhotoBlob.data` に保存するようにした。
- Homeの体験ギャラリーと記録詳細で、先頭の `PhotoBlob.data` を実画像として表示するようにした。

### 変更意図
ジャンルごとに入力項目が長くなる前提に合わせ、早い段階でMystorium同様の折りたたみ入力構造へ移行するため。仮データは画面確認用なので、各ジャンルに最低1件あり、写真が実際に見える必要がある。追加だけで削除できないと検証データが増え続けるため、通常データと区別できるデバッグURL/パスを使って安全に削除できるようにした。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（入力アコーディオン土台）
- favorecoAPP/favorecoAPP/Services/DebugDataSeeder.swift（全ジャンル仮データ、写真生成、削除処理）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（仮データ削除ボタン）
- favorecoAPP/favorecoAPP/Views/HomeView.swift（ギャラリー写真表示）
- favorecoAPP/favorecoAPP/Views/ExperienceDetailView.swift（詳細写真表示）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/favorecoDerivedAccordionDebug build` 成功。

### 残課題
- `people`、`ticketPlan`、`photos`、`importOCR`、`money`、`advanced` の実入力UIを順番に接続する。
- 仮データ写真のデザインは検証用の簡易画像なので、本番サンプル用には後でカテゴリ別の見栄えを調整する。
- 仮データ削除はデバッグ用URL/パスのみを対象にしているため、将来のデバッグデータ拡張時は同じ識別ルールを守る。

## 2026-07-10: 課金・プラン画面に無料/有料境界を表示

### 変更概要
- `BillingPlanSettingsView` に、無料で使えること、Pro買い切り候補、同期サブスク候補、フル買い切り候補の表示を追加した。
- 無料枠には、基本記録、写真10枚、カレンダー手動追加/追加先選択、手動バックアップを明記した。
- Pro買い切り候補には、詳細統計/年間まとめ、OCR高度化、テーマ/フォント拡張を表示した。
- 同期サブスク候補には、iCloud同期、自動バックアップ、継続更新される入力補助/参照データ候補を表示した。
- フル買い切り候補には、ライト買い切り+同期永久の頭金方式を表示した。
- StoreKitは未接続のまま、購入/復元は入口のみ維持した。

### 変更意図
課金実装前に、ユーザーにも開発側にも無料/有料の境界が見える状態にするため。購入処理を先に作ると後から文言やプラン構造を変えづらいため、まず設定画面に仕様を反映し、アプリ内の情報設計を固める。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（課金・プラン画面の境界表示追加）
- favoreco/CLAUDE.md（課金・プラン画面の現仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/favorecoDerivedBillingPlan build` 成功。

### 残課題
- StoreKit商品ID、価格、購入復元、権利判定を実装する。
- 実際の無料制限、Pro解放、同期サブスク解放を機能フラグに接続する。
- DBパックの扱いは、参照データの権利/規約/更新コスト確認後に確定する。

## 2026-07-10: 新ユニットID採用と人物/場所リンクモデルを追加

### 変更概要
- `RecordUnitDefinition` を、`basic` / `people` / `ticketPlan` / `photos` / `importOCR` / `money` / `officialInfo` / `memo` / `advanced` の9ユニットへ更新した。
- 旧 `U1` / `U3` / `U4` などの `enabledUnitsRaw` が残っていても新ユニットへ読み替える互換マップを追加した。
- `CategoryPresetSeeder` の標準ジャンル初期ユニットを、確定済みのジャンル別構成へ更新した。
- 自作ジャンル追加のテンプレ初期値も新ユニットIDへ更新した。
- `EventPersonLink` を追加し、人物/団体と `ExperienceEvent` / `Visit` の関係役割をリンク側に保存できるようにした。
- `Visit.placeMaster` を追加し、会場スナップショットを残したまま `PlaceMaster` へ参照できるようにした。
- OCR高度化はPro買い切り候補に寄せる方針を正本仕様へ反映した。

### 変更意図
入力アコーディオンの標準構成が固まったため、古いU番号ベースの実装を早めに整理し、標準ジャンル・自作ジャンル・設定画面で同じユニット語彙を使えるようにするため。人物/団体は作品・回ごとに役割が変わるため、マスター本体ではなく中間リンクに役割を持たせる。場所は過去記録を壊さないよう、既存の会場名/座標スナップショットを残しつつマスター参照を足した。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Utilities/RecordUnitDefinition.swift（新ユニットIDと旧ID互換マップ）
- favorecoAPP/favorecoAPP/Services/CategoryPresetSeeder.swift（標準ジャンル初期ユニット更新）
- favorecoAPP/favorecoAPP/Views/GenreManagementView.swift（自作ジャンル初期ユニット更新）
- favorecoAPP/favorecoAPP/Views/CategoryTopView.swift（プレビューのユニットID更新）
- favorecoAPP/favorecoAPP/Models/CoreModels.swift（`EventPersonLink` と `Visit.placeMaster` 追加）
- favorecoAPP/favorecoAPP/favorecoAPPApp.swift（Schema登録）
- favoreco/CLAUDE.md（正本仕様更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/favorecoDerivedUnitLinks build` 成功。

### 残課題
- `EventPersonLink` と `PlaceMaster` を使う入力/詳細/統合UIを実装する。
- 課金・プラン画面に無料/Pro/Premium境界の表示を追加する。
- 記録入力アコーディオンを本実装し、各ユニットの入力項目をジャンル別に接続する。

## 2026-07-09: 無料/有料境界表とPerson/Place最小モデルを追加

### 変更概要
- 無料/Pro買い切り候補/Premium候補の境界を表に整理した。
- 無料は、基本記録、写真10枚、URL/動画リンク保存、カレンダー手動追加/追加先選択、基本統計、手動バックアップまで広めに扱う方針にした。
- Premium候補は、同期/自動バックアップ、外部候補補助、高度取込、OCR高度化、カレンダー片方向自動更新/一括追加を中心にした。
- `PersonMaster` の最小SwiftDataモデルを追加した。
- `PlaceMaster` の最小SwiftDataモデルを追加した。
- アプリSchemaに `PersonMaster` / `PlaceMaster` を登録した。
- カレンダーのv1範囲を、手動追加/追加先選択に加えて、外部カレンダー予定の読み取り重ね表示までにした。
- 動画のv1範囲を、外部リンク保存、Photos参照、サムネイル表示までにした。

### 変更意図
企画で決まった無料/有料境界を一覧化し、後から課金設計で迷わないようにするため。人物・会場は横断マスターとして後続の入力補助、重複統合、サマリーカード、統計に効くため、まずCloudKit互換の最小モデルだけを追加した。カレンダーと動画は、便利さと実装/容量コストのバランスを取り、v1の現実的な範囲を明確にした。

### 主な変更ファイル
- favoreco/CLAUDE.md（無料/有料境界表、カレンダーv1範囲、動画v1範囲を更新）
- favorecoAPP/favorecoAPP/Models/CoreModels.swift（`PersonMaster` / `PlaceMaster` 追加）
- favorecoAPP/favorecoAPP/favorecoAPPApp.swift（Schema登録）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/favorecoDerivedPersonPlace build` 成功。

### 残課題
- `PersonMaster` / `PlaceMaster` と `ExperienceEvent` / `Visit` を結ぶリンクモデルを設計する。
- 重複候補UI、統合UI、外部候補取得UIを実装する。
- 外部カレンダー読み取り重ね表示と動画サムネイルの実装を行う。

## 2026-07-09: 美術展ユニット/関係タイプ/サマリーカード方針を確定

### 変更概要
- 美術展の初期有効ユニットを、基本情報、人物・団体、チケット・予定、写真、OCR・取込、公式情報、メモに決定した。
- 人物/団体を記録に紐付ける時は、PersonMaster自体の固定種別だけでなく、紐付け側に関係タイプ/役割を持つ方針にした。
- 関係タイプの初期セットを、アーティスト、出演、主演、作家、作者、監督、脚本、演出、原作、音楽、演奏、翻訳、キュレーター、主催、制作、出版社、ゲスト、その他にした。
- Home/一覧/サマリーカードの共通ベースを、カバー写真、ジャンル色/アイコン、タイトル、日付、場所、人物/団体1〜2件、評価またはステータス、短いメモ1行にした。
- ジャンル別サマリー案として、観劇/ライブ、映画、本、美術展、酒、御朱印、テーマパーク/おでかけの表示項目を整理した。

### 変更意図
美術展は作品や会場だけでなく、作家、キュレーター、主催などの関係者が記録価値になるため人物・団体ユニットを初期ONにする。人物/団体はジャンルを横断するため、マスター自体に役割を固定せず、各記録との関係として役割を持つ。サマリーカードは実装後に精査する前提で、まずジャンルごとの情報優先度を揃える。

### 主な変更ファイル
- favoreco/CLAUDE.md（美術展初期ユニット、関係タイプ、サマリーカード方針を追加）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- ドキュメントのみ。ビルド対象なし。

### 残課題
- `RecordUnitDefinition` とカテゴリseedを今回の初期有効ユニットへ合わせる。
- PersonMaster/PlaceMaster実装時に、関係タイプを保存するリンクモデルを設計する。
- サマリーカードUIを実装後、実機で情報量と見た目を精査する。

## 2026-07-09: カレンダー追加先選択の方針を追加

### 変更概要
- 外部カレンダー書き出しのUI文言を、`iOSカレンダーに追加` ではなく `カレンダーに追加` として扱う方針にした。
- `カレンダーに追加` ボタン押下後、初回はEventKit権限を求め、追加先はiOSに登録されているカレンダー一覧から選ぶ方針にした。
- Googleカレンダーも、iOS標準カレンダーに登録済みで書き込み可能なら追加先として表示される扱いにした。
- 次回以降は最後に使ったカレンダーを初期選択し、設定で既定の追加先カレンダーを変更できるようにする方針にした。
- 無料は手動追加と追加先選択まで、Premium候補はfavorecoで作った予定の片方向自動更新、一括追加、自動で既定カレンダーへ追加とした。

### 変更意図
ユーザー視点ではApple/Googleのブランド名より「どのカレンダーに入れるか」が重要。EventKit経由ではiOSに登録されたカレンダー一覧を扱うため、Google Calendar APIを直接使わず、iCloud/Google/共有カレンダーを同じUIで選べる形にする。

### 主な変更ファイル
- favoreco/CLAUDE.md（カレンダー追加先選択と無料/Premium境界を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- ドキュメントのみ。ビルド対象なし。

### 残課題
- EventKitで取得したカレンダー一覧の表示名、アカウント種別、書き込み可否の見せ方を設計する。
- 既定の追加先カレンダー保存キーを追加する。

## 2026-07-09: 会場マスター/iOSカレンダー書き出し/動画方針を追加

### 変更概要
- 会場/場所は横断の `PlaceMaster` として扱い、劇場、ライブ会場、映画館、美術館、寺社、酒蔵、飲食店、施設などをタグ/種別で切り分ける方針にした。
- 会場の重複候補は、名称、住所、座標、よみ、公式URLから判定し、「同じ会場の可能性があります」と提示してユーザー確認で統合する方針にした。
- 無料制限は広めにし、1記録あたり写真10枚、URL保存、YouTube/PV/個人動画などの外部リンク保存、iOSカレンダーへの手動追加を無料にする方針にした。
- iOSカレンダー書き出しは、Mystorium同様にユーザーが押す「カレンダーに追加」ボタンから始める方針にした。
- EventKitで作成した外部カレンダーイベントの識別子を保存し、後から更新/削除できる余地を持たせる方針にした。
- 外部カレンダー予定の読み取り重ね表示、一括登録、変更追従、双方向同期は技術的には可能な範囲があるが、権限・重複・競合解決が重いためv2以降/有料候補にした。
- 動画は容量とiCloud同期負荷が大きいため、v1では外部リンク保存とPhotos参照/サムネ中心を基本にし、動画ファイルのアプリ内コピー/Cloud同期/バックアップ同梱は明示ON/容量警告つき、またはv2以降の有料候補とした。

### 変更意図
favorecoは会場・場所がジャンルをまたいで出てくるため、ジャンル別に分けず横断マスター化する方が統計や重複統合に強い。カレンダーはユーザーの標準カレンダーへ乗せられると便利だが、完全同期は複雑なため、まずMystoriumで実績のある手動追加を安全な土台にする。動画は思い出価値が高い一方で容量負荷が大きいため、リンク/参照を基本にして保存と同期は明示的に扱う。

### 主な変更ファイル
- favoreco/CLAUDE.md（PlaceMaster、無料制限、iOSカレンダー、動画方針を追加）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- ドキュメントのみ。ビルド対象なし。

### 残課題
- `PlaceMaster` の実モデル、重複候補判定、統合UIを実装する。
- EventKitの手動追加、外部イベントID保存、更新/削除導線を設計する。
- 動画をPhotos参照で扱う場合の権限、サムネ保存、バックアップ対象外の説明文を設計する。

## 2026-07-09: ジャンル別の初期有効ユニット方針を追加

### 変更概要
- 観劇/ライブは、基本情報、人物・団体、チケット・予定、写真、OCR・取込、金額、公式情報、メモを初期有効にする方針にした。
- 映画は、基本情報、人物・団体、写真、OCR・取込、公式情報、メモを初期有効にする方針にした。
- 本は、基本情報、人物・団体、写真、OCR・取込、メモを初期有効にする方針にした。
- 酒/御朱印は、基本情報、写真、OCR・取込、メモを初期有効にする方針にした。
- テーマパーク/おでかけ施設は、基本情報、チケット・予定、写真、OCR・取込、金額、公式情報、メモを初期有効にする方針にした。
- 美術展は未確定とし、作家/主催を重視する展示寄りにするか、施設訪問寄りに軽くするかを残課題にした。

### 変更意図
観劇/ライブはチケット・予定・金額まで必要な重い入力にする一方、酒/御朱印は軽く記録できる形を優先する。ジャンルごとの初期表示を変えることで、横断アプリでありながら最初の入力負荷をジャンルに合わせて調整する。

### 主な変更ファイル
- favoreco/CLAUDE.md（ジャンル別初期有効ユニット方針を追加）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- ドキュメントのみ。ビルド対象なし。

### 残課題
- 美術展の初期有効ユニットを決める。
- `RecordUnitDefinition` とカテゴリseedの実装を、今回の標準ユニット/初期有効ユニットへ合わせて更新する。

## 2026-07-09: DBパックは商品確定せず参照データ候補として検討に変更

### 変更概要
- DBパック単体販売を、現時点で確定商品にせず検討扱いに変更した。
- 課金・プランは、無料 / Pro買い切り / Premiumサブスクを主軸にし、DBパックは実データの権利/規約/更新コストを確認してから判断する方針にした。
- 有名な寺社、ライブ会場、劇場、施設などの公開性が高く安定したスポット/会場データや、御朱印の印種別、酒のスペック、OCR補助語彙などの辞書・プリセットを参照データ候補として残した。
- 取得・同梱・再配布・キャッシュ・有料提供の可否が確認できないデータはDBとして持たない方針を明記した。
- 記録は参照データに依存させず、名称/住所/座標などをユーザー記録へスナップショット保存する方針を維持した。

### 変更意図
DBパックは実装してみないと価値・権利・保守コストが見えにくく、先に商品として固定すると危ない。寺社やライブ会場のように扱いやすそうなデータはあるが、ジャンルごとに条件が違うため、まずは入力補助/参照データ候補として扱い、持てるものだけを安全に採用する。

### 主な変更ファイル
- favoreco/CLAUDE.md（DBパック/参照データ方針を検討扱いに更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- ドキュメントのみ。ビルド対象なし。

### 残課題
- ジャンルごとに、利用可能な参照データソースとライセンス/規約を確認する。
- 参照データをPremiumに含めるか、買い切りパック化するか、無料の入力補助に留めるかを実装前に判断する。

## 2026-07-09: 入力アコーディオンの標準ユニット構成を更新

### 変更概要
- 記録追加/編集フォームの標準アコーディオンを、基本情報 / 人物・団体 / チケット・予定 / 写真 / OCR・取込 / 金額 / 公式情報 / メモ / 詳細オプションに整理した。
- 会場・住所・日付・種別・評価はイベント/訪問の核なので、場所ユニットではなく基本情報に含める方針にした。
- 写真と半券/OCRは分け、写真はギャラリー/思い出、OCR・取込は半券/チケット/レシート/リスト画像からの読み取りに寄せる方針にした。
- 公式URL、SNS投稿リンク、参考URLは、メモではなく公式情報ユニットとして分離する方針にした。

### 変更意図
入力画面が長くなるジャンルでも迷わないように、情報の性質でユニットを分けるため。会場や住所は記録の基本軸であり、写真/OCR/公式リンクは用途が違うため、同じブロックに混ぜない方がジャンル別ON/OFFや将来の自動取込にもつなげやすい。

### 主な変更ファイル
- favoreco/CLAUDE.md（入力アコーディオン標準構成を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- ドキュメントのみ。ビルド対象なし。

### 残課題
- `RecordUnitDefinition` の既存ユニット名/説明を、今回の標準構成に合わせて実装側で更新する。
- 各ジャンルの初期有効ユニット（映画/観劇/本/御朱印/酒など）を決める。

## 2026-07-09: 人物マスター統合と外部候補優先順位を決定

### 変更概要
- 人物/アーティストマスターはジャンル別DBに分けず、Mystoriumの制作団体マスター同様に横断DBとして扱う方針にした。
- 人物の種別は固定カテゴリだけで分断せず、タグ/役割で「アーティスト」「俳優」「作家」「監督」「演者」などを表現する方針にした。
- 重複統合は最初から必要な機能とし、保存時/検索時に「似た人物があります」と提示し、ユーザー確認で統合できるUIを用意する方針にした。
- 外部候補は正確性の高いソースを優先し、音楽=Apple Music / MusicBrainz / Wikidata、映画=TMDb / Wikidata、本=国会図書館系 / Open Library、観劇=手入力中心 + 公式URL/OCRを基本候補にした。
- 記録詳細画面は保存情報を原則すべて表示し、Home/一覧/サマリーカードは厳選情報だけを表示する方針にした。

### 変更意図
人物はジャンルをまたいで登場するため、音楽・映画・観劇・本で別々に持つと重複と統計分断が起きる。横断DBにしてタグ/役割で文脈を表すことで、「この人の映画」「この人の舞台」「この人の本」などをあとから自然に集計できる。外部DBは入力補助として使い、正確性と権利確認を優先する。

### 主な変更ファイル
- favoreco/CLAUDE.md（人物マスター統合、タグ/役割、外部候補優先、詳細/サマリー方針を追加）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- ドキュメントのみ。ビルド対象なし。

### 残課題
- 重複候補の判定条件（表記ゆれ、よみ、外部ID一致、同一ジャンル内の近似名）を設計する。
- 統合時にVisit/ExperienceEvent/出演・関係リンクが壊れないよう、リレーション移行手順を設計する。
- 外部ソースごとの利用規約、画像利用、キャッシュ可否を実装前に確認する。

## 2026-07-09: 人物/アーティストマスターの必須/任意項目方針を追加

### 変更概要
- `PersonMaster` は、表示名と種別/役割だけで保存できる最小マスターとして扱う方針にした。
- 別名、メモ、公式URL、SNSはDB必須にせず、詳細オプション/アコーディオンで扱う方針にした。
- MusicBrainz ID、Wikidata QID、Apple Music IDなどの外部IDは、ユーザー入力項目ではなく、候補取得・名寄せ用のoptional内部IDとして扱う方針にした。
- 無料/ローカルではユーザーが記録した人物の再利用、Premium/サブスクでは外部候補読み込みを入力補助としてONにする方向にした。
- 写真メタデータ削除はON固定とし、GPS/Exif等は写真ファイルから削除、訪問日・会場・天気などは `Visit` 側で管理する方針を追記した。

### 変更意図
人物マスターを最初から巨大なタレント名鑑として作ると、実装・保守・権利確認・名寄せが重くなる。まずはユーザーの記録から育つ個人用マスターを正本にし、外部DBは候補提示と補助に限定することで、入力の楽さとデータの安全性を両立する。

### 主な変更ファイル
- favoreco/CLAUDE.md（人物/アーティストマスターと外部候補補助の方針を追加）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- ドキュメントのみ。ビルド対象なし。

### 残課題
- `PersonMaster` の実モデル、検索UI、重複統合UIを実装する。
- 外部候補取得に使うソース（MusicBrainz / Wikidata / Apple Music等）の利用規約、画像利用、キャッシュ可否を実装前に確認する。
- Premium/サブスクでどこまで候補補助を開放するか、DBパック単体販売との境界を確定する。

## 2026-07-09: 公演前日/当日通知だけ初期ONに変更

### 変更概要
- 通知初期設定を、公演前日/当日だけ初期ONに変更した。
- 申込締切、当落、入金、発券、FC・会員期限、思い出リマインダーは引き続き初期OFFで、ユーザーが必要なものを選ぶ方針にした。
- iOS通知許可は起動直後に求めず、通知を有効化する操作やチケット/予定作成時に用途を説明してから求める方針は維持した。

### 変更意図
申込/入金/発券などの実務通知はうるさくなりやすいためユーザー選択にする。一方で、公演前日/当日は体験直前のリマインドとして自然で、記録アプリとしての安心感にもつながるため標準で助ける。

### 主な変更ファイル
- favoreco/CLAUDE.md（通知初期設定方針を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- ドキュメントのみ。ビルド対象なし。

### 残課題
- `NotificationSettingsView` に、公演前日/当日の初期ONと各通知タイプ別ON/OFFを実装する。

## 2026-07-09: Mystorium課金4プラン構造を参照モデルとして追加

### 変更概要
- Mystoriumの同期実装後4プラン構造を、favorecoの課金設計の参照モデルとして `favoreco/CLAUDE.md` に追記した。
- 構造は、無料 / ライト買い切り¥1,500 / 同期サブスク月¥250・年¥1,500 / フル買い切り¥6,000。
- フル¥6,000は、ライト¥1,500 + バックアップ・同期永久¥4,500 の頭金方式とし、どの購入ルートでも合計が揃う考え方を記録した。
- 創設メンバー特典として、既存¥980ユーザー＋発売締切までの新規購入者に同期永久無料を付与する考え方を記録した。
- favorecoはDBパック単体販売が加わるため、最終命名（Pro/Premium vs ライト/フル）とDBパックの関係は実装前に確定する残課題とした。

### 変更意図
Mystoriumで整理済みの「買い切り主役＋控えめサブスク＋頭金方式」を、favorecoの課金設計でも再利用できるようにするため。一方でfavorecoは参照DB/DBパックがあるため、Mystorium構造をそのままコピーせず、転用時の論点も残す。

### 主な変更ファイル
- favoreco/CLAUDE.md（Mystorium課金モデル参照を追加）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- ドキュメントのみ。ビルド対象なし。

### 残課題
- favorecoの最終プラン名を Pro/Premium 系にするか、ライト/フル 系に寄せるか決める。
- DBパック単体販売をライト/フル/サブスクとどう並べるか決める。
- 無料ティアの写真枚数（3〜5枚）を確定する。

## 2026-07-09: 通知初期設定はユーザー選択に決定

### 変更概要
- 申込締切、当落、入金、発券、公演前日/当日、FC・会員期限、思い出リマインダーは初期ONにせず、ユーザーが必要なものを選ぶ方針にした。
- iOS通知許可は起動直後に求めず、通知を有効化する操作やチケット/予定作成時に、用途を説明してから求める方針にした。

### 変更意図
通知はチケット/予定管理の価値に直結する一方で、最初から多く鳴るとアプリの印象が悪くなる。必要な通知だけユーザーが選ぶ形にして、通知の信頼性と快適さを優先する。

### 主な変更ファイル
- favoreco/CLAUDE.md（通知初期設定方針を追加）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- ドキュメントのみ。ビルド対象なし。

### 残課題
- `NotificationSettingsView` に、通知タイプ別のON/OFFと通知許可説明UIを実装する。

## 2026-07-09: リンク/サポートと規約置き場方針を追加

### 変更概要
- 利用規約、プライバシーポリシー、問い合わせページの正本をRANOVIQO公式ドメイン配下に置く方針にした。
- 問い合わせは公式Xを主導線にしてよいが、App Store審査、削除依頼、プライバシー問い合わせ、法務連絡のためにメールまたはフォームの恒久窓口もRANOVIQOドメイン側に置く方針にした。
- 公式SNSはXを置き、InstagramはFacebookログイン制約があるため現時点では置かない方針にした。
- 規約/プライバシーポリシー草案で扱う項目として、写真メタデータ削除、位置情報、同期/iCloud、手動バックアップ、Apple Music連携、MapKit、WeatherKit、参照DB、課金/サブスク/DBパック、問い合わせ/削除依頼を列挙した。

### 変更意図
SNSはユーザーとの距離が近くサポート導線として使いやすいが、規約やプライバシー問い合わせには恒久URLと安定した窓口が必要になる。アプリ・デザイン・写真活動をRANOVIQO屋号に集約する前提で、アプリ内には入口を置き、正本はRANOVIQOドメインに集約する。

### 主な変更ファイル
- favoreco/CLAUDE.md（リンク/サポートと規約置き場方針を追加）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- ドキュメントのみ。ビルド対象なし。

### 残課題
- RANOVIQOドメイン上のURL構成を確定する。
- 利用規約/プライバシーポリシー/問い合わせページの草案を作成する。

## 2026-07-09: 課金/マイ/テーマ設定方針を追加

### 変更概要
- 課金・プランを、無料 / Pro買い切り / Premiumサブスク / DBパック単体販売の4層で整理した。
- Pro買い切りは、ローカルのフル機能所有（自作カテゴリ、詳細統計、年間まとめ、エクスポート、上限緩和、買い切りテーマ/フォント等）を担う方針にした。
- Premiumサブスクは、iCloud同期、自動バックアップ、継続更新される参照DBアクセス、月次/年次リキャップ、思い出再提示、限定テーマ/フォントなど継続価値を担う方針にした。価格感はMystorium参考で月額200〜250円、年額1,500円前後を仮説にした。
- DBパック単体販売は、特定カテゴリの参照DBを買い切りで使いたい人向けの選択肢として残した。
- マイ領域に、プロフィール/SNSだけでなく、FC・プレイガイド・劇場会員・カード枠・外部カレンダー連携を含める方針にした。
- フォントは基本固定（Noto Sans JP / Noto Serif JP / Cormorant Garamond）とし、将来のフォント変更はPro/Premium側のカスタマイズ候補にした。
- Home表示設定は、将来ファーストビューの優先表示を選べる余地を残す方針にした。
- テーマは、標準では白ベース＋ジャンル色アクセント、全体テーマONでは全体統一、個別テーマONではジャンルごとのテーマ/色世界を設定できる方針にした。高度な個別テーマはPro/Premium候補にした。

### 変更意図
Mystoriumの「買い切り主役＋控えめサブスク」を参考にしつつ、favorecoでは横断ジャンル・参照DB・同期/バックアップがあるため、所有価値と継続価値を分けて課金設計するため。チケット/観劇/ライブ管理では登録情報・連携が重要になるため、マイ領域に早めに受け皿を作る。

### 主な変更ファイル
- favoreco/CLAUDE.md（課金/マイ/テーマ設定方針を追加）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- ドキュメントのみ。ビルド対象なし。

### 残課題
- Pro/Premium/DBパックの最終価格、無料制限、買い切りDBパックの更新範囲を実装前に確定する。
- 設定画面に、登録情報・連携、テーマ、フォント、Home優先表示、プラン比較の具体UIを追加する。

## 2026-07-09: 同期/バックアップ境界と削除系設定方針を確定

### 変更概要
- 同期・バックアップの無料/有料境界を、ローカル手動書き出しバックアップは無料、iCloud同期/自動バックアップは有料寄りとした。
- データ管理に、キャッシュ削除、写真キャッシュ削除、アーカイブデータ削除、全データ削除の削除系入口を置く方針にした。
- 不可逆操作は通常導線から一段深く置き、確認文言入力/二段階確認などの誤操作防止を必須にした。

### 変更意図
ユーザーの記録が端末内に閉じ込められないよう、Mystorium同様の手動バックアップは無料の安全網として残すため。一方で、継続的なiCloud同期や自動バックアップは運用コストがかかるため有料寄りにする。削除系は必要だが危険なので、データ管理に集約しつつ誤操作防止を設計条件にする。

### 主な変更ファイル
- favoreco/CLAUDE.md（同期/バックアップ境界と削除系設定方針を追加）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- ドキュメントのみ。ビルド対象なし。

### 残課題
- `DataManagementView` に削除系の実UIを追加する。
- `SyncBackupSettingsView` / `BillingPlanSettingsView` に無料/有料境界がわかる表示を追加する。

## 2026-07-09: 入力/編集フォームのアコーディオン方針を追加

### 変更概要
- 記録追加/編集フォームは、Mystorium同様にユニット単位のアコーディオンUIを基本方針にした。
- 基本情報、写真/半券、チケット、リスト/OCR、場所/天気、金額、メモなどを折りたたみ可能なブロックとして扱う方針を `favoreco/CLAUDE.md` に追記した。
- 保存後は編集画面ではなく記録詳細画面へ戻る前提を明記した。

### 変更意図
favorecoはジャンルごとに入力項目が大きく変わり、観劇・ライブ・パーク・酒・本などでは編集画面が長くなりやすい。最初からユニット単位の折りたたみ前提にしておくことで、入力負荷を抑えつつ、後からチケット/OCR/写真/金額などを追加しやすくするため。

### 主な変更ファイル
- favoreco/CLAUDE.md（入力/編集フォームのアコーディオン方針追加）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- ドキュメントのみ。ビルド対象なし。

### 残課題
- `AddExperienceView` / `EditExperienceView` の実UIはまだ最小フォーム。次の入力フォーム改修でアコーディオンUIへ移行する。

## 2026-07-09: 記録・入力補助設定を追加

### 変更概要
- 設定トップに `記録・入力補助` セクションを追加した。
- `RecordInputAssistSettingsView` を追加し、記録の初期値、写真、入力補助、後日検討の4ブロックに整理した。
- デフォルト記録日を「今日」、デフォルトジャンルを「最後に使ったジャンル / Homeで選択中のジャンル」、記録追加後を「詳細を開く」にした。
- 写真追加の初期動作を「カメラを開く / 写真ライブラリを開く」、写真圧縮を「85% / 65%」から選べるようにした。
- URL取込候補、OCR取込、Map検索、天気自動付与、入力補助辞書のON/OFFを追加した。
- Apple Music連携はV2以降で検討として表示だけにした。

### 変更意図
favorecoの勝ち筋である「記録の楽さ」を設定として育てられるようにするため。記録フォームそのものではなく、記録時の初期値・入力補助・自動取得の好みをまとめる場所として定義した。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（記録・入力補助画面追加）
- favorecoAPP/favorecoAPP/Utilities/AppStorageKeys.swift（記録・入力補助用キー追加）
- favoreco/CLAUDE.md（現在仕様を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- 各設定値は保存するが、記録追加画面・写真処理・URL/OCR/Map/天気取得への実接続は未実装。
- Apple Music連携は重さ、権限、画像利用、同名アーティスト問題を踏まえてV2以降で検討する。

## 2026-07-09: 設定トップ構造を確定形に近づけた

### 変更概要
- `SettingsView` のトップセクションを マイ / 表示 / ジャンル / 通知 / データ管理 / 同期・バックアップ / 課金・プラン / リンク・サポート / 開発 に整理した。
- `NotificationSettingsView` を追加し、申込開始/締切、当落、入金、発券、公演前日/当日、FC・会員期限、思い出リマインダーの入口を置いた。
- `SyncBackupSettingsView` を追加し、iCloud同期、自動バックアップ、復元、同期トラブル診断をデータ管理から分離した。
- `BillingPlanSettingsView` を追加し、現在のプラン、アップグレード、購入復元、Pro機能一覧、DBパック管理の入口を置いた。
- `SupportLinksView` を追加し、公式サイト、規約、プライバシーポリシー、問い合わせ、レビュー、シェア、公式SNSをまとめた。

### 変更意図
ユーザー確認で合意した設定カテゴリに合わせ、今後の実装が散らからないように器を先に確定するため。記録入力設定は検討中のため、今回のトップ構造には入れない。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（設定トップと各サブ設定入口）
- favoreco/CLAUDE.md（設定画面の現在仕様を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- 通知、同期、バックアップ、課金、外部リンク、レビュー/シェアはプレースホルダー。
- 記録入力設定は何を含めるか検討中。

## 2026-07-09: 表示設定分離とデータ管理/リンク入口を追加

### 変更概要
- `SettingsView` を マイ / 表示 / ジャンル / データ管理 / リンク / 開発 にセクション整理した。
- Home表示ON/OFFを `SettingsView` 直下から `DisplaySettingsView` に移動した。
- `DataManagementView` を追加し、記録/写真/Inbox/ジャンル/対象の件数表示、同期プレースホルダー、JSON/CSVインポート/エクスポート入口、バックアップ説明を置いた。
- リンクセクションを追加し、利用規約 / プライバシーポリシー / お問い合わせの入口を作った。
- デバッグ用の写真付き仮データ追加ボタンを開発セクションへ整理した。

### 変更意図
設定画面が今後、同期・バックアップ・課金・規約・表示調整を受け止められるように、先に器を分けておくため。2/3/4は入口中心に留め、実データを変更する処理はまだ接続しない。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（設定セクション整理、表示設定/データ管理/リンク入口追加）
- favoreco/CLAUDE.md（実装状態と重要ルールを更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- iCloud同期、JSON/CSVインポート/エクスポート、規約本文、問い合わせ導線はプレースホルダー。
- 文字サイズ、外観モードは表示のみで未実装。
- 設定画面のセクション整理は入れたが、課金/同期/通知などの詳細設計は次以降で詰める。

## 2026-07-09: Home上部の横断ミニ統計を実装

### 変更概要
- `HomeView` のHero直下に横断ミニ統計を追加した。
- 指標は `今後の予定`、`今年の記録`、`総記録数` の3つにした。
- 現時点では `今後の予定` を未来日Visit数、`今年の記録` を今年のVisit数、`総記録数` を全Visit数として集計する。
- `HomeMiniStatCell` を追加し、3カラムでコンパクトに表示するようにした。

### 変更意図
Mystoriumで実績のある「開いてすぐ全体感がわかる」導線をfavorecoにも入れるため。ジャンル横断アプリなので、Home上部に全体の予定/今年/累計が見えると、アテンションや体験ギャラリーへ入る前に現在地が掴みやすい。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/HomeView.swift（横断ミニ統計追加）
- favoreco/CLAUDE.md（実装状態を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- Plan / TicketAttempt モデル追加後、`今後の予定` は未来日VisitではなくPlan中心の集計へ切り替える。
- 横断ミニ統計は常設表示。将来、表示設定に含めるかは運用後に判断する。

## 2026-07-09: Home表示設定と体験ギャラリーを実装

### 変更概要
- Homeの固定表示順を、アテンション / 体験ギャラリー / あとで記録 / 最近の記録 / ジャンル一覧 / 統計サマリ / お気に入り・ベストにした。
- `SettingsView` に `Home表示` セクションを追加し、各HomeセクションをON/OFFできるようにした。
- `AppStorageKeys` にHome表示用キーを追加した。
- `HomeView` にアテンション枠を追加した。現状は未来日Visitと未整理Inboxを表示する。
- `HomeView` に体験ギャラリー枠を追加した。現状は最近のVisitを横スクロールカードで表示する。
- 統計サマリとお気に入り/ベストは初期OFFのプレースホルダーとして用意した。

### 変更意図
Homeを「やることが見える実用の入口」と「開いた瞬間に体験棚が見えてテンションが上がる入口」の両方にするため。並び替えは入れず、固定順とON/OFFだけにして設定を重くしすぎない。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/HomeView.swift（Homeセクション追加・固定順表示）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（Home表示ON/OFF追加）
- favorecoAPP/favorecoAPP/Utilities/AppStorageKeys.swift（Home表示キー追加）
- favoreco/CLAUDE.md（実装状態を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- アテンションの本命である申込締切、当落、入金、発券、会員期限、通知リマインダーの専用モデルは未実装。
- 体験ギャラリーは写真データの実表示ではなく、現状は色付きカードとSF Symbol表示。
- Homeセクションの並び替えは未実装。必要になるまで固定順で運用する。

## 2026-07-09: 自作ジャンル作成を実装

### 変更概要
- `RecordCategory` に自作ジャンル用の `templateTypeKey`、`targetNameLabel`、`recordUnitName`、`dateLabel` を追加した。
- ジャンル管理の右上 `+` から `AddCustomGenreView` を開き、自作ジャンルを追加できるようにした。
- 自作ジャンル作成時に、表示名、アイコン、テーマカラー、テンプレタイプ、呼び名、有効ユニットを設定できるようにした。
- テンプレタイプは鑑賞系 / 訪問系 / 読書系 / コレクション系 / 飲食系 / 自由の6種類にした。
- `GenreDetailSettingsView` でもテンプレタイプ、呼び名、有効ユニットを編集できるようにした。
- `CategoryRecordTemplate` を更新し、自作ジャンルの入力フォーム文言を保存済みラベルから生成するようにした。
- `CategoryPresetSeeder.ensureAtLeastOneActiveCategory` を標準ジャンル限定ではなく全ジャンル対象にし、自作ジャンルだけが有効な場合に標準ジャンルが勝手に復帰しないようにした。

### 変更意図
標準ジャンルだけでなく、ユーザーの趣味や生活に合わせた記録ジャンルを作れるようにするため。作成時は軽く始められ、あとから詳細設定で呼び名やユニットを育てられる構成にした。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Models/CoreModels.swift（RecordCategoryに自作ジャンル用フィールド追加）
- favorecoAPP/favorecoAPP/Views/GenreManagementView.swift（自作ジャンル追加・詳細編集拡張）
- favorecoAPP/favorecoAPP/Utilities/CategoryRecordTemplate.swift（自作ジャンル用フォーム文言生成）
- favorecoAPP/favorecoAPP/Utilities/RecordUnitDefinition.swift（必須ユニット/並び順ヘルパー）
- favorecoAPP/favorecoAPP/Services/CategoryPresetSeeder.swift（標準プリセットの新フィールド設定・最低1ジャンル補正）
- favoreco/CLAUDE.md（実装状態を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- アイコンはSF Symbol文字列入力のまま。将来ピッカー化する。
- 自作ジャンルの削除/複製は未実装。現状は非表示で運用する。
- ユニットON/OFFは入力フォームの出し分けまでは未接続。保存値と詳細表示/編集の土台まで。

## 2026-07-09: ジャンル管理v1を実装

### 変更概要
- `GenreManagementView` を追加し、設定からジャンル一覧を管理できるようにした。
- 表示/非表示を `RecordCategory.isArchived` で切り替え、最後の1件は非表示にできないようにした。
- 並び替えを `sortOrder` に保存し、Home / 追加導線 / ジャンル切替に効く土台にした。
- `GenreDetailSettingsView` で表示名、アイコン、テーマカラー、紐付けSNS一覧、有効ユニット一覧を確認/編集できるようにした。
- `RecordUnitDefinition` を追加し、`enabledUnitsRaw` を人間が読めるユニット名/説明に変換した。

### 変更意図
初回選択だけでなく、運用中にジャンルを育てられるようにするため。非表示は削除ではなく、記録は残しつつ入口から外す。テーマカラーやSNS紐付け、有効ユニットをジャンル単位で見られるようにして、年間まとめや自作ジャンルの土台にする。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/GenreManagementView.swift（ジャンル一覧・詳細設定）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（ジャンル管理導線追加）
- favorecoAPP/favorecoAPP/Utilities/RecordUnitDefinition.swift（有効ユニット定義）
- favoreco/CLAUDE.md（実装状態を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- 自作ジャンル追加は未実装。
- 有効ユニットは現時点では表示中心で、本格的なON/OFF制御は未実装。
- アイコン入力はSF Symbol文字列の直接入力。将来ピッカー化する。

## 2026-07-09: プロフィールSNS管理を実装

### 変更概要
- `SocialAccount` モデルを追加し、SNSアカウントを複数保存できるようにした。
- `SocialPlatform` を追加し、Instagram / X / Threads / Facebook の表示名、アイコン、ID/URL入力からのURL解決をまとめた。
- `ProfileSettingsView` を追加し、プロフィール設定内でSNS一覧、追加、編集、外部リンクオープンができるようにした。
- `EditSocialAccountView` を追加し、SNS種別、メモ/名前、IDまたはURL、ジャンル紐付け、用途メモを保存できるようにした。
- `SettingsView` にプロフィール導線を追加した。
- `ModelContainer` とプレビュー用modelContainerに `SocialAccount` を追加した。

### 変更意図
映画・観劇・本などジャンルごとに使い分けるSNSを、プロフィールの一部として登録できるようにするため。IDだけでもURLでも入力でき、タップで外部SNSへ飛べるようにして、記録アプリ内の自己紹介/公開導線の下地にする。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Models/CoreModels.swift（SocialAccountモデル追加）
- favorecoAPP/favorecoAPP/Utilities/SocialPlatform.swift（SNS種別とURL解決）
- favorecoAPP/favorecoAPP/Views/ProfileSettingsView.swift（SNS一覧・追加・編集）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（プロフィール導線追加）
- favorecoAPP/favorecoAPP/favorecoAPPApp.swift（ModelContainer更新）
- favoreco/CLAUDE.md（実装状態を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- プロフィール表示名・アイコン編集は未実装。
- SNSの並び替え、実機での外部アプリ遷移確認は未実施。

## 2026-07-09: 4タブ＋中央追加ボタンのルートナビを実装

### 変更概要
- `MainTabView` を追加し、Home / 記録 / カレンダー / 統計 の4タブ構成にした。
- 下部中央にタブではない大きな `+` ボタンを重ね、記録開始の常設導線にした。
- 中央 `+` から、有効ジャンルへの記録追加と `AddInboxItemView` によるあとで記録を選べるようにした。
- `ContentView` の初回完了後入口を `HomeView` から `MainTabView` に変更した。
- Home右上の設定ギア/Inbox追加ボタンを整理し、右上プロフィールアイコンから `SettingsView` を開くようにした。
- 記録 / カレンダー / 統計タブは、まず最小の一覧・プレースホルダーとして追加した。

### 変更意図
favorecoの主要導線を「横断Home」「横断記録一覧」「日付軸」「統計」に整理し、記録開始だけはMystorium同様に中央の `+` に集約するため。設定は下部タブに置かず、将来のマイ/プロフィール領域として右上プロフィールアイコンへ寄せる。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/MainTabView.swift（4タブルート・中央追加ボタン・記録/カレンダー/統計タブ）
- favorecoAPP/favorecoAPP/ContentView.swift（初回完了後入口をMainTabViewへ変更）
- favorecoAPP/favorecoAPP/Views/HomeView.swift（右上プロフィール入口へ整理）
- favoreco/CLAUDE.md（実装状態を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- 中央 `+` の見た目・タブバーとの重なりは実機でタップ領域を確認する。
- カレンダー / 統計はプレースホルダー。実データ表示は未実装。

## 2026-07-09: ジャンルトップ見出しスイッチャーを実装

### 変更概要
- `CategoryTopView` のヒーロー見出しを、ジャンル名 + 下向きアイコンのスイッチャーにした。
- 見出しタップで有効ジャンル一覧のメニューを開き、別ジャンルの `CategoryTopView` へ遷移できるようにした。
- 画面全体スワイプではなく、見出しの明示操作でジャンル切り替えする設計にした。
- `favoreco/CLAUDE.md` に現在の画面構成を反映した。

### 変更意図
favorecoはページ内ユニットで横スクロールを多用する想定のため、画面全体の横スワイプによるジャンル遷移は避ける。ジャンルトップの主役である見出しをそのまま切り替え導線にすることで、ノイズを増やさず現在地と移動先を両立する。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/CategoryTopView.swift（見出しスイッチャー追加）
- favoreco/CLAUDE.md（実装状態を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- 実機でメニューからのジャンル遷移感、戻る履歴の積まれ方を確認する。
- ジャンル数が多い場合の検索/並び替えは未実装。

## 2026-07-09: 初回ジャンル選択とデバッグデータ投入を実装

### 変更概要
- `GenreOnboardingView` を追加し、初回起動時に記録したい標準ジャンルをチェック選択できるようにした。
- 選択完了前は `ContentView` からオンボーディングを表示し、完了後に `HomeView` を表示するようにした。
- `CategoryPresetSeeder` を更新し、初回選択後にseedが全カテゴリを勝手に再表示しないようにした。
- 全ジャンルが非表示になった場合でも、先頭の標準カテゴリを復帰させる保険を入れた。
- `SettingsView` を追加し、初回ジャンル選択のやり直しと写真付き仮データ追加ボタンを置いた。
- `DebugDataSeeder` を追加し、有効ジャンルに対して `ExperienceEvent` / `Visit` / `PhotoBlob` / `InboxItem` の仮データを投入できるようにした。

### 変更意図
ユーザーごとに記録したいジャンルを絞れる初期導線を作るため。あわせて、Mystoriumで発生した「全チェック解除で起動不能」系の事故を避けるため、UIとseedの両方で最低1ジャンルが有効になるようにした。開発確認を速くするため、設定から写真付きサンプルデータを投入できるようにした。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/GenreOnboardingView.swift（初回ジャンル選択）
- favorecoAPP/favorecoAPP/Views/SettingsView.swift（設定・デバッグ入口）
- favorecoAPP/favorecoAPP/Services/DebugDataSeeder.swift（写真付き仮データ投入）
- favorecoAPP/favorecoAPP/Services/CategoryPresetSeeder.swift（選択状態保持・最低1ジャンル復帰）
- favorecoAPP/favorecoAPP/ContentView.swift（初回導線切替）
- favorecoAPP/favorecoAPP/Views/HomeView.swift（設定ボタン・空ジャンル表示）
- favorecoAPP/favorecoAPP/Utilities/AppStorageKeys.swift（AppStorageキー管理）
- favoreco/CLAUDE.md（実装状態を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- 実機で初回インストール状態の画面遷移確認は未実施。
- デバッグ投入した `PhotoBlob` の写真表示UIは未実装。現状はデータ投入確認用。

## 2026-07-09: Inboxから本記録への変換導線を実装

### 変更概要
- `InboxDetailView` を追加し、InboxItemの詳細確認、カテゴリ候補の選択、本記録への変換、削除ができるようにした。
- HomeのInbox行を詳細画面へのNavigationLinkにし、未解決Inboxだけを表示するようにした。
- `AddExperienceView` に初期Draftと保存時フックを追加し、InboxItemのタイトル / URL / メモを引き継げるようにした。
- `AddExperienceView` / `EditExperienceView` で公式URLを保存・編集できるようにした。
- `favoreco/CLAUDE.md` に現在の画面構成を反映した。

### 変更意図
Inboxを一時保存で終わらせず、記録作成の入口として使える状態にするため。既存の記録追加フォームを再利用し、保存時だけ `ExperienceEvent` / `Visit` とInboxItemの状態をまとめて更新する。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/InboxDetailView.swift（Inbox詳細・変換導線）
- favorecoAPP/favorecoAPP/Views/HomeView.swift（Inbox詳細遷移・未解決フィルタ）
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（初期Draft、保存フック、公式URL入力）
- favoreco/CLAUDE.md（実装状態を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- InboxItemから既存対象への回追加、予定/申込への変換は未実装。
- 変換完了後に詳細画面を自動的に閉じる/作成した記録へ遷移する導線は未実装。

## 2026-07-09: Inbox手動追加を実装

### 変更概要
- `AddInboxItemView` を追加し、あとで記録したい候補をタイトル / URL / カテゴリ候補 / メモで保存できるようにした。
- `HomeView` のツールバーにInbox追加ボタンを追加した。
- HomeのInbox行を、カテゴリ候補・URL有無・作成日・メモプレビューつきの表示にした。
- `favoreco/CLAUDE.md` に現在の画面構成を反映した。

### 変更意図
気になる作品・行きたい場所・飲みたい酒などを、本記録にする前に逃さず保存する入口を作るため。最初から `ExperienceEvent` / `Visit` を作らず、`InboxItem` として軽く受け止める。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/AddInboxItemView.swift（Inbox手動追加フォーム）
- favorecoAPP/favorecoAPP/Views/HomeView.swift（Inbox追加導線・Inbox行表示更新）
- favoreco/CLAUDE.md（実装状態を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- InboxItemから本記録 / 既存対象 / 予定への変換導線は未実装。
- URL正規化・OGP取得・OCR/共有シート取込は未実装。

## 2026-07-09: 対象編集画面を実装

### 変更概要
- `EditEventView` を追加し、対象自体のタイトル、シリーズ、公式URL、対象メモを編集できるようにした。
- `EventDetailView` のツールバーに対象編集ボタンを追加した。
- 対象詳細に対象メモと公式リンクの表示セクションを追加した。
- `favoreco/CLAUDE.md` に現在の画面構成を反映した。

### 変更意図
回ごとの記録編集だけでは、作品名・銘柄名・シリーズ名など対象そのものの修正ができないため。Event/Visit分離に合わせ、対象情報と回情報の編集責務を分ける。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/EventDetailView.swift（対象編集フォームと対象メモ表示追加）
- favoreco/CLAUDE.md（実装状態を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- 対象のアーカイブ、削除、代表アイキャッチ設定は未実装。
- 公式URLの正規化・入力バリデーションは未実装。

## 2026-07-09: 対象詳細画面を実装

### 変更概要
- `EventDetailView` を追加し、対象単位のカテゴリ、シリーズ、記録数、最新日、平均評価、履歴を表示できるようにした。
- 対象詳細から既存対象への回追加 `AddVisitView` を開けるようにした。
- 対象詳細の履歴から各 `ExperienceDetailView` へ遷移できるようにした。
- `CategoryTopView` の対象行を対象詳細へのNavigationLinkにした。
- `favoreco/CLAUDE.md` に現在の画面構成を反映した。

### 変更意図
カテゴリトップだけでは対象ごとの記録履歴を追いづらいため。作品・銘柄・本・施設などの単位で回を重ねる体験を、一覧ではなく詳細画面でも確認・追加できるようにする。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/EventDetailView.swift（対象詳細画面追加）
- favorecoAPP/favorecoAPP/Views/CategoryTopView.swift（対象行から詳細へ遷移）
- favoreco/CLAUDE.md（実装状態を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- 対象自体の編集、アーカイブ、代表アイキャッチ設定は未実装。
- 対象詳細の統計は最小値のみ。ジャンル別の深い集計は未実装。

## 2026-07-09: 既存対象への回追加導線を実装

### 変更概要
- `AddVisitView` を追加し、既存 `ExperienceEvent` に新しい `Visit` だけを追加できるようにした。
- `CategoryTopView` に対象一覧を追加し、各対象から「この対象に回を追加」できるボタンを表示した。
- カテゴリトップの主要導線を、初回は「最初の記録を追加」、記録ありでは「新しい対象を追加」に切り替えた。
- 空状態表示を共通化し、対象0件と記録0件のメッセージを分けた。
- `favoreco/CLAUDE.md` に現在の画面構成と再訪追加ルールを反映した。

### 変更意図
同じ作品を複数回観る、同じ酒をまた飲む、同じ施設へ再訪するなど、favorecoの中心になる「対象に回を重ねる」記録体験を作るため。新規対象の乱立を避け、Event/Visit分離を画面導線にも反映する。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（既存対象への回追加フォーム追加）
- favorecoAPP/favorecoAPP/Views/CategoryTopView.swift（対象一覧と回追加導線追加）
- favoreco/CLAUDE.md（実装状態を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- 対象詳細画面、対象自体の編集、対象のアーカイブは未実装。
- 回追加後に作成したVisitの詳細へ自動遷移する導線は未実装。

## 2026-07-09: 編集画面とカテゴリ別フォーム文言を実装

### 変更概要
- `CategoryRecordTemplate` を追加し、観劇 / 美術展 / ライブ / 映画 / 酒 / おでかけ施設 / 御朱印 / 書籍ごとにフォーム文言を切り替えられるようにした。
- `AddExperienceView` のセクション名、プレースホルダー、日付/場所/評価/メモ文言をカテゴリ別にした。
- `EditExperienceView` を追加し、保存済み `ExperienceEvent` + `Visit` のタイトル、シリーズ、日付、場所、評価、メモを編集保存できるようにした。
- `ExperienceDetailView` に編集ボタンを追加し、詳細画面から編集シートへ遷移できるようにした。
- `favoreco/CLAUDE.md` に現在の画面構成とフォーム文言ルールを反映した。

### 変更意図
1件保存して終わりではなく、あとから記録を直せる基本体験に進めるため。あわせて、同じ最小フォームでもカテゴリごとの言葉に置き換え、観劇・酒・読書などで入力の意味が自然に伝わる状態にする。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Utilities/CategoryRecordTemplate.swift（カテゴリ別フォーム文言定義）
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（追加フォーム文言切替・編集フォーム追加）
- favorecoAPP/favorecoAPP/Views/ExperienceDetailView.swift（編集導線追加・詳細ラベル文言切替）
- favoreco/CLAUDE.md（実装状態を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- テンプレ別の専用入力ユニット、チケット、写真、Map、OCRは未実装。
- 編集対象の削除、アーカイブ、既存Eventへの再訪追加は未実装。

## 2026-07-09: 可変フォント基盤を実装

### 変更概要
- Google Fontsの可変TTFとして `Noto Sans JP` / `Noto Serif JP` / `Cormorant Garamond` をアプリに同梱した。
- `FontRegistrar` を追加し、起動時に同梱フォントをプロセス登録するようにした。
- `FavorecoTypography` を追加し、日本語サンセリフ・日本語セリフ・英字ディスプレイを共通トークンとして使えるようにした。
- ホーム、カテゴリトップ、記録詳細の主要テキストへタイポグラフィを適用した。

### 変更意図
favorecoの文字表現をシステムフォント依存から切り離し、画面ごとに太さや書体を調整できる下地を作るため。日本語は読みやすさと記憶感、英字はブランド感を分けて扱う。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Resources/Fonts/（可変TTFとOFLライセンス追加）
- favorecoAPP/favorecoAPP/Utilities/FontRegistrar.swift（同梱フォント登録）
- favorecoAPP/favorecoAPP/Utilities/FavorecoTypography.swift（タイポグラフィ定義）
- favorecoAPP/favorecoAPP/favorecoAPPApp.swift（起動時フォント登録）
- favorecoAPP/favorecoAPP/Views/HomeView.swift（ホームへ適用）
- favorecoAPP/favorecoAPP/Views/CategoryTopView.swift（カテゴリトップへ適用）
- favorecoAPP/favorecoAPP/Views/ExperienceDetailView.swift（詳細画面へ適用）
- favoreco/CLAUDE.md（実装状態を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- Cormorant SCは未同梱。ロゴ専用・小文字なし表現が必要になった時点で追加判断する。
- 連続的なwght軸スライダーUIは未実装。現状はSwiftUIの `Font.Weight` トークンで太さを切り替える。

## 2026-07-09: 保存済み記録の詳細画面を実装

### 変更概要
- `ExperienceDetailView` を追加し、保存済みVisitのカテゴリ、対象名、シリーズ、日付、場所、評価、メモを表示できるようにした。
- カテゴリトップの最近の記録行から詳細画面へ遷移できるようにした。
- ホームの最近の記録行からも詳細画面へ遷移できるようにした。
- `favoreco/CLAUDE.md` に現在の画面構成を反映した。

### 変更意図
最小登録フローで保存した記録を、保存後に確認できる状態にするため。編集や写真追加に進む前に、Event/Visitの表示解決（カテゴリ・対象・回）を確認できる導線を作る。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/ExperienceDetailView.swift（記録詳細画面追加）
- favorecoAPP/favorecoAPP/Views/CategoryTopView.swift（記録行から詳細へ遷移）
- favorecoAPP/favorecoAPP/Views/HomeView.swift（最近の記録から詳細へ遷移）
- favoreco/CLAUDE.md（実装状態を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- xcodebuild（iOS Simulator向け）が成功。

### 残課題
- 詳細画面から編集する導線は未実装。
- 写真、タグ、チケット、テンプレ別ユニットは未表示。

## 2026-07-09: カテゴリトップと最小記録追加フローを実装

### 変更概要
- ホームのカテゴリカードをタップ可能にし、カテゴリ別トップ `CategoryTopView` へ遷移するようにした。
- `CategoryTopView` でカテゴリ名、記録数、対象数、ユニット数、最近の記録を表示するようにした。
- `AddExperienceView` を追加し、タイトル / シリーズ名 / 日付 / 場所 / 評価 / メモだけで `ExperienceEvent` + `Visit` を保存できる最小登録フローを実装した。
- 入力中は `AddExperienceDraft` に保持し、保存ボタン押下時だけ SwiftData に書き込むようにした。
- `Color(hex:)` を共通ユーティリティへ移動した。

### 変更意図
カテゴリプリセットが見えるだけの状態から、実際に1件目の記録を作れる状態へ進めるため。今後テンプレ別フォームを足す前に、Event/Visit分離とDraftState→Save→Modelの基本導線を確認できるようにする。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Views/HomeView.swift（カテゴリカードを遷移化）
- favorecoAPP/favorecoAPP/Views/CategoryTopView.swift（カテゴリトップ追加）
- favorecoAPP/favorecoAPP/Views/AddExperienceView.swift（最小記録追加フォーム追加）
- favorecoAPP/favorecoAPP/Utilities/Color+Hex.swift（色変換ユーティリティ追加）
- favoreco/CLAUDE.md（実装状態を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/favorecoDerived build` が成功。

### 残課題
- 次スライスで保存後の詳細表示、またはカテゴリ別テンプレに応じた入力項目の出し分けを実装する。
- 既存Eventへの再訪/再飲としてVisitを追加する導線は未実装。

## 2026-07-08: 標準カテゴリプリセットの初回注入を実装

### 変更概要
- `CategoryPresetSeeder` を追加し、初回起動時に標準カテゴリ8種（観劇 / 美術展 / ライブ / 映画 / 酒 / おでかけ施設 / 御朱印 / 書籍）を `RecordCategory` として注入するようにした。
- 注入は `templateKey` + `isBuiltIn` で既存カテゴリを探して更新し、重複作成しないfetch-first方式にした。
- `HomeView` のカテゴリカードを、色バー・SF Symbol・標準チップ・ユニット数表示つきに更新した。
- `favorecoAPPApp` で `ModelContainer.mainContext` へ起動時seedを接続した。

### 変更意図
最初のホームを空の器ではなく、favorecoの主要ジャンルが見える状態にするため。プリセットは固定enumではなく保存済み `RecordCategory` として扱い、将来ユーザー編集やテンプレ更新に耐える構造にする。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Services/CategoryPresetSeeder.swift（標準カテゴリ注入）
- favorecoAPP/favorecoAPP/favorecoAPPApp.swift（起動時seed接続）
- favorecoAPP/favorecoAPP/Views/HomeView.swift（カテゴリカード表示更新）
- favoreco/CLAUDE.md（実装状態を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/favorecoDerived build` が成功。

### 残課題
- 次スライスでカテゴリカードから登録フローまたはジャンル別トップへ遷移させる。
- プリセットの `enabledUnitsRaw` は仕様キーの初期接続のみ。各ユニットの実UIは未実装。

## 2026-07-08: Xcodeプロジェクト作成と最小SwiftDataモデル実装

### 変更概要
- Xcodeで `favorecoAPP` プロジェクトを作成し、SwiftUI / SwiftData のアプリ本体を開始。
- Xcodeテンプレートの `Item` モデルを削除し、`RecordCategory` / `ExperienceEvent` / `Visit` / `InboxItem` / `PhotoBlob` の最小モデルを追加。
- `ContentView` を初期 `HomeView` へ差し替え、空データでもカテゴリ・最近の記録・Inboxが見えるホームを実装。
- Bundle Identifier を `com.nori.favoreco` に調整し、共有schemeと `.gitignore` を追加。
- Xcode個人状態ファイルと `.DS_Store` はGit管理対象から外す方針にした。

### 変更意図
実装フェーズの最初の安全な足場として、仕様正本の中核である Event/Visit 分離と RecordCategory 一般化を、ビルド可能なSwiftDataモデルとして置く。チケット・酒詳細・登録フローに進む前に、CloudKit互換ルールを満たす最小スキーマと起動可能なホームを確定する。

### 主な変更ファイル
- favorecoAPP/favorecoAPP.xcodeproj（Xcodeプロジェクト）
- favorecoAPP/favorecoAPP/Models/CoreModels.swift（最小SwiftDataモデル）
- favorecoAPP/favorecoAPP/Views/HomeView.swift（初期ホーム）
- favorecoAPP/favorecoAPP/ContentView.swift（HomeView入口へ変更）
- favorecoAPP/favorecoAPP/favorecoAPPApp.swift（ModelContainer接続）
- .gitignore（Xcode個人状態・.DS_Store・ビルド成果物除外）
- favoreco/CLAUDE.md（実装状態・構成を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
- `xcodebuild -project favorecoAPP/favorecoAPP.xcodeproj -scheme favorecoAPP -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/favorecoDerived build` が成功。
- 初回のサンドボックス内ビルドは SwiftData macro 実行権限で失敗したため、外側権限で再実行して成功を確認。

### 残課題
- アプリ/ターゲット/フォルダ名 `favorecoAPP` を後で `favoreco` 系に整理するか判断する。
- 次スライスでカテゴリプリセット注入と、最初の登録導線を実装する。

## 2026-07-08: Designテーマをジャンル別選択式に更新

### 変更概要
- `DESIGN.md` のジャンル色を固定パレットではなく、ジャンルごとに選択できるテーマ方式に変更。
- 無料版は `Free Light` / `Free Dark` の2種、有料版は追加テーマをジャンルごとに適用できる方針にした。
- 生成モック由来のテーマとして、Velvet Curtain / Stage Bloom / Aqua Nocturne / Daydream Lake / Amber Cellar / Museum Haze / Tour Teal を保存。
- オフホワイト基調の `Porcelain Ivory` と各Ivory variantを追加。
- 追加要望テーマとして、Sakura Mist（桜色系）、Moegi Glass（萌葱色）、Pale Blue Air（ペールブルー）、Mono Vivid Yellow（モノクロ＋ビビットイエロー）、Mono Soft Magenta（モノクロ＋薄めマゼンタ）を追加。
- Mono Vivid Yellow / Mono Soft Magenta は白黒反転版も持つ方針にした。
- テーマ比較用の `docs/design-theme-variants.html` を新規作成。
- `design-theme-variants.html` に、ペール系、Mono系、白黒反転Mono系、生成画像由来パレットのサンプルカードを追加。

### 変更意図
ジャンルごとに固定色を押し付けるのではなく、ユーザーが自分の好みやジャンルの使い方に合わせてテーマカラーを選べるようにする。無料版はシンプルにし、有料版の価値としてカラー拡張を置く。

### 主な変更ファイル
- docs/DESIGN.md（テーマ選択方式、無料/有料テーマ、追加パレットを記録）
- docs/design-theme-variants.html（テーマの見た目を確認するプレビュー）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
ドキュメント/HTMLプレビューのみ。ビルド対象なし。`DESIGN.md` にテーマトークンと本文説明が入り、`design-theme-variants.html` で無料/有料/ペール/モノクロ/白黒反転/生成画像由来テーマを視覚確認できる状態にした。

### 残課題
- 実装時に、ジャンルごとの `selectedThemeId` と課金状態によるテーマロック/プレビュー導線を設計する。

## 2026-07-08: ライブトップと公演系のグッズ/遠征/スケジュール扱いを更新

### 変更概要
- ライブトップの構成を `Hero → チケット要対応 → 参戦予定 → ライブライブラリ → データ` 方向に整理。
- ライブライブラリは横スクロールではなく縦スタックを主役にし、カード内に `4回参戦` `セトリあり` `写真6枚` `グッズ2件` などのバッジを表示する方針にした。
- `セトリ・思い出` は独立セクション既定OFFにし、必要な人だけトップセクションとして表示できるようにした。
- Heroの `次のアクション` 文言は出しすぎず、ステータスチップの色と日付（例: `6/12 当落発表`）で状態が読めるようにした。
- グッズ/コレクションは写真＋名前/コメント＋タグ（銀テ/Tシャツ/会場看板/チケット画像等）＋金額任意に拡張。
- 観劇/ライブなど公演系で、グッズ代・旅費・交通費・宿泊費・遠征費を詳細画面の任意項目として扱う方針にした。
- 宿・移動・集合・物販待ちなどを軽く組める `スケジュール/旅程` ユニットを追加。詳細画面とグローバルカレンダーの両方から追加/変更できる。

### 変更意図
ライブトップはセトリ管理アプリではなく、自分の参戦履歴が積み上がるライブラリを主役にする。セトリやグッズは熱量のある人には重要だが、全員のトップに常設すると重いため、カードバッジと任意セクションで扱う。遠征は体験の一部なので、費用だけでなく宿・移動予定も記録とカレンダーにつながる形にする。

### 主な変更ファイル
- docs/spec-B1-ライブラリ画面.md（ライブトップ、Hero、セトリ/思い出、詳細項目を更新）
- docs/08-テンプレユニット設計.md（U18スケジュール/旅程、U11/U12拡張を追加）
- docs/spec-A3-ユニット別フィールド.md（コレクション明細と金額明細を拡張）
- docs/spec-A4-テンプレ別プリセット.md（観劇/ライブのコレクション・金額方針を更新）
- docs/spec-A5-集計カレンダー地図.md（U11金額をU12集計に接続）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
ドキュメントのみ。ビルド対象なし。ライブトップ、コレクション明細、金額集計、スケジュール/旅程の方針が仕様へ反映されていることを確認。

### 残課題
- `spec-A7` に、ライブ/観劇詳細からのグッズ追加、旅費明細追加、スケジュール追加、カレンダーからの編集フローを反映する。

## 2026-07-08: 観劇トップの見せ方を確定

### 変更概要
- 観劇トップの構成を `Hero → チケット要対応 → 申込・観劇予定 → 観劇ライブラリ → データ` に確定。
- Heroは、次に観る公演、要対応がある公演、最近観た公演、手動固定の順で選ぶ。
- チケット要対応は1列または2列で、トップには最大2〜3件だけ表示し、`もっと見る`でチケット一覧へ遷移する。
- 複数申込はFC先行/カード枠/プレイガイド等を行ごとに扱う。
- 申込・観劇予定は未完了の未来/進行中の公演回だけを表示し、観劇済みは観劇ライブラリ/観劇履歴へ移す。
- 観劇ライブラリは横スクロールではなく縦スタックにし、作品カード内に `3回観劇` などのリピート回数を表示する。リピート観劇の独立セクションは作らない。
- データは `今年の観劇回数` をマストにし、`申込中/要対応チケット数`、`最多リピート作品/回数` をトップ候補にした。劇場数・マチソワ・当選率などは詳細統計側を基本にする。
- トップに出しすぎないものとして、アカウント情報、パスワード、全申込履歴、落選一覧、名義別当選率、長文感想、キャスト詳細を詳細/統計/設定へ逃がす方針にした。

### 変更意図
観劇トップは管理画面ではなく、チケットの危険信号と観劇の積み上がりを同時に見る画面にする。リピートは独立欄にせず作品カードのメタ情報に溶かすことで、トップの視線を散らさない。

### 主な変更ファイル
- docs/spec-B1-ライブラリ画面.md（観劇トップ構成を確定）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
ドキュメントのみ。ビルド対象なし。観劇トップの構成、Hero、チケット要対応、申込・観劇予定、縦スタックの観劇ライブラリ、データの優先度が仕様へ反映されていることを確認。

### 残課題
- 観劇トップのデータタイルは、実装時に設定で表示項目を差し替えられるようにする。

## 2026-07-08: 観劇のVisit単位とキャスト管理/OCR方針を確定

### 変更概要
- 観劇回数は `Visit` 数で数える方針にした。同じ日のマチソワはVisit 2件。
- キャスト管理は、作品/Eventのキャスト候補と、自分が観た回/Visitの実キャストを分ける方針にした。
- 実キャストはVisitにスナップショットとして残し、公式情報が変わっても自分が観た回の記録を保持する。
- 入力補助として、公式キャスト候補から選ぶ、前回キャストをコピー、手入力、当日キャスト表/プログラム画像OCRを採用。
- キャスト取り込みは画像OCRだけでなく、URLとテキストペーストからも候補化する方針にした。
- キャストOCR/URL/テキスト取り込みは精度重視とし、前処理・列解析・Person辞書補正・精査画面を必須にした。役名と人物名のペアを崩さず、勝手に確定しない。
- 精査後、保存先を作品全体のキャスト候補(Event)、自分が観た回の実キャスト(Visit)、または両方から選べるようにした。

### 変更意図
観劇ではWキャスト、日替わり、代役があり、誰で観たかが記録価値と統計価値を持つ。必須入力にすると重くなるため任意にしつつ、記録したい人には高精度に残せる導線を用意する。

### 主な変更ファイル
- docs/spec-A3-ユニット別フィールド.md（Eventキャスト候補/Visit実キャスト、OCR精度要件を追加）
- docs/spec-A4-テンプレ別プリセット.md（観劇プリセットにキャスト管理/OCRを追加）
- docs/08-テンプレユニット設計.md（観劇回数=Visit数、キャスト管理方針を追加）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
ドキュメントのみ。ビルド対象なし。Visit数、Event/Visitキャスト分離、OCR精度要件が仕様へ入っていることを確認。

### 残課題
- `spec-A5` に俳優別観劇回数、役別キャスト、作品別キャスト違い、推し俳優の出演作一覧を反映する。
- `spec-A7` にキャスト表OCRの登録フローとプレビュー編集UIを反映する。

## 2026-07-08: 観劇チケットの要対応表示・複数申込・FC/チケットアカウント管理を設計

### 変更概要
- 観劇トップのチケット表示は、チケット管理画面を主役にせず、要対応だけを出す方針にした。
- トップに出す対象を、申込開始（特に当日）/ 申込締切 / 当落発表 / 入金締切 / 発券開始・発券待ち / 公演当日に限定した。
- チケット申込は `Visit` 直持ちではなく、申込1件ごとの `TicketAttempt` として独立管理する方針に更新。同じ公演にFC先行/カード枠/ぴあ先行/一般など複数申込を持てる。
- FC管理を、FC/プレイガイド/劇場会員/カード枠を含む「FC・チケットアカウント管理」に拡張。サイトURL、ログインID、会員番号、名義、有効期限、年会費、色を一元管理する。
- パスワードはSwiftData/CloudKitに保存せず、必要な場合のみKeychainへ保存し、表示/コピー/編集時はFace ID/Touch ID/端末パスコード認証を必須にする。
- 要対応カードから申込ページを開けるようにし、アカウント情報を開く場合は生体認証後にID/パスワードコピーを行う方針にした。

### 変更意図
観劇の価値はチラシ/記録/思い出だが、申込開始・申込締切・入金締切を逃すと体験自体を失う。チケット管理をトップの主役にはせず、通知と要対応レイヤーを堅牢な資産として設計する。複数先行・複数名義・複数チケットサイトに耐えるため、TicketAttemptとアカウント管理を最初から分離する。

### 主な変更ファイル
- CLAUDE.md（チケット/ライブ管理の正本ルールを更新）
- docs/spec-A8-チケット管理・通知.md（TicketAttempt独立、Account管理、Keychain/生体認証方針へ更新）
- docs/spec-B1-ライブラリ画面.md（観劇トップの要対応表示範囲を更新）
- docs/spec-A3-ユニット別フィールド.md（Account/TicketAttempt/Visitの所属を更新）
- docs/spec-A5-集計カレンダー地図.md（当選率/名義別集計の源をTicketAttempt/Accountへ更新）
- docs/08-テンプレユニット設計.md（観劇チケットユニットの方針更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
ドキュメントのみ。ビルド対象なし。観劇トップの要対応、TicketAttempt独立、FC・チケットアカウント管理、パスワードKeychain＋生体認証方針が仕様へ反映されていることを確認。

### 残課題
- `spec-A7` にチケット申込登録・スクショ/OCR・アカウント選択・通知設定の登録フローを反映する。
- 実装時はKeychain項目の移行/削除/端末変更時の扱いを別途詰める。

## 2026-07-08: 酒トップの一覧単位・データ・写真・場所扱いを確定

### 変更概要
- 酒の飲んだ一覧は、飲んだ回単位ではなく**銘柄単位**で並べる方針にした。同じ酒は1カードにまとめ、再飲はVisitとして積む。
- 気になる酒を飲んだ時は、同じ銘柄のEventへ昇格し、飲んだ回(Visit)を追加する。気になるメモ・写真・URLは引き継ぐ。
- データ表示は、酒種別タブに応じて変化する。基本項目は酒種別比率、今月飲んだ種類数、年間飲んだ種類数、よく飲む地域、生産者/酒蔵、評価。
- 代表写真はボトル/グラス/ラベルのどれでも可。ラベル表/裏はLv2詳細で保存する。
- 場所は「どこで飲んだ」をトップ/Lv1の主役にし、「買った場所」はLv2任意欄にした。

### 変更意図
お酒トップはボトル棚として眺める体験を優先するため、一覧は銘柄単位が合う。飲んだ回の履歴は詳細側へ積み、トップは軽く美しく保つ。気になる酒から飲んだ記録への昇格導線を決めることで、クイック登録から正式記録へ自然に移れる。

### 主な変更ファイル
- docs/spec-B1-ライブラリ画面.md（酒トップの一覧単位・気になる昇格・データ・写真扱いを更新）
- docs/spec-A4-テンプレ別プリセット.md（酒プリセットの一覧単位・写真・データ方針を追記）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
ドキュメントのみ。ビルド対象なし。酒トップの残決定事項が仕様へ反映されていることを確認。

### 残課題
- `spec-A5` に酒種別タブ別のデータ算出、銘柄数/Visit数/再飲数の扱いを反映する。

## 2026-07-08: 酒トップの表示順と全ジャンルのセクション順カスタムを整理

### 変更概要
- 酒種別タブを `すべて / 日本酒 / ビール / ワイン / ウィスキー / 焼酎 / その他` を初期案とし、並び替え・表示/非表示をユーザー設定で変更できるようにした。
- Heroは最近飲んだ/お気に入りランダムを中心にし、`気になる酒` はHero候補に含めない方針にした。
- 酒トップの順番を `酒種別タブ → Hero → 気になる酒 → 飲んだ一覧 → データ` に整理。
- `気になる酒` は買いたい/飲みたいを分けず、まとめて扱う。店で見た/すすめられた/SNSで見た等はタグ・メモで表現する。
- 飲んだ一覧の既定表示は、ボトル/ラベル写真が主役のグリッドにした。
- 全ジャンル共通で、トップ内セクションの並び替え・表示/非表示を持つ方針を追加。ただし完全自由レイアウトはやらない。

### 変更意図
酒トップは入口を軽くし、Heroで思い出、気になる酒で未来、飲んだ一覧で記録、データで傾向を見る構成にする。セクション順はジャンルやユーザーの使い方で重要度が変わるため、全カテゴリ共通で軽いカスタムを許可する。

### 主な変更ファイル
- docs/spec-B1-ライブラリ画面.md（酒トップ順、気になる酒、飲んだ一覧、全ジャンルセクション順カスタムを更新）
- docs/spec-A4-テンプレ別プリセット.md（酒種別タブの並び替え/表示設定を追記）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
ドキュメントのみ。ビルド対象なし。酒トップと共通見せ方機能に今回の決定が反映されていることを確認。

### 残課題
- 酒の「飲んだ一覧」を銘柄単位にするか、飲んだ回単位にするかを決める。
- `spec-A5` にセクション順設定、酒データ表示、気になる酒数などの集計を反映する。

## 2026-07-08: 酒詳細を3段階開示に変更

### 変更概要
- 酒詳細画面の入力・表示を、Lv1「みんな使う」/ Lv2「詳しく記録」/ Lv3「専門スペック」の3段階に整理。
- Lv1は名前・酒種別・写真・飲んだ日・場所・評価・ひとことメモだけで成立する軽い記録にした。
- Lv2は度数・生産者・地域・飲み方・価格・同行者・ラベル写真・タグ。
- Lv3は日本酒の精米歩合/日本酒度/酸度/使用米/酵母/製造年月など、酒種別プリセットの詳細値。初期は閉じる。

### 変更意図
お酒はライト層と詳しい層の差が大きい。最初から網羅的なフォームを見せると登録が重くなるため、入口は軽くし、必要な人だけ深く記録できる段階開示にする。

### 主な変更ファイル
- docs/spec-B1-ライブラリ画面.md（酒詳細の3段階開示を追加）
- docs/spec-A4-テンプレ別プリセット.md（酒プリセットの段階開示を追加）
- docs/08-テンプレユニット設計.md（酒テンプレの入力負荷方針を追加）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
ドキュメントのみ。ビルド対象なし。酒詳細がLv1/Lv2/Lv3の3段階で記載されていることを確認。

### 残課題
- `spec-A7` の酒登録フローで、クイック登録/ちゃんと登録/専門スペック展開の導線を詰める。

## 2026-07-08: Liveのペイン・思い出保管/統計方針・横断マスター方針を記録

### 変更概要
- `spec-B1` のライブ・フェス section を更新。Liveは後で詳細を詰める前提で、方向性メモとして「思い出保管＋統計」を主軸にした。
- Live Rock等のレビューから見えたペインを整理。フェス/対バン/KPOP/アイドル/声優/2.5D系は、出演者・公演回・セトリ・チケット・費用・同行者の管理が重くなりやすい。
- フェス/対バンの出演者は、画像OCR・コピペ一括登録・手入力追加に対応する方針を追加。出演者一覧と実際に観た出演者を分ける。
- Liveと観劇はUI上は別ジャンルだが、内部ではチケット・公演回・出演者・座席・ProgramItem・写真/グッズ/費用を共通部品として扱う方針を追加。
- 推しは独立ジャンルではなく、Person/Artist等のマスターにFavoを付ける横断軸として整理。同行者は絵文字/色/イニシャル/写真チップ付きのCompanionマスターとして扱う。
- 予定共有はv1では共有カード・カレンダー出力・メッセージ送信用テンプレを優先し、アプリ内友達機能/共同編集はv2以降とした。

### 変更意図
favorecoのLiveの勝ち筋は、チケット販売やライブ発見ではなく、参戦した思い出を保管し、自分の音楽/推し活データを統計で見返せること。フェス/対バン/アイドル系の実利用では、複数出演者・複数公演・セトリ・費用・同行者・推し別集計が絡むため、早い段階で構造だけ切っておく。

### 主な変更ファイル
- docs/spec-B1-ライブラリ画面.md（ライブ・フェス方向性メモ追加）
- docs/spec-A3-ユニット別フィールド.md（Person/Favo、Companionアイコン方針を追記）
- docs/spec-A4-テンプレ別プリセット.md（ライブ形態・出演者一括登録・ProgramItem・共有方針を追記）
- docs/08-テンプレユニット設計.md（ライブテンプレに同内容を追記）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
ドキュメントのみ。ビルド対象なし。Liveの方向性、フェス/対バン出演者登録、観劇との共通部品、Favo横断軸、同行者アイコン、予定共有の段階案が仕様へ入っていることを確認。

### 残課題
- Liveの詳細UI、トップデザイン、統計項目、チケット進捗の見せ方は後で詰める。
- `spec-A5` にFavo別/同行者別/曲別/会場別/費用集計を反映する。
- `spec-A7` にLiveのクイック登録、OCR、コピペ一括登録、共有カード生成を反映する。
- 次は酒ジャンルへ戻る。

## 2026-07-08: 酒ジャンルの共通ベースと酒種別プリセット構造を整理

### 変更概要
- `spec-B1` の酒セクションを更新。Heroを「最近飲んだお酒」または「お気に入りからランダム」にし、ボトル写真・名前・酒種別・度数・飲んだ日・飲んだ場所を表示する方針にした。
- 全酒種共通情報を整理。酒そのものは `Event`（名前 / 酒種別 / 度数 / 代表写真）、飲んだ体験は `Visit`（飲んだ日 / どこで飲んだ / 評価 / メモ / 写真）に分ける。
- 酒種別タブ `すべて / 日本酒 / ビール / ウィスキー / ワイン / 焼酎 / その他` をトップの軸に追加。
- 日本酒・ウィスキー・ワイン・ビール・焼酎の固有情報は、共通ベースの上に酒種別プリセットとして足す方針を明文化。

### 変更意図
酒は種類ごとに記録したい情報が違うが、名前・飲んだ日・酒種別・度数・飲んだ場所は横断して使う。最初から共通ベースと酒種別固有プリセットを分けることで、後からウィスキーやワインを追加してもスキーマを壊さないようにする。

### 主な変更ファイル
- docs/spec-B1-ライブラリ画面.md（酒トップ構成更新）
- docs/spec-A3-ユニット別フィールド.md（酒のEvent/Visit分離を追記）
- docs/spec-A4-テンプレ別プリセット.md（全酒種共通ベースを追加）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
ドキュメントのみ。ビルド対象なし。酒トップにHero、酒種別タブ、ボトルライブラリ、最近のテイスティング、気になる酒、味覚マップ、酒蔵/産地マップ、データの構成が入っていることを確認。

### 残課題
- `spec-A5` に酒のHero候補、味覚マップ、酒蔵/産地マップ、再飲集計の算出ルールを反映する。
- `spec-A7` に酒のクイック登録（名前＋酒種、写真＋酒種、URL保存、ラベルOCR）を反映する。
- ウィスキー/ワイン/ビール/焼酎の詳細プリセットは、実装前に入力負荷を見て最小化する。

## 2026-07-08: 御朱印ジャンルトップを印種別タブ＋最近いただいた印Heroに更新

### 変更概要
- `spec-B1` の御朱印セクションを更新。印種別タブ `すべて / 御朱印 / 御城印 / 御船印` をトップの軸にした。
- Heroを「最新の御朱印帳」ではなく、**最近いただいた印そのもの**に変更。御朱印/御城印/御船印の写真を大きく出し、場所名・日付・都道府県・帳面名を表示する。
- 帳面は主役ではなく整理単位として扱う。最新帳だけ少し大きめ、帳面一覧は小さめカード。収録数・最新記録・表紙写真を表示する。
- 地図、気になる場所、データの役割を整理。気になる場所は印種別に応じて「行きたい寺社 / 行きたい城 / 行きたい港・船」と文言を切り替える。

### 変更意図
御朱印ジャンルでユーザーが見返したい主役は帳面の表紙ではなく、いただいた印そのもの。御城印・御船印も同じ器で受けるが、UIでは種別タブで切り替えて散らからないようにする。

### 主な変更ファイル
- docs/spec-B1-ライブラリ画面.md（御朱印セクション更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
ドキュメントのみ。ビルド対象なし。御朱印セクションに印種別タブ、最近いただいた印Hero、帳面/地図/気になる場所/データのトップ構成が反映されていることを確認。

### 残課題
- `spec-A3` / `spec-A5` に印種別タブの集計・地図・Hero候補・気になる場所を反映する。
- 次は酒ジャンルのベースを整理する。

## 2026-07-08: おでかけ施設・美術展トップと動画/MediaAsset方針を反映

### 変更概要
- `spec-B1` のおでかけ施設を確定記述に更新。テーマパーク/水族館/動物園/植物園を共通の `OutingFacilityGenreTop` として扱い、予定がある日はToday/Next Plan Card、予定がない日は思い出Heroを主役にする構造を明文化。
- おでかけ施設のトップ構成を確定：予定カード内のGoogleカレンダー1日表示風タイムライン、思い出Hero、訪問日アルバム、写真ギャラリー、動画、コレクション、データ。
- 水族館/動物園/植物園は写真メインとし、写真ごとに生きもの名/動物名/植物名/展示名を `caption` で入れられる方針を追加。種名板OCRは入力補助、AI種同定はv1対象外。
- `spec-B1` 美術展に、会期・予定Attentionの**ミニガントバー型**を追加。会期終了間近/日時指定/チケット済みをHero下に最大3件表示する。
- `spec-A3` と `09` を更新し、PhotoBlobを写真専用にしすぎず、将来の動画/iPad同期を見据えた `MediaAsset` 方針を追加。動画はデフォルトPhotos参照＋サムネ＋メタ、アプリ内コピー/動画Cloud同期は明示ONにした。
- 今後の進行順を、御朱印 → 観劇 → ライブ後回しとする方針を確認。

### 変更意図
テーマパークは頻繁な予定管理より思い出写真が主役だが、当日/直近予定がある日は実用的に動ける画面が必要。水族館・動物園・植物園では写真とcaptionが中心になる。動画は需要が高い一方、アプリ内コピーや自動同期は容量圧迫につながるため、最初から保存モードと同期状態を分ける。

### 主な変更ファイル
- docs/spec-B1-ライブラリ画面.md（おでかけ施設・美術展更新）
- docs/spec-A3-ユニット別フィールド.md（U4タイムライン、MediaAsset/caption/video方針）
- docs/09-CloudKit写真ストレージ仕様.md（MediaAsset・動画保存/同期方針）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
ドキュメントのみ。ビルド対象なし。おでかけ施設の共通トップ、美術展ミニガントバー、動画のPhotos参照/明示保存/将来同期の方針が仕様へ入っていることを確認。

### 残課題
- `spec-A5` におでかけ施設の訪問回数/写真枚数/よく行く月/同行者、及び美術展の会期Attention算出・ミニガント表示ルールを反映する。
- `spec-A7` におでかけ施設のGoogle/Appleカレンダー候補取り込み、写真時刻候補、種名板OCRの登録フローを反映する。
- 次は御朱印ジャンルトップを見直し、その後に観劇へ進む。ライブは優先度を下げる。

## 2026-07-08: 映画ジャンルトップをHero Carousel＋ポスター主役に更新

### 変更概要
- `spec-B1` 映画セクションに、ファーストビューの **Hero Carousel** を追記。最近観た映画固定ではなく、次に観る映画・もうすぐ公開・最近観た映画・手動で「トップに出す」映画を横スワイプで切り替える構造にした。
- 映画一覧は **ポスターグリッド既定** と明記。テキストは最小限にし、監督・出演者・あらすじ・登録元・劇場/座席は詳細画面へ逃がす。
- 表示モードを追加：ポスターのみ（既定）／ポスター＋最小情報／情報カード／リスト。列数は2列/3列/4列で切替可能にする。
- 予定はグローバルのプラン/カレンダーで横断表示しつつ、映画トップでは7日以内の鑑賞予定・公開日が近い観たい映画・舞台挨拶/抽選等の要対応がある時だけHero/小Attentionに出す方針にした。

### 変更意図
映画は言葉よりポスターで思い出すジャンルのため、トップを管理表にせず、ポスターが並ぶ私的コレクションとして見せる。一方でfavorecoの差別化である「予定でワクワクする」体験も残すため、Heroだけは動的に次の予定・手動候補を出せる構造にする。

### 主な変更ファイル
- docs/spec-B1-ライブラリ画面.md（映画セクション更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
ドキュメントのみ。ビルド対象なし。映画セクションにHero Carousel、ポスター主役、表示モード、列数切替、予定の条件付き表示が反映されていることを確認。

### 残課題
- `spec-A3` / `spec-A5` に `isHeroCandidate` / `heroSortOrder` / `heroAddedAt` 相当と、映画Hero候補の算出ルールを反映する。
- 映画のクイック登録・TMDb/URL画像のローカル保存方針を `spec-A7` / 写真仕様へ反映する。

## 2026-07-08: 書籍ジャンルのメインページ・状態設計を確定

### 変更概要
- `spec-B1` の書籍ライブラリを確定記述に更新。棚板/木目の古い本棚表現を避け、表紙主役の現代的なカード/グリッド型にする方針を明文化。
- 書籍トップ構成を確定：最近買った本／読書データ／気になる本／購入済み一覧（ジャンルタブ＋もっと見る）／読書メモ／写真・コレクション／シリーズ。
- 書籍タイルに表示モードを追加：**書影グリッド（既定）**／情報カード／リスト。書影だけで眺めるモードを選べるようにした。
- 書籍状態を単一の「読了/積読」から、**共通興味ステータス（気になる/欲しい）＋書籍固有の入手状態（未入手/購入済み）＋購入済み後の任意読書状態（未読/読書中/読了/中断/再読中/再読了）**に分離。
- ISBN/URL由来の書影は外部URL依存にせず、アイキャッチ用にローカル保存/キャッシュする方針に更新。写真欄へは自動追加せず、ユーザーが「写真にも保存」を選んだ場合のみPhotoBlobへ追加。

### 変更意図
「買ったか忘れる」「書店で気になった本をISBNで放り込む」という実用性を保ちつつ、読書管理アプリの重い進捗管理に寄せすぎないため。トップでは表紙を主役にし、著者/訳者/出版社/ISBN/登録元などの詳細は詳細画面へ逃がして、登録と閲覧を軽くする。

### 主な変更ファイル
- docs/spec-B1-ライブラリ画面.md（書籍ライブラリ確定）
- docs/08-テンプレユニット設計.md（書籍テンプレの状態・購入情報・書影/写真方針を更新）
- docs/spec-A4-テンプレ別プリセット.md（書籍プリセット状態を3レイヤーへ更新）
- docs/spec-A3-ユニット別フィールド.md（書籍フィールド定義を更新）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
ドキュメントのみ。ビルド対象なし。書籍の古い「読了/積読」単一状態記述を主要仕様から3レイヤー状態へ置き換え、書影グリッド表示モード・購入情報折りたたみ・書影ローカル保存方針が反映されていることを確認。

### 残課題
- `spec-A5` に書籍の購入冊数/読了冊数/月別推移/ジャンル比率/カレンダー表示（購入日・読始日・読了日・メモ日）を反映する。
- `spec-A7` にクイック登録（ISBN/URL/写真/タイトル）から書籍 `InboxItem` → `Event` 昇格の具体フローを反映する。

## 2026-07-08: Mystorium再発防止の実装アーキテクチャ・性能ルールを正本化

### 変更概要
- Mystoriumで重かったリファクタ・性能改善の教訓を、favorecoの実装前ルールとして `docs/14-実装アーキテクチャ・性能ルール.md` に新設。
- `favoreco/CLAUDE.md` §5 に、最重要4原則（入力中にDBを書かない／一覧で原寸画像を使わない／bodyで全件処理しない／巨大Viewを作らない）と、DraftState・Snapshot/DTO・画像3段階・background/batch save・Apple Kit境界の必須化を追記。
- ライフサイクル状態の責務分離を明文化：`InboxItem` / `Event` / `Plan`・`Performance` / `TicketAttempt` / `Visit` / `MemoryDraft`。複数先行・落選履歴・名義別当選率・通知更新に耐えるため、チケット状態を `Visit` に直持ちしない方針を正本化。
- 将来Androidを完全に捨てないため、SwiftUI/SwiftData/CloudKit/MapKit/WeatherKit/EventKit/Vision/StoreKit はiOS実装で使いつつ、ドメインモデル・状態遷移・Smart Add解析結果・Provider境界はApple APIへ直結させない方針を追加。

### 変更意図
Mystoriumで後から直して高コストだった問題（巨大View、SwiftData直接更新、body内全件処理、原寸画像デコード、MainActor上のI/O、1件ごとのsave）を、favorecoでは実装初日から避ける。ジャンル数・画像数・チケット状態がMystoriumより増えるため、最初から責務分離と性能予算を仕様化する。

### 主な変更ファイル
- favoreco/CLAUDE.md（重要な実装ルールに追記）
- docs/14-実装アーキテクチャ・性能ルール.md（新規）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
ドキュメントのみ。ビルド対象なし。`CLAUDE.md` から新規doc14への参照があること、doc14内でDraftState/Snapshot/DTO/TicketAttempt/Apple Kit境界のルールが一通り明文化されていることを確認。

### 残課題
- 既存の `spec-A8` はまだ「Visitにチケット状態を持たせる」記述が残るため、次に `TicketAttempt` 独立モデル前提へ改訂する。
- `spec-A1` / `spec-A3` / `spec-A5` / `spec-A7` に `InboxItem`・`Plan/Performance`・`MemoryDraft`・Snapshot/DTO・Provider境界を反映する。

## 2026-07-07: mystoriumbase の設計正本をマージ＋doc12/13を正本に突き合わせ

### 変更概要
- `claude/mystoriumbase-generic-app-pkvkzt`（main未マージ）の設計確定を app-ui-design-inspiration ブランチへ**マージ**：DESIGN.md（デザイン正本）・design-preview.html・spec-A4/A5/A6/A8・spec-B1 等が全部入りに。コンフリクトは project-log のみ（両エントリ保持で解消）。
- **doc13 §9 チケット管理**を spec-A8 のリサーチに差し替え：参考にしていたプレイガイド（ぴあ/e+/tixeebox/MOALA）に加え、**実際の直接競合＝LiveSoul／TheaterRecords／Cherie Log／Live Rock・relight・Tickemo**、チケコレ=更新停止を明記。9-A（管理アプリ＝競合）/9-B（プレイガイド＝参考）に再構成し spec-A8 を正本参照に。
- **doc12（ホーム画面デザイン）を DESIGN.md に突き合わせ**：トークンの正本を DESIGN.md に委譲し、本書は差分だけ保持。**重大な対立を明示**＝3案/モックは「暖色クリーム＋金でホーム全体」、DESIGN.md 憲法#4は「ホーム＝ニュートラル白＋青・色はライブラリだけ」。§5-0に色の要決定、§5-1にナビ（spec-B1の5タブ＝プラン廃止/マイページ追加）を追加。YOUR JOURNEY の発生源を spec-A8 状態pipelineに接続。
- モック（home-mock.html）に「色・ナビ未反映／DESIGN.md・spec-B1が正」の注記を追加。

### 変更意図
別セッションで進んだ設計正本（DESIGN.md/spec-A8/spec-B1）と、本セッションで作ったホームモック・ライバル一覧を1ブランチに統合し、矛盾（暖色ホーム vs ニュートラル憲法・ナビ4/5タブ・チケット競合の顔ぶれ）を可視化してユーザー判断に載せる。

### 主な変更ファイル
- （マージ取り込み）docs/DESIGN.md・design-preview.html・spec-A4/A5/A6/A8・spec-B1 ほか
- docs/13-ジャンル別ライバル一覧.md（§9 再構成・spec-A8準拠）
- docs/12-ホーム画面デザイン.md（DESIGN.md委譲・色/ナビの要決定を明示）
- docs/mock/home-mock.html（未反映注記）
- docs/project-log.md（本記録・マージ）

### 確認結果（実機 / ビルド）
ドキュメント/HTMLのみ。マージ後コンフリクトマーカー無しをgrepで確認。

### 要決定（ユーザー）
- **ホームの色**：DESIGN.md 憲法維持（ホーム=白+青）か、ホームだけ暖色+金を例外化して DESIGN.md 改訂か（doc12 §5-0）。
- 決定後：モックを DESIGN.md/spec-B1（5タブ）に合わせて修正 → spec-B2 ホーム画面を新設。

## 2026-07-07: ホーム画面デザイン言語の確定作業＋ジャンル別ライバル一覧

### 変更概要
- **ホーム画面モック（`docs/mock/home-mock.html`）新規**: ChatGPT提供の3案（＋ジャンル別5案）からデザイン言語を抽出・統合した、Safariでそのまま開ける自己完結モック。白カード on クリーム地・写真主役・真鍮ゴールド差し色・セリフ見出し・浮遊ガラスタブバー。目玉は**YOUR JOURNEY**（発見→抽選→当選→体験→記録の体験ライフサイクルをタイムライン化）。
- **ホーム画面デザイン仕様（`docs/12-ホーム画面デザイン.md`）新規**: concept §6で「別途デザイン仕様で確定」と保留していたデザイン言語（カラートークン・タイポ・素材）とホーム構成を草案化。§5に要選択事項5点（集計の重複/JOURNEYの対象/ヒーローの明暗/書体/サブコピー）。
- **ジャンル別ライバル一覧（`docs/13-ジャンル別ライバル一覧.md`）新規**: 実装予定8ジャンル＋横断機能（チケット管理・スケジュール管理）ごとにライバル・参考サービスを台帳化。01（戦略総論）を補完するジャンル別の実務台帳。酒・御朱印・おでかけ施設・チケット・スケジュールはWeb検索で裏取り。

### 変更意図
- ブランチ`app-ui-design-inspiration`の宿題＝3案からデザイン言語を確定しホーム構成に落とすこと。ユーザーが「テンション爆上がる構成」と評価した密度・物語性（YOUR JOURNEY）を中核に据えた統合案をモックで提示し、react可能にした。
- ライバル一覧はユーザー依頼（実装予定ジャンルごと＋チケット/スケジュール参考元）。01は7カテゴリを戦略視点で扱うが、新規テンプレ（酒/おでかけ施設/御朱印）と横断機能が未カバーだったため補完。

### 主な変更ファイル
- docs/mock/home-mock.html（新規）
- docs/12-ホーム画面デザイン.md（新規・草案）
- docs/13-ジャンル別ライバル一覧.md（新規）

### 確認結果（実機 / ビルド）
ドキュメント＋HTMLモックのみ。モックは外部リソースなしの自己完結（Safariでそのまま表示）。数値・料金・提供状況（特にVinicaの終了情報）はMac側で最終確認が必要。

### 要選択・残課題
- 12 §5の5点（ユーザー判断）を決めてデザイン言語を「確定」に上げ、concept §6の保留を解消
- ジャンル別5案（映画=暗色/ライブ/観劇=劇場赤/美術展=青/酒）を12のデザイン言語と統合し、ジャンル別スキンのルール化
- ②-A続き A4〜A6（既存の残課題）

## 2026-07-07: デザインの正本 DESIGN.md を新設＋プレビュー（同骨格×別色世界を実証）

### 変更概要
- ユーザー参照（google-labs-code/design.md／VoltAgent/awesome-design-md）を踏まえ、**favorecoのデザイン正本 `docs/DESIGN.md` を新設**。形式はawesome-design-md流（プレーンMD＋軽量トークン）。理由＝厳密YAML＋CLI版はexport先がCSS/TailwindでSwiftUIに無駄、散文＋パレット＋ガードレールの軽い形が実装時に最も効く。
- 内容：空気感／**共存の憲法（ガードレール）**／共通スケルトン色＋**ジャンル8色世界**（観劇ワインレッド+ゴールド・酒琥珀・映画チャコール・美術展ブルー・ライブコーラル・御朱印朱×墨×金・おでかけグリーン・書籍タン）／タイポ（既定sans・格調ジャンルはserif）／8pxグリッド余白／コンポーネント／ダーク／アンチパターン／SwiftUI写経メモ。
- **`docs/design-preview.html`**：パレット・タイポ・コンポーネント＋**同じ骨格×別色世界のライブラリ4例（映画/観劇/酒/美術展）**。ステータス/ヘッダー/フィルタ/セクション/ナビは同一構造、色・書体・中身のレイアウトだけジャンルで替わる＝共存の憲法を視覚実証。

### 変更意図
口伝だとセッションをまたいで薄れる（実際ロスト経験あり）色・寸法・佇まいを1枚の正本に固定し、実装（SwiftUI）とモックのブレを防ぐ。仕様正本=spec-*、意思決定=project-log、見た目トークン=DESIGN.md の三分担を確立。

### 主な変更ファイル
- docs/DESIGN.md（新規・デザイン正本）
- docs/design-preview.html（新規・プレビュー）

### 確認結果（実機 / ビルド）
ドキュメント/HTMLのみ。ブラウザでプレビュー確認（絵文字は仮・実装はSF Symbols）。

### 残課題
- DESIGN.md のトークンをSwiftUI（Asset Catalog/定数/Material）へ写経（実装フェーズ）
- 残ジャンルのライブラリ確定（ライブ・おでかけ・書籍）後にプレビューへ追加
- ダーク版プレビュー（preview-dark）の要否

## 2026-07-07: 酒ライブラリ／酒カードの表示方向を確定（spec-B1 §5）

### 変更概要
- ユーザーのスケッチ2枚（IMG_6312 フルカード／IMG_6313 2列コンパクト）とモック確認を経て、**酒の見せ方を確定**（「デザインはダサいけどそういうこと」＝構造・振る舞いは合意・ビジュアルの磨きはデザインフェーズ）。
- **カード構造＝名前バンド＋全体写真（ボトル）＋ラベル表・裏＋下部情報**。裏ラベルが無い時は右枠を味わいレーダー（さけのわ6軸）に自動差し替え。
- **密度3段（表示サイズ切替）**＝最小3列アイコン（名前＋ボトルのみ）／コンパクト2列（＋産地・★・既定）／フル1列（＋ラベル・スペック・レーダー）。同一カードが密度で伸縮。
- **タップで詳細**＝スペック個別列＋6軸レーダー×味覚マップ2軸＋官能メモ＋評価＋酒蔵ハブ横断リンク。酒キラー＝酒蔵所在県マップ・味覚マップ（A5連動）。

### 変更意図
酒の「一覧（棚）→カード→詳細」を確定し、ライブラリ残ジャンルの1つを埋める。SNSは作らずさけのわ集計を借りる方針（02勝ち筋#4）と整合。

### 主な変更ファイル
- docs/spec-B1-ライブラリ画面.md（§5 酒 を確定記述で追記）

### 確認結果（実機 / ビルド）
ドキュメントのみ。モックで構造をユーザー確認済み（ビジュアルは仮）。

### 残課題
- ホーム（モジュール式）の「Record」と「最近のアクティビティ」の切り分け（要ユーザー判断）→ 確定後 spec-B2 ホーム画面を新設
- ライブラリ残ジャンル：ライブ・おでかけ施設・書籍
- 酒カードの実写真反映・最小アイコンに★/産地を出すかの微調整はデザインフェーズ

## 2026-07-07: SNS（公開型レーティング・口コミ）非採用を決定 → シェアカードで代替

### 変更概要
- ユーザー質問「SNS機能（レーティング・口コミ）をつけると大変か」への検討の結論として、**公開型SNSは非採用**を決定。「自分の評価・感想（private・★/メモ）」は既に実装済みで軽いが、**公開UGC（他人と共有する口コミ・フォロー）は別プロダクト級の負担**。
- 非採用の理由：①サーバ/共有DB ②アカウント/プロフィール ③**モデレーション＋App Store Guideline 1.2（UGC義務）** ④コールドスタート ⑤**プライバシー方針（自分の・私的な記録）との矛盾**。加えてネットワーク効果を持つ既存勢（Letterboxd/食べログ/Untappd）と最も勝ちにくい土俵になる。
- **代替＝シェアカード**（既存SNSへ吐き出す・バックエンド/モデレーション不要）。これがfavorecoの唯一の"社交"手段。
- **コミュニティ集計は"借りる"**を明文化：さけのわ（日本酒版Untappd＝本格バックエンド運用）の公開API（さけのわData・読み取り専用）で集計フレーバー/ランキングを参考値として取得。映画=TMDb、書籍=openBD/NDLも同型。個々の口コミ文の転載は規約・権利上しない（集計値の参考表示に留める）。

### 変更意図
「大変なバックエンドは他社が運用済み、favorecoはその出力だけ読み取りで使う」パターンを戦略として確定し、favoreco本体を「自分の記録 × 横断 × 登録の楽さ」に集中させる。SNS化の誘惑に対する明文の歯止め。

### 主な変更ファイル
- docs/02-コンセプトと勝ち筋.md（勝ち筋#4にSNS非採用決定を追記）
- docs/spec-A8-チケット管理・通知.md（§6 シェアカードを唯一の社交手段と明記）

### 確認結果（実機 / ビルド）
ドキュメントのみ。ビルド対象なし。

### 残課題
- シェアカードの具体設計（テンプレ・背景透過ステッカー・年間ベスト）＝Mystorium RESONANCEカード資産の流用
- 将来サブスクの目玉として限定的共有機能を検討する余地は残す（当面は非採用）

## 2026-07-07: U4リスト画像OCR取込（汎用）＋FC管理を登録情報・連携ハブへ

### 変更概要
- **U4「リスト」ユニットに📷画像OCR取込を追加（汎用・A3 §5-2 新設）**：ユーザー指摘「セトリ記録はOCRで写真から入れたい／博物・美術展でも使えそう」を受け、**セトリ専用でなく U4 を使う全種別の共通機能**に一般化。写真→撮影補正（feasibility §4-2）→Vision `VNRecognizeTextRequest`→縦位置ソートで順序化→プレビューで訂正/並び替え→U4 unitFieldsRaw。呼び名は種別切替（ライブ=セトリ／観劇=演目／美術展=出品目録・作品リスト／おでかけ=見たもの）。外部ライブラリゼロ。
- **美術展での住み分けを明記**：U4出品目録OCR＝観たもののチェックリスト／U11コレクション＝自分で撮った個別作品の写真＋キャプション。曲名/作品名は名寄せ正規化で A5 演奏回数・再訪集計に接続。複数列/縦書き/番号なしのパース注意と、複雑レイアウトの行単位フォールバック（失敗しない設計）を実装メモに記載。
- **FC管理の置き場所を「マイ/設定 > 登録情報・連携」ハブに確定（A8 §3.4 新設）**：ユーザー指摘「ユーザー登録情報にFC管理を／Googleカレンダー連動でどうせアカウントを入れる」を反映。FCアカウント/名義は個々のチケットに埋めず**ユーザー登録情報として一元管理**（1回登録・全チケットから参照＝Cherie Log同型）。同ハブに**外部カレンダー連携（EventKit＝Apple/iOS上のGoogleアカウント経由・読み取りのみ）**を同居させ「アカウントを入れる場所」を1箇所に集約。パスワードは平文保存しない方針を維持。

### 変更意図
OCRリスト取込を最初からU4汎用として設計し、ジャンル追加のたびに作り直さない。FC名義を record内蔵からユーザー登録情報（マスター）へ引き上げ、外部アカウント連携と同じ「連携」面にまとめることで、掛け持ち運用と設定導線を自然にする。

### 主な変更ファイル
- docs/spec-A3-ユニット別フィールド.md（§5-2 リスト画像OCR取込 新設）
- docs/spec-A8-チケット管理・通知.md（§3.4 登録情報・連携ハブ 新設・setlist/v1スコープに画像OCR追記）
- docs/spec-A7-登録フロー.md（U4リストOCRの入力補助を観察に追記）
- docs/08-テンプレユニット設計.md（美術展リスト＝出品目録OCR・U11住み分けを追記）
- favoreco/CLAUDE.md（U4リストOCR汎用・FC登録情報ハブを追記）

### 確認結果（実機 / ビルド）
ドキュメントのみ。A3/A7/A8/08/CLAUDE.md の相互参照が矛盾しないことを読み直しで確認。

### 残課題
- リストOCRの精度チューニング（種別辞書＝曲名/作品名の表記ゆれ・複数列パース）
- 外部カレンダー連携の実装範囲（EventKit読み取り・Google経由の確認）はfeasibility §4-3準拠で継続
- FC/名義の名寄せ（同一FC重複統合）＝A6

## 2026-07-07: 推し活/チケット/ライブ管理アプリのリサーチ → spec-A8（チケット管理・通知）新設・v1徹底作り込み確定

### 変更概要
- **競合リサーチ（推し活/チケット/ライブ管理）**：ユーザー指摘「チケコレは更新停止・レビュー無し＝参考にしない」を受け、クラスタを調査。実質の王者は **LiveSoul**（抽選管理＝当選率追跡/締切リマインダー/座席一部3D/遠征マップ・★4.5/1273件）・**TheaterRecords**（チケットOCR自動認識/分析）・**Cherie Log**（複数名義・掛け持ち管理）。ビジュアル派＝**Live Rock/relight/Tickemo**（セトリOCR/シェアカード/カウントダウン）。
- **戦略の確定**：競合は全て単一ジャンル専門アプリ。favorecoの勝ち筋は①**横断**（観劇/ライブ/映画を1アプリ・統一統計）②**登録の楽さ**。Live Rockの★4レビュー2件が競合の最大共通不満＝「初期設定・全手動入力が面倒／既存公演は外部連携で引きたい／会場・アーティスト検索が弱い」を名指し → favorecoのA7（OCR/URL取込/参照DB連携/名寄せ）が直接刺さることを確認。
- **v1スコープ確定（ユーザー：「V1を徹底的に作り込む、通知機能なども含めて」）**：チケット/ライブ管理を **A寄り＝v1でフル装備**。状態pipeline・通知全タイプ・FCアカウント/名義管理・OCRスキャン・座席テキスト・セトリ（並び替え可）・当選率/名義別/座席傾向分析・カウントダウンを v1。**3D座席のみ v2**（スコープ判断でなくデータ制約＝会場別座席図が要る／LiveSoulも対応会場のみ）。シェアカード・セトリ外部連携・認証情報キーチェーンも v2。
- **新規 spec-A8 作成**：チケット状態pipeline（気になる→申込前→当落待ち→当選/落選→入金待ち→発券待ち→参戦済/見送り）・先行区分・期限フィールド・通知設計（UserNotifications・タイプ別/オフセット・ScheduleResultで失敗可視化）・**FCAccountエンティティ**（会員番号/有効期限アラート/年会費/掛け持ち色分け・パスワードは平文保存しない方針）・OCR取込・集計連携を1本に集約。

### 変更意図
チケコレを基準にした旧設計を、現行の実質王者（LiveSoul/TheaterRecords/Cherie Log）基準に更新し、「記録も管理も一番」を v1 から成立させる。分量が多いため独立分冊（A8）に切り出し、A3/A5/08 からは参照させて重複を避ける。

### 主な変更ファイル
- docs/spec-A8-チケット管理・通知.md（新規・正本）
- docs/spec-A3-ユニット別フィールド.md（FCAccountマスター追加・チケット行をpipeline/先行区分/セトリ/名義参照に拡張・CloudKit関係にfcAccount追加）
- docs/spec-A5-集計カレンダー地図.md（当選率/セトリ演奏回数/名義別/座席傾向を統計表に追加）
- docs/08-テンプレユニット設計.md（チケットユニットをA8参照に更新・通知v1前倒しを明記・FC名義/セトリ追記）
- favoreco/CLAUDE.md（チケット/ライブ管理v1徹底作り込みの1項追加）

### 確認結果（実機 / ビルド）
ドキュメントのみ。ビルド対象なし。A3/A5/08/CLAUDE.md の記述が spec-A8 と矛盾しないことを読み直しで確認。

### 残課題
- 認証情報（パスワード）のキーチェーン/パスワード連携の要否（v1はloginHintのみ・平文非保存を確定）
- セトリの外部DB連携（Livefans等）の可否・規約
- 3D座席の対応会場データ源
- FCAccountの名寄せ（同一FC重複統合）詳細＝A6準拠
- 通知設定UI・カウントダウン表示のデザインフェーズ確定
- ライブラリ（spec-B1）の残ジャンル（ライブ/酒/おでかけ/書籍）と、観劇ライブラリへのFC名義・当選率の反映

## 2026-07-06: 書籍テンプレ確定（消失分の復元）＋参照DBシード元一覧を追加

### 変更概要
- **書籍テンプレ確定（08 §4-11）**：作品DB・バーコード・ソーシャルでは戦わない方針の上で復元。ISBN取得＝**openBD**（無料・和書に強い・入力補助のみ）＋**奥付OCR○**（洋書/同人/古書=openBD穴埋めフォールバック）。対象=本(1冊/1巻)・回=読んだ回。成果=読了/積読/中断/再読。
- **シリーズ・続巻機能★**：seriesName＋巻数でグルーピング。**最新刊登録(add-next)**（最新巻から属性引き継ぎ＋巻数+1で登録）・**巻スクロール**（シリーズビュー）・**一覧のスタック表示**（シリーズを重ねた1タイルに畳む）。v1はseriesNameグルーピング（派生・ハードなSeriesエンティティなし）。
- **書籍種別サブレイヤーは通さない**：ユーザーの読書（漫画・技術・デザイン）では形態(U14)1つで十分。A2のsubType nil特例＋後付け可なので将来も痛い作り直しなし。
- **参照DBシード元一覧（docs/11 新規）**：各カテゴリのデータ取得元をカタログ化（実取得はWeb取得可能な環境に依頼する前提・当環境は403多発）。

### 決定ログ
- openBD vs 奥付OCR＝相補（openBDが持てば構造化で精度上・無ければOCR/手動。洋書はopenBD弱くOCRが効く）。
- 場所（読んだ場所）・評価軸レーダーは書籍では低価値→○オフ開始。座席等＝–。
- テンプレ第1弾が全確定（観劇/美術展/ライブ/映画/酒/おでかけ施設/御朱印/書籍）。テーマパークはおでかけ施設に統合。
- **登録フローの入り口を精緻化（spec-A7）**：書籍＝**NDL Searchでタイトル検索**（openBDはISBN引きのみ）＋バーコードは**「ISBN(978〜)」と明示・価格コード(192〜)は自動リジェクト**（マイクロコピー原則＝生活語＋誤操作防止語だけ明示・司書資格者のユーザー指摘）。奥付OCRは**洋書対策として残す**（稀）。酒の「銘柄で探す」＝**さけのわデータAPI採用**（無料・商用可・帰属のみ・2500超銘柄＋フレーバー数値）。御朱印＝地図/名前/現在地から選ぶ（Apple POIが本物のDB）。"探す"が言えるのは裏に本物のDB/APIがある時だけ（映画TMDb・書籍NDL・酒さけのわ・場所Apple POI）。
- **観劇・美術展・ライブ＝URL(OGP)を主フックに格上げ**（2026-07-06 ユーザー指示）：公開DBが無いこれらは、公演/展覧会/ツアーのURL（公式・チケサイト・公式X）を貼ると**OGPで最低限（公演名 og:title・キービジュアル og:image・概要 og:description）を自動取得**。映画のURLフォールバックと同じ仕組みを主役化。構造化データ（キャスト/セトリ）は手動、チラシ写真をアイキャッチにする副フックも。

### 映画テンプレ拡充（2026-07-06 確定）
- 原題/製作年/製作国/上映時間/ジャンル/あらすじ/監督/脚本/出演者/ポスターを **TMDb（無料API・日本語・映画版openBD）** で自動取得。**登録フロー＝タイトル入力→サジェスト→選択で自動フィル→自分の記録を足す**。**URL(OGP)フォールバック**（映画.com/公式・単館やTMDb未収録の穴埋め・全文スクレイピングはしない）＋手動。
- **あらすじは「続きを読む」で畳む**・あらすじ(取得)とメモ(感想)は別欄。**出演者を○→●昇格**（人物マスター→「この監督/俳優の映画n本」＝自分のフィルモグラフィ統計）。映画.com/Filmarks/IMDbはAPI無し/複製不可で使わず、開かれたTMDbのみ。08 §4-5・docs/11 §5b。

### 残課題
- カード系（ご当地カード）テンプレの項目別ヒアリング（将来）
- **②-A（データモデル仕様 A1〜A7）一巡完了（2026-07-06）**。A6＝同一対象判定（正規化＋fetch-first upsert・リピートはタイトル正規化＋候補提示でユーザー確定）・スナップショット（生きた参照＋値コピー・削除/参照DB消滅に耐える）・共有マスター横断リンク（酒蔵ハブ実装）・PhotoBlob role/caption拡張（09 §11に追記）。08 §5の持ち越し5項目も全解消（A6 §6）。**次は Xcodeプロジェクト作成＋PoC（実装①）**。

## 2026-07-06: おでかけ施設・御朱印テンプレ確定＋天気自動付与＋参照DB配信方針

### 変更概要
- **おでかけ施設テンプレ確定**（08 §4-7）: テーマパーク／水族館／動物園を**1テンプレ＋施設種別サブレイヤー**（案A）に統合。施設マスターDB・会計独立ユニット・見たもの記録は(a)回ごとのみ。
- **御朱印カテゴリ確定**（08 §4-8）: 軽量・体験/旅と併存。印種別サブレイヤー（御朱印/御城印/御船印）・位置情報必須・直書き/書き置き・由緒書き写真=コレクション・都道府県マップ。
- **天気アイコン自動付与**（08 §4-9）: 出かける系共通（観劇/美術展/ライブ/おでかけ施設・酒店書籍映画は除外）。WeatherKitで訪問日経過後に履歴天気を取得しSF Symbolsで表示。取得範囲2021/8〜。
- **参照DBの配信方針転換**（08 §4-10）: 場所DB（御朱印/城/船/施設）を同梱プリセットではなく**テンプレONでダウンロード（CloudKit公開DB）**。ここを課金の柱にする意向。
- 水族館・動物園の記録フィールドリサーチ（docs/10）を追加済み。

### 変更意図
- テーマパークのヒアリング中に水族館・動物園も同種と判明→施設種別サブレイヤーで統合（A2の2例目・下地の再利用）。御朱印もリサーチの結果「王者はDBと探すに振りデザインが弱い」＝体験の美しさが空白と確認、軽量カテゴリとして参入。
- 天気は「日付が過ぎたら自動でアイコン」というユーザー発案を土台機能化。Yahoo天気は終了/外部契約のためWeatherKit（Apple純正・方針適合）を採用。
- DB配信は「同梱せずDLで増やし課金の柱に」というユーザー意向。純ローカル原則の例外としてCloudKit公開DBで実装。

### 主な変更ファイル
- docs/08-テンプレユニット設計.md（§4-7〜§4-10 追記）
- docs/10-水族館・動物園リサーチ.md（別コミット9dfe06dで追加済み）
- docs/project-log.md（本記録）

### 確認結果（実機 / ビルド）
ドキュメントのみ。実機・ビルド対象なし。

### 決定ログ・要確認
- **AI生き物ライフリスト**: favorecoには入れない（体験ファーストのコンセプト外）。姉妹アプリ構想として温存。※ユーザー補足「作る気はあまりないが、AIを低ランニングコストで簡単に乗せられるならやる」→ 実装容易性の調査は将来課題。
- **参照DBの課金枠＝(A)＋(B)併用で確定**（2026-07-06 追記）: (A)サブスクに参照DBアクセス＋更新を含める／(B)カテゴリDBパック単体販売（アドオン買い切り）。(C)買い切り込みは不採用（増えるDBを一度の買い切りで賄えない）。守る線=「記録は無料（Apple POIでどこでも可）、課金はDBの便利さのみ」。
- **参照DBは記録の正本にしない＝スナップショット**（2026-07-06 追記）: 記録時に場所の名称/住所/座標をVisitへ焼き付け。DBやスポットが消えても記録は無傷（spec-A1 §6）。閉業＝「もう行けない場所の記録」としてむしろ価値。
- **コストは"深さ"でなく"幅"**（2026-07-06 ユーザー指摘で修正）: 寺社/城/船は半有限で安定〜微減、増え続けない。継続コストは「一度作る＋軽い保守」。成長は新しい収集ドメイン追加で作る＝御酒印（場所=既存Breweryマスター流用）/ダムカード（国交省）/マンホールカード（GKP）/道の駅きっぷ/インフラカード…各々が新(B)パック。
- WeatherKit履歴の取得範囲2021/8/1〜は要出典確認済み（Apple Developer Forums）。それ以前・海外はアイコンなし。

### 決定ログ・追記（2026-07-06）
- **収集系の括り方＝案ii＝印系とカード系を別カテゴリで確定**。理由（ユーザー）：御朱印は「スタンプラリーと揶揄されるが参拝・訪問の"証"」であり、ダムカード等の配布収集品とは行為の意味が違うので切り分けたい。印系＝御朱印カテゴリ（御朱印/御城印/御船印/将来 御酒印＝酒蔵はBrewery流用）・カード系＝別カテゴリ「ご当地カード」（ダム/マンホール/道の駅/インフラ）。仕組みは共通・フレーミング（証 vs 収集）で分ける。
- **共有マスターによる横断リンク（酒蔵ハブで御酒印↔酒）**（ユーザー要望）：御酒印と酒が同じBrewery(酒蔵)を参照し、御酒印記録に「この酒蔵で飲んだお酒一覧」を出す・御酒印から酒蔵プリセット済みで酒を登録できる。成立条件＝同一酒蔵エンティティ参照（酒蔵DBから選ぶ／手入力は名寄せ）。横断は生きた参照を使いスナップショットとは別。**Breweryを共有マスターとして設計する下地はv1から**（御酒印パックはv1圏外）。一般則＝共有マスターを持つ記録は横断でつながる（Venue↔飲食店も同型）。feasibility §4-1f・08 §4-8。

### 残課題
- カード系テンプレ（ご当地カード）の項目別ヒアリング（v1圏外・将来）
- 書籍テンプレの復元（前セッションで議論・未保存）
- ②-A続き A3〜A7

## 2026-07-06: ②-A spec-A1/A2 を清書（消失したレビュー確定分の復元）

### 変更概要
- `docs/spec-A1-データモデル基盤.md`（新規）: RecordCategory / Event / Visit の中核モデル、Event/Visit境界ルール、CloudKit互換3条件、アイキャッチ二段構え、削除・退避、PhotoBlob、ユニット値の格納（個別プロパティ＋unitFieldsRaw JSON）を定義
- `docs/spec-A2-種別サブレイヤー.md`（新規）: 2階層マスター〈カテゴリ→SubType→軸/スペック/OCR〉、1階層=subType nil特例、解決ルール（categoryKeyでfetch→Swift側でOR判定）、key/displayName分離、v1は日本酒のみ、PoC検証項目

### 変更意図
- 前セッションで作成・ユーザーレビュー済みだった②-A分割（A1/A2）が、ツール不調で**保存されず消失**していた（GitHub・project-log のいずれにも記録なし）ことを、GitHub API直接確認で特定。確定内容は引き継ぎに残っていたため清書として復元した
- あわせて main へマージ実施（作業ブランチ全コミットをfast-forward・af04217→29a7d05）

### 主な変更ファイル
- docs/spec-A1-データモデル基盤.md（新規）
- docs/spec-A2-種別サブレイヤー.md（新規）

### 確認結果（実機 / ビルド）
ドキュメントのみ。ファイル実在をls/wc/git statusで検証済み（前セッションの偽装成功を踏まえ二重確認）。

### 決定ログ（2026-07-06 ユーザー再確認で全決着）
- **Event/Visit境界**: 会場・総合評価・座席・写真・成果・タグ・同行者・金額を Visit 側に置く。理由=ツアー公演/再飲で「1対象=1評価・1会場」前提が破綻するため。→ **確定（そのまま）**
- **ツアーの扱い**: 東京公演と大阪公演は「同じ対象（1 Event）＋別の回（2 Visit）」。別Eventにはしない。→ **確定**（ユーザー選択）
- **アイキャッチ**: **回ごとに個別**（Visit.eyecatchPath）。リピート登録時は直前の回のアイキャッチを初期値として引き継ぎ、その回だけ個別変更も可。対象単位のまとめ表示（リピートグループ・統計）用に Event 代表（既定=初回Visit・独立指定も可）を併せ持つ。※一度「v1は1段」と誤記→ユーザー訂正「Visit毎に個別で選べる／リピートは前回引き継ぎ／個別でも変えられる」で確定。→ **確定**
- **スペック格納の二本立て**: U9自由ペアは unitFieldsRaw の JSON のまま。ただし**日本酒の定番数値（精米歩合/日本酒度/酸度/アルコール分）は検索・グラフ用に Event 側の専用数値列へ昇格**（ユーザー「グラフ・ソート出したい」）。OCRはこの2系統へ振り分け。→ **確定**

### 残課題
- ②-A 続き: A3（ユニット別フィールド）/ A4（テンプレ別プリセット具体リスト・種別別の数値列振り分け含む）/ A5（集計・カレンダー・地図）/ A6（周辺）/ A7（登録フロー）
- 書籍・テーマパークのテンプレ確定（08 §4-7/§4-8 未着手）は前セッションのチャットで議論済みだが未保存 → 別途復元が必要

## 2026-07-05: 酒の種別サブレイヤー下地を設計要件化＋URL複数化・SNSトグル

### 変更概要
- **酒種別サブレイヤーの下地をv1必須の設計要件に格上げ**（ユーザー強調「ちゃんと下地作らないと後で後悔する」）。〈カテゴリ→酒種別→軸/スペック/OCR辞書〉の2階層マスターで、種別（日本酒/ビール/ウィスキー…）を選ぶとプリセットが切り替わる仕組み。v1で下地を通し中身は日本酒のみ実装
- URL欄を「＋で複数」に、SNS（X/Instagram/Threads）を各サービス別トグルに一般化——全テンプレ共通の土台項目へ

### 変更意図
種別ごとに味覚軸・スペック・OCR辞書が違う。後付けすると既存記録の移行が発生し、Mystoriumの「enum rawValue変更→デコード不能クラッシュ」「後から重いリファクタ」の二の舞になるため、種別フィールドと種別キー引きの仕組みを最初から通す。

### 主な変更ファイル
- docs/08-テンプレユニット設計.md（§4-6★★下地設計要件・土台にURL複数/SNSトグル）
- docs/favoreco-feasibility.md（PoCに2階層マスター検証を追加）
- favoreco/CLAUDE.md（§5にサブ種別レイヤー下地ルール）

### 確認結果（実機 / ビルド）
ドキュメントのみ。

### 残課題
- 残り1テンプレ（書籍）。テーマパークは未着手
- ②-A: 2階層マスターの具体設計・種別別プリセットのデータ構造

## 2026-07-05: 酒テンプレ確定（5/7）＋味覚マップ・ラベルOCR・酒蔵マップ

### 変更概要
酒テンプレを日本酒ベース・銘柄単位で確定（08 §4-6）。新ユニット2つ（U16ラベルOCR・U17味覚2軸マップ）と新マスター（Brewery=酒蔵・所在県付き）、酒蔵所在県マップ（v1）を追加。

### 決定ログ
- 記録単位=銘柄単位（Untappd/さけのわ型）／日本酒ベース1テンプレ／アイキャッチ3:4縦
- **味の評価＝U17味覚2軸マップ（甘辛×濃淡）を基本**（業界標準・軽い）。6軸レーダー(U7)・官能メモ(U10)は両方オンオフ可のオプション（「そこまで味分かる人いない」ため基本オフ）
- スペック表プリセットに使用米・酵母を追加／ラベルOCR●（Vision標準）
- **酒蔵をDB化（Breweryマスター・所在県付き）**、URLは酒蔵EC対応／**酒蔵所在県マップをv1に**（好きな産地を地図で一覧・MapKit資産）
- 場所○・金額○・コレクション○・リピート●・タグ●・成果●・同行者○
- 飲食店記録との連動は将来構想として記録（②-A以降）
- アイキャッチ比率＝プリセットは対象物比率のまま維持（「スマホは3:4」指摘に対し、トリミングで対応する運用で決着）

### 主な変更ファイル
- docs/08-テンプレユニット設計.md（§4-6・U16/U17・マトリクス）
- docs/favoreco-feasibility.md（Brewery エンティティ・§4-1c 所在県マップ）

### 確認結果（実機 / ビルド）
ドキュメントのみ。

### 残課題
- 残り2テンプレ（テーマパーク・書籍）
- ②-A: 飲食店テンプレ（第1弾外）と酒の連動設計・Breweryと銘柄の紐付け


## 2026-07-05: 映画テンプレ確定（4/7・Filmarks流）

### 変更概要
「大手のマネでいい」方針により、Filmarksの設計（スコア一本評価・鑑賞方法の構造化）に寄せて確定。08 §4-5に記録。

### 決定ログ
- レーダー○（スコア一本文化＝総合評価が担う）／イベント回（舞台挨拶・応援上映）は専用欄なしのタグ運用／形態●=鑑賞方式（劇場/IMAX/4DX/ドルビー/配信）
- アイキャッチ2:3縦・参加日=開映時刻+上映時間15分刻み・コレクションに入場者特典明記・他は提案どおり

### 主な変更ファイル
- docs/08-テンプレユニット設計.md（§4-5新設・マトリクス更新）

### 確認結果（実機 / ビルド）
ドキュメントのみ。

### 残課題
- 残り3テンプレ（酒・テーマパーク・書籍）


## 2026-07-05: ライブ・フェス参戦テンプレ確定（3/7）

### 変更概要
リサーチ根拠付きの完成案提示＋好み判断のみのヒアリングで確定（ユーザーの知見が薄い領域のため方式を変更）。08 §4-4に記録。

### 決定ログ
- アイキャッチ=1:1正方形（ジャケ写文化）／レーダー○（セトリ・感想中心文化）／**金額=独立ユニット●**（グッズ代・遠征費の推し活会計。チケ代はチケットユニットと分担）
- 開場・開演の2段時刻＋公演時間30分刻みセレクト／座席=「座席・整理番号」／コレクションに銀テープ明記
- 他は提案どおり（出演者●・セトリ●・リピート●・形態●等）

### 主な変更ファイル
- docs/08-テンプレユニット設計.md（§4-4新設・アイキャッチプリセット・マトリクス更新）

### 確認結果（実機 / ビルド）
ドキュメントのみ。

### 残課題
- 残り4テンプレ（映画・酒・テーマパーク・書籍）


## 2026-07-05: 美術展・博物展テンプレ確定（項目別ヒアリング2件目）

### 変更概要
美術展テンプレを項目別ヒアリングで確定し、08 §4-3に記録。会期専用フィールド（●・カレンダー会期バーの元データ）を新設。

### 決定ログ
- 基本情報=観劇と同構成／会期●／参加日=訪問日+入場時刻(任意)+滞在時間セレクト／チケット●（観劇と同構成）
- 形態●に昇格（企画展/常設/芸術祭/巡回）／レーダーは○に降格（「基本オフでカスタムできれば十分」ユーザー判断）
- 作家○（出演者ユニット転用）／リスト○（心に残った作品）／他は提案どおり
- **UI設計原則を追加: 日付・期間の入力はカレンダー式ピッカー（日付ホイール禁止）。期間は開始→終了をタップで範囲選択**（08 設計原則5）

### 主な変更ファイル
- docs/08-テンプレユニット設計.md（§4-3新設・設計原則5・マトリクス更新）

### 確認結果（実機 / ビルド）
ドキュメントのみ。

### 残課題
- 残り5テンプレ（ライブ・映画・酒・テーマパーク・書籍）のヒアリング


## 2026-07-05: カレンダーの終日・期間表示の描き分けルール確定（モックv3）

### 変更概要
Googleカレンダーの「終日帯が積み上がる」表示への不満を起点に、モック3版の往復で描き分けルールを確定。feasibility §4-3に正式記録。

### 決定ログ（モックv3で合意）
1. 期間もの（販売期間・会期）＝セル下部の**期間バー**（太め・バー内白抜きタイトル・重なりは2段まで＋n）。背景ベタ塗り案は「重なりに弱い」というユーザー指摘で廃止
2. 発売日＝販売期間と同一データの開始点を枠線チップで強調（点と線の関係）
3. 通常イベントチップ＝タイトル2行まで・あふれ「+n」
4. 終日体験＝月はグレー枠線1行チップ／週は折りたたみピル（ユーザー指定）
5. 済み記録＝薄めチップ（参加済みの意）
6. 月グリッドは7列完全均等・iPhone縦比率で検証
- デザインベース＝リキッドグラス（アプリ全体・コンセプト§6に記録済み）

### 主な変更ファイル
- docs/favoreco-feasibility.md（§4-3に描き分けルール6項を追記）
- モック: Artifact（calendar-mock v3.1・白基調）

### 確認結果（実機 / ビルド）
ドキュメント＋HTMLモックのみ。

### 残課題
- 残り6テンプレの項目別ヒアリング（美術展から）

## 2026-07-05: CloudKit写真ストレージ仕様（PhotoBlob方式）を正本として採用

### 変更概要
Mystorium V10で当日実装・実機検証された写真ストレージ仕様（PhotoBlob＋externalStorage）を `docs/09-CloudKit写真ストレージ仕様.md` として取り込み、favorecoのデフォルト構造に採用。07・feasibility・実装仕様正本の「写真はファイルパス正本」記述をPhotoBlob方式に更新。

### 変更意図
CloudKit自動同期はSwiftDataストアの中身しか同期せず、ファイル直置きの写真は同期に載らないことがMystorium実装で確定したため。externalStorageならDB肥大化を回避しつつ同期対象にできる（実績: 4,808枚・1,201.9MB移行・失敗0件）。favorecoは最初からblob方式で作れば移行コード自体が不要——「新規開発の利点を取り切る」方針の具体化。

### 主な変更ファイル
- docs/09-CloudKit写真ストレージ仕様.md（新規・Mystorium発の仕様書）
- docs/07-CloudKit同期設計リファレンス.md（旧記述「externalStorageに依存しない」を撤回・修正）
- docs/favoreco-feasibility.md（§2保存方針を更新）
- favoreco/CLAUDE.md（§5実装ルールにPhotoBlob・Swift 6 nonisolated等を追加）

### 確認結果（実機 / ビルド）
ドキュメントのみ（仕様の実機検証はMystorium側で完了済み）。

### 残課題
- 残り6テンプレのヒアリング／カレンダー終日表示の描き分け方式のユーザー確認（モック提示中）

## 2026-07-05: カレンダー機能の範囲・時期確定、観劇テンプレ全項目確定

### 変更概要
- カレンダー: **A（Google式の体験特化カレンダー）＋B（EventKit外部予定重ね表示）を両方v1に投入**。週/日は時間軸グリッドのGoogle式完全再現（ユーザーのGoogleカレンダー実スクショを仕様の参照に）。C（汎用予定作成）は「やらないこと」に明記
- 観劇テンプレ: 上演時間セレクト式を採用し**全項目確定**

### 変更意図
ユーザーの実際のカレンダー（体験の予定と生活の予定が1つに混在）を見ると、外部予定の重ね表示がないと乗り換え価値が半減するため、Bをv1に含める。汎用予定の作成はGoogle/Appleカレンダーの土俵なので戦わない。

### 主な変更ファイル
- docs/favoreco-feasibility.md（§4-3をA+B確定仕様に更新：ビュー・レイヤー構成）
- docs/favoreco-mvp.md（カレンダーをv1主役機能として詳記）
- docs/favoreco-concept.md（やらないことに汎用予定作成を追加）
- docs/08-テンプレユニット設計.md（上演時間セレクト式確定・観劇テンプレ完了宣言）

### 確認結果（実機 / ビルド）
ドキュメントのみ。

### 残課題
- 残り6テンプレの項目別ヒアリング（次は美術展）
- v1実装量が増えた（時間グリッド新規・EventKit）——実装フェーズの分割計画で吸収する

## 2026-07-05: 地図・場所入力3系統とカレンダー連携（EventKit）の方針決定

### 変更概要
- 場所入力を3系統に確定: アプリ内検索（MapKit）／Google共有URL／Apple共有URL（ユーザー提案）。Google Places APIは不採用
- カレンダー連携はEventKit読み取りでApple/Google両カレンダーの予定をfavorecoカレンダーに薄く重ね表示する方針を決定（投入時期・カレンダー機能全体の範囲A/B/Cは保留）

### 変更意図
- Places APIの規約（取得データの永続保存不可・30日キャッシュ・Place IDのみ永続）が「一生残す記録アプリ」と根本非互換のため。「特定はGoogleの精度・保存はAppleデータ＋リンク」の分業で、精度ニーズと規約・運営費ゼロ構造を両立する
- GoogleカレンダーはiOS標準カレンダー経由でEventKitから読めるため、Google API直接連携は不要と判断

### 主な変更ファイル
- docs/favoreco-feasibility.md（§4-2 地図・場所入力 / §4-3 カレンダー連携を新設）

### 確認結果（実機 / ビルド）
ドキュメントのみ。

### 残課題
- カレンダー機能の範囲（体験特化A／連携B／汎用C）と投入時期の決定（ユーザー保留中）
- 観劇テンプレ: 上演時間セレクト式の採否確認
- 残り6テンプレの項目別ヒアリング

## 2026-07-05: 観劇テンプレの項目別ヒアリング完了（1点のみ確認継続）

### 変更概要
観劇テンプレを1項目ずつヒアリングし、08 §4-2 に確定構成を記録。基本公演情報（アイキャッチ/タイトル+サブタイトル/URL+X+insta/会場/主催/メモ+総合評価）・参加日（開演・開場・上演時間）・チケット（発売日時・アラーム・チケットサイト・入手経路・支払/発券・チケ代）のグループ構成はユーザー定義。

### 決定ログ
- 座席●・キャスト●・同行者●・タグ●・レーダー●・成果●・コレクション●・リピート●・形態●（現地/配信/LV）・作品ジャンル●（マチソワは開演時刻から自動判定）・リスト–・官能–
- 金額は独立ユニットにせずチケットに統合（観劇の場合）
- スペック表＝OFF開始の任意ON。プリセットチップ: 作/脚本・原作・演出・翻訳（企画製作は外す・上演時間は参加日へ移管）
- 「会場時間」＝開場時間（任意欄）
- **チケット発売リマインド通知をv1に昇格**（MVP更新済み。Mystoriumで後付け実装が面倒だった教訓）
- 上演時間はセレクト式（入力はセレクト・保存は終演を自動導出）を推奨提示中——採否のみ確認待ち

### 主な変更ファイル
- docs/08-テンプレユニット設計.md（§4-2 観劇確定構成）
- docs/favoreco-mvp.md（発売リマインドのv1昇格）

### 確認結果（実機 / ビルド）
ドキュメントのみ。画面モックはArtifactで提示（スペック表・観劇詳細・トグル設定）。

### 残課題
- 上演時間セレクト式の採否確認
- 残り6テンプレ（美術展・ライブ・映画・酒・テーマパーク・書籍）の項目別ヒアリング

## 2026-07-05: アイキャッチ全カテゴリ標準化・書籍テンプレ昇格・作品ジャンルユニット追加

### 変更概要
- アイキャッチを全カテゴリの土台項目に追加。**縦横比はカテゴリごとに設定**（テンプレプリセット案: 観劇/美術展=A4縦、映画/書籍=2:3縦、酒=3:4縦、ライブ=16:9横、テーマパーク=4:3横）
- **書籍をテンプレ第1弾に昇格**（6種→7種）。形態プリセット=マンガ/小説/参考書/技術書/電子書籍/紙
- **U15作品ジャンル**ユニット新設（SF/推理/恋愛等。映画・書籍で標準ON。タグと違いカテゴリ内管理の分類）

### 変更意図
ユーザー指示（2026-07-05）。書籍は「受け皿」から器付きテンプレへ格上げするが、作品DB・バーコード・ソーシャルで読書メーターと戦わない方針は不変（コンセプト§5の表現を更新）。

### 主な変更ファイル
- docs/08-テンプレユニット設計.md（土台にアイキャッチ・U15追加・マトリクス7列化）
- docs/favoreco-concept.md（§7テンプレ7種・§5やらないこと表現更新）
- docs/favoreco-mvp.md（テンプレ7種）
- favoreco/CLAUDE.md（§7更新）

### 確認結果（実機 / ビルド）
ドキュメントのみ。

### 残課題
- アイキャッチ縦横比プリセット案のユーザー確認
- 08マトリクスの残レビュー（●○–の過不足・コレクション標準ONの是非）

## 2026-07-05: テンプレユニット設計の草案作成

### 変更概要
「テンプレは項目ユニットの組み合わせ・カスタムも同じユニットを再利用」というユーザー方針を `docs/08-テンプレユニット設計.md` として設計草案化。土台5項目＋ユニット14種＋テンプレ6種×ユニットのマトリクスを定義。

### 変更意図
「美しく記録する」の実装面の担保として「使わないユニットは表示に出ない」原則を採用。スキーマはスーパーセット固定（動的スキーマ禁止・CloudKit互換維持）とし、テンプレ6種は「保存済みプリセット」にすぎない構造にすることで、テンプレとカスタムの二重実装を避ける。

### 主な変更ファイル
- docs/08-テンプレユニット設計.md（新規・草案）

### 確認結果（実機 / ビルド）
ドキュメントのみ。

### 残課題
- ユニットの過不足・名称のユーザーレビュー
- ②-A持ち越し事項（U3/U14統合・スペック表のCloudKit表現・リピート判定・プリセット具体リスト）

## 2026-07-05: CloudKit同期設計をデフォルト構造として採用

### 変更概要
MystoriumのiCloud同期設計（ON/OFF図解・Artifact PDF）を `docs/07-CloudKit同期設計リファレンス.md` として取り込み、favorecoのデフォルト構造に採用。feasibility・MVP・実装仕様の正本に「v1スキーマはCloudKit互換制約で設計する」ルールを反映。

### 変更意図
同期機能の公開はv2（サブスク）だが、CloudKit互換制約（リレーション全optional・unique制約なし等）は後付けできない。favorecoは新規開発なので、Mystoriumで必要になる「ストレージ移行バッチ」を最初から不要にできる——この利点を確実に取るため、v1のスキーマ・写真保存形式を同期前提で固定する。

### 主な変更ファイル
- docs/07-CloudKit同期設計リファレンス.md（新規・PDF内容の転記＋favoreco適用方針）
- docs/favoreco-feasibility.md（§2 保存方針にCloudKit互換要件を追加）
- docs/favoreco-mvp.md（v2項目に構造準備の注記）
- favoreco/CLAUDE.md（§5 重要実装ルールに追加）

### 確認結果（実機 / ビルド）
ドキュメントのみ。

### 決定ログ
- 同期の大原則を踏襲: デフォルトOFF・opt-inトグル／CloudKitプライベートDB（開発者から見えない・サーバー費ゼロ維持）／端末内データは絶対に消えない／動画本体は同期に載せない／zipバックアップ併用
- ②-A（データモデル仕様）のレビュー観点に「CloudKit互換か」を必ず入れる

### 残課題
- レビュー観点.md への「CloudKit互換」チェック項目の追記（②-A仕様書を書く段階で）

## 2026-07-04: 商標クリア確認、実現性メモ・MVP定義の草案作成（フェーズ4・5）

### 変更概要
- ユーザーによる商標・アプリ名調査の結果を記録: **favorecoは商標登録もアプリも存在せずクリア**（oshireco=終了済みサービス、推しレコ=I-O DATA商標だが録画系で役務非重複）。J-PlatPat確認の残課題を解消
- `docs/favoreco-feasibility.md` 草案作成（フェーズ4）: エンティティ素描・保存方針・山場・**致命リスク=RecordCategory化のPoC検証**を定義
- `docs/favoreco-mvp.md` 草案作成（フェーズ5）: v1に入れる9項目／入れない8項目／検証可能な成功条件5つ／粗ロードマップ

### 変更意図
立ち上げガイドの全フェーズを文書として揃え、実装着手前の合意対象を明確にする。

### 主な変更ファイル
- docs/favoreco-feasibility.md（新規・草案）
- docs/favoreco-mvp.md（新規・草案）

### 確認結果（実機 / ビルド）
ドキュメントのみ。

### 決定ログ
- 商標・名前被りクリア（2026-07-04 ユーザー確認）

### 残課題（ユーザー確認待ちの提案）
- コード共有方式: フォークでPoC→後で共有コア切り出し（推奨として記載・要承認）
- サブスクはv2導入・年間まとめはv1.x（年末）というロードマップの承認
- 無料層の制限設計（件数制限等）

## 2026-07-04: アプリ名「favoreco」正式決定

### 変更概要
アプリ名を favoreco（favorite + record）で正式決定。`APP_NAME/` を `favoreco/` にリネームし、実装仕様の正本（favoreco/CLAUDE.md）に確定済みプロダクト方針を転記。ルートCLAUDE.md §6・コンセプトシートの「仮称」表記を削除。

### 変更意図
名前の被り・商標をユーザーが下調べ（oshireco=終了済みサービス、推しレコ=I-O DATA商標だが録画系で役務が異なる）した上で採用判断。「ファボ」の響きが初期市場（観劇・推し活クラスタのX文化圏）と地続きである点も採用理由。

### 主な変更ファイル
- APP_NAME/ → favoreco/（リネーム）
- favoreco/CLAUDE.md（正本の初期化：コンセプト・スタック・確定方針を転記）
- CLAUDE.md §6（仮称削除・参照先更新）
- docs/favoreco-concept.md（仮称削除）

### 確認結果（実機 / ビルド）
ドキュメントのみ。

### 決定ログ
- アプリ名＝favoreco（2026-07-04 ユーザー決定）。対抗馬: 余韻/Yoin・Favorium・綴
- Bundle ID 案: `com.<開発者ID>.favoreco`（Mystoriumの規約に合わせて最終決定）

### 残課題
- J-PlatPatで「ファボレコ」「favoreco」の称呼検索（リリース前まで・Mac側で5分）
- README.md はスターターキットの説明のまま（Xcodeプロジェクト作成時にアプリ用READMEへ書き換え）

## 2026-07-04: キャッチの字句修正（「味わった」→「体験した」）

### 変更概要
確定キャッチを「観た・行った・**体験した**を、美しく一生残す。」に変更（ユーザー指示）。

### 変更意図
「味わった」は食に寄って聞こえるため、雑食＝あらゆる体験を受け止める言葉に広げた。

### 主な変更ファイル
- docs/favoreco-concept.md（§1）

### 確認結果（実機 / ビルド）
ドキュメントのみ。過去ログ・02資料内の旧表現は履歴として残置。

## 2026-07-04: コンセプトシート確定（フェーズ3完了）

### 変更概要
一言キャッチを「観た・行った・味わったを、美しく一生残す。」（1文完結・課金訴求なし）で確定し、コンセプトシートのステータスを「確定」に更新。

### 変更意図
「記録は買い切りで全部入り。」は俗っぽいというユーザー判断により、キャッチは世界観だけに専念させ、買い切り訴求はストア説明文・LPへ分離する。

### 主な変更ファイル
- docs/favoreco-concept.md（キャッチ確定・ステータス確定）

### 確認結果（実機 / ビルド）
ドキュメントのみ。

### 決定ログ
- キャッチ＝「観た・行った・味わったを、美しく一生残す。」（2026-07-04 ユーザー確定）。没案: 買い切り併記型・「柱」前面型
- これで立ち上げフェーズ3（コンセプト確定）完了。確定事項: コア体験／差別化（柱の横断×買い切り全部入り）／やらないこと／テンプレ第1弾6種＋横断フィールド／課金3層／デザイン方向性

### 残課題
- フェーズ4の残り: 致命リスクの特定・検証方法（実現性メモの正式化）
- フェーズ5: MVP定義表（機能レベルのin/out・v1成功条件）
- アプリ名の正式決定・共有コアorフォーク・具体価格

## 2026-07-04: 課金方針（3層）をコンセプトシートに反映

### 変更概要
コンセプトシートv2に §8 課金方針を新設。無料／買い切り（記録・自作カテゴリ・統計・年間まとめ・エクスポート）／サブスク（同期・自動バックアップ・思い出再提示・月次リキャップ・限定デザイン）の3層構造を明文化。キャッチ案Aと「やらないこと」のサブスク表現も整合するよう修正。

### 変更意図
「サブスクの線を残したい」というユーザー意向と、「統計・記録を人質にしない」という差別化の両立。統計は"見る能力=買い切り／自動で届ける=サブスク"で分離した。

### 主な変更ファイル
- docs/favoreco-concept.md（§8 課金方針追加・§1/§5修正）

### 確認結果（実機 / ビルド）
ドキュメントのみ。

### 決定ログ
- 統計の詳細化はサブスクに**入れない**（Filmarks対抗軸の維持。2026-07-04 提案採用）
- 自作カテゴリは買い切り側（キログが記録カスタマイズ無料のため、サブスク化は競合比較で不利）
- エクスポートは買い切りに含める（キログのCSV有料への対抗軸）
- 思い出の再提示（On This Day型）はオンオフ可のopt-in。通知型より「選んだ体験の写真ランダム表示」型を主に（2026-07-04 ユーザー意向：勝手に届くのは好みでない）
- 月次リキャップはfavoreco新規機能とし、Mystoriumには入れない（見せ方含め構造から必要なため。2026-07-04 ユーザー判断）
- 年間まとめは買い切り側（バイラル装置を課金壁に入れない）

### 残課題
- キャッチ3案の選択（A/B/C）→コンセプトシート確定
- 無料層の体験版制限設計（件数制限等）
- サブスク・買い切りの具体価格

## 2026-07-04: テンプレート第1弾の確定とコンセプトシートv2練り直し

### 変更概要
- テンプレート第1弾を6種＋横断フィールドで**確定**（観劇/美術展/ライブ参戦/映画/酒/テーマパーク＋「半券・印・カード写真＋メモ」共通フィールド）
- コンセプトシートをv2に練り直し（ユーザーの「練り直し」指示による。差別化を「柱の横断」主語に再構成、キャッチ3案併記、やらないことにゲーミフィケーション排除を追加）

### 変更意図
リサーチ（05/06）の結論をコンセプトに反映し、フェーズ5（MVP範囲確定）に進む前提を整える。

### 主な変更ファイル
- docs/favoreco-concept.md（v2草案へ全面改稿）
- CLAUDE.md（§6/§7 実環境反映・前コミット）

### 確認結果（実機 / ビルド）
ドキュメントのみ。Mac側のクローン・プル導線は確認済み（Already up to date）。

### 決定ログ
- テンプレート第1弾＝6種＋横断フィールド（2026-07-04 ユーザー確定）。サウナ・御朱印は王者アプリ存在によりテンプレ化見送り
- コンセプトシートv1の差別化・やらないことは確定に至らず「練り直し」判断（2026-07-04）

### 残課題
- コンセプトシートv2のレビュー（キャッチ3案の選択・差別化の言い回し・やらないことの範囲）
- フェーズ5: MVP定義表の作成（機能レベルのin/out）
- アプリ名の正式決定

## 2026-07-04: ジャンル別リサーチ2本の完了（05・06）

### 変更概要
- `docs/05-ジャンル別記録フィールドリサーチ.md` — リスト済み12ジャンルの記録フィールド表と横断設計パターン5つ
- `docs/06-追加ジャンル発掘リサーチ.md` — リスト外ジャンルの発掘と「記録文化×アプリ空白度」ランキング

### 変更意図
テンプレート第1弾の範囲決定（MVPスコープ）とフィールド設計（②-A）の素材とするため。

### 主な変更ファイル
- docs/05-ジャンル別記録フィールドリサーチ.md（新規）
- docs/06-追加ジャンル発掘リサーチ.md（新規）

### 確認結果（実機 / ビルド）
ドキュメントのみ。

### 決定ログ・知見
- 検証済みまで到達したのは観劇（シアティ実例・3-0票）のみ。他は検索ベース——実行環境のネットワーク制限（外部サイト403）により本文検証が不能だったため。②-A仕様化時に個別出典を確認する
- 御朱印は当初「手薄」想定だったが専用アプリの王者複数と判明 → テンプレ優先度を下げ「印」汎用フィールドで対応する方針に転換
- 「〇〇印」制度の増殖・半券分類ノート文化から、ジャンルテンプレとは別の横断仕様（半券/印/カード写真＋メモ）の必要性を確認
- リサーチ実行の運用知見: セッション休止でバックグラウンドのワークフローが停止する。再開時はスクリプトパス＋resumeFromRunId＋args再指定が必要

### 残課題
- テンプレート第1弾の範囲確定（フェーズ5 MVP：観劇・美術展・ライブ/推し活・映画・酒＋テーマパーク昇格の判断）
- コンセプトシートの差別化・やらないことの確定

## 2026-07-04: Mystorium構造リファレンス追加＋コンセプトシート草案（フェーズ3着手）

### 変更概要
- `docs/04-Mystorium構造リファレンス.md` を追加（Mystoriumの技術スタック・9モデル・設計原則・流用資産・SwiftData/SwiftUIの罠のまとめ。favoreco のベース参照用）
- `docs/favoreco-concept.md` を新規作成（立ち上げガイド フェーズ3のコンセプトシート）。コア体験を「記録が美しい思い出になる」の1つに確定

### 変更意図
- 04はimmersiveApp `docs/favoreco-handoff` 由来の資料（リモート未プッシュのためアップロード経由で持ち込み）。技術設計の出発点として正本化する
- コンセプトシートは 01/02 の検討結果を台本のフォーマットに落とし、コア体験の一本化をユーザーと合意した記録

### 主な変更ファイル
- docs/04-Mystorium構造リファレンス.md（新規）
- docs/favoreco-concept.md（新規・ステータス検討中）

### 確認結果（実機 / ビルド）
ドキュメントのみ。ビルド対象なし。

### 決定ログ
- コア体験＝「記録が美しい思い出になる」に一本化（2026-07-04 ユーザー選択）。統計・シェアカードは付加価値の位置づけ。理由: 「機能ではNotionに勝てず、勝てるのは体験の質だけ」という競合分析の結論との整合

### 残課題
- コンセプトシートの差別化・やらないこと（草案）のユーザー確認 → ステータスを「確定」へ
- アプリ名の正式決定（現状「favoreco」仮称）・Bundle ID・デザイン言語
- フェーズ4以降: 共有コア or フォーク、MVPテンプレート数、価格、CloudKit

## 2026-07-04: Mystorium派生・汎用「体験」記録アプリの検討資料を持ち込み

### 変更概要
別セッション（Mystoriumプロジェクト）で実施した検討の正本3点を `docs/` に配置した。
- `docs/01-競合分析.md` — 書籍/映画/美術館/観劇/食べ歩き/汎用記録/推し活の競合調査
- `docs/02-コンセプトと勝ち筋.md` — 「作品DBが要らない"体験"の記録アプリ」に絞る戦略仮説
- `docs/03-Mystoriumからの技術移行メモ.md` — EventCategory enum をユーザー定義 Category モデルへ一般化する技術方針

### 変更意図
このリポジトリ（favoreco）を Mystorium 派生の汎用記録アプリの開発拠点とするため、前段の意思決定（フェーズ1〜2 相当：言語化・精査）の成果物を正本として引き継ぐ。

### 主な変更ファイル
- docs/01-競合分析.md（新規）
- docs/02-コンセプトと勝ち筋.md（新規）
- docs/03-Mystoriumからの技術移行メモ.md（新規）

### 確認結果（実機 / ビルド）
ドキュメントのみの変更。ビルド対象なし。

### 残課題
- コンセプトシート正式版の作成（`docs/新規アプリ立ち上げ.md` フェーズ3）
- アプリ名・Bundle ID・デザイン言語の決定
- コード共有方式（共有コア or フォーク）の決定
- MVPテンプレート数・カテゴリ横断統計の初期スコープ確定
- 価格（買い切り主役は確定・具体額未定）・CloudKit 初期導入可否

## 2026-07-10: FAVORECOアプリアイコン初版作成

### 変更概要
- 高級感あるSNS寄りのFAVORECOアプリアイコン初版を作成
- Fモノグラム＋しおり/記録カードを主モチーフにし、淡いピンク、オフホワイト、薄いブルー差し色で構成
- 比較用にシンボル案2種も保存

### 変更意図
App Store向けおよび既存アプリ組み込み前提の1024pxアイコンを用意するため。FAVORECOの「体験を美しく残す」方向性と、白ベース/リキッドグラス基調のデザイン方針に合わせた。

### 主な変更ファイル
- favoreco/assets/app-icon/favoreco-app-icon-1024.png（完成候補の1024pxアイコン）
- favoreco/assets/app-icon/favoreco-app-icon-final-source.png（生成元サイズの完成候補）
- favoreco/assets/app-icon/favoreco-app-icon-symbol-heart.png（比較用シンボル案）
- favoreco/assets/app-icon/favoreco-app-icon-symbol-abstract.png（比較用抽象シンボル案）
- favorecoAPP/favorecoAPP/Assets.xcassets/AppIcon.appiconset/favoreco-app-icon-1024.png（Xcode AppIcon用PNG）
- favorecoAPP/favorecoAPP/Assets.xcassets/AppIcon.appiconset/Contents.json（AppIconのfilename設定）

### 確認結果（実機 / ビルド）
- 生成画像を目視確認済み
- 完成候補が1024x1024pxであることを確認済み
- ビルド/実機確認は未実施

### 残課題
- 実機ホーム画面とApp Store Connect表示で小サイズ視認性を確認する
- 必要に応じてダーク/ティント用の別アイコンを作成する

## 2026-07-10: FAVORECOアプリアイコン色違い比較案追加

### 変更概要
- 既存FAVORECOアイコンの形状を維持した色違い案を3種追加
- ヴァイオレット系、黒系、ネイビー系を1024x1024pxで保存

### 変更意図
App Store向けアイコンの最終トーン比較を行うため。淡色ピンク案に加え、高級感・SNS感・小サイズ視認性を比較できる色展開を用意した。

### 主な変更ファイル
- favoreco/assets/app-icon/favoreco-app-icon-violet-1024.png（ヴァイオレット系）
- favoreco/assets/app-icon/favoreco-app-icon-black-1024.png（黒系）
- favoreco/assets/app-icon/favoreco-app-icon-navy-1024.png（ネイビー系）

### 確認結果（実機 / ビルド）
- 生成画像を目視確認済み
- 3案すべて1024x1024pxであることを確認済み
- AppIcon本体の差し替えとビルド/実機確認は未実施

### 残課題
- 採用色を決めた後、AppIcon.appiconsetへ反映する
- 実機ホーム画面で小サイズ視認性を確認する

## 2026-07-10: Fなしアプリアイコン比較案追加

### 変更概要
- F文字を使わないFAVORECOアプリアイコン比較案を3種追加
- SNSカード、ハートカード、しおりの3モチーフを1024x1024pxで保存

### 変更意図
Fモノグラム案以外の方向性を比較するため。文字に依存せず、体験記録・お気に入り・SNS感が伝わるアイコン候補を用意した。

### 主な変更ファイル
- favoreco/assets/app-icon/favoreco-app-icon-no-f-social-card-1024.png（抽象SNSカード案）
- favoreco/assets/app-icon/favoreco-app-icon-no-f-heart-card-1024.png（ハート＋記録カード案）
- favoreco/assets/app-icon/favoreco-app-icon-no-f-bookmark-1024.png（しおり＋記録カード案）

### 確認結果（実機 / ビルド）
- 生成画像を目視確認済み
- 3案すべて1024x1024pxに正規化済み
- AppIcon本体の差し替えとビルド/実機確認は未実施

### 残課題
- Fあり案とFなし案を並べて採用方針を決める
- 採用案決定後、AppIcon.appiconsetへ反映する

## 2026-07-10: ワインレッド系アプリアイコン比較案追加

### 変更概要
- FAVORECOアイコンのワインレッド系比較案を2種追加
- Fモノグラム版とFなししおり版を1024x1024pxで保存

### 変更意図
男女問わず使いやすい高級感のある色味を比較するため。ワインレッドを主色にしつつ、アイボリー、シャンパン、薄いブルー差し色で重くなりすぎない構成にした。

### 主な変更ファイル
- favoreco/assets/app-icon/favoreco-app-icon-wine-f-1024.png（ワインレッド系Fあり案）
- favoreco/assets/app-icon/favoreco-app-icon-wine-bookmark-1024.png（ワインレッド系Fなししおり案）

### 確認結果（実機 / ビルド）
- 生成画像を目視確認済み
- 2案とも1024x1024pxに正規化済み
- AppIcon本体の差し替えとビルド/実機確認は未実施

### 残課題
- 男女問わず合う最終案を選定し、AppIcon.appiconsetへ反映する
- 実機ホーム画面で小サイズ視認性を確認する

## 2026-07-10: Fなしアイボリー案をAppIconへ設定

### 変更概要
- Fなしのアイボリー系しおりアイコンをアプリ本体のAppIconに設定
- 通常/ダーク/ティントの3枠すべてに同じ1024px PNGを指定

### 変更意図
Fモノグラムではなく、男女問わず使いやすい中性的な記録/しおりモチーフを暫定採用して、実機で見え方を確認できる状態にするため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Assets.xcassets/AppIcon.appiconset/favoreco-app-icon-no-f-bookmark-1024.png（AppIcon用PNG）
- favorecoAPP/favorecoAPP/Assets.xcassets/AppIcon.appiconset/Contents.json（AppIcon参照先をFなしアイボリー案へ変更）

### 確認結果（実機 / ビルド）
- AppIconのfilenameが通常/ダーク/ティントすべて favoreco-app-icon-no-f-bookmark-1024.png になっていることを確認
- AppIcon用PNGが1024x1024pxであることを確認
- ビルド/実機確認は未実施

### 残課題
- 実機ホーム画面で小サイズ視認性を確認する
- 必要に応じてダーク/ティント用の専用アイコンを作成する

## 2026-07-10: AppIconをFなしワインレッド案へ修正

### 変更概要
- 暫定設定していたFなしアイボリー案から、Fなしワインレッドしおり案へAppIconを差し替え
- 通常/ダーク/ティントの3枠すべてに同じ1024px PNGを指定

### 変更意図
ユーザー指定の採用色がアイボリーではなくワインレッドだったため、アプリ本体のAppIcon参照を正しい候補に修正するため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Assets.xcassets/AppIcon.appiconset/favoreco-app-icon-wine-bookmark-1024.png（AppIcon用PNG）
- favorecoAPP/favorecoAPP/Assets.xcassets/AppIcon.appiconset/Contents.json（AppIcon参照先をFなしワインレッド案へ変更）

### 確認結果（実機 / ビルド）
- AppIconのfilenameが通常/ダーク/ティントすべて favoreco-app-icon-wine-bookmark-1024.png になっていることを確認
- AppIcon用PNGが1024x1024pxであることを確認
- ビルド/実機確認は未実施

### 残課題
- 実機ホーム画面で小サイズ視認性を確認する
- 必要に応じてダーク/ティント用の専用アイコンを作成する

## 2026-07-10: AppIconダーク表示を黒系案へ変更

### 変更概要
- AppIconのダーク表示枠のみ黒系アイコンへ変更
- 通常表示とティント表示はFなしワインレッドしおり案のまま維持

### 変更意図
ダークモード時に黒系の高級感あるアイコンを使い、通常表示との差分を確認できる状態にするため。

### 主な変更ファイル
- favorecoAPP/favorecoAPP/Assets.xcassets/AppIcon.appiconset/favoreco-app-icon-black-1024.png（ダーク表示用AppIcon PNG）
- favorecoAPP/favorecoAPP/Assets.xcassets/AppIcon.appiconset/Contents.json（dark luminosity枠のみ黒系案へ変更）

### 確認結果（実機 / ビルド）
- 通常/ティントは favoreco-app-icon-wine-bookmark-1024.png、ダークは favoreco-app-icon-black-1024.png を参照していることを確認
- 黒系AppIcon用PNGが1024x1024pxであることを確認
- ビルド/実機確認は未実施

### 残課題
- 実機でライト/ダーク切替時のホーム画面アイコン表示を確認する

## 2026-07-10: 現状画面ラフボード作成

### 変更概要
- 現在実装されている主要画面の見え方を一覧できるラフボードを作成
- 初期設定、Home、記録一覧、カレンダー/統計、記録追加、記録詳細、カテゴリトップ、設定、表示設定、プロフィール、データ管理、ジャンル管理を1枚に整理

### 変更意図
実装済み範囲の画面構成を視覚的に確認し、今後のUI調整や不足画面の洗い出しに使うため。

### 主な変更ファイル
- favoreco/assets/mockups/current-pages-overview.svg（編集用ラフボード）
- favoreco/assets/mockups/current-pages-overview.png（確認用PNG）

### 確認結果（実機 / ビルド）
- PNGが2400x1780pxで生成されていることを確認
- 目視で12画面の配置とラベルを確認
- 実機スクリーンショットではなく、コード参照ベースの構造ラフ

### 残課題
- 実機またはシミュレータで実際のSwiftUI表示を確認する
- 必要に応じて各画面を個別の高精度モックへ分解する

## 2026-07-10: 初回オンボーディング流れ整理ラフ作成

### 変更概要
- 初回登録時に出す説明オンボーディングの流れを6画面で整理
- 価値訴求、記録内容、横断ジャンル、安心材料、ジャンル選択、開始確認の順に構成

### 変更意図
現行のジャンル選択だけでは初回ユーザーに「何のアプリか」「なぜジャンルを選ぶのか」が伝わりにくいため、登録前説明の見せ方を検討できる形にするため。

### 主な変更ファイル
- favoreco/assets/mockups/onboarding-flow-proposal.svg（編集用オンボーディング流れラフ）
- favoreco/assets/mockups/onboarding-flow-proposal.png（確認用PNG）

### 確認結果（実機 / ビルド）
- PNGが2200x1280pxで生成されていることを確認
- 目視で6画面の流れと推奨方針を確認
- 実装は未変更

### 残課題
- 文言を最終調整する
- 採用後、現行GenreOnboardingViewの前段として説明オンボーディングを実装する

## 2026-07-10: 初回導入＋登録手順チュートリアルラフ作成

### 変更概要
- FAVORECO初回導入の文言トーンを反映したラフを作成
- ようこそ、ジャンル選択、プロフィール、できること、開始の5画面に整理
- 「思い出を記録する」後に、Home上で中央＋、追加メニュー、入力ユニットを順に案内するチュートリアル案を追加

### 変更意図
Siriのように聞いてくれる導入演出と、初回ユーザーが実際に記録を始めるまでの流れを視覚化するため。

### 主な変更ファイル
- favoreco/assets/mockups/onboarding-guided-tour-rough.svg（編集用ラフ）
- favoreco/assets/mockups/onboarding-guided-tour-rough.png（確認用PNG）

### 確認結果（実機 / ビルド）
- PNGが2400x1500pxで生成されていることを確認
- 目視でオンボーディング5画面と登録手順チュートリアル5画面の流れを確認
- 実装は未変更

### 残課題
- ジャンル選択画面など文字量が多い箇所の文言を実装前に短く調整する
- 採用後、オンボーディング状態管理とHome初回チュートリアルを実装する
