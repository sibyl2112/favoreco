import SwiftUI
import UIKit

struct LocalStoreRecoveryView: View {
    let errorMessage: String
    @State private var didCopyError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: "externaldrive.badge.exclamationmark")
                        .font(.system(size: 44))
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("記録データを開けませんでした")
                            .font(FavorecoTypography.heroLead)

                        Text("保存済みのデータは削除していません。アプリを一度終了し、再起動してください。")
                            .font(FavorecoTypography.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Label("この画面では新しい記録を保存しません", systemImage: "lock.shield")
                        Label("アプリの削除や「全データ削除」は行わないでください", systemImage: "trash.slash")
                        Label("再起動で改善しない場合は、下のエラーを添えてお問い合わせください", systemImage: "envelope")
                    }
                    .font(FavorecoTypography.body)

                    Button {
                        UIPasteboard.general.string = errorMessage
                        didCopyError = true
                    } label: {
                        Label(didCopyError ? "エラーをコピーしました" : "エラーをコピー", systemImage: didCopyError ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Link(destination: URL(string: "https://ranoviqo.com/favoreco/")!) {
                        Label("公式サイトでサポートを確認", systemImage: "arrow.up.right.square")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    DisclosureGroup("エラー詳細") {
                        Text(errorMessage)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    }
                    .font(FavorecoTypography.bodyStrong)
                }
                .frame(maxWidth: 560, alignment: .leading)
                .padding(24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Favoreco")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    LocalStoreRecoveryView(errorMessage: "SwiftDataの保存ストアを開けませんでした。")
}
