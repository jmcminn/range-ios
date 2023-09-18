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
    /// no support for updates in projects model
    var localCommandsProvider: RealmModelLocalCommandsProvider?

    /// Firestore reference
    let firestore: Firestore

    /// Firestore listeners, map of firestore id => listener
    var listeners: [String: ListenerRegistration] = [:]

    private(set) var currentUser: User?
    /// token for observing the current user in the realm
    private var userNotificationToken: NotificationToken?

    /// Currently selected organization, can be nil (user can have no organizations)
    @objc private(set) dynamic var currentOrganization: Organization?
    private var organizationsNotificationToken: NotificationToken?

    init(userId: String, newlySignedIn: Bool) throws {
        self.userId = userId
        self.newlySignedIn = newlySignedIn
        firestore = Firestore.firestore()
        var config = Realm.Configuration.defaultConfiguration
        config.schemaVersion = 5
        config.fileURL!.deleteLastPathComponent()
        config.fileURL!.appendPathComponent("user_\(userId)")
        config.fileURL!.appendPathExtension("realm")
        config.migrationBlock = { migration, oldSchemaVersion in
            ProjectsModel.migrate(migration, oldSchemaVersion)
        }
        config.objectTypes = [User.self, ProjectSummary.self, Location.self, Organization.self]
        Logger.model.info("user realm file url: \(config.fileURL?.path ?? "")")
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
        let firUser = try await firestore.document("users/\(userId)").getDocument(as: FirestoreUser.self)
        try await write { realm in
            try firUser.upsert(withId: self.userId, inRealm: realm)
        }

        // 2. load current user and observe for project updates
        guard let user = mainRealm.object(ofType: User.self, forPrimaryKey: userId) else {
            throw ModelError.currentUserNotFound
        }
        userNotificationToken = user.observe { [weak self] change in
            switch change {
            case let .change(_, properties):
                if properties.contains(where: { $0.name == "projectIds" }) {
                    self?.syncCurrentUserProjects()
                }
                if properties.contains(where: { $0.name == "organizationIds" }) {
                    self?.syncCurrentUserOrganizations()
                }
            case let .error(error):
                Logger.model.info("Error syncing current user: \(error.localizedDescription)")
            case .deleted:
                Logger.model.error("current user removed from server.")
            }
        }
        currentUser = user

        // 3. enable syncing current user from Firestore
        listeners[userId] = sync(firestore.document("users/\(userId)"), as: FirestoreUser.self)

        // 4. sync the organizations that user has permissions to
        syncCurrentUserOrganizations()

        // 5. sync the projects that user has permissions to
        syncCurrentUserProjects()

        // 6. setup push notifications
        await setupNotifications()

        // 7. update currentOrganization
        updateCurrentOrganization()

        // 8. listen to changes in organizations and update current organization if needed
        organizationsNotificationToken = mainRealm.objects(Organization.self).observe { [weak self] _ in
            self?.updateCurrentOrganization()
        }
    }

    func setCurrentOrganization(_ organization: Organization) {
        if organization != currentOrganization {
            currentOrganization = organization
            UserDefaults.lastOpenOrganizationId = organization.id
        }
    }

    /// Set the currentOrganization if it's nil and user has permissions to any organizations.
    /// This can also trigger resetting the currentOrganization to nil if it was removed from user permissions
    func updateCurrentOrganization() {
        if let currentOrganization = currentOrganization, currentOrganization.isInvalidated {
            // current organization was removed, clear it
            self.currentOrganization = nil
            DispatchQueue.main.async {
                ToastWindow.shared.showWarning(text: "User removed from organization")
            }
        }

        if currentOrganization == nil {
            // try the last open organization
            if let organizationId = UserDefaults.lastOpenOrganizationId {
                currentOrganization = mainRealm.object(ofType: Organization.self, forPrimaryKey: organizationId)
            }

            // if not found then try the first organization
            if currentOrganization == nil {
                currentOrganization = mainRealm.objects(Organization.self).sorted(by: \.name).first
            }

            if let currentOrganization = currentOrganization {
                UserDefaults.lastOpenOrganizationId = currentOrganization.id
            }
        }
    }

    /// The list of organizations to sync depends on the user permissions, so based on user changes this function maintains the listeners
    /// for organizations and removes the local organizations that are no longer configured for user
    func syncCurrentUserOrganizations() {
        guard let user = currentUser else { return }

        let newOrgIds = Set<String>(user.organizationIds)

        let currentOrgs = mainRealm.objects(Organization.self)

        // 1. remove the organizations that are no longer configured for user
        for org in currentOrgs {
            if !newOrgIds.contains(org.id) {
                Logger.model.debug("user lost permissions for organizations \(org.id), removing.")
                listeners[org.id]?.remove()
                listeners.removeValue(forKey: org.id)
                try? mainRealm.write {
                    mainRealm.delete(org)
                }
            }
        }

        // 2. start listening to new orgs
        for newOrgId in newOrgIds {
            if listeners[newOrgId] == nil {
                Logger.model.debug("user has permissions for organization \(newOrgId), syncing.")
                listeners[newOrgId] = sync(firestore.document("organizations/\(newOrgId)"),
                                           as: FirestoreOrganization.self)
            }
        }
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
                listeners[newProjectId] = sync(firestore.document("projects/\(newProjectId)"),
                                               as: FirestoreProjectSummary.self)
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
        organizationsNotificationToken?.invalidate()
        organizationsNotificationToken = nil
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

// MARK: current user management

extension ProjectsModel {
    /// Updates the current user data in Firestore.
    /// This is an online action only, applied directly in Firestore.
    @MainActor
    func updateUserData(firstName: String, lastName: String, jobTitle: String) async throws {
        guard let user = currentUser else { return }

        let userRef = firestore.document("users/\(user.id)")
        _ = try await firestore.runTransaction { tx, _ in
            tx.updateData([
                "firstName": firstName,
                "lastName": lastName,
                "role": jobTitle,
            ], forDocument: userRef)
        }
    }
}
