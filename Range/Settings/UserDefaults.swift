import Foundation
import OrderedCollections

/// Store implicit user preferences (not available in settings but based on recent user actions)
extension UserDefaults {
    enum UserDefaultsConstants: String {
        /// last project open by the user (to automatically reopen when starting the app)
        case lastOpenProjectId
        /// the prefix to be used for storing last open canvas for a project, will be followed by a project id
        case lastOpenCanvasIdPrefix = "lastOpenCanvasId_"
        /// the prefix to be used for storing last open canvas source for a canvas, will be followed by a canvas id
        case lastOpenCanvasSourceIdPrefix = "lastOpenCanvasSourceId_"
        /// last select geometry id for a photo to use it as a default for the next photo
        case lastPhotoPinId
        /// last user's choice if annotation (tags/description) is enabled in the photo flow, `true` by default
        case annotationEnabled
        /// last user's choice if multi photo session is enabled in the photo flow, `true` by default
        case multiPhotoSessionEnabled
        /// last user's choice if the feed has more or less update, `false` by default
        case moreUpdatesInTheFeed
        /// the prefix to be used for storing recent tags for a project, will be followed by a project id
        case recentTagsPrefix = "recentTags_"
        /// last user's choice if the tasks list shows all or only mine tasks, `false` by default
        case showOnlyMineTasks
        /// remember the last option selected by user when creating a new collaboration in the photo flow
        case lastPinTypeOption
        /// remember last fcm token, so it can be removed when a new one is obtained
        case lastFCMToken
    }

    static var lastOpenProjectId: String? {
        get {
            UserDefaults.standard.string(forKey: UserDefaultsConstants.lastOpenProjectId.rawValue)
        }
        set {
            if let id = newValue {
                UserDefaults.standard.set(id, forKey: UserDefaultsConstants.lastOpenProjectId.rawValue)
            } else {
                UserDefaults.standard.removeObject(forKey: UserDefaultsConstants.lastOpenProjectId.rawValue)
            }
        }
    }

    /// construct key used for storing last open canvas id for given project
    private static func lastOpenCanvasIdKey(forProjectId projectId: String) -> String {
        UserDefaultsConstants.lastOpenCanvasIdPrefix.rawValue + projectId
    }

    /// Returns the last open canvas id for given project or nil if nothing yet
    static func lastOpenCanvasId(forProjectId projectId: String) -> String? {
        guard let canvasId = UserDefaults.standard
            .object(forKey: lastOpenCanvasIdKey(forProjectId: projectId)) as? String
        else {
            return nil
        }
        return canvasId
    }

    static func setLastOpenCanvasId(_ canvasId: String, forProjectId projectId: String) {
        UserDefaults.standard.set(canvasId, forKey: lastOpenCanvasIdKey(forProjectId: projectId))
    }

    /// construct key used for storing last open canvas source id for given canvas
    private static func lastOpenCanvasSourceIdKey(forCanvasId canvasId: String) -> String {
        UserDefaultsConstants.lastOpenCanvasSourceIdPrefix.rawValue + canvasId
    }

    /// Returns the last open canvas source id for given canvas or nil if nothing yet
    static func lastOpenCanvasSourceId(forCanvasId canvasId: String) -> String? {
        guard let sourceId = UserDefaults.standard
            .object(forKey: lastOpenCanvasSourceIdKey(forCanvasId: canvasId)) as? String
        else {
            return nil
        }
        return sourceId
    }

    static func setLastOpenCanvasSourceId(_ canvasSourceId: String, forCanvasId canvasId: String) {
        UserDefaults.standard.set(canvasSourceId, forKey: lastOpenCanvasSourceIdKey(forCanvasId: canvasId))
    }

    /// stores the last select geometry id for a photo to use it as a default for the next photo
    static var lastPhotoPinId: String? {
        get {
            UserDefaults.standard.string(forKey: UserDefaultsConstants.lastPhotoPinId.rawValue)
        }
        set {
            if let id = newValue {
                UserDefaults.standard.set(id, forKey: UserDefaultsConstants.lastPhotoPinId.rawValue)
            } else {
                UserDefaults.standard.removeObject(forKey: UserDefaultsConstants.lastPhotoPinId.rawValue)
            }
        }
    }

    /// construct key used for storing recent tags for given project, exposed for tests
    static func recentTagsKey(forProjectId projectId: String) -> String {
        UserDefaultsConstants.recentTagsPrefix.rawValue + projectId
    }

    /// return at most last 10 recent tags. The most recent tag is at the end of the array
    static func recentTagIds(forProjectId projectId: String) -> [String] {
        UserDefaults.standard.array(forKey: UserDefaults.recentTagsKey(forProjectId: projectId)) as? [String] ?? []
    }

    /// adds given tags to recent tags for given project (the order of input matters, the tags with higher indices are treated as more recent)
    /// If tag exist in recent tags it will be reinserted at the end (so it's "more recent")
    /// only 10 most recent tags are kept
    static func addRecentTagIds(_ recentTagIds: [String], forProjectId projectId: String) {
        var orderedTagIds = OrderedSet(UserDefaults.recentTagIds(forProjectId: projectId))
        for recentTagId in recentTagIds {
            orderedTagIds.remove(recentTagId) // remove first, so it gets added at the end
            orderedTagIds.append(recentTagId)
        }
        // keep last 10 at most
        if orderedTagIds.count > 10 {
            orderedTagIds.removeFirst(orderedTagIds.count - 10)
        }
        // store in user defaults for given project key
        UserDefaults.standard.set(orderedTagIds.elements, forKey: UserDefaults.recentTagsKey(forProjectId: projectId))
    }

    static var annotationEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: UserDefaultsConstants.annotationEnabled.rawValue) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: UserDefaultsConstants.annotationEnabled.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsConstants.annotationEnabled.rawValue)
        }
    }

    static var multiPhotoSessionEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: UserDefaultsConstants.multiPhotoSessionEnabled.rawValue) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: UserDefaultsConstants.multiPhotoSessionEnabled.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsConstants.multiPhotoSessionEnabled.rawValue)
        }
    }

    static var moreUpdatesInTheFeed: Bool {
        get {
            UserDefaults.standard.bool(forKey: UserDefaultsConstants.moreUpdatesInTheFeed.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsConstants.moreUpdatesInTheFeed.rawValue)
        }
    }

    static var showOnlyMineTasks: Bool {
        get {
            UserDefaults.standard.bool(forKey: UserDefaultsConstants.showOnlyMineTasks.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsConstants.showOnlyMineTasks.rawValue)
        }
    }

    /// remember the last option selected by user when creating a new collaboration in the photo flow
    static var lastPinTypeOption: PinTypeOption? {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: UserDefaultsConstants.lastPinTypeOption.rawValue)
            else { return nil }
            return PinTypeOption.allCases.first { $0.rawValue == rawValue }
        }
        set {
            if let option = newValue {
                UserDefaults.standard.set(option.rawValue, forKey: UserDefaultsConstants.lastPinTypeOption.rawValue)
            } else {
                UserDefaults.standard.removeObject(forKey: UserDefaultsConstants.lastPinTypeOption.rawValue)
            }
        }
    }

    /// stores the last Firebase Cloud Messaging Token
    static var lastFCMToken: String? {
        get {
            UserDefaults.standard.string(forKey: UserDefaultsConstants.lastFCMToken.rawValue)
        }
        set {
            if let id = newValue {
                UserDefaults.standard.set(id, forKey: UserDefaultsConstants.lastFCMToken.rawValue)
            } else {
                UserDefaults.standard.removeObject(forKey: UserDefaultsConstants.lastFCMToken.rawValue)
            }
        }
    }
}
