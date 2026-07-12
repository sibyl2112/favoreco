import CloudKit
import Foundation
import SwiftData

enum FavorecoModelContainerBootstrap {
    static let schema = Schema([
        RecordCategory.self,
        ExperienceEvent.self,
        Visit.self,
        InboxItem.self,
        PhotoBlob.self,
        SocialAccount.self,
        PersonMaster.self,
        EventPersonLink.self,
        PlaceMaster.self,
        Plan.self,
        TicketAccount.self,
        TicketAttempt.self,
    ])

    @MainActor
    static func makeContainer() -> ModelContainer {
        let defaults = UserDefaults.standard
        let wantsCloudSync = defaults.bool(forKey: AppStorageKeys.iCloudSyncEnabled)
            && EntitlementAccess.canUseSyncFeatures
        defaults.set(false, forKey: AppStorageKeys.iCloudSyncActiveAtLaunch)
        defaults.set("", forKey: AppStorageKeys.iCloudSyncStartupError)

        if wantsCloudSync {
            do {
                let cloudConfiguration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    cloudKitDatabase: .automatic
                )
                let container = try ModelContainer(for: schema, configurations: [cloudConfiguration])
                defaults.set(true, forKey: AppStorageKeys.iCloudSyncActiveAtLaunch)
                return container
            } catch {
                defaults.set(error.localizedDescription, forKey: AppStorageKeys.iCloudSyncStartupError)
            }
        }

        do {
            let localConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            return try ModelContainer(for: schema, configurations: [localConfiguration])
        } catch {
            fatalError("Could not create local ModelContainer: \(error)")
        }
    }
}

struct CloudSyncDiagnostic: Sendable {
    let accountStatusText: String
    let isAccountAvailable: Bool
    let hasUbiquityContainer: Bool
    let errorMessage: String
}

enum CloudSyncService {
    nonisolated static func diagnostic() async -> CloudSyncDiagnostic {
        do {
            let status = try await CKContainer.default().accountStatus()
            return CloudSyncDiagnostic(
                accountStatusText: accountStatusText(status),
                isAccountAvailable: status == .available,
                hasUbiquityContainer: FileManager.default.ubiquityIdentityToken != nil,
                errorMessage: ""
            )
        } catch {
            return CloudSyncDiagnostic(
                accountStatusText: "確認できません",
                isAccountAvailable: false,
                hasUbiquityContainer: FileManager.default.ubiquityIdentityToken != nil,
                errorMessage: error.localizedDescription
            )
        }
    }

    nonisolated private static func accountStatusText(_ status: CKAccountStatus) -> String {
        switch status {
        case .available: return "利用可能"
        case .noAccount: return "iCloud未サインイン"
        case .restricted: return "利用制限あり"
        case .couldNotDetermine: return "確認できません"
        case .temporarilyUnavailable: return "一時的に利用不可"
        @unknown default: return "不明"
        }
    }
}
