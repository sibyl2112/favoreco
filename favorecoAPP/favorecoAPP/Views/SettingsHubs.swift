import SwiftUI
import SwiftData

struct SettingsNavigationLabel: View {
    @Environment(\.favorecoThemePalette) private var themePalette

    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            FavorecoIcon(systemName: systemImage, size: 20, fallbackWeight: .semibold)
                .foregroundStyle(themePalette.globalTint)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(FavorecoTypography.bodyStrong)
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(FavorecoTypography.jpSans(11, weight: .regular, relativeTo: .caption))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(minHeight: 54)
        .favorecoSettingsRowLayout()
    }
}

struct MySettingsHubView: View {
    var body: some View {
        List {
            FavorecoSettingsSection("プロフィールと連携") {
                NavigationLink {
                    ProfileSettingsView()
                } label: {
                    SettingsNavigationLabel(
                        title: "プロフィール・SNS",
                        detail: "表示名、プロフィール写真、SNSアカウント",
                        systemImage: "person.crop.circle"
                    )
                }

                NavigationLink {
                    RegistrationIntegrationSettingsView()
                } label: {
                    SettingsNavigationLabel(
                        title: "チケット・会員・カレンダー",
                        detail: "FC、プレイガイド、劇場会員、外部カレンダー",
                        systemImage: "person.text.rectangle"
                    )
                }
            }
        }
        .favorecoSettingsListLayout()
        .navigationTitle("プロフィール・連携")
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
            FavorecoSettingsSection("人物と場所") {
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

                NavigationLink {
                    PublicRecurringEventCatalogView()
                } label: {
                    LabeledContent("定期イベントカタログ", value: "芸術祭・音楽祭")
                }
            }

            FavorecoSettingsSectionWithFooter("記録の分類") {
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
            } footer: {
                Text("タグは記録の表記を集約します。同行者は記録の表記を保ちながら、表示アイコンをマスターへ保存できます。改名・統合・削除は関連記録へ反映されます。")
            }
        }
        .favorecoSettingsListLayout()
        .navigationTitle("マスターデータ")
        .navigationBarTitleDisplayMode(.inline)
    }
}
