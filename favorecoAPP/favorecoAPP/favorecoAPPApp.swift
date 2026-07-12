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
                    await CategoryPresetSeeder.seedIfNeeded(in: sharedModelContainer.mainContext)
                    _ = try? AutomaticBackupService.createIfDue(in: sharedModelContainer.mainContext)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
