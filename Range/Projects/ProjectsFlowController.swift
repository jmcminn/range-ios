import Combine
import Foundation
import OSLog
import Realm
import RealmSwift
import SwiftUI
import UIKit

/// Handling projects selection and starting ProjectFlowController for selected project
/// This flow controller is a UINavigationController as it pushes project flow controller(s) onto the navigation stack
class ProjectsFlowController: UINavigationController {
    private let userId: String
    let projectsModel: ProjectsModel
    let localFiles: LocalFiles
    let mediaCache: MediaCache
    let userSettings = UserSettings()
    let pendingUploadsModel: FirebasePendingUploadsModel
    let pendingActionsModel = PendingActionsModelImpl()

    var onSignedOut: (() -> Void)?

    var currentUserNotificationToken: NotificationToken?
    var projectFC: ProjectFlowController?
    /// to observe the state of project flow controller `started`
    var projectFCStarted: AnyCancellable?
    var currentProjectNotificationToken: NotificationToken?

    /// if present show this project and it's task list when user signs in
    var showTaskListOnLoginForProjectId: String?

    init(userId: String, newlySignedIn: Bool) throws {
        self.userId = userId
        projectsModel = try ProjectsModel(userId: userId, newlySignedIn: newlySignedIn)
        localFiles = try LocalFiles()
        mediaCache = MediaCache(localFiles: localFiles)
        pendingUploadsModel = try FirebasePendingUploadsModel(
            localFiles: localFiles,
            mediaCache: mediaCache,
            userSettings: userSettings
        )
        super.init(rootViewController: LaunchScreenViewController())
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // hide as the controllers in tab bar have their own navigation stacks
        setNavigationBarHidden(true, animated: animated)
    }

    func start() async throws {
        try await projectsModel.start()
        try await pendingUploadsModel.start()
        pendingActionsModel.start()

        let tabBarVC = setupTabBarViewController()

        let tryLoadProject: (String) async -> Void = { projectId in
            do {
                self.projectFC = try await self.buildProjectFlowController(projectId: projectId)
                self.setViewControllers([tabBarVC, self.projectFC!], animated: false)
                self.updateLastOpenProjectAndCanvas()
                self.observeCurrentProject()
            } catch {
                Logger.model.error("loading project failed: \(error.localizedDescription, privacy: .public)")
                // fallback to projects list only
                self.setViewControllers([tabBarVC], animated: false)
                UserDefaults.lastOpenProjectId = nil
            }
        }

        // open some project on start?
        if let showTaskListOnLoginForProjectId = showTaskListOnLoginForProjectId {
            // open project from push notification and open it's task list
            await tryLoadProject(showTaskListOnLoginForProjectId)
            showTaskListAfterProjectFlowStarted()
        } else if DebugSettings().openLastProjectOnStart, let lastOpenProjectId = UserDefaults.lastOpenProjectId {
            // reopen last project
            await tryLoadProject(lastOpenProjectId)
        } else {
            setViewControllers([tabBarVC], animated: false)
        }
        observeCurrentUser()
    }

    func stop() async {
        do {
            try await projectsModel.stop()
        } catch {
            Logger.model.error("Failed to stop the projectsModel: \(error)s")
        }
        pendingUploadsModel.stop()
        pendingActionsModel.stop()
        currentUserNotificationToken?.invalidate()
        currentProjectNotificationToken?.invalidate()
    }

    private func buildProjectsViewController() -> ProjectsViewController {
        let projects = projectsModel.mainRealm.objects(ProjectSummary.self).sorted(by: \.name)
        let projectsVC = ProjectsViewController(projects: projects)
        projectsVC.onProjectSelected = { [weak self] project in
            self?.loadAndPushProjectFlowController(projectId: project.id, animated: true)
        }
        return projectsVC
    }

    private func buildSettingsViewController() -> UIViewController {
        userSettings.signOutAction = { [weak self] in
            self?.signOut()
        }
        return UIHostingController(
            rootView: UserSettingsView().environmentObject(userSettings)
        )
    }

    /// Sets the root view controller of this navigation controller to be a tab bar with "My Projects" and "Settings" tabs
    private func setupTabBarViewController() -> UITabBarController {
        let projectsVC = buildProjectsViewController()
        projectsVC.title = String(localized: "My Projects")
        let projectsNavC = UINavigationController(rootViewController: projectsVC)
        projectsNavC.tabBarItem = UITabBarItem(
            title: String(localized: "My Projects"),
            image: UIImage(systemName: "rectangle.grid.1x2"),
            tag: 0
        )

        let settingsVC = buildSettingsViewController()
        settingsVC.title = String(localized: "Settings")
        let settingsNavC = UINavigationController(rootViewController: settingsVC)
        settingsNavC.tabBarItem = UITabBarItem(
            title: String(localized: "Settings"),
            image: UIImage(systemName: "gearshape"),
            tag: 1
        )

        let tabBarVC = UITabBarController()
        tabBarVC.setViewControllers([projectsNavC, settingsNavC], animated: false)

        // HACK - add separator to tab bar (maybe not even a hack??)
        let separator = UIView()
        separator.backgroundColor = .dynamic(.Neutral_07)
        tabBarVC.tabBar.addSubview(separator)
        separator.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(1)
        }

        return tabBarVC
    }

    /// Loads and shows the project or displays the alert view if loading project failed
    private func loadAndPushProjectFlowController(projectId: String, animated: Bool, completion: (() -> Void)? = nil) {
        let activityView = UIActivityIndicatorView(style: .large)
        activityView.backgroundColor = .black.withAlphaComponent(0.3)
        activityView.color = .Pink_03
        view.addSubview(activityView)
        activityView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        activityView.startAnimating()
        Task { @MainActor in
            do {
                // hide the spinner when data store call is finished
                defer {
                    DispatchQueue.main.async {
                        activityView.removeFromSuperview()
                    }
                }
                let previousProjectFC = self.projectFC
                self.projectFC = try await buildProjectFlowController(projectId: projectId)
                DispatchQueue.main.async {
                    if let previousProjectFC = previousProjectFC {
                        // replace if some project flow controller is already showing
                        previousProjectFC.stop()
                        guard let tabBarVC = self.viewControllers.first else {
                            fatalError("no view controller in ProjectFlowController navigation stack")
                        }

                        self.setViewControllers([tabBarVC, self.projectFC!], animated: animated)
                    } else {
                        self.pushViewController(self.projectFC!, animated: animated)
                    }
                    self.updateLastOpenProjectAndCanvas()
                    self.observeCurrentProject()
                    completion?()
                }
            } catch {
                Logger.model.error("loading project failed: \(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async {
                    self.showProjectOpenError(withMessage: error.localizedDescription)
                }
            }
        }
    }

    private func updateLastOpenProjectAndCanvas() {
        guard let projectModel = projectFC?.model else { return }
        UserDefaults.lastOpenProjectId = projectModel.projectId
        UserDefaults.setLastOpenCanvasId(
            projectModel.currentCanvas.id,
            forProjectId: projectModel.projectId
        )
        UserDefaults.setLastOpenCanvasSourceId(
            projectModel.currentCanvas.currentCanvasSource.id,
            forCanvasId: projectModel.currentCanvas.id
        )
    }

    /// Build and configure project flow controller
    private func buildProjectFlowController(projectId: String) async throws -> ProjectFlowController {
        let projectFC = try await ProjectFlowController(
            userId: userId,
            projectId: projectId,
            canvasId: UserDefaults.lastOpenCanvasId(forProjectId: projectId),
            localFiles: localFiles,
            mediaCache: mediaCache,
            pendingUploadsModel: pendingUploadsModel,
            pendingActionsModel: pendingActionsModel,
            userSettings: userSettings
        )
        projectFC.onBack = { [weak self] in
            self?.closeCurrentProject()
        }
        return projectFC
    }

    private func closeCurrentProject() {
        _ = popViewController(animated: true)
        projectFC?.stop()
        projectFC = nil
        UserDefaults.lastOpenProjectId = nil
        currentProjectNotificationToken?.invalidate()
        currentProjectNotificationToken = nil
    }

    private func observeCurrentUser() {
        guard let currentUser = projectsModel.currentUser else {
            fatalError("observeCurrentUser called when there's no current user")
        }
        currentUserNotificationToken = currentUser.observe { [weak self] change in
            if case .deleted = change {
                self?.onSignedOut?()
                // it is important that toast is shown after 'onSignedOut' as the sign out
                // reloads the ToastWindow
                ToastWindow.shared.showWarning(text: "User removed")
            }
        }
    }

    private func observeCurrentProject() {
        guard let projectId = projectFC?.model.projectId else {
            fatalError("observeCurrentProject called when no project is open")
        }
        guard let project = projectsModel.mainRealm.object(ofType: ProjectSummary.self, forPrimaryKey: projectId)
        else { return }
        currentProjectNotificationToken?.invalidate()
        currentProjectNotificationToken = project.observe { [weak self] change in
            if case .deleted = change {
                ToastWindow.shared.showWarning(text: "Project removed")
                self?.closeCurrentProject()
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
        alertController.addAction(UIAlertAction(title: "Ok", style: .cancel) { _ in })
        present(alertController, animated: true)
    }

    private func signOut() {
        // TODO: delete all realm files on sign in when the user is different from the previous one?
        // We need to delete all projects, so Realm.deleteFiles(for: config) is not enough, manual removal
        // like describe here https://github.com/realm/realm-swift/issues/4625 needed
        onSignedOut?()
    }

    func showProjectTaskList(projectId: String) {
        let showProjectTaskListAnimated: ((Bool) -> Void) = { [weak self] animated in
            self?.loadAndPushProjectFlowController(projectId: projectId, animated: animated) {
                self?.projectFCStarted = self?.projectFC?.startedFuture?.sink { _ in
                    self?.showTaskListAfterProjectFlowStarted()
                }
            }
        }

        if let projectFC = projectFC {
            let reloadProject = {
                if projectId == projectFC.model.projectId {
                    // this project is already open, reload the project flow controller with no animations
                    // We reload instead of reusing the current projectFC to avoid cleaning up its UI
                    // state (open views, etc.)
                    showProjectTaskListAnimated(false)
                } else {
                    // a different project is open, replace animated
                    showProjectTaskListAnimated(true)
                }
            }
            if projectFC.isUserEditingProject {
                let alert = UIAlertController(
                    title: "View notification",
                    message: "It looks like you're in the middle of something, are you sure you want to view this notification?",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "Cancel", style: .default))
                alert.addAction(UIAlertAction(title: "View", style: .destructive, handler: { _ in
                    reloadProject()
                }))
                _topViewController().present(alert, animated: true)
            } else {
                reloadProject()
            }
        } else {
            // no project is currently shown, navigate to a project
            showProjectTaskListAnimated(true)
        }
    }

    private func showTaskListAfterProjectFlowStarted() {
        /// when opening tasks list from notification default to "Only Mine"
        UserDefaults.showOnlyMineTasks = true
        projectFCStarted = projectFC?.startedFuture?.sink { [weak self] _ in
            self?.projectFC?.showTaskListAction()
            self?.projectFCStarted?.cancel()
            self?.projectFCStarted = nil
        }
    }
}
