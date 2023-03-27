import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseMessaging
import Foundation
import OSLog
import RealmSwift
import UIKit

/// Responsible for configuring the Realm for all projects for given user
/// Contains all the business methods for project (like adding photo, etc.)
class ProjectsModel: NSObject, RealmModel {
    /// The Range id of the current logged in user
    let userId: String

    /// Configuration for creating realms to access this project objects
    let realmConfig: Realm.Configuration
    /// Main thread Realm
    let mainRealm: Realm

    /// Background serial queue to perform write operations.
    let writeQueue = DispatchQueue(label: "projects-model-write-queue")
    /// Realm operating on `writeQueue`, initialized on first use
    var writeRealm: Realm!

    /// Firestore reference
    let firestore: Firestore

    /// Firestore listeners, map of firestore id => listener
    var listeners: [String: ListenerRegistration] = [:]

    private(set) var currentUser: Participant?
    /// token for observing the current user in the realm
    private var userNotificationToken: NotificationToken?

    init(userId: String) throws {
        self.userId = userId
        firestore = Firestore.firestore()
        var config = Realm.Configuration.defaultConfiguration
        config.schemaVersion = 2
        config.fileURL!.deleteLastPathComponent()
        config.fileURL!.appendPathComponent("projects")
        config.fileURL!.appendPathExtension("realm")
        Logger.model.info("projects realm file url: \(config.fileURL?.path ?? "")")
        config.objectTypes = [Participant.self, ProjectSummary.self, Location.self]
        realmConfig = config
        mainRealm = try Realm(configuration: realmConfig)
    }

    deinit {
        stop()
    }

    /// Initiates the writeRealm
    @MainActor
    func start() async throws {
        try await _asyncOnQueue(queue: writeQueue) {
            self.writeRealm = try Realm(configuration: self.realmConfig, queue: self.writeQueue)
        }

        // 1. require the current user, so it can be loaded and observed
        let firUser = try await firestore.document("users/\(userId)").getDocument(as: FirestoreParticipant.self)
        try await write { realm in
            try firUser.upsert(withId: self.userId, inRealm: realm)
        }

        // 2. load current user and observe for project updates
        guard let user = mainRealm.object(ofType: Participant.self, forPrimaryKey: userId) else {
            throw ModelError.currentUserNotFound
        }
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
        currentUser = user

        // 3. enable syncing current user from Firestore
        listeners[userId] = sync(firestore.document("users/\(userId)"), as: FirestoreParticipant.self)

        // 4. sync the projects that user has permissions to
        syncCurrentUserProjects()

        // 5. Check current fcm token and update in firestore if changed
        await refreshFCMToken()
    }

    /// The list of projects to sync depends on the user permissions, so based on user changes this function maintains the listeners
    /// for projects and removes the local projects that are no longer configured for user
    func syncCurrentUserProjects() {
        guard let user = currentUser else { return }

        let newProjectIds = Set<String>(user.projectIds)

        let currentProjects = mainRealm.objects(ProjectSummary.self)

        // 1. remove the projects that are no longer configured for user
        for project in currentProjects {
            if !newProjectIds.contains(project.id) {
                Logger.model.debug("user lost permissions for project \(project.id), removing.")
                listeners[project.id]?.remove()
                listeners.removeValue(forKey: project.id)
                try? mainRealm.write {
                    mainRealm.delete(project)
                }
            }
        }

        // 2. start listening to new projects
        for newProjectId in newProjectIds {
            if listeners[newProjectId] == nil {
                Logger.model.debug("user has permissions for project \(newProjectId), syncing.")
                // we need to allow reading from cache when syncing the projects.
                // Normally reading from cache is disabled as it would overwrite any local changes
                // but project summary is not updated locally and the project summary may have
                // already been loaded by the Project model. In this case projects model will
                // not get any data when syncing until the project summary is changed.
                listeners[newProjectId] = sync(firestore.document("projects/\(newProjectId)"),
                                               as: FirestoreProjectSummary.self,
                                               allowFromCache: true)
            }
        }
    }

    /// Deregisters all observers.
    /// Will be called on deinit
    func stop() {
        userNotificationToken?.invalidate()
        userNotificationToken = nil
        listeners.values.forEach { $0.remove() }
        listeners.removeAll()
    }

    @MainActor
    private func refreshFCMToken() async {
        do {
            let fcmToken = try await Messaging.messaging().token()
            Logger.pushNotifications.info("FCM token: \(fcmToken)")
            updateFCMToken(fcmToken)

            // TODO: 1012 update if not there yet (in Firestore), remove previous (so remember previous)
            if !UIApplication.shared.isRegisteredForRemoteNotifications {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            Logger.pushNotifications.debug("Failed to obtain FCM token: \(error)")
        }
    }

    // TODO: 1012 add offline support and actions for user updates? (or is it enough to do it on app start?)
    func updateFCMToken(_ token: String) {
        guard let user = currentUser else { return }
        guard !user.fcmTokens.contains(token) else { return }

        let userRef = firestore.document("users/\(user.id)")
        firestore.runTransaction { tx, _ in
            var newTokens: [String]
            do {
                let userDoc = try tx.getDocument(userRef)
                if let tokens = userDoc.data()?["fcmTokens"] as? [String] {
                    if tokens.contains(token) { return true }
                    newTokens = tokens
                    newTokens.append(token)
                } else {
                    newTokens = [token]
                }
                tx.updateData(["fcmTokens": newTokens], forDocument: userRef)
                return true
            } catch {
                return error
            }
        } completion: { _, error in
            if let error = error {
                Logger.firestore.debug("update FCM token failed: \(error.localizedDescription)")
            }
        }
    }
}
