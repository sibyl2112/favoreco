//
//  ContentView.swift
//  favorecoAPP
//
//  Created by 平塚祝一 on 2026/07/08.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @AppStorage(AppStorageKeys.hasCompletedGenreOnboarding) private var hasCompletedGenreOnboarding = false
    @AppStorage(AppStorageKeys.appearanceMode) private var appearanceModeRaw = AppAppearanceMode.system.rawValue
    @AppStorage(AppStorageKeys.themeMode) private var themeModeRaw = FavorecoThemeMode.categoryAccent.rawValue
    @AppStorage(AppStorageKeys.unifiedThemeColorHex) private var unifiedThemeColorHex = "#147C88"
    @AppStorage(AppStorageKeys.fontStyle) private var fontStyleRaw = AppFontStyle.standard.rawValue
    @AppStorage(AppStorageKeys.fontWeight) private var fontWeightRaw = AppFontWeight.standard.rawValue
    @AppStorage(AppStorageKeys.lastSeenReleaseVersion) private var lastSeenReleaseVersion = ""
    @AppStorage(AppStorageKeys.localStoreStartupError) private var localStoreStartupError = ""
    @State private var presentedReleaseNote: AppReleaseNote?

    var body: some View {
        Group {
            if !localStoreStartupError.isEmpty {
                LocalStoreRecoveryView(errorMessage: localStoreStartupError)
            } else if hasCompletedGenreOnboarding {
                MainTabView()
            } else {
                GenreOnboardingView()
            }
        }
        .modifier(AppTextSizeModifier())
        .preferredColorScheme(appearanceMode.colorScheme)
        .environment(\.favorecoThemePalette, effectiveThemePalette)
        .tint(effectiveThemePalette.globalTint)
        .animation(nil, value: fontStyleRaw)
        .animation(nil, value: fontWeightRaw)
        .task(id: hasCompletedGenreOnboarding) {
            prepareReleaseUpdateIfNeeded()
        }
        .sheet(item: $presentedReleaseNote, onDismiss: acknowledgeCurrentRelease) { release in
            ReleaseUpdateSheet(release: release)
        }
    }

    private var appearanceMode: AppAppearanceMode {
        AppAppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    private var effectiveThemePalette: FavorecoThemePalette {
        let mode = FavorecoThemeMode(rawValue: themeModeRaw) ?? .categoryAccent
        guard purchaseManager.currentPlan.includesLocalFullFeatures, mode == .unified else {
            return .standard
        }
        return FavorecoThemePalette(mode: .unified, unifiedColorHex: unifiedThemeColorHex)
    }

    private func prepareReleaseUpdateIfNeeded() {
        guard localStoreStartupError.isEmpty else { return }
        let currentVersion = AppReleaseNotes.currentVersion
        guard !currentVersion.isEmpty else { return }

        if !hasCompletedGenreOnboarding {
            if lastSeenReleaseVersion.isEmpty {
                lastSeenReleaseVersion = currentVersion
            }
            return
        }

        guard lastSeenReleaseVersion != currentVersion else { return }
        presentedReleaseNote = AppReleaseNotes.current
    }

    private func acknowledgeCurrentRelease() {
        let currentVersion = AppReleaseNotes.currentVersion
        guard !currentVersion.isEmpty else { return }
        lastSeenReleaseVersion = currentVersion
    }
}

#Preview {
    ContentView()
        .environmentObject(PurchaseManager.shared)
        .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self, SocialAccount.self], inMemory: true)
}
