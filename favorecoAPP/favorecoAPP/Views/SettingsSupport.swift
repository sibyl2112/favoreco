import SwiftUI
import SwiftData

struct SupportLinksView: View {
    private let ranoviqoSiteURL = URL(string: "https://ranoviqo.com")!
    private let favorecoSiteURL = AppReleaseNotes.detailURL
    private let supportURL = URL(string: "https://ranoviqo.com/favoreco/support/")!
    private let officialXURL = URL(string: "https://x.com/favorecoapp")!

    var body: some View {
        Form {
            Section("リンク") {
                Link(destination: ranoviqoSiteURL) {
                    Label("RANOVIQO公式サイト", systemImage: "globe")
                }

                NavigationLink {
                    SettingsDocumentView(title: "利用規約", bodyText: FavorecoLegalText.terms)
                } label: {
                    Label("利用規約", systemImage: "doc.text")
                }

                NavigationLink {
                    SettingsDocumentView(title: "プライバシーポリシー", bodyText: FavorecoLegalText.privacy)
                } label: {
                    Label("プライバシーポリシー", systemImage: "hand.raised")
                }
            }

            Section("アプリ情報") {
                NavigationLink {
                    ReleaseHistoryView()
                } label: {
                    Label("更新履歴", systemImage: "clock.arrow.circlepath")
                }

                Link(destination: favorecoSiteURL) {
                    Label("Favoreco公式サイト", systemImage: "arrow.up.right.square")
                }

                LabeledContent("バージョン", value: AppReleaseNotes.currentVersion)
            }

            Section("サポート") {
                Link(destination: supportURL) {
                    Label("お問い合わせ", systemImage: "envelope")
                }

                ShareLink(
                    item: favorecoSiteURL,
                    subject: Text("Favoreco"),
                    message: Text("好きな体験を、ジャンルを横断して記録できるFavoreco")
                ) {
                    Label("アプリをシェア", systemImage: "square.and.arrow.up")
                }
            }

            Section("公式SNS") {
                Link(destination: officialXURL) {
                    Label("公式X", systemImage: "arrow.up.right.square")
                }
            }
        }
        .navigationTitle("リンク・サポート")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SettingsDocumentView: View {
    let title: String
    let bodyText: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(FavorecoTypography.heroLead)
                Text(bodyText)
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private enum FavorecoLegalText {
    static let terms = """
    最終更新日: 2026年7月12日

    Favorecoは、映画、観劇、ライブ、本、展示、訪問、飲食などの体験を利用者自身が記録・管理するためのアプリです。本アプリを利用することで、本規約に同意したものとみなします。

    1. 記録内容
    利用者は、入力する文章、写真、チケット、座席、金額、URLその他の情報について必要な権利を有し、法令および第三者の権利を侵害しない範囲で利用するものとします。

    2. 禁止事項
    他人になりすます行為、第三者の権利を侵害する行為、不正アクセス、アプリの運営を妨げる行為、法令または公序良俗に反する行為を禁止します。

    3. 外部サービス
    地図、カレンダー、天気、Webサイト、クラウド同期などの外部サービスは、各提供者の利用条件と提供状況に従います。外部情報の正確性や継続提供を保証するものではありません。

    4. 有料機能
    有料機能の価格、期間、利用範囲は購入画面に表示します。サブスクリプションの管理および解約はApple Accountの設定から行います。購入の復元には購入時と同じApple Accountが必要です。

    5. データ管理
    利用者は必要に応じてバックアップを書き出し、自身の責任で保管してください。端末の故障、アプリ削除、同期設定、外部サービス障害などによるデータ消失を完全に防げることは保証しません。

    6. 免責
    本アプリは現状有姿で提供します。運営者の故意または重大な過失がある場合を除き、本アプリの利用によって生じた間接的または付随的な損害について責任を負いません。

    7. 変更・終了
    機能、規約、提供条件は必要に応じて変更されることがあります。重要な変更はアプリ内または公式サイトで案内します。

    8. お問い合わせ
    不具合、ご意見、規約に関するお問い合わせはRANOVIQO公式サイトの案内をご利用ください。
    """

    static let privacy = """
    最終更新日: 2026年7月12日

    RANOVIQOは、Favorecoに保存される情報と外部サービスの利用について、以下のとおり取り扱います。

    1. 保存する情報
    利用者が入力した記録、予定、チケット情報、人物・団体、場所、金額、メモ、URL、写真、設定値を保存します。基本データは端末内に保存され、利用者がiCloud同期を有効にした場合は利用者のiCloud領域へ同期されます。

    2. 写真
    選択された写真は保存時に縮小・再描画し、撮影日時やGPSなど元画像のメタデータを引き継がない形で保存します。写真へのアクセスは、利用者が追加操作を行った時だけ求めます。

    3. 位置情報・地図
    現在地の継続取得は行いません。会場や施設の地図表示には、利用者が入力・選択した施設名、住所、座標を使用します。住所が登録されている場合は住所を優先して位置を解決します。

    4. カレンダー・通知
    利用者が許可した場合に限り、外部カレンダーの表示や予定追加、端末内通知の予約を行います。権限はiOSの設定から変更できます。

    5. Web・天気・OCR
    URL候補取得、地図検索、天気取得には入力されたURL、場所、日付など必要な情報を各サービスへ送る場合があります。OCRは端末上のApple Visionを使用し、読み取った文字は利用者が保存した場合だけ記録へ残ります。

    6. 課金
    購入処理はAppleのStoreKitを利用します。運営者がクレジットカード番号を取得・保存することはありません。アプリは購入状態と利用可能な権利を確認します。

    7. 共有と第三者提供
    利用者が共有、書き出し、外部リンクを明示的に実行した場合を除き、記録内容を第三者へ公開しません。法令に基づく場合を除き、個人データを販売しません。

    8. 削除・バックアップ
    設定からキャッシュ、写真キャッシュ、アーカイブ、全データを削除できます。JSON、CSV、写真付き完全バックアップは利用者が明示的に書き出します。iCloud上のデータは同期状態に応じて反映に時間がかかる場合があります。

    9. 変更・お問い合わせ
    本ポリシーを変更する場合は、アプリ内または公式サイトで案内します。お問い合わせはRANOVIQO公式サイトの案内をご利用ください。
    """
}

#Preview {
    SettingsView()
        .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self, SocialAccount.self], inMemory: true)
}
