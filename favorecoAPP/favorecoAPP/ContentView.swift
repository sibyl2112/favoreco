//
//  ContentView.swift
//  favorecoAPP
//
//  Created by 平塚祝一 on 2026/07/08.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage(AppStorageKeys.hasCompletedGenreOnboarding) private var hasCompletedGenreOnboarding = false

    var body: some View {
        Group {
            if hasCompletedGenreOnboarding {
                MainTabView()
            } else {
                GenreOnboardingView()
            }
        }
        .modifier(AppTextSizeModifier())
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self, SocialAccount.self], inMemory: true)
}
