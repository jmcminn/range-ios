import Foundation
import OSLog

extension UserDefaults {
    // UserDefaults instance for given user (we want to separate defaults so every user
    // logged in on this device has their own preferences/settings)
    static func forUser(_ userId: String) -> UserDefaults {
        UserDefaults(suiteName: "\(Bundle.main.bundleIdentifier ?? "").\(userId)") ?? .standard
    }

    /// Migrate user defaults from .standard to given user UserDefaults
    /// After migration set a flag in the .standard defaults so they're not migrated again
    /// The migration is manually picking keys from the defaults as there's no way to choose all of the defaults set from Range code.
    static func possiblyMigrateUserDefaults(userId: String) {
        let alreadyMigratedFlag = "range_migrated_to_user_level"

        guard UserDefaults.standard.bool(forKey: alreadyMigratedFlag) == false else {
            Logger.settings.info("Standard Range defaults already migrated to user level")
            return
        }
        Logger.settings.info("Migrating standard Range defaults to user \(userId) defaults")

        let userDefaults = UserDefaults.forUser(userId)
        let keyPrefixes = [
            UserPreferences.Keys.lastPresentedOrganizationIds,
            UserPreferences.Keys.lastOpenOrganizationId,
            UserPreferences.Keys.recentProjectIdsPrefix,
            UserPreferences.Keys.lastOpenCanvasIdPrefix,
            UserPreferences.Keys.lastOpenCanvasSourceIdPrefix,
            UserPreferences.Keys.annotationEnabled,
            UserPreferences.Keys.multiPhotoSessionEnabled,
            UserPreferences.Keys.moreUpdatesInTheFeed,
            UserPreferences.Keys.recentTagsPrefix,
            UserPreferences.Keys.lastPinTypeOption,
            UserPreferences.Keys.lastFCMToken,
            UserPreferences.Keys.canvasFiltersPrefix,
            UserPreferences.Keys.taskListFiltersPrefix,
            UserPreferences.Keys.cardOnboardingComplete,
            UserPreferences.Keys.lastCopiedPinsPrefix,
            UserPreferences.Keys.lastPickedAnnotationColor,
            UserPreferences.Keys.lastPickedAnnotationLineThickness,
            UserPreferences.Keys.lastPickedAnnotationFontSize,
            UserPreferences.Keys.recentAnnotationTexts,
            UserPreferences.Keys.recentAnnotations,
            UserSettings.Keys.uploadUsingCellular,
            UserSettings.Keys.saveImagesToDevice,
            PendingActionsModelImpl.DefaultsKey.actions,
            PendingActionsModelImpl.DefaultsKey.retryCount,
            PendingActionsModelImpl.DefaultsKey.nextAttemptAt,
            PendingActionsModelImpl.DefaultsKey.lastError,
        ]

        for (key, value) in UserDefaults.standard.dictionaryRepresentation() {
            if keyPrefixes.contains(where: { key.hasPrefix($0) }) {
                Logger.settings.info("Migrating \(key)")
                userDefaults.set(value, forKey: key)
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        Logger.settings.info("Marking standard defaults as migrated")
        UserDefaults.standard.setValue(true, forKey: alreadyMigratedFlag)
    }
}
