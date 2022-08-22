import CoreLocation
import FirebaseAuth
import OSLog
import PDFKit
import RealmSwift
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    var images: Images?
    var projectModel: ProjectModel?
    var pendingUploadsModel: FirebasePendingUploadsModel?
    var projectModelFirestoreSync: ProjectModelFirestoreSync?

    var projectFC: ProjectFlowController?

    func scene(
        _ scene: UIScene,
        willConnectTo _: UISceneSession,
        options _: UIScene.ConnectionOptions
    ) {
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
                    self.loadAndShowProject(userId: userId)
                }
            }
        } else {
            showAuth()
        }
    }

    /// Start the auth flow for authenticating the user
    private func showAuth() {
        let authFlowController = AuthFlowController { [weak self] userId in
            self?.loadAndShowProject(userId: userId, initializeWindow: false)
        }
        window!.rootViewController = authFlowController
        window!.makeKeyAndVisible()

        authFlowController.start()
    }

    /// Loads and shows the project or displays the alert view if loading project failed
    /// - Parameters:
    ///     - initializeWindow - whether the window needs to be initialized (was never made key and visible) or is there a view controller already there (like showing project from the auth flow)
    private func loadAndShowProject(userId: String, initializeWindow: Bool = true) {
        if initializeWindow {
            window!.rootViewController = LaunchScreenViewController()
            window!.makeKeyAndVisible()
        }
        // TODO: projectId hardcoded for now
        let projectId = "474503d1-1adc-4268-88fe-2a797148f16d"

        Task {
            do {
                try await createProjectModel(userId: userId, projectId: projectId)
                try self.showProject()
            } catch {
                Logger.model.error("loading project failed: \(error.localizedDescription, privacy: .public)")
                signOut()
                showProjectOpenError(withMessage: error.localizedDescription)
            }
        }
    }

    /// Present alert controller with project loading error message
    private func showProjectOpenError(withMessage message: String) {
        let alertController = UIAlertController(
            title: "Loading project failed",
            message: message,
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Ok", style: .cancel) { _ in
            alertController.dismiss(animated: true)
        })
        if let viewController = window?.rootViewController {
            viewController.present(alertController, animated: true)
        } else {
            // TODO: show some (project) loading view controller and present the alert from it?
            window!.rootViewController = LaunchScreenViewController()
            window!.makeKeyAndVisible()
            window!.rootViewController!.present(alertController, animated: true)
        }
    }

    /// Loads project
    /// This can throw if project model cannot be loaded
    ///
    /// - Parameters:
    ///     - userId: range id of the logged in user
    ///     - projectId: id of the project
    /// - Returns: loaded ProjectModel
    private func createProjectModel(userId: String, projectId: String) async throws {
        let _images = Images(projectId: projectId)
        let _pendingUploadsModel = try FirebasePendingUploadsModel(images: _images)
        try await _pendingUploadsModel.start()

        let _projectModel = try ProjectModel(
            userId: userId,
            projectId: projectId,
            images: _images,
            pendingUploadsModel: _pendingUploadsModel
        )

        let _projectModelFirestoreSync = ProjectModelFirestoreSync(model: _projectModel)
        try await _projectModelFirestoreSync.start()

        try _projectModel.loadProject()

        images = _images
        pendingUploadsModel = _pendingUploadsModel
        projectModel = _projectModel
        projectModelFirestoreSync = _projectModelFirestoreSync
    }

    /// Shows a project for current model
    private func showProject() throws {
        let projectFC = try ProjectFlowController(images: images!, model: projectModel!)
        projectFC.onSignOut = { [weak self] in
            self?.signOut()
        }
        window!.rootViewController = projectFC
        window!.makeKeyAndVisible()

        projectFC.start()
        self.projectFC = projectFC
    }

    private func signOut() {
        projectFC?.stop()
        projectFC = nil
        pendingUploadsModel?.stop()
        pendingUploadsModel = nil
        projectModel = nil
        projectModelFirestoreSync = nil
        images = nil
        do {
            try Auth.auth().signOut()
        } catch {
            Logger.firebase.error("Error while trying to sign out: \(error.localizedDescription, privacy: .public)")
        }
        showAuth()
        // TODO: delete all realm files on sign in when the user is different from the previous one?
        // We need to delete all projects, so Realm.deleteFiles(for: config) is not enough, manual removal
        // like describe here https://github.com/realm/realm-swift/issues/4625 needed
    }

    func sceneDidDisconnect(_: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }
}
