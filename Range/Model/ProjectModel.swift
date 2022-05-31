import CoreLocation
import Foundation
import OSLog
import RealmSwift

// possible errors for ProjectModel
enum ModelError: Error {
    case summaryNotFound
}

// model error extension to provide localized descriptions of errors
extension ModelError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .summaryNotFound:
            return "Couldn't load project"
        }
    }
}

/// Responsible for configuring the Realm for given project (id).
/// Contains all the business methods for project (like adding photo, etc.)
class ProjectModel {
    /// The UUID for the project
    let projectId: String
    /// Configuration for creating realms to access this project objects
    let realmConfig: Realm.Configuration
    /// Main thread Realm
    let mainRealm: Realm

    /// Project summary, only available after `loadProject`
    private(set) var projectSummary: ProjectSummary!

    /// Initializes the model with Realm file url for given projectId (every project has a separate realm)
    /// - Parameters:
    ///     - projectId:        id of the project, will be used for the realm identifier
    ///     - inMemory:      optional parameter to create the Realm in memory (for tests), but default `false`
    /// - Warning: to be called on the Main thread
    init(projectId: String, inMemory: Bool = false) throws {
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
    }

    /// Returns `true` if the project is available for offline usage
    /// The current implementation relies on the project summary being available.
    func isProjectDownloaded() -> Bool {
        getProjectSummary() != nil
    }

    /// Initial method to be called on the model after initiating it. It checks that all required project data is available and fails otherwise.
    func loadProject() throws {
        guard let summary = getProjectSummary() else {
            throw ModelError.summaryNotFound
        }
        projectSummary = summary
    }

    /// Loads the project summary for this project.
    private func getProjectSummary() -> ProjectSummary? {
        mainRealm.object(ofType: ProjectSummary.self, forPrimaryKey: projectId)
    }
    // TODO: 44 (methods should be async?)
//    func addPhoto(_: UIImage, toCollaboration _: Collaboration) {}
//    func addPhoto(_: UIImage, at _: CLLocationCoordinate2D) {}
}
