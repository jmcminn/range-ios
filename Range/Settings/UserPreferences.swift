import Foundation
import OrderedCollections
import OSLog
import UIKit

/// Store implicit user preferences (not available in settings but based on recent user actions)
class UserPreferences {
    let defaults: UserDefaults

    enum Keys {
        /// Ids of the organizations (array of strings) shown to the user when the organization selector was presented for the last time
        static let lastPresentedOrganizationIds = "lastPresentedOrganizationIds"
        /// Id of the last open organization
        static let lastOpenOrganizationId = "lastOpenOrganizationId"
        /// stores ProjectFilters
        static let projectFilters = "projectFilters"
        /// Ids of the up to 3 recently open projects per organization, will be followe by an organization id
        static let recentProjectIdsPrefix = "recentProjectsIds_"
        /// the prefix to be used for storing last open canvas for a project, will be followed by a project id
        static let lastOpenCanvasIdPrefix = "lastOpenCanvasId_"
        /// the prefix to be used for storing last open canvas source for a canvas, will be followed by a canvas id
        static let lastOpenCanvasSourceIdPrefix = "lastOpenCanvasSourceId_"
        /// last user's choice if annotation (tags/description) is enabled in the photo flow, `true` by default
        static let annotationEnabled = "annotationEnabled"
        /// last user's choice if multi photo session is enabled in the photo flow, `true` by default
        static let multiPhotoSessionEnabled = "multiPhotoSessionEnabled"
        /// last user's choice if the feed has more or less update, `false` by default
        static let moreUpdatesInTheFeed = "moreUpdatesInTheFeed"
        /// the prefix to be used for storing recent tags for a project, will be followed by a project id
        static let recentTagsPrefix = "recentTags_"
        /// remember the last option selected by user when creating a new collaboration in the photo flow
        static let lastPinTypeOption = "lastPinTypeOption"
        /// remember last fcm token, so it can be removed when a new one is obtained
        static let lastFCMToken = "lastFCMToken"
        /// the prefix used for storing canvasFilters for a project, will be followed by a project id
        static let canvasFiltersPrefix = "canvasFilters_"
        /// the prefix used for storing the task list filters for a project, will be followed by a project id
        static let taskListFiltersPrefix = "taskListFilters_"
        /// whether the card onboarding was complete (action card for project needs to be maximized)
        static let cardOnboardingComplete = "cardOnboardingComplete"
        static let canvasSelectorOnboardingComplete = "canvasSelectorOnboardingComplete"
        static let canvasFiltersOnboardingComplete = "canvasFiltersOnboardingComplete"
        /// the prefix used for storing last copied pins (array of ids) for a projects, will be followed by a project id
        /// it's stored as lastCopiedTasks_ for backward compatibility (it used to store tasks only)
        static let lastCopiedPinsPrefix = "lastCopiedTasks_"
        /// Annotation editor user choices
        static let lastPickedAnnotationColor = "lastPickedAnnotationColor"
        static let lastPickedAnnotationLineThickness = "lastPickedAnnotationLineThickness"
        static let lastPickedAnnotationFontSize = "lastPickedAnnotationFontSize"
        /// Recent annotations texts. 10 recent items. Each item is a [annotationId, annotationText] array, so we can update the entry
        /// if a text for given annotation was updated, instead of adding new text and keeping the old.
        /// It's stored separately from recentAnnotations as what might be considered a duplicate from the text point of view is not necessarily
        /// a duplicated annotation (as it might have a different color for example). We could store just recentAnnotations and deduplicate by text only when
        /// using for recent annotations texts, but then we could end up with lower number of items than 10.
        static let recentAnnotationTexts = "recentAnnotationTexts"
        /// Recently inserted/updated annotations. 10 recent items. Stores an array of [TextAnnotation]
        static let recentAnnotations = "recentAnnotationTexts"
    }

    /// Ids of the organizations (array of strings) shown to the user when the organization selector was presented for the last time
    var lastPresentedOrganizationIds: [String]? { didSet {
        if let ids = lastPresentedOrganizationIds {
            defaults.set(ids, forKey: Keys.lastPresentedOrganizationIds)
        } else {
            defaults.removeObject(forKey: Keys.lastPresentedOrganizationIds)
        }
    } }

    /// stores the last open organization id
    var lastOpenOrganizationId: String? {
        didSet {
            if let id = lastOpenOrganizationId {
                defaults.set(id, forKey: Keys.lastOpenOrganizationId)
            } else {
                defaults.removeObject(forKey: Keys.lastOpenOrganizationId)
            }
        }
    }

    /// Returns the project filters for this user (filters used on the projects listing screen)
    func projectFilters() -> ProjectFilters {
        guard let filtersString = defaults.object(forKey: Keys.projectFilters) as? String else {
            return ProjectFilters()
        }
        do {
            let filtersData = try filtersString.data(using: .utf8)
                .or(error: "Failed to get data from project filters string")
            let jsonDecoder = JSONDecoder()
            return try jsonDecoder.decode(ProjectFilters.self, from: filtersData)
        } catch {
            Logger.settings.error("Failed to load project filters: \(error)")
            return ProjectFilters()
        }
    }

    func setProjectFilters(_ filters: ProjectFilters) {
        do {
            let jsonEncoder = JSONEncoder()
            let filtersData = try jsonEncoder.encode(filters)
            let filtersString = try String(data: filtersData, encoding: .utf8)
                .or(error: "Failed to create String from project filters data")
            defaults.set(filtersString, forKey: Keys.projectFilters)
        } catch {
            Logger.settings.error("Failed to save project filters: \(error)")
        }
    }

    /// construct key used for storing recent project ids for given organization
    private func recentProjectIdsKey(forOrganizationId organizationId: String) -> String {
        Keys.recentProjectIdsPrefix + organizationId
    }

    /// return at most last 3 recent project ids. The most recent project is at the beginning of the array
    func recentProjectIds(forOrganizationId organizationId: String) -> [String] {
        defaults.array(forKey: recentProjectIdsKey(forOrganizationId: organizationId)) as? [String] ?? []
    }

    /// adds given project id to recent projects for given organization (the order of input matters, the projects with lower indices are treated as more recent)
    /// If project exist in recent projects it will be reinserted at the beginning (so it's "more recent")
    /// only 3 most recent projects are kept
    func addRecentProjectId(_ projectId: String, forOrganizationId organizationId: String) {
        var orderedProjectIds = OrderedSet(recentProjectIds(forOrganizationId: organizationId))
        orderedProjectIds.remove(projectId) // remove, so it gets added at the beginning
        orderedProjectIds.insert(projectId, at: 0)
        // keep last 3 at most
        if orderedProjectIds.count > 3 {
            orderedProjectIds.removeLast(orderedProjectIds.count - 3)
        }
        // store in user defaults
        defaults.set(
            orderedProjectIds.elements,
            forKey: recentProjectIdsKey(forOrganizationId: organizationId)
        )
    }

    /// construct key used for storing last open canvas id for given project
    private func lastOpenCanvasIdKey(forProjectId projectId: String) -> String {
        Keys.lastOpenCanvasIdPrefix + projectId
    }

    /// Returns the last open canvas id for given project or nil if nothing yet
    func lastOpenCanvasId(forProjectId projectId: String) -> String? {
        defaults.object(forKey: lastOpenCanvasIdKey(forProjectId: projectId)) as? String
    }

    func setLastOpenCanvasId(_ canvasId: String, forProjectId projectId: String) {
        defaults.set(canvasId, forKey: lastOpenCanvasIdKey(forProjectId: projectId))
    }

    /// construct key used for storing last open canvas source id for given canvas
    private func lastOpenCanvasSourceIdKey(forCanvasId canvasId: String) -> String {
        Keys.lastOpenCanvasSourceIdPrefix + canvasId
    }

    /// Returns the last open canvas source id for given canvas or nil if nothing yet
    func lastOpenCanvasSourceId(forCanvasId canvasId: String) -> String? {
        defaults.object(forKey: lastOpenCanvasSourceIdKey(forCanvasId: canvasId)) as? String
    }

    func setLastOpenCanvasSourceId(_ canvasSourceId: String, forCanvasId canvasId: String) {
        defaults.set(canvasSourceId, forKey: lastOpenCanvasSourceIdKey(forCanvasId: canvasId))
    }

    /// construct key used for storing recent tags for given project, exposed for tests
    func recentTagsKey(forProjectId projectId: String) -> String {
        Keys.recentTagsPrefix + projectId
    }

    /// return at most last 10 recent tags. The most recent tag is at the end of the array
    func recentTagIds(forProjectId projectId: String) -> [String] {
        defaults.array(forKey: recentTagsKey(forProjectId: projectId)) as? [String] ?? []
    }

    /// adds given tags to recent tags for given project (the order of input matters, the tags with higher indices are treated as more recent)
    /// If tag exist in recent tags it will be reinserted at the end (so it's "more recent")
    /// only 10 most recent tags are kept
    func addRecentTagIds(_ newRecentTagIds: [String], forProjectId projectId: String) {
        var orderedTagIds = OrderedSet(recentTagIds(forProjectId: projectId))
        for recentTagId in newRecentTagIds {
            orderedTagIds.remove(recentTagId) // remove first, so it gets added at the end
            orderedTagIds.append(recentTagId)
        }
        // keep last 10 at most
        if orderedTagIds.count > 10 {
            orderedTagIds.removeFirst(orderedTagIds.count - 10)
        }
        // store in user defaults for given project key
        defaults.set(orderedTagIds.elements, forKey: recentTagsKey(forProjectId: projectId))
    }

    var annotationEnabled: Bool {
        didSet {
            defaults.set(annotationEnabled, forKey: Keys.annotationEnabled)
        }
    }

    var multiPhotoSessionEnabled: Bool {
        didSet {
            defaults.set(multiPhotoSessionEnabled, forKey: Keys.multiPhotoSessionEnabled)
        }
    }

    var moreUpdatesInTheFeed: Bool {
        didSet {
            defaults.set(moreUpdatesInTheFeed, forKey: Keys.moreUpdatesInTheFeed)
        }
    }

    /// remember the last option selected by user when creating a new collaboration in the photo flow
    var lastPinTypeOption: PinTypeOption? {
        get {
            guard let rawValue = defaults.string(forKey: Keys.lastPinTypeOption)
            else { return nil }
            return PinTypeOption.allCases.first { $0.rawValue == rawValue }
        }
        set {
            if let option = newValue {
                defaults.set(option.rawValue, forKey: Keys.lastPinTypeOption)
            } else {
                defaults.removeObject(forKey: Keys.lastPinTypeOption)
            }
        }
    }

    /// stores the last Firebase Cloud Messaging Token
    var lastFCMToken: String? {
        didSet {
            if let lastFCMToken {
                defaults.set(lastFCMToken, forKey: Keys.lastFCMToken)
            } else {
                defaults.removeObject(forKey: Keys.lastFCMToken)
            }
        }
    }

    /// construct key used for storing canvas filters for given project
    private func canvasFiltersKey(forProjectId projectId: String) -> String {
        Keys.canvasFiltersPrefix + projectId
    }

    /// Returns the canvas filters for given project or default CanvasFilters if not set yet
    func canvasFilters(forModel model: ProjectModel) -> CollaborationFilters {
        guard let canvasFiltersString = defaults
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

    func setCanvasFilters(_ canvasFilters: CollaborationFilters, forProjectId projectId: String) {
        do {
            let jsonEncoder = JSONEncoder()
            let canvasFiltersData = try jsonEncoder.encode(canvasFilters)
            let canvasFiltersString = try String(data: canvasFiltersData, encoding: .utf8)
                .or(error: "Failed to create String from canvas filters data")
            defaults.set(canvasFiltersString, forKey: canvasFiltersKey(forProjectId: projectId))
        } catch {
            Logger.settings.error("Failed to save canvas filters: \(error)")
        }
    }

    /// construct key used for storing tasks filters for given project
    private func taskListFiltersKey(forProjectId projectId: String) -> String {
        Keys.taskListFiltersPrefix + projectId
    }

    /// Returns the tasks filters for given project or default TaskListFilters if not set yet
    func taskListFilters(forModel model: ProjectModel) -> CollaborationFilters {
        guard let taskListFiltersString = defaults
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

    func setTaskListFilters(_ filters: CollaborationFilters, forProjectId projectId: String) {
        do {
            let jsonEncoder = JSONEncoder()
            let filtersData = try jsonEncoder.encode(filters)
            let filtersString = try String(data: filtersData, encoding: .utf8)
                .or(error: "Failed to create String from task list filters data")
            defaults.set(filtersString, forKey: taskListFiltersKey(forProjectId: projectId))
        } catch {
            Logger.settings.error("Failed to save task list filters: \(error)")
        }
    }

    var cardOnboardingComplete: Bool {
        didSet {
            defaults.set(cardOnboardingComplete, forKey: Keys.cardOnboardingComplete)
        }
    }
    var canvasSelectorOnboardingComplete: Bool {
        didSet {
            defaults.set(canvasSelectorOnboardingComplete, forKey: Keys.canvasSelectorOnboardingComplete)
        }
    }
    
    var canvasFiltersOnboardingComplete: Bool {
        didSet {
            defaults.set(canvasFiltersOnboardingComplete, forKey: Keys.canvasFiltersOnboardingComplete)
        }

    }

    /// Reset onboarding user defaults, so onboarding animation can be tested again (for dev/testing purposes only)
    func resetOnboarding() {
        cardOnboardingComplete = false
        canvasSelectorOnboardingComplete = false
        canvasFiltersOnboardingComplete = false
    }

    /// construct key used for storing last copied pin ids for given project
    private func lastCopiedPinsKey(forProjectId projectId: String) -> String {
        Keys.lastCopiedPinsPrefix + projectId
    }

    /// Returns the last copied pin ids for given project. The most recently copied pin id is at the beginning of the array
    func lastCopiedPins(forProjectId projectId: String) -> [String] {
        defaults.array(forKey: lastCopiedPinsKey(forProjectId: projectId)) as? [String] ?? []
    }

    /// adds given task id to last copied pin ids for given project
    /// If pin id exist in recent pin ids it will be reinserted at the beginning (so it's "more recent")
    func addLastCopiedPin(_ pinId: String, forProjectId projectId: String) {
        var orderedPinIds = OrderedSet(lastCopiedPins(forProjectId: projectId))
        orderedPinIds.remove(pinId) // remove, so it gets added at the beginning
        orderedPinIds.insert(pinId, at: 0)
        // store in user defaults
        defaults.set(
            orderedPinIds.elements,
            forKey: lastCopiedPinsKey(forProjectId: projectId)
        )
    }

    init(userId: String) {
        defaults = UserDefaults.forUser(userId)

        defaults.register(defaults: [
            Keys.annotationEnabled: true,
            Keys.multiPhotoSessionEnabled: true,
            Keys.moreUpdatesInTheFeed: false,
            Keys.cardOnboardingComplete: false,
        ])

        lastPresentedOrganizationIds = defaults.stringArray(forKey: Keys.lastPresentedOrganizationIds)
        lastOpenOrganizationId = defaults.string(forKey: Keys.lastOpenOrganizationId)
        annotationEnabled = defaults.bool(forKey: Keys.annotationEnabled)
        multiPhotoSessionEnabled = defaults.bool(forKey: Keys.multiPhotoSessionEnabled)
        moreUpdatesInTheFeed = defaults.bool(forKey: Keys.moreUpdatesInTheFeed)
        lastFCMToken = defaults.string(forKey: Keys.lastFCMToken)
        cardOnboardingComplete = defaults.bool(forKey: Keys.cardOnboardingComplete)
        canvasSelectorOnboardingComplete = defaults.bool(forKey: Keys.canvasSelectorOnboardingComplete)
        canvasFiltersOnboardingComplete = defaults.bool(forKey: Keys.canvasFiltersOnboardingComplete)
    }
}
