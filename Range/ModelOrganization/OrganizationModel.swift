import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseFunctions
import FirebaseMessaging
import Foundation
import OSLog
import RealmSwift
import UIKit

/// Responsible for configuring the Realm for given user and organization (will sync the organization, current user participant and projects)
class OrganizationModel: NSObject, RealmModel {
    let user: User
    let organizationId: String

    /// Configuration for creating realms to access this project objects
    let realmConfig: Realm.Configuration
    /// Main thread Realm
    let mainRealm: Realm

    /// Background serial queue to perform write operations.
    let writeQueue = DispatchQueue(label: "organization-model-write-queue")
    /// Realm operating on `writeQueue`, initialized on first use
    var writeRealm: Realm!
    /// no support for updates in user model
    var localCommandsProvider: RealmModelLocalCommandsProvider?

    /// Firestore reference
    let firestore: Firestore

    /// Firestore listeners, map of firestore id => listener
    var listeners: [String: ListenerRegistration] = [:]

    /// for maintaining the ids for projects listeners
    var listenersProjectIds = Set<String>()

    /// The organization handled by this model
    private(set) var organization: Organization!
    /// Participant object for current user (user with id = `userId`)
    private(set) var currentUser: Participant!

    /// token for observing the current user in the realm
    private var userNotificationToken: NotificationToken?
    private var organizationNotificationToken: NotificationToken?

    /// Exposed for convenience, list of non placeholder ProjectSummary objects from this realm (so all user projects from this organization)
    let projects: Results<ProjectSummary>

    /// throttle fetching the task counts per status for all projects for current organization, report no more frequently than every 10 seconds
    private var updateStatusCountsThrottler: Throttler?

    init(user: User, organizationId: String) throws {
        self.user = user
        self.organizationId = organizationId
        firestore = Firestore.firestore()
        var config = Realm.Configuration.defaultConfiguration
        // v3 introduces Organization.industry
        // v4 introduces ProjectSummary.projectType
        // v5 introduces ProjectSummary.organizationId
        // v6 introduces ProjectSummary.identifier and Collaboration.identifier
        // v7 introduces ProjectSummary.statusTaskCounts
        config.schemaVersion = 7
        config.fileURL!.deleteLastPathComponent()
        config.fileURL!.appendPathComponent("user_\(user.id)_org_\(organizationId)")
        config.fileURL!.appendPathExtension("realm")
        Logger.model.info("organization realm file url: \(config.fileURL?.path ?? "")")
        config.objectTypes = [
            Organization.self,
            ProjectSummary.self,
            Location.self,
            Participant.self,
            StatusTaskCount.self,
        ]
        realmConfig = config
        mainRealm = try Realm(configuration: realmConfig)
        projects = mainRealm.objects(ProjectSummary.self).where { $0.placeholder == false }
    }

    /// Initiates the writeRealm and all objects required for the model
    @MainActor
    func start() async throws {
        try await _asyncOnQueue(queue: writeQueue) {
            self.writeRealm = try Realm(configuration: self.realmConfig, queue: self.writeQueue)
        }

        let userId = user.id
        let orgDoc = firestore.document("organizations/\(organizationId)")

        // require the current organization
        let firOrganization = try await orgDoc.getDocument(as: FirestoreOrganization.self)
        try await write { realm in
            try firOrganization.upsert(withId: self.organizationId, inRealm: realm)
        }

        // enable syncing the organization from Firestore
        listeners[organizationId] = sync(orgDoc, as: FirestoreOrganization.self)

        let orgParticipantDoc = orgDoc.collection("participants").document(userId)

        // require the current user on start
        let firParticipant = try await orgParticipantDoc.getDocument(as: FirestoreParticipant.self)
        try await write { realm in
            try firParticipant.upsert(withId: userId, inRealm: realm)
        }

        // enable syncing the participant from Firestore
        listeners[userId] = sync(orgParticipantDoc, as: FirestoreParticipant.self)

        mainRealm.refresh()
        guard let organization = getCurrentOrganization() else {
            throw ModelError.organizationNotFound
        }
        self.organization = organization
        guard let currentUser = getCurrentUser() else {
            throw ModelError.currentUserNotFound
        }
        self.currentUser = currentUser

        syncCurrentUserProjects()
        userNotificationToken = user.observe { [weak self] change in
            switch change {
            case let .change(_, properties):
                if properties.contains(where: { $0.name == "projectIds" }) {
                    self?.syncCurrentUserProjects()
                }
            case let .error(error):
                Logger.model.info("Error syncing current user: \(error.localizedDescription)")
            case .deleted:
                Logger.model.error("current user removed from server.")
            }
        }
        organizationNotificationToken = organization.observe { [weak self] _ in
            self?.syncCurrentUserProjects()
        }

        // associate user with given organization (which is called a group) in analytics
        analytics?.group(groupId: organizationId, traits: [
            "name": organization.name,
            "industry": organization.industry,
            "size": "10-50",
            "organizationRole": currentUser.organizationRole.rawValue,
        ])
    }

    /// The list of projects to sync depends on the user permissions, so based on user changes this function maintains the listeners
    /// for projects and removes the local projects that are no longer configured for user
    func syncCurrentUserProjects() {
        guard !organization.isInvalidated else { return }
        // sync projects (intersection of user and org projects)
        let newProjectIds = Set<String>(user.projectIds).intersection(organization.projectIds)

        let currentProjects = projects

        // 1. remove the projects that are no longer configured for user
        for project in currentProjects {
            if !newProjectIds.contains(project.id) {
                Logger.model.debug("user lost permissions for project \(project.id), removing.")
                try? mainRealm.write {
                    mainRealm.delete(project)
                }
            }
        }

        // 2. remove the listeners for old projects - the projects might already be gone when this function
        // is called so we separately maintain the listeners keys
        for projectId in listenersProjectIds {
            if !newProjectIds.contains(projectId) {
                listeners[projectId]?.remove()
                listeners.removeValue(forKey: projectId)
            }
        }

        // 3. start listening to new projects
        for newProjectId in newProjectIds {
            if listeners[newProjectId] == nil {
                Logger.model.debug("user has permissions for project \(newProjectId), syncing.")
                listeners[newProjectId] = sync(firestore.document("projects/\(newProjectId)"),
                                               as: FirestoreProjectSummary.self)
            }
        }

        listenersProjectIds = newProjectIds
    }

    /// Deregisters all observers.
    func stop() {
        listeners.values.forEach { $0.remove() }
        listeners.removeAll()
        userNotificationToken?.invalidate()
        organizationNotificationToken?.invalidate()
    }

    /// Loads the current organization
    private func getCurrentOrganization() -> Organization? {
        mainRealm.object(ofType: Organization.self, forPrimaryKey: organizationId)
    }

    /// Loads the current user
    private func getCurrentUser() -> Participant? {
        mainRealm.object(ofType: Participant.self, forPrimaryKey: user.id)
    }

    /// Calls the "createProject" firebase function with given parameters and return the id of the newly created project.
    @MainActor
    func createProject(_ model: CreateProjectViewModel) async throws -> String {
        guard let location = model.location else { throw "Project location not selected" }
        guard let projectType = model.typeId else { throw "Project type not selected" }
        let projectId = generateRealmId()
        let center = [location.longitude, location.latitude]
        let mapCanvasId = generateRealmId()
        let mapCanvas = ["id": mapCanvasId, "name": "Satellite Map"]
        let mapCanvasSource: [String: Any] = [
            "id": generateRealmId(),
            "canvas": mapCanvasId,
            "type": "mapbox",
            "name": "",
            "center": center,
            "zoom": 18,
            "styleUrl": "mapbox://styles/mapbox/satellite-streets-v11",
        ]
        let parameters: [String: Any?] = [
            "organizationId": organizationId,
            "projectId": projectId,
            "projectType": projectType,
            "name": model.name,
            "center": center,
            "address": model.address,
            "canvasOrder": [mapCanvasId],
            "description": model.description,
            "tagSource": model.tagSourceId,
            "canvases": [mapCanvas],
            "canvasSources": [mapCanvasSource],
        ]
        _ = try await Functions.functions(region: "us-west2")
            .httpsCallable("createProject")
            .call(parameters)

        return projectId
    }

    /// Update collaboration counts per status for all projects in this organization
    /// Throttled: First invocation is immediate, next ones no more often than every 10 seconds
    func updateStatusCounts() {
        if let updateStatusCountsThrottler {
            updateStatusCountsThrottler.throttle { [weak self] in
                self?.updateStatusCountsAndLogError()
            }
        } else {
            // no throttler yet - first invocation is immediate and create throttler for next ones
            updateStatusCountsAndLogError()
            updateStatusCountsThrottler = Throttler(throttleTime: 10)
        }
    }

    /// Private function that wraps the async one and logs error
    private func updateStatusCountsAndLogError() {
        Task {
            do {
                try await updateStatusCounts()
            } catch {
                Logger.firestore.debug("failed to update status counts: \(error, privacy: .public)")
            }
        }
    }

    /// Update collaboration counts per status for all projects in this organization
    @MainActor
    private func updateStatusCounts() async throws {
        _ = try await projects.concurrentMapOnMain { project in
            // fetch statuses for given project
            // TODO? this could be a custom getModelElements(as: ...Syncable)... so it returns [Status] given getModelElements(as: FirestoreStatusName)
            let statusNames: [Status] = try await self.firestore.collection("projects/\(project.id)/statusNames")
                .getDocuments().documents
                // map document snapshots to Statuses
                .map { try $0.data(as: FirestoreStatusName.self).modelObject(withId: $0.documentID) }
                // sort the status names, so the counts are sorted by status reversed
                .sorted(by: Status.uiSortingOrder)
                .reversed()

            // fetch task count per status
            let statusTaskCounts = try await statusNames.concurrentMapOnMain { status in
                let query = self.firestore.collection("projects/\(project.id)/collaborations")
                    .whereField("statusName", isEqualTo: status.id)
                let taskCount = try await query.count.getAggregation(source: .server).count as? Int ?? 0
                return StatusTaskCount(
                    id: status.id, name: status.name, hexColor: status.hexColor, taskCount: taskCount
                )
            }
            // save the task counts per status for given project in Realm
            try self.mainRealm.write {
                project.statusTaskCounts.removeAll()
                project.statusTaskCounts.append(objectsIn: statusTaskCounts)
            }
        }
    }
}
