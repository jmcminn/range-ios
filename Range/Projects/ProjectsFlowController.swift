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

    var projectFC: ProjectFlowController?
    var currentProjectNotificationToken: NotificationToken?

    init(userId: String) throws {
        self.userId = userId
        projectsModel = try ProjectsModel(userId: userId)
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

        // reopen last project
        if let lastOpenProjectId = UserDefaults.lastOpenProjectId {
            // try load the last open project
            do {
                projectFC = try await buildProjectFlowController(projectId: lastOpenProjectId)
                setViewControllers([tabBarVC, projectFC!], animated: false)
                UserDefaults.lastOpenProjectId = lastOpenProjectId
                UserDefaults.setLastOpenCanvasId(
                    projectFC!.model.currentCanvas.id,
                    forProjectId: projectFC!.model.projectId
                )
                observeCurrentProject()
            } catch {
                Logger.model
                    .error("loading last open project failed: \(error.localizedDescription, privacy: .public)")
                // fallback to projects list only
                setViewControllers([tabBarVC], animated: false)
                UserDefaults.lastOpenProjectId = nil
            }
        } else {
            setViewControllers([tabBarVC], animated: false)
        }
    }

    func stop() {
        projectsModel.stop()
        pendingUploadsModel.stop()
        pendingActionsModel.stop()
        currentProjectNotificationToken?.invalidate()
    }

    private func buildProjectsViewController() -> ProjectsViewController {
        let projects = projectsModel.mainRealm.objects(ProjectSummary.self).sorted(by: \.name)
        let projectsVC = ProjectsViewController(projects: projects)
        projectsVC.onProjectSelected = { [weak self] project in
            self?.loadAndPushProjectFlowController(projectId: project.id)
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
        separator.backgroundColor = .dynamicColor(light: .Neutral_04, dark: .Neutral_07)
        tabBarVC.tabBar.addSubview(separator)
        separator.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(1)
        }

        return tabBarVC
    }

    /// Loads and shows the project or displays the alert view if loading project failed
    private func loadAndPushProjectFlowController(projectId: String) {
        let activityView = UIActivityIndicatorView(style: .large)
        activityView.backgroundColor = .black.withAlphaComponent(0.3)
        activityView.color = .Pink_03
        view.addSubview(activityView)
        activityView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        activityView.startAnimating()
        Task {
            do {
                // hide the spinner when data store call is finished
                defer {
                    DispatchQueue.main.async {
                        activityView.removeFromSuperview()
                    }
                }
                self.projectFC = try await buildProjectFlowController(projectId: projectId)
                DispatchQueue.main.async {
                    self.pushViewController(self.projectFC!, animated: true)
                    UserDefaults.lastOpenProjectId = projectId
                    UserDefaults.setLastOpenCanvasId(
                        self.projectFC!.model.currentCanvas.id,
                        forProjectId: self.projectFC!.model.projectId
                    )
                    self.observeCurrentProject()
                }
            } catch {
                Logger.model.error("loading project failed: \(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async {
                    self.showProjectOpenError(withMessage: error.localizedDescription)
                }
            }
        }
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
}
