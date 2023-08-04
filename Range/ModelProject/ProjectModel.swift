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
    var writeRealm: Realm!
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
        pendingUploadsModel: PendingUploadsModel,
        pendingActionsModel: PendingActionsModel,
        inMemory: Bool = false
    ) throws {
        self.userId = userId
        self.projectId = projectId.lowercased()
        self.localFiles = localFiles
        self.mediaCache = mediaCache
        self.pendingUploadsModel = pendingUploadsModel
        self.pendingActionsModel = pendingActionsModel
        var config = Realm.Configuration.defaultConfiguration
        if inMemory {
            config.inMemoryIdentifier = self.projectId
        } else {
            config.schemaVersion = 14
            config.fileURL!.deleteLastPathComponent()
            config.fileURL!.appendPathComponent(self.projectId)
            config.fileURL!.appendPathExtension("realm")
            config.migrationBlock = { migration, oldSchemaVersion in
                ProjectModel.migrate(migration, oldSchemaVersion)
            }
            Logger.model.info("project realm file url: \(config.fileURL?.path ?? "")")
        }
        config.objectTypes = [
            ProjectSummary.self, Status.self, Tag.self, Participant.self, CanvasCollection.self,
            Canvas.self, CanvasSource.self, Geometry.self, Feature.self, Collaboration.self, Comment.self,
            Update.self, Upload.self, Location.self,
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
            guard let firstCanvas = [Canvas](mainRealm.objects(Canvas.self))
                .filter({ !$0.canvasSources.isEmpty })
                .sorted(by: Canvas.sortingOrder)
                .first
            else {
                throw ModelError.canvasNotFound
            }
            try setCurrentCanvas(firstCanvas)
        }
    }

    /// Updates current canvas and loads the last open source for it (or the first source if it wasn't opened yet)
    func setCurrentCanvas(_ canvas: Canvas) throws {
        // only if it's a different canvas
        guard currentCanvas == nil || currentCanvas.id != canvas.id else { return }
        guard !canvas.canvasSources.isEmpty else { throw ModelError.canvasSourceNotFound }

        // preselect the last canvas source for this canvas or use the first one otherwise
        if let initialCanvasSourceId = UserDefaults.lastOpenCanvasSourceId(forCanvasId: canvas.id),
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
        UserDefaults.setLastOpenCanvasId(currentCanvas.id, forProjectId: projectId)
    }

    /// Loads the project summary for this project.
    private func getProjectSummary() -> ProjectSummary? {
        mainRealm.object(ofType: ProjectSummary.self, forPrimaryKey: projectId)
    }

    /// Loads the current user
    private func getCurrentUser() -> Participant? {
        mainRealm.object(ofType: Participant.self, forPrimaryKey: userId)
    }
}
