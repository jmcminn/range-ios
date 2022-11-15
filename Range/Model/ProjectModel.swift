import CoreLocation
import Foundation
import Kingfisher
import OSLog
import RealmSwift
import UIKit

// possible errors for ProjectModel
enum ModelError: Error, Equatable {
    case canvasNotFound
    case collaborationNotFound
    case commentNotFound
    case currentUserNotFound
    case featureNotFound
    case fieldNotSupported(_ field: String)
    case fileTypeNotSupported(_ type: String)
    case geometryNotFound
    case malformedUrl(_ url: String)
    case statusNotFound
    case summaryNotFound
    case uploadNotFound
    case userNotFound
}

// model error extension to provide localized descriptions of errors
extension ModelError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .canvasNotFound: return "Canvas not found"
        case .collaborationNotFound: return "Collaboration not found"
        case .commentNotFound: return "Comment not found"
        case .currentUserNotFound: return "Couldn't load user data"
        case .featureNotFound: return "Feature not found"
        case let .fieldNotSupported(field): return "\(field) field not supported"
        case let .fileTypeNotSupported(type): return "\(type) fileType not supported"
        case .geometryNotFound: return "Geometry not found"
        case let .malformedUrl(url): return "Malformed URL: \(url)"
        case .statusNotFound: return "Status not found"
        case .summaryNotFound: return "Couldn't load project"
        case .uploadNotFound: return "Upload not found"
        case .userNotFound: return "User not found"
        }
    }
}

/// Responsible for configuring the Realm for given project (id).
/// Contains all the business methods for project (like adding photo, etc.)
class ProjectModel {
    /// The Range id of the current logged in user
    let userId: String
    /// The UUID for the project
    let projectId: String
    /// images...
    unowned let imageCaches: ImageCaches
    /// global pending uploads
    unowned let pendingUploadsModel: PendingUploadsModel
    /// global pending actions
    unowned let pendingActionsModel: PendingActionsModel
    /// Configuration for creating realms to access this project objects
    let realmConfig: Realm.Configuration
    /// Main thread Realm
    let mainRealm: Realm

    /// temporarily store the canvas to show (until canvas loading/selection is implemented)
    var demoCanvas: DemoCanvas!

    /// Project summary, only available after `loadProject`
    private(set) var projectSummary: ProjectSummary!
    /// Participant object for current user (user with id = `userId`)
    private(set) var currentUser: Participant!

    /// Background serial queue to perform write operations.
    let writeQueue = DispatchQueue(label: "model-write-queue")
    /// Realm operating on `writeQueue`, initialized on first use
    var writeRealm: Realm!

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
        imageCaches: ImageCaches,
        pendingUploadsModel: PendingUploadsModel,
        pendingActionsModel: PendingActionsModel,
        inMemory: Bool = false
    ) throws {
        self.userId = userId
        self.projectId = projectId.lowercased()
        self.imageCaches = imageCaches
        self.pendingUploadsModel = pendingUploadsModel
        self.pendingActionsModel = pendingActionsModel
        var config = Realm.Configuration.defaultConfiguration
        // TODO: [db-migration] for now we just remove the Realm and resync if migration needed...
        config.deleteRealmIfMigrationNeeded = true
        if inMemory {
            config.inMemoryIdentifier = self.projectId
        } else {
            config.fileURL!.deleteLastPathComponent()
            config.fileURL!.appendPathComponent(self.projectId)
            config.fileURL!.appendPathExtension("realm")
            Logger.model.info("project realm file url: \(config.fileURL?.path ?? "")")
        }
        config.objectTypes = [
            ProjectSummary.self, Status.self, Tag.self, Participant.self, PDFCanvas.self,
            Geometry.self, Feature.self, Collaboration.self, Comment.self, Update.self, Upload.self,
            Location.self,
        ]
        realmConfig = config
        mainRealm = try Realm(configuration: realmConfig)
    }

    /// Initiates the writeRealm
    func start() async throws {
        try await _asyncOnQueue(queue: writeQueue) {
            self.writeRealm = try Realm(configuration: self.realmConfig, queue: self.writeQueue)
        }
    }

    /// Initial method to be called on the model after initiating it. It checks that all required project data is available and fails otherwise.
    func loadProject(initialCanvasId: String) throws {
        guard let summary = getProjectSummary() else {
            throw ModelError.summaryNotFound
        }
        projectSummary = summary
        guard let user = getCurrentUser() else {
            throw ModelError.currentUserNotFound
        }
        currentUser = user
        guard mainRealm.object(ofType: PDFCanvas.self, forPrimaryKey: initialCanvasId) != nil else {
            throw ModelError.canvasNotFound
        }
    }

    /// Loads the project summary for this project.
    private func getProjectSummary() -> ProjectSummary? {
        mainRealm.object(ofType: ProjectSummary.self, forPrimaryKey: projectId)
    }

    /// Loads the current user
    private func getCurrentUser() -> Participant? {
        mainRealm.object(ofType: Participant.self, forPrimaryKey: userId)
    }

    /// Runs given closure on the writeQueue in the writeRealm transaction as an async function
    func write(_ closure: @escaping (Realm) throws -> Void) async throws {
        try await _asyncOnQueue(queue: writeQueue) { [self] in
            // at this point writeRealm is set or it threw an error
            try writeRealm!.write {
                try closure(writeRealm!)
            }
        }
    }
}
