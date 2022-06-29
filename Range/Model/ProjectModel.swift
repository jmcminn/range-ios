import CoreLocation
import Foundation
import Kingfisher
import OSLog
import RealmSwift
import UIKit

// possible errors for ProjectModel
enum ModelError: Error {
    case summaryNotFound
    case currentUserNotFound
    case canvasNotFound
    case geometryNotFound
    case featureNotFound
    case collaborationNotFound
    case statusNotFound
}

// model error extension to provide localized descriptions of errors
extension ModelError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .summaryNotFound:
            return "Couldn't load project"
        case .currentUserNotFound:
            return "Couldn't load user data"
        case .canvasNotFound:
            return "Canvas not found"
        case .geometryNotFound:
            return "Geometry not found"
        case .featureNotFound:
            return "Feature not found"
        case .collaborationNotFound:
            return "Collaboration not found"
        case .statusNotFound:
            return "Status not found"
        }
    }
}

protocol ProjectModelWriter: AnyObject {
    func write(_ closure: @escaping (Realm) throws -> Void) async throws
}

/// To be implemented by the backend synchronizer to update the data on the backend.
/// Currently implemented by `ProjectModelFirebaseSync`
protocol ProjectModelRemoteUpdater: AnyObject {
    // TODO: 44 not needed if Command class works (can be stored)
    func runActionCommand(_: ActionCommand, writer: ProjectModelWriter) async throws
    // TODO: 44 document
    func runCommand(_: Command, writer: ProjectModelWriter) async throws -> Bool
}

/// Responsible for configuring the Realm for given project (id).
/// Contains all the business methods for project (like adding photo, etc.)
class ProjectModel {
    /// The Range id of the current logged in user
    let userId: String
    /// The UUID for the project
    let projectId: String
    /// Configuration for creating realms to access this project objects
    let realmConfig: Realm.Configuration
    /// Main thread Realm
    let mainRealm: Realm

    /// Project summary, only available after `loadProject`
    private(set) var projectSummary: ProjectSummary!
    /// Participant object for current user (user with id = `userId`)
    private(set) var currentUser: Participant!

    /// Background serial queue to perform write operations.
    let writeQueue = DispatchQueue(label: "model-write-queue")
    /// Realm operating on `writeQueue`, initialized on first use
    var writeRealm: Realm?

    // TODO: 44 revisit the disk cache storage - how does it play with using cache later for
    // downloaded images???
    /// Using Kingfisher image cache for local images store (configured disk cache to never expire)
    let localPhotosCache = ImageCache(name: "local-photos")

    weak var remoteUpdater: ProjectModelRemoteUpdater?

    /// Initializes the model with Realm file url for given projectId (every project has a separate realm)
    /// - Parameters:
    ///     - userId:           Range id of the logged in user
    ///     - projectId:        id of the project, will be used for the realm identifier
    ///     - inMemory:      optional parameter to create the Realm in memory (for tests), but default `false`
    /// - Warning: to be called on the Main thread
    init(userId: String, projectId: String, inMemory: Bool = false) throws {
        self.userId = userId
        self.projectId = projectId.lowercased()
        var config = Realm.Configuration.defaultConfiguration
        // TODO: 44 for now we just remove the Realm and resync if migration needed...
        config.deleteRealmIfMigrationNeeded = true
        if inMemory {
            config.inMemoryIdentifier = self.projectId
        } else {
            config.fileURL!.deleteLastPathComponent()
            config.fileURL!.appendPathComponent(self.projectId)
            config.fileURL!.appendPathExtension("realm")
            Logger.model.info("project realm file url: \(config.fileURL?.path ?? "")")
        }
        realmConfig = config
        mainRealm = try Realm(configuration: realmConfig)
        localPhotosCache.diskStorage.config.expiration = .never
    }

    /// Returns `true` if the project is available for offline usage
    /// The current implementation relies on the project summary and the participant for current user being available.
    func isProjectDownloaded() -> Bool {
        getProjectSummary() != nil && getCurrentUser() != nil
    }

    /// Initial method to be called on the model after initiating it. It checks that all required project data is available and fails otherwise.
    func loadProject() throws {
        guard let summary = getProjectSummary() else {
            throw ModelError.summaryNotFound
        }
        projectSummary = summary
        guard let user = getCurrentUser() else {
            throw ModelError.currentUserNotFound
        }
        currentUser = user
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
