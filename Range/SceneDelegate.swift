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
            await self.showProjects(forUserId: userId, newlySignedIn: newlySignedIn)
        }
    }

    private func showProjects(forUserId userId: String, newlySignedIn: Bool) async {
        do {
            let projectsFlowController = try ProjectsFlowController(userId: userId, newlySignedIn: newlySignedIn)
            projectsFlowController.showTaskListOnLoginForProjectId = showTaskListOnLoginForProjectId
            showTaskListOnLoginForProjectId = nil
            projectsFlowController.onSignedOut = { [weak self] in
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
        Task { @MainActor in
            if let projectsFC = window?.rootViewController as? ProjectsFlowController {
                await projectsFC.stop()
            }
            do {
                try Auth.auth().signOut()
            } catch {
                Logger.firebase.error("Error while trying to sign out: \(error.localizedDescription, privacy: .public)")
            }
            showAuth()
        }
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
