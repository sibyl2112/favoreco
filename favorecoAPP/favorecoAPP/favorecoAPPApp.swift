//
//  favorecoAPPApp.swift
//  favorecoAPP
//
//  Created by 平塚祝一 on 2026/07/08.
//

import SwiftUI
import SwiftData

@main
struct favorecoAPPApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        FontRegistrar.registerBundledFonts()
    }

    var sharedModelContainer: ModelContainer = FavorecoModelContainerBootstrap.makeContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(PurchaseManager.shared)
                .task {
#if DEBUG
                    let debugForcesRecovery = UserDefaults.standard.bool(
                        forKey: AppStorageKeys.debugForcesLocalStoreRecovery
                    )
                    guard !debugForcesRecovery else { return }
#endif
                    let localStoreStartupError = UserDefaults.standard.string(
                        forKey: AppStorageKeys.localStoreStartupError
                    ) ?? ""
                    guard localStoreStartupError.isEmpty else { return }
                    await CategoryPresetSeeder.seedIfNeeded(in: sharedModelContainer.mainContext)
                    await PersonStarterPresetSeeder.seedIfNeeded(in: sharedModelContainer.mainContext)
                    let defaults = UserDefaults.standard
                    if defaults.integer(forKey: AppStorageKeys.bundledTheaterSampleEyecatchRefreshVersion) < 1 {
                        if (try? SampleDataSeeder.refreshBundledTheaterSampleEyecatches(
                            in: sharedModelContainer.mainContext
                        )) != nil {
                            defaults.set(1, forKey: AppStorageKeys.bundledTheaterSampleEyecatchRefreshVersion)
                        }
                    }
                    if defaults.integer(forKey: AppStorageKeys.ticketNotificationMetadataMigrationVersion) < 1 {
                        if (try? TicketNotificationMetadataMigrationService.normalize(
                            in: sharedModelContainer.mainContext
                        )) != nil {
                            defaults.set(1, forKey: AppStorageKeys.ticketNotificationMetadataMigrationVersion)
                        }
                    }
                    let plans = (try? sharedModelContainer.mainContext.fetch(
                        FetchDescriptor<Plan>()
                    )) ?? []
                    let attempts = (try? sharedModelContainer.mainContext.fetch(
                        FetchDescriptor<TicketAttempt>()
                    )) ?? []
                    try? await TicketNotificationSettingsSyncService.synchronizeCopyIfNeeded(
                        plans: plans,
                        attempts: attempts,
                        in: sharedModelContainer.mainContext
                    )
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
