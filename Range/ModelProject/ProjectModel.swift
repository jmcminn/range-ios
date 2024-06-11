import CoreLocation
import Foundation
import Kingfisher
import OSLog
import RealmSwift
import UIKit

/// Responsible for configuring the Realm for given project (id).
/// Contains all the business methods for project (like adding photo, etc.)
class ProjectModel: NSObject, RealmModel {
    /// The Range id of the current logged in user
    let userId: String
    /// The UUID for the project
    let projectId: String
    /// Local files
    unowned let localFiles: LocalFiles
    /// Media cache
    unowned let mediaCache: MediaCache
    let userPreferences: UserPreferences
    /// global pending uploads
    unowned let pendingUploadsModel: PendingUploadsModel
    /// global pending actions
    unowned let pendingActionsModel: PendingActionsModel
    /// Configuration for creating realms to access this project objects
    let realmConfig: Realm.Configuration
    /// Main thread Realm
    let mainRealm: Realm

    /// Project summary, only available after `loadProject`
    private(set) var projectSummary: ProjectSummary!
    /// Participant object for current user (user with id = `userId`)
    private(set) var currentUser: Participant!

    /// The current canvas for the project, @objc dynamic so it can be observed
    @objc private(set) dynamic var currentCanvas: Canvas!

    /// Background serial queue to perform write operations.
    let writeQueue = DispatchQueue(label: "model-write-queue")
    /// Realm operating on `writeQueue`, initialized on first use
    private(set) var writeRealm: Realm!
    /// provides LocalCommands from PendingActionsModel
    var localCommandsProvider: RealmModelLocalCommandsProvider?

    /// Initializes the model with Realm file url for given projectId (every project has a separate realm)
    /// - Parameters:
    ///     - userId:           Range id of the logged in user
    ///     - projectId:        id of the project, will be used for the realm identifier
    ///     - images:          access to images caches
    ///     - pendingUploadsModel:       keep unowned reference to the global pending uploads
    ///     - inMemory:      optional parameter to create the Realm in memory (for tests), but default `false`
    /// - Warning: to be called on the Main thread
    init(
        userId: String,
        projectId: String,
        localFiles: LocalFiles,
        mediaCache: MediaCache,
        userPreferences: UserPreferences,
        pendingUploadsModel: PendingUploadsModel,
        pendingActionsModel: PendingActionsModel,
        inMemory: Bool = false
    ) throws {
        self.userId = userId
        self.projectId = projectId.lowercased()
        self.localFiles = localFiles
        self.mediaCache = mediaCache
        self.userPreferences = userPreferences
        self.pendingUploadsModel = pendingUploadsModel
        self.pendingActionsModel = pendingActionsModel
        var config = Realm.Configuration.defaultConfiguration
        if inMemory {
            config.inMemoryIdentifier = self.projectId
        } else {
            config.schemaVersion = 23
            config.fileURL!.deleteLastPathComponent()
            config.fileURL!.appendPathComponent("user_\(userId)_project_\(projectId)")
            config.fileURL!.appendPathExtension("realm")
            config.migrationBlock = { migration, oldSchemaVersion in
                ProjectModel.migrate(migration, oldSchemaVersion)
            }
            Logger.model.info("project realm file url: \(config.fileURL?.path ?? "")")
        }
        config.objectTypes = [
            ProjectSummary.self, Status.self, Tag.self, Participant.self,
            Canvas.self, CanvasSource.self, Geometry.self, Feature.self, Collaboration.self, Comment.self,
            Update.self, Upload.self, Location.self, StatusTaskCount.self,
        ]
        realmConfig = config
        mainRealm = try Realm(configuration: realmConfig)
        super.init()

        localCommandsProvider = { [weak self] (targetId: String) -> [LocalCommand] in
            guard let self = self else { return [] }
            return self.pendingActionsModel.getLocalCommands(forProjectId: self.projectId, targetObjectId: targetId)
        }
    }

    /// Initiates the writeRealm
    func start() async throws {
        try await _asyncOnQueue(queue: writeQueue) {
            self.writeRealm = try Realm(configuration: self.realmConfig, queue: self.writeQueue)
        }
    }

    /// Initial method to be called on the model after initiating it. It checks that all required project data is available and fails otherwise.
    ///
    /// - Parameters:
    ///     - initialCanvasId: id of the canvas to set as currentCanvas, if not provided then load the 1st canvas in a project
    func loadProject(initialCanvasId: String?) throws {
        guard let summary = getProjectSummary() else {
            throw ModelError.summaryNotFound
        }
        projectSummary = summary
        guard let user = getCurrentUser() else {
            throw ModelError.currentUserNotFound
        }
        currentUser = user
        if let initialCanvasId = initialCanvasId {
            guard let initialCanvas = mainRealm.object(ofType: Canvas.self, forPrimaryKey: initialCanvasId) else {
                throw ModelError.canvasNotFound
            }
            try setCurrentCanvas(initialCanvas)
        } else {
            guard let firstCanvas = sortedCanvases.first else {
                throw ModelError.canvasNotFound
            }
            try setCurrentCanvas(firstCanvas)
        }
    }

    /// Sorts canvases by projectSummary.canvasOrder. If canvas id is not in canvasOrder it'll be at the end (sorted by name).
    /// So in case canvasOrder is not there it'll effectively sort canvases by name
    private func canvasOrderBasedSortingOrder(_ c1: Canvas, _ c2: Canvas) -> Bool {
        let c1Index = projectSummary.canvasOrder.firstIndex(of: c1.id)
        let c2Index = projectSummary.canvasOrder.firstIndex(of: c2.id)
        if let c1Index = c1Index, let c2Index = c2Index {
            return c1Index < c2Index
        } else if c1Index == nil, c2Index == nil {
            // both not in canvasOrder? sort by name
            return c1.name.compare(c2.name, options: .caseInsensitive).rawValue < 0
        } else if c2Index == nil {
            // whatever is not in canvasOrder goes at the end of sorted canvases
            return true
        }
        return false
    }

    var sortedCanvases: [Canvas] {
        [Canvas](mainRealm.objects(Canvas.self).where { $0.placeholder == false })
            .filter { !$0.canvasSources.isEmpty }
            .sorted(by: canvasOrderBasedSortingOrder)
    }

    /// Updates current canvas and loads the last open source for it (or the first source if it wasn't opened yet)
    func setCurrentCanvas(_ canvas: Canvas) throws {
        // only if it's a different canvas
        guard currentCanvas == nil || currentCanvas.id != canvas.id else { return }
        guard !canvas.canvasSources.isEmpty else { throw ModelError.canvasSourceNotFound }

        // preselect the last canvas source for this canvas or use the first one otherwise
        if let initialCanvasSourceId = userPreferences.lastOpenCanvasSourceId(forCanvasId: canvas.id),
           let initialCanvasSource = canvas.canvasSources.first(where: { $0.id == initialCanvasSourceId })
        {
            canvas.currentCanvasSource = initialCanvasSource
        }
        // If no last canvas then select the first one
        if canvas.currentCanvasSource == nil {
            canvas.currentCanvasSource = canvas.canvasSources.sorted(by: CanvasSource.sortingOrder).first
        }
        // if still no canvas then it's an error (canvas has no sources)
        if canvas.currentCanvasSource == nil {
            throw ModelError.canvasSourceNotFound
        }

        // set currentCanvas after its currentCanvasSource is set, so we have fully set object before
        // notifying the listeners
        currentCanvas = canvas
        userPreferences.setLastOpenCanvasId(currentCanvas.id, forProjectId: projectId)
    }

    /// Loads the project summary for this project.
    private func getProjectSummary() -> ProjectSummary? {
        mainRealm.object(ofType: ProjectSummary.self, forPrimaryKey: projectId)
    }

    /// Loads the current user
    private func getCurrentUser() -> Participant? {
        mainRealm.object(ofType: Participant.self, forPrimaryKey: userId)
    }

    /// gets the center of canvas source if it's the map, otherwise (for pdfs) returns the center of project
    var currentCanvasSourceCenter: CLLocationCoordinate2D {
        switch currentCanvas.currentCanvasSource.data {
        case .pdf: return projectSummary.center
        case let .mapbox(mapboxData): return mapboxData.center.decodedCoordinates
        case let .droneDeploy(droneDeployData): return droneDeployData.center.decodedCoordinates
        }
    }

    /// Checks if given location is in range of current canvas source.
    /// Calculates the distance between given location and currentCanvasSourceCenter and checks if it's smaller than a given hardcoded value.
    func isLocationInCurrentCanvasSourceRange(_ location: CLLocationCoordinate2D) -> Bool {
        location.distance(to: currentCanvasSourceCenter) <= 1000
    }

    func collaborationIdentifier(_ collaboration: Collaboration) -> String? {
        guard let projectIdentifier = projectSummary.identifier,
              let collaborationIdentifier = collaboration.identifier else { return nil }
        return "\(projectIdentifier)-\(collaborationIdentifier)"
    }

    /// Correlated uploads, *includes this Upload* so it's always an array of length at least = 1
    func correlatedUploads(_ upload: Upload) -> Results<Upload> {
        mainRealm.objects(Upload.self)
            .where { $0.correlationId == upload.correlationId }
            .sorted(by: \.timestamp)
    }
}
