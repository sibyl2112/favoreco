//
//  AppStorageKeys.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import Foundation

enum AppStorageKeys {
    static let hasCompletedGenreOnboarding = "hasCompletedGenreOnboarding"
    static let lastSeenReleaseVersion = "lastSeenReleaseVersion"
    static let showsHomeAttention = "showsHomeAttention"
    static let showsHomeExperienceGallery = "showsHomeExperienceGallery"
    static let showsHomeInbox = "showsHomeInbox"
    static let showsHomeInterestingExpanded = "showsHomeInterestingExpanded"
    static let showsHomeRecentRecords = "showsHomeRecentRecords"
    static let showsHomeCategories = "showsHomeCategories"
    static let showsHomeStatsSummary = "showsHomeStatsSummary"
    static let showsHomeFavorites = "showsHomeFavorites"
    static let debugHomeCategoryLayout = "debugHomeCategoryLayout"
    static let followsSystemTextSize = "followsSystemTextSize"
    static let appTextSize = "appTextSize"
    static let fontStyle = "fontStyle"
    static let fontWeight = "fontWeight"
    static let appearanceMode = "appearanceMode"
    static let themeMode = "themeMode"
    static let unifiedThemeColorHex = "unifiedThemeColorHex"
    static let profileDisplayName = "profileDisplayName"
    static let profileImageData = "profileImageData"
    static let iCloudSyncEnabled = "iCloudSyncEnabled"
    static let iCloudSyncActiveAtLaunch = "iCloudSyncActiveAtLaunch"
    static let iCloudSyncStartupError = "iCloudSyncStartupError"
    static let localStoreStartupError = "localStoreStartupError"
    static let debugForcesLocalStoreRecovery = "debugForcesLocalStoreRecovery"
    static let automaticBackupEnabled = "automaticBackupEnabled"
    static let automaticBackupLastCreatedAt = "automaticBackupLastCreatedAt"
    static let automaticBackupUsesICloudDrive = "automaticBackupUsesICloudDrive"
    static let automaticBackupLastICloudCreatedAt = "automaticBackupLastICloudCreatedAt"
    static let automaticBackupICloudError = "automaticBackupICloudError"
    nonisolated static let purchasedPlanCache = "purchasedPlanCache"
    nonisolated static let debugPlanOverride = "debugPlanOverride"
    static let defaultRecordDateMode = "defaultRecordDateMode"
    static let defaultGenreMode = "defaultGenreMode"
    static let lastUsedCategoryTemplateKey = "lastUsedCategoryTemplateKey"
    static let homeSelectedCategoryTemplateKey = "homeSelectedCategoryTemplateKey"
    static let categoryLibraryLayoutModePrefix = "categoryLibraryLayoutMode."
    static let recordsLayoutMode = "recordsLayoutMode"
    static let hasMigratedLegacyFavoritesToFavoPins = "hasMigratedLegacyFavoritesToFavoPins"
    static let afterSaveRecordAction = "afterSaveRecordAction"
    static let photoAddStartMode = "photoAddStartMode"
    static let photoCompressionQuality = "photoCompressionQuality"
    static let usesURLImportAssist = "usesURLImportAssist"
    static let usesOCRImportAssist = "usesOCRImportAssist"
    static let usesMapSearchAssist = "usesMapSearchAssist"
    static let usesWeatherAutoFill = "usesWeatherAutoFill"
    static let usesInputSuggestionDictionary = "usesInputSuggestionDictionary"
    static let showsExternalCalendarEvents = "showsExternalCalendarEvents"
    static let automaticallyUpdatesExternalCalendar = "automaticallyUpdatesExternalCalendar"
    static let notificationMasterEnabled = "notificationMasterEnabled"
    static let notificationApplicationStartEnabled = "notificationApplicationStartEnabled"
    static let notificationApplicationDeadlineEnabled = "notificationApplicationDeadlineEnabled"
    static let notificationLotteryResultEnabled = "notificationLotteryResultEnabled"
    static let notificationPaymentDeadlineEnabled = "notificationPaymentDeadlineEnabled"
    static let notificationTicketIssueEnabled = "notificationTicketIssueEnabled"
    static let notificationPerformanceReminderEnabled = "notificationPerformanceReminderEnabled"
    static let notificationPreparationDeadlineEnabled = "notificationPreparationDeadlineEnabled"
    static let notificationApplicationStartTiming = "notificationApplicationStartTiming"
    static let notificationApplicationDeadlineTiming = "notificationApplicationDeadlineTiming"
    static let notificationLotteryResultTiming = "notificationLotteryResultTiming"
    static let notificationPaymentDeadlineTiming = "notificationPaymentDeadlineTiming"
    static let notificationTicketIssueTiming = "notificationTicketIssueTiming"
    static let notificationPerformanceTiming = "notificationPerformanceTiming"
    static let notificationPreparationTiming = "notificationPreparationTiming"
    static let notificationMembershipExpiryEnabled = "notificationMembershipExpiryEnabled"
    static let notificationMemoryReminderEnabled = "notificationMemoryReminderEnabled"
    static let notificationMonthlyReportEnabled = "notificationMonthlyReportEnabled"
    static let pendingNotificationPlanID = "pendingNotificationPlanID"
    static let pendingNotificationAttemptID = "pendingNotificationAttemptID"
    static let pendingNotificationPreparationTaskID = "pendingNotificationPreparationTaskID"
    static let opensPreviousMonthlyReport = "opensPreviousMonthlyReport"
    static let opensPreviousYearlyReport = "opensPreviousYearlyReport"
}

enum RecordsLayoutMode: String, CaseIterable, Identifiable {
    // Keep the former raw values so an existing saved selection migrates without resetting.
    case gallery = "gridThree"
    case compact = "gridFour"
    case banner = "detail"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gallery: "ギャラリー"
        case .compact: "ミニ詳細"
        case .banner: "バナー"
        }
    }

    var systemImage: String {
        switch self {
        case .gallery: "square.grid.3x3"
        case .compact: "rectangle.grid.2x2"
        case .banner: "rectangle.grid.1x2"
        }
    }
}

enum CategoryLibraryLayoutMode: String, CaseIterable, Identifiable {
    case gallery
    case compact
    case banner

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gallery: "ギャラリー"
        case .compact: "ミニ詳細"
        case .banner: "バナー"
        }
    }

    var systemImage: String {
        switch self {
        case .gallery: "square.grid.3x3"
        case .compact: "rectangle.grid.2x2"
        case .banner: "rectangle.grid.1x2"
        }
    }

    static func defaultMode(for templateKey: String) -> CategoryLibraryLayoutMode {
        switch templateKey {
        case "movie", "theater": .gallery
        case "live": .banner
        default: .compact
        }
    }

    static func stored(for templateKey: String) -> CategoryLibraryLayoutMode {
        let key = AppStorageKeys.categoryLibraryLayoutModePrefix + templateKey
        guard let rawValue = UserDefaults.standard.string(forKey: key),
              let mode = CategoryLibraryLayoutMode(rawValue: rawValue) else {
            return defaultMode(for: templateKey)
        }
        return mode
    }

    func store(for templateKey: String) {
        UserDefaults.standard.set(rawValue, forKey: AppStorageKeys.categoryLibraryLayoutModePrefix + templateKey)
    }
}

enum HomeCategoryLayoutMode: String, CaseIterable, Identifiable {
    case horizontal
    case grid

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .horizontal:
            return "横1段"
        case .grid:
            return "4列"
        }
    }
}
