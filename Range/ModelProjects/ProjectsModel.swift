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

    private let newlySignedIn: Bool

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

    init(userId: String, newlySignedIn: Bool) throws {
        self.userId = userId
        self.newlySignedIn = newlySignedIn
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

        // 5. setup push notifications
        await setupNotifications()
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

    /// Request authorization for notifications, update the fcm token and listen for token changes
    private func setupNotifications() async {
        if newlySignedIn {
            /// clear the previous token if not cleared yet (so this newly signed in user gets a fresh new token)
            do {
                try await Messaging.messaging().deleteToken()
            } catch {
                Logger.pushNotifications.debug("Failed to delete FCM token: \(error)")
            }
        }

        // receive fcm token updates
        Messaging.messaging().delegate = self

        do {
            try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            await UIApplication.shared.registerForRemoteNotifications()
            await refreshFCMToken()
        } catch {
            Logger.pushNotifications.error("Failed to requestAuthorization: \(error)")
        }
    }

    private func tearDownNotifications() async throws {
        // 1. Stop receiving the notifications when signed out (the token is being invalidated on sign out
        // but it will not work if user is offline, so there might still be a valid fcm token
        // after the user has signed out)
        await UIApplication.shared.unregisterForRemoteNotifications()
        // 2. Delete the FCM token from Firebase, when it succeeds the push notifications sent to
        // this token will fail. This will fail if user is offline (so notifications sent using this
        // token will still be delivered to this device, even after sign out)
        do {
            try await Messaging.messaging().deleteToken()
        } catch {
            Logger.pushNotifications.debug("Failed to delete FCM token: \(error)")
        }
        // 3. Remove the token from Firestore (try to cleanup so the server side does not even attempt
        // to send notifications to this device)
        await updateFCMToken(nil)
    }

    /// Deregisters all observers.
    /// Will be called on deinit
    func stop() async throws {
        userNotificationToken?.invalidate()
        userNotificationToken = nil
        listeners.values.forEach { $0.remove() }
        listeners.removeAll()
        try await tearDownNotifications()
    }

    @MainActor
    private func refreshFCMToken() async {
        do {
            let fcmToken = try await Messaging.messaging().token()
            Logger.pushNotifications.info("FCM token: \(fcmToken)")
            await updateFCMToken(fcmToken)
        } catch {
            Logger.pushNotifications.debug("Failed to obtain FCM token: \(error)")
        }
    }

    /// Updates fcm token in Firestore
    /// It adds a new token if provided
    /// If the token is different than a previous token (stored in UserDefaults.lastFCMToken) then the previous token is removed from
    /// Firestore (so the server side doesn't send push notifications to invalid tokens)
    @MainActor
    func updateFCMToken(_ token: String?) async {
        guard let user = currentUser else { return }

        let previousFCMToken = UserDefaults.lastFCMToken
        guard previousFCMToken != token else { return }

        let userRef = firestore.document("users/\(user.id)")
        do {
            _ = try await firestore.runTransaction { tx, errorPointer in
                do {
                    let userDoc = try tx.getDocument(userRef)
                    var newTokens: [String] = userDoc.data()?["fcmTokens"] as? [String] ?? []

                    if let previousFCMToken = previousFCMToken {
                        // remove previous token
                        newTokens.removeAll { $0 == previousFCMToken }
                    }
                    if let token = token, !newTokens.contains(token) {
                        // add new token
                        newTokens.append(token)
                    }
                    tx.updateData(["fcmTokens": newTokens], forDocument: userRef)
                } catch let error as NSError {
                    errorPointer?.pointee = error
                }
                return true
            }
        } catch {
            Logger.firestore.debug("update FCM token failed: \(error.localizedDescription)")
        }
        UserDefaults.lastFCMToken = token
    }
}

extension ProjectsModel: MessagingDelegate {
    /// Note: This callback is fired at each app startup and whenever a new token is generated.
    func messaging(_: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else { return }
        Logger.pushNotifications.debug("didReceiveRegistrationToken: \(fcmToken)")
        Task { @MainActor in
            await updateFCMToken(fcmToken)
        }
    }
}
