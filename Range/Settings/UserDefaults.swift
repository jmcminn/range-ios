import Foundation
import OrderedCollections
import OSLog
import UIKit

/// Store implicit user preferences (not available in settings but based on recent user actions)
extension UserDefaults {
    enum UserDefaultsConstants: String {
        /// Ids of the organizations (array of strings) shown to the user when the organization selector was presented for the last time
        case lastPresentedOrganizationIds
        /// Id of the last open organization
        case lastOpenOrganizationId
        /// Ids of the up to 3 recently open projects per organization, will be followe by an organization id
        case recentProjectIdsPrefix = "recentProjectsIds_"
        /// the prefix to be used for storing last open canvas for a project, will be followed by a project id
        case lastOpenCanvasIdPrefix = "lastOpenCanvasId_"
        /// the prefix to be used for storing last open canvas source for a canvas, will be followed by a canvas id
        case lastOpenCanvasSourceIdPrefix = "lastOpenCanvasSourceId_"
        /// last user's choice if annotation (tags/description) is enabled in the photo flow, `true` by default
        case annotationEnabled
        /// last user's choice if multi photo session is enabled in the photo flow, `true` by default
        case multiPhotoSessionEnabled
        /// last user's choice if the feed has more or less update, `false` by default
        case moreUpdatesInTheFeed
        /// the prefix to be used for storing recent tags for a project, will be followed by a project id
        case recentTagsPrefix = "recentTags_"
        /// remember the last option selected by user when creating a new collaboration in the photo flow
        case lastPinTypeOption
        /// remember last fcm token, so it can be removed when a new one is obtained
        case lastFCMToken
        /// the prefix used for storing canvasFilters for a project, will be followed by a project id
        case canvasFiltersPrefix = "canvasFilters_"
        /// the prefix used for storing the task list filters for a project, will be followed by a project id
        case taskListFiltersPrefix = "taskListFilters_"
        /// whether the card onboarding was complete (action card for project needs to be maximized)
        case cardOnboardingComplete
        /// the prefix used for storing last copied pins (array of ids) for a projects, will be followed by a project id
        /// it's stored as lastCopiedTasks_ for backward compatibility (it used to store tasks only)
        case lastCopiedPinsPrefix = "lastCopiedTasks_"
        /// Annotation editor user choices
        case lastPickedAnnotationColor
        case lastPickedAnnotationLineThickness
        case lastPickedAnnotationFontSize
        /// Recent annotations texts. 10 recent items. Each item is a [annotationId, annotationText] array, so we can update the entry
        /// if a text for given annotation was updated, instead of adding new text and keeping the old.
        /// It's stored separately from recentAnnotations as what might be considered a duplicate from the text point of view is not necessarily
        /// a duplicated annotation (as it might have a different color for example). We could store just recentAnnotations and deduplicate by text only when
        /// using for recent annotations texts, but then we could end up with lower number of items than 10.
        case recentAnnotationTexts
        /// Recently inserted/updated annotations. 10 recent items. Stores an array of [TextAnnotation]
        case recentAnnotations
    }

    /// Ids of the organizations (array of strings) shown to the user when the organization selector was presented for the last time
    static var lastPresentedOrganizationIds: [String]? {
        get {
            UserDefaults.standard.stringArray(forKey: UserDefaultsConstants.lastPresentedOrganizationIds.rawValue)
        }
        set {
            if let ids = newValue {
                UserDefaults.standard.set(ids, forKey: UserDefaultsConstants.lastPresentedOrganizationIds.rawValue)
            } else {
                UserDefaults.standard.removeObject(forKey: UserDefaultsConstants.lastPresentedOrganizationIds.rawValue)
            }
        }
    }

    /// stores the last open organization id
    static var lastOpenOrganizationId: String? {
        get {
            UserDefaults.standard.string(forKey: UserDefaultsConstants.lastOpenOrganizationId.rawValue)
        }
        set {
            if let id = newValue {
                UserDefaults.standard.set(id, forKey: UserDefaultsConstants.lastOpenOrganizationId.rawValue)
            } else {
                UserDefaults.standard.removeObject(forKey: UserDefaultsConstants.lastOpenOrganizationId.rawValue)
            }
        }
    }

    /// construct key used for storing recent project ids for given organization
    private static func recentProjectIdsKey(forOrganizationId organizationId: String) -> String {
        UserDefaultsConstants.recentProjectIdsPrefix.rawValue + organizationId
    }

    /// return at most last 3 recent project ids. The most recent project is at the beginning of the array
    static func recentProjectIds(forOrganizationId organizationId: String) -> [String] {
        UserDefaults.standard.array(forKey: recentProjectIdsKey(forOrganizationId: organizationId)) as? [String] ?? []
    }

    /// adds given project id to recent projects for given organization (the order of input matters, the projects with lower indices are treated as more recent)
    /// If project exist in recent projects it will be reinserted at the beginning (so it's "more recent")
    /// only 3 most recent projects are kept
    static func addRecentProjectId(_ projectId: String, forOrganizationId organizationId: String) {
        var orderedProjectIds = OrderedSet(recentProjectIds(forOrganizationId: organizationId))
        orderedProjectIds.remove(projectId) // remove, so it gets added at the beginning
        orderedProjectIds.insert(projectId, at: 0)
        // keep last 3 at most
        if orderedProjectIds.count > 3 {
            orderedProjectIds.removeLast(orderedProjectIds.count - 3)
        }
        // store in user defaults
        UserDefaults.standard.set(
            orderedProjectIds.elements,
            forKey: recentProjectIdsKey(forOrganizationId: organizationId)
        )
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

    /// construct key used for storing canvas filters for given project
    private static func canvasFiltersKey(forProjectId projectId: String) -> String {
        UserDefaultsConstants.canvasFiltersPrefix.rawValue + projectId
    }

    /// Returns the canvas filters for given project or default CanvasFilters if not set yet
    static func canvasFilters(forModel model: ProjectModel) -> CollaborationFilters {
        guard let canvasFiltersString = UserDefaults.standard
            .object(forKey: canvasFiltersKey(forProjectId: model.projectId)) as? String
        else {
            return CollaborationFilters(model: model, variant: .canvas)
        }
        do {
            let canvasFiltersData = try canvasFiltersString.data(using: .utf8)
                .or(error: "Failed to get data from canvas filters string")
            let jsonDecoder = JSONDecoder()
            return try jsonDecoder.decode(CollaborationFilters.self, from: canvasFiltersData)
        } catch {
            Logger.settings.error("Failed to load canvas filters: \(error)")
            return CollaborationFilters(model: model, variant: .canvas)
        }
    }

    static func setCanvasFilters(_ canvasFilters: CollaborationFilters, forProjectId projectId: String) {
        do {
            let jsonEncoder = JSONEncoder()
            let canvasFiltersData = try jsonEncoder.encode(canvasFilters)
            let canvasFiltersString = try String(data: canvasFiltersData, encoding: .utf8)
                .or(error: "Failed to create String from canvas filters data")
            UserDefaults.standard.set(canvasFiltersString, forKey: canvasFiltersKey(forProjectId: projectId))
        } catch {
            Logger.settings.error("Failed to save canvas filters: \(error)")
        }
    }

    /// construct key used for storing tasks filters for given project
    private static func taskListFiltersKey(forProjectId projectId: String) -> String {
        UserDefaultsConstants.taskListFiltersPrefix.rawValue + projectId
    }

    /// Returns the tasks filters for given project or default TaskListFilters if not set yet
    static func taskListFilters(forModel model: ProjectModel) -> CollaborationFilters {
        guard let taskListFiltersString = UserDefaults.standard
            .object(forKey: taskListFiltersKey(forProjectId: model.projectId)) as? String
        else {
            return CollaborationFilters(model: model, variant: .taskList)
        }
        do {
            let taskListFiltersData = try taskListFiltersString.data(using: .utf8)
                .or(error: "Failed to get data from task list filters string")
            let jsonDecoder = JSONDecoder()
            let filters = try jsonDecoder.decode(CollaborationFilters.self, from: taskListFiltersData)
            filters.model = model
            return filters
        } catch {
            Logger.settings.error("Failed to load task list filters: \(error)")
            return CollaborationFilters(model: model, variant: .taskList)
        }
    }

    static func setTaskListFilters(_ filters: CollaborationFilters, forProjectId projectId: String) {
        do {
            let jsonEncoder = JSONEncoder()
            let filtersData = try jsonEncoder.encode(filters)
            let filtersString = try String(data: filtersData, encoding: .utf8)
                .or(error: "Failed to create String from task list filters data")
            UserDefaults.standard.set(filtersString, forKey: taskListFiltersKey(forProjectId: projectId))
        } catch {
            Logger.settings.error("Failed to save task list filters: \(error)")
        }
    }

    static var cardOnboardingComplete: Bool {
        get {
            if UserDefaults.standard.object(forKey: UserDefaultsConstants.cardOnboardingComplete.rawValue) == nil {
                return false
            }
            return UserDefaults.standard.bool(forKey: UserDefaultsConstants.cardOnboardingComplete.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsConstants.cardOnboardingComplete.rawValue)
        }
    }

    /// Reset onboarding user defaults, so onboarding animation can be tested again (for dev/testing purposes only)
    static func resetOnboarding() {
        cardOnboardingComplete = false
    }

    /// construct key used for storing last copied pin ids for given project
    private static func lastCopiedPinsKey(forProjectId projectId: String) -> String {
        UserDefaultsConstants.lastCopiedPinsPrefix.rawValue + projectId
    }

    /// Returns the last copied pin ids for given project. The most recently copied pin id is at the beginning of the array
    static func lastCopiedPins(forProjectId projectId: String) -> [String] {
        UserDefaults.standard.array(forKey: lastCopiedPinsKey(forProjectId: projectId)) as? [String] ?? []
    }

    /// adds given task id to last copied pin ids for given project
    /// If pin id exist in recent pin ids it will be reinserted at the beginning (so it's "more recent")
    static func addLastCopiedPin(_ pinId: String, forProjectId projectId: String) {
        var orderedPinIds = OrderedSet(lastCopiedPins(forProjectId: projectId))
        orderedPinIds.remove(pinId) // remove, so it gets added at the beginning
        orderedPinIds.insert(pinId, at: 0)
        // store in user defaults
        UserDefaults.standard.set(
            orderedPinIds.elements,
            forKey: lastCopiedPinsKey(forProjectId: projectId)
        )
    }
}
