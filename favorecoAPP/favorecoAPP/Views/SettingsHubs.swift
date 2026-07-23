import SwiftUI
import SwiftData

struct SettingsNavigationLabel: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(FavorecoTypography.bodyStrong)
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

struct MySettingsHubView: View {
    var body: some View {
        List {
            NavigationLink {
                ProfileSettingsView()
            } label: {
                SettingsNavigationLabel(
                    title: "プロフィール",
                    detail: "表示名、写真、SNSアカウント",
                    systemImage: "person.crop.circle"
                )
            }

            NavigationLink {
                RegistrationIntegrationSettingsView()
            } label: {
                SettingsNavigationLabel(
                    title: "登録情報・連携",
                    detail: "FC、プレイガイド、劇場会員、外部カレンダー",
                    systemImage: "person.text.rectangle"
                )
            }
        }
        .navigationTitle("マイ・登録情報")
        .navigationBarTitleDisplayMode(.inline)
    }
}
struct MasterDataSettingsHubView: View {
    @Query private var people: [PersonMaster]
    @Query private var places: [PlaceMaster]
    @Query private var companions: [CompanionMaster]
    @Query private var visits: [Visit]

    private var activePeopleCount: Int {
        people.filter { !$0.isArchived }.count
    }

    private var activePlaceCount: Int {
        places.filter { !$0.isArchived }.count
    }

    private var tagCount: Int {
        recordFacetMasterValues(in: visits, kind: .tag).count
    }

    private var companionCount: Int {
        let recorded = recordFacetMasterValues(in: visits, kind: .companion).map(\.id)
        let registered = companions.filter { !$0.isArchived }.map { normalizedRecordFacetMasterName($0.name) }
        return Set(recorded + registered).count
    }

    var body: some View {
        List {
            Section("基本マスター") {
                NavigationLink {
                    PersonMasterManagementView()
                } label: {
                    LabeledContent("人物・団体", value: "\(activePeopleCount)件")
                }

                NavigationLink {
                    PlaceMasterManagementView()
                } label: {
                    LabeledContent("場所", value: "\(activePlaceCount)件")
                }
            }

            Section {
                NavigationLink {
                    RecordFacetMasterManagementView(kind: .tag)
                } label: {
                    LabeledContent("タグ", value: "\(tagCount)件")
                }

                NavigationLink {
                    CompanionMasterManagementView()
                } label: {
                    LabeledContent("同行者", value: "\(companionCount)件")
                }
            } header: {
                Text("記録から集約")
            } footer: {
                Text("タグは記録の表記を集約します。同行者は記録の表記を保ちながら、表示アイコンをマスターへ保存できます。改名・統合・削除は関連記録へ反映されます。")
            }
        }
        .navigationTitle("マスターデータ")
        .navigationBarTitleDisplayMode(.inline)
    }
}
