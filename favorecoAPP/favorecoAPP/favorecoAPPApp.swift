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
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            RecordCategory.self,
            ExperienceEvent.self,
            Visit.self,
            InboxItem.self,
            PhotoBlob.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
