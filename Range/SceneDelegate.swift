import FirebaseAuth
import OSLog
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

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
                    self.showProjects(forUser: userId)
                }
            }
        } else {
            showAuth()
        }
    }

    /// Start the auth flow for authenticating the user
    private func showAuth() {
        let authFlowController = AuthFlowController { [weak self] userId in
            self?.showProjects(forUser: userId)
        }
        window!.rootViewController = authFlowController
        window!.makeKeyAndVisible()

        authFlowController.start()
    }

    /// Show the main flow for the app (which currently is the projects listing)
    private func showProjects(forUser userId: String) {
        Task {
            do {
                let projectsFlowController = try ProjectsFlowController(userId: userId)
                projectsFlowController.onSignedOut = { [weak self, weak projectsFlowController] in
                    projectsFlowController?.stop()
                    self?.onSignedOut()
                }
                window!.rootViewController = projectsFlowController
                window!.makeKeyAndVisible()

                try await projectsFlowController.start()
            } catch {
                DispatchQueue.main.async {
                    self.onSignedOut()
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

    private func onSignedOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            Logger.firebase.error("Error while trying to sign out: \(error.localizedDescription, privacy: .public)")
        }
        showAuth()
    }
}
