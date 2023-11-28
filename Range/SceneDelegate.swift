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

    var authenticatedUserListenerHandle: AuthStateDidChangeListenerHandle?

    func scene(_ scene: UIScene, willConnectTo _: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions)
    {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let windowScene = (scene as? UIWindowScene) else { return }
        setupWindow(windowScene: windowScene)

        Task { @MainActor in

            // check whether user is authenticated
            if let user = Auth.auth().currentUser {
                do {
                    // reload the user to update the email verification
                    try await user.reload()
                } catch {
                    // don't sign out on error while reloading the user, this might just mean that we're offline
                    Logger.auth.warning("Error while reloading the user: \(error)")
                }
                do {
                    let userId = try await user._getUserId()
                    if user.isEmailVerified {
                        await self.startMainFlow(forUser: userId, newlySignedIn: false)
                    } else {
                        showAuth()
                    }
                } catch {
                    self.showAuth()
                }
            } else {
                showAuth()
            }

            // do the auth action
            if let activity = connectionOptions.userActivities.first,
               activity.activityType == NSUserActivityTypeBrowsingWeb
            {
                await handleAuthAction(activity)
            }
        }
    }

    func scene(_: UIScene, continue activity: NSUserActivity) {
        Task { @MainActor in
            await handleAuthAction(activity)
        }
    }

    /// Handles the auth actions confirmations (resetPassword, recoverEmail, verifyEmail) by parsing the link tapped by user,
    /// extracting the mode and oobCode and applying the code in Firebase Auth
    /// It is assumed that auth actions have url: "range_domain/actionCode"
    @MainActor
    func handleAuthAction(_ activity: NSUserActivity) async {
        // a map where keys are modes constants provided by Firebase auth and values are the strings
        // used for iOS messaging
        let modes = [
            "resetPassword": "Password reset",
            "recoverEmail": "Email recovery",
            "verifyEmail": "Email verification",
        ]

        guard activity.activityType == NSUserActivityTypeBrowsingWeb,
              let incomingURL = activity.webpageURL,
              let components = NSURLComponents(url: incomingURL, resolvingAgainstBaseURL: true)
        else { return }

        guard components.path == "/actioncode", let params = components.queryItems,
              let mode = params.first(where: { $0.name == "mode" })?.value,
              let oobCode = params.first(where: { $0.name == "oobCode" })?.value
        else { return }

        guard let modeName = modes[mode] else {
            Logger.auth.error("Unsupported auth auction: \(mode)")
            return
        }

        if mode == "resetPassword" {
            // reset password shows a screen and only then applies the code
            if let authFlow = window?.rootViewController as? AuthFlowController {
                // auth flow is showing, present the reset password
                authFlow.startResetPassword(oobCode)
            } else {
                // sign out and start auth
                await onSignedOut()
                guard let authFlow = window?.rootViewController as? AuthFlowController else { return }
                authFlow.startResetPassword(oobCode)
            }
        } else {
            do {
                try await Auth.auth().applyActionCode(oobCode)
                if let user = Auth.auth().currentUser {
                    user.getIDTokenForcingRefresh(true)
                }
                ToastWindow.shared.showSuccess(text: "\(modeName) succeeded")
            } catch {
                Logger.auth.error("Error applying auth action \(mode): \(error)")
                let message = error._messageForAuthError()
                ToastWindow.shared.showError(text: "\(modeName) failed. \(message)")
            }
        }
    }

    /// Initiate the main app window
    private func setupWindow(windowScene: UIWindowScene) {
        #if DEBUG
            // use DebugWindow in DEBUG mode (= running from Xcode) and only for environments for
            // which ShowDebugOptions is true (excluding staging and production)
            if AppConfiguration.showDebugOptions {
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
        let authFlowController = createAuthFlowController()
        window!.rootViewController = authFlowController
        window!.makeKeyAndVisible()

        ToastWindow.shared.showForKeyWindow(window!)

        authFlowController.start()
    }

    private func createAuthFlowController() -> AuthFlowController {
        AuthFlowController { [weak self] userId in
            Analytics.logEvent(AnalyticsEventLogin, parameters: [AnalyticsParameterMethod: "email"])
            Task { @MainActor in
                await self?.startMainFlow(forUser: userId, newlySignedIn: true)
            }
        }
    }

    /// Show the main flow for the app (which currently is the projects listing)
    /// - Parameters:
    ///    - userId: Firestore user id
    ///    - newlySignedIn: true if main flow is starting after user went through authentication (and false if user was already authenticated when the app started)
    @MainActor
    private func startMainFlow(forUser userId: String, newlySignedIn: Bool) async {
        observeAuthenticatedUser()
        Analytics.setUserID(userId)
        SentrySDK.setUser(Sentry.User(userId: userId))
        await showProjects(forUserId: userId, newlySignedIn: newlySignedIn)
    }

    private func observeAuthenticatedUser() {
        authenticatedUserListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            if user == nil {
                Logger.auth.info("user (no longer) authenticated")
                self?.onSignedOut()
            }
        }
    }

    @MainActor
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
            Logger.firebase.error("Error loading projects: \(error.localizedDescription, privacy: .public)")
            await onSignedOut()
            showProjectsOpenError(withMessage: error.localizedDescription)
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

    /// Convenience wrapper for the async version
    private func onSignedOut(callback: (() -> Void)? = nil) {
        Task { @MainActor in
            await onSignedOut()
            callback?()
        }
    }

    @MainActor
    private func onSignedOut() async {
        if let authenticatedUserListenerHandle = authenticatedUserListenerHandle {
            Auth.auth().removeStateDidChangeListener(authenticatedUserListenerHandle)
        }
        if let projectsFC = window?.rootViewController as? ProjectsFlowController {
            await projectsFC.stop()
        }
        do {
            try Auth.auth().signOut()
        } catch {
            Logger.firebase.error("Error while trying to sign out: \(error.localizedDescription, privacy: .public)")
        }
        SentrySDK.setUser(nil)
        analytics?.reset()
        showAuth()
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
