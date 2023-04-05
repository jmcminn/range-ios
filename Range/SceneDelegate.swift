import Firebase
import FirebaseAuth
import FirebaseMessaging
import OSLog
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    /// if present show this project and it's task list when user signs in
    var showTaskListOnLoginForProjectId: String?

    func scene(_ scene: UIScene, willConnectTo _: UISceneSession, options _: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let windowScene = (scene as? UIWindowScene) else { return }
        window = UIWindow(windowScene: windowScene)

        // check whether user is authenticated
        if let user = Auth.auth().currentUser {
            getUserId(forUser: user) { result in
                switch result {
                case .failure:
                    self.showAuth()
                case let .success(userId):
                    self.startMainFlow(forUser: userId, newlySignedIn: false)
                }
            }
        } else {
            showAuth()
        }
    }

    /// Start the auth flow for authenticating the user
    private func showAuth() {
        let authFlowController = AuthFlowController { [weak self] userId in
            Analytics.logEvent(AnalyticsEventLogin, parameters: [AnalyticsParameterMethod: "email"])
            self?.startMainFlow(forUser: userId, newlySignedIn: true)
        }
        window!.rootViewController = authFlowController
        window!.makeKeyAndVisible()

        ToastWindow.shared.showForKeyWindow(window!)

        authFlowController.start()
    }

    /// Show the main flow for the app (which currently is the projects listing)
    /// - Parameters:
    ///    - userId: Firestore user id
    ///    - newlySignedIn: true if main flow is starting after user went through authentication (and false if user was already authenticated when the app started)
    private func startMainFlow(forUser userId: String, newlySignedIn: Bool) {
        Analytics.setUserID(userId)
        Task { @MainActor in
            if newlySignedIn {
                await self.initializePushNotifications()
            }
            await self.showProjects(forUserId: userId)
        }
    }

    private func initializePushNotifications() async {
        do {
            try await Messaging.messaging().deleteToken()
        } catch {
            Logger.pushNotifications.debug("Failed to delete FCM token: \(error)")
        }
    }

    private func showProjects(forUserId userId: String) async {
        do {
            let projectsFlowController = try ProjectsFlowController(userId: userId)
            projectsFlowController.showTaskListOnLoginForProjectId = showTaskListOnLoginForProjectId
            showTaskListOnLoginForProjectId = nil
            projectsFlowController.onSignedOut = { [weak self, weak projectsFlowController] in
                projectsFlowController?.stop()
                self?.onSignedOut()
            }
            window!.rootViewController = projectsFlowController
            window!.makeKeyAndVisible()

            ToastWindow.shared.showForKeyWindow(window!)

            try await projectsFlowController.start()
        } catch {
            DispatchQueue.main.async {
                self.onSignedOut()
                self.showProjectsOpenError(withMessage: error.localizedDescription)
            }
        }
    }

    private func showProjectsOpenError(withMessage message: String) {
        let alertController = UIAlertController(
            title: "Loading project failed",
            message: message,
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Ok", style: .cancel) { _ in })
        window!.rootViewController!.present(alertController, animated: true)
    }

    private func onSignedOut() {
        // 1. Stop receiving the notifications when signed out (the token is being invalidated on sign out
        // but it will not work if user is offline, so there might still be a valid fcm token
        // after the user has signed out)
        UIApplication.shared.unregisterForRemoteNotifications()
        // 2. Delete the FCM token from Firebase, when it succeeds the push notifications sent to
        // this token will fail. This will fail if user is offline (so notifications sent using this
        // token will still be delivered to this device, even after sign out)
        Messaging.messaging().deleteToken { error in
            if let error = error {
                Logger.pushNotifications.debug("Failed to delete FCM token: \(error)")
            }
        }
        // 3. Remove the token from Firestore (try to cleanup so the server side does not even attempt
        // to send notifications to this device.
        // TODO: 1012 remove from Firestore (this should block before calling sign out, but do not prevent signOut)

        do {
            try Auth.auth().signOut()
        } catch {
            Logger.firebase.error("Error while trying to sign out: \(error.localizedDescription, privacy: .public)")
        }
        showAuth()
    }

    /// Used when responding to push notifications.
    /// Opens given project (if not open yet) and shows the task list (closes other views / cancels flows when tapped)
    /// When signed out, it does it after the user signs in
    func showProjectTaskList(projectId: String) {
        if let projectsFlowController = window?.rootViewController as? ProjectsFlowController {
            projectsFlowController.showProjectTaskList(projectId: projectId)
        } else {
            // open when the user logs in, or when the projects flow is there (the app can be just starting)
            showTaskListOnLoginForProjectId = projectId
        }
    }
}
