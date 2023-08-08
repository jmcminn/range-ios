import Firebase
import FirebaseAuth
import FirebaseMessaging
import OSLog
import Sentry
import SwiftUI
import UIKit

/// Used only in debug mode
/// adds a shake gesture recognition to show a special debug screen (CTRL+CMD+z)
class DebugWindow: UIWindow {
    // Enable detection of shake motion
    override func motionEnded(_ motion: UIEvent.EventSubtype, with _: UIEvent?) {
        if motion == .motionShake {
            showDebugSettings()
        }
    }

    /// Shows view controller for debug settings
    private func showDebugSettings() {
        let debugSettingsVC = UIHostingController(
            rootView: DebugSettingsView().environmentObject(_debugSettings)
        )
        rootViewController?._topViewController().present(debugSettingsVC, animated: true)
    }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    /// if present show this project and it's task list when user signs in
    var showTaskListOnLoginForProjectId: String?

    func scene(_ scene: UIScene, willConnectTo _: UISceneSession, options _: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let windowScene = (scene as? UIWindowScene) else { return }
        setupWindow(windowScene: windowScene)

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

    /// Initiate the main app window
    private func setupWindow(windowScene: UIWindowScene) {
        #if DEBUG
            // use DebugWindow in DEBUG mode (= running from Xcode) and only for environments for
            // which ShowDebugOptions is true (excluding staging and production)
            if try! AppConfiguration.bool(for: "ShowDebugOptions") {
                window = DebugWindow(windowScene: windowScene)
            } else {
                window = UIWindow(windowScene: windowScene)
            }
        #else
            window = UIWindow(windowScene: windowScene)
        #endif
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
        SentrySDK.setUser(User(userId: userId))
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
                self.onSignedOut {
                    self.showProjectsOpenError(withMessage: error.localizedDescription)
                }
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

    private func onSignedOut(callback: (() -> Void)? = nil) {
        Task { @MainActor in
            if let projectsFC = window?.rootViewController as? ProjectsFlowController {
                await projectsFC.stop()
            }
            do {
                try Auth.auth().signOut()
            } catch {
                Logger.firebase.error("Error while trying to sign out: \(error.localizedDescription, privacy: .public)")
            }
            SentrySDK.setUser(nil)
            showAuth()
            callback?()
        }
    }

    /// Used when responding to push notifications.
    /// Opens given project (if not open yet) and shows the task list (closes other views / cancels flows when tapped)
    /// When signed out, it does it after the user signs in
    func showProjectTaskList(projectId: String, projectName: String) {
        if let projectsFlowController = window?.rootViewController as? ProjectsFlowController {
            projectsFlowController.showProjectTaskList(projectId: projectId, projectName: projectName)
        } else {
            // open when the user logs in, or when the projects flow is there (the app can be just starting)
            showTaskListOnLoginForProjectId = projectId
        }
    }
}
