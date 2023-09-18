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
    let canvasFileLoader: CanvasFileLoader
    let userSettings = UserSettings()
    let pendingUploadsModel: FirebasePendingUploadsModel
    let pendingActionsModel = PendingActionsModelImpl()

    var onSignedOut: (() -> Void)?

    let projectsVC: ProjectsViewController

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
        canvasFileLoader = try CanvasFileLoader()
        pendingUploadsModel = try FirebasePendingUploadsModel(
            userId: userId,
            localFiles: localFiles,
            mediaCache: mediaCache,
            userSettings: userSettings,
            pendingActionsModel: pendingActionsModel
        )
        projectsVC = ProjectsViewController(model: projectsModel)
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

        if let user = projectsModel.currentUser, !user.accountReady {
            collectUserData()
        }

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
            }
        }

        // open some project on start?
        if let showTaskListOnLoginForProjectId = showTaskListOnLoginForProjectId {
            // open project from push notification and open it's task list
            await tryLoadProject(showTaskListOnLoginForProjectId)
            showTaskListAfterProjectFlowStarted()
        } else if _debugSettings.openLastProjectOnStart,
                  let organizationId = UserDefaults.lastOpenOrganizationId,
                  let lastOpenProjectId = UserDefaults.recentProjectIds(forOrganizationId: organizationId).first
        {
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

    private func setupProjectsViewController() {
        projectsVC.title = String(localized: "My Projects")
        projectsVC.onOrganizationButtonTap = { [weak self] in
            self?.selectOrganizationAction()
        }
        projectsVC.onProjectSelected = { [weak self] project in
            self?.loadAndPushProjectFlowController(projectId: project.id, animated: true)
        }
    }

    private func setupSettingsViewController() -> UIViewController {
        userSettings.signOutAction = { [weak self] in
            self?.signOut()
        }
        return UIHostingController(
            rootView: UserSettingsView().environmentObject(userSettings).environmentObject(projectsModel.currentUser!)
        )
    }

    /// Sets the root view controller of this navigation controller to be a tab bar with "My Projects" and "Settings" tabs
    private func setupTabBarViewController() -> UITabBarController {
        setupProjectsViewController()
        let projectsNavC = UINavigationController(rootViewController: projectsVC)
        projectsNavC.tabBarItem = UITabBarItem(
            title: String(localized: "My Projects"),
            image: UIImage(named: "projects_icon"),
            tag: 0
        )

        let settingsVC = setupSettingsViewController()
        settingsVC.title = String(localized: "Settings")
        let settingsNavC = UINavigationController(rootViewController: settingsVC)
        settingsNavC.tabBarItem = UITabBarItem(
            title: String(localized: "Settings"),
            image: UIImage(systemName: "gearshape", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13)),
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
        guard let organizationId = projectsModel.currentOrganization?.id else { return }
        UserDefaults.addRecentProjectId(projectModel.projectId, forOrganizationId: organizationId)
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
            canvasFileLoader: canvasFileLoader,
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
        currentProjectNotificationToken?.invalidate()
        currentProjectNotificationToken = nil
    }

    private func observeCurrentUser() {
        guard let currentUser = projectsModel.currentUser else {
            fatalError("observeCurrentUser called when there's no current user")
        }
        currentUserNotificationToken = currentUser.observe { [weak self] change in
            guard let self = self else { return }
            if case .deleted = change {
                self.onSignedOut?()
                // it is important that toast is shown after 'onSignedOut' as the sign out
                // reloads the ToastWindow
                ToastWindow.shared.showWarning(text: "User removed")
            } else if case .change = change {
                if let currentProjectId = self.projectFC?.model.projectId,
                   !currentUser.projectIds.contains(currentProjectId)
                {
                    ToastWindow.shared.showWarning(text: "User removed from project")
                    self.closeCurrentProject()
                }
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

    func showProjectTaskList(projectId: String, projectName: String) {
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
                    title: "View Task List",
                    message: "It looks like you're in the middle of something. Are you sure you want to view your task list for \(projectName)?",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                alert.addAction(UIAlertAction(title: "View", style: .default, handler: { _ in
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
        projectFCStarted = projectFC?.startedFuture?.sink { [weak self] _ in
            guard let self = self, let projectFC = self.projectFC else { return }
            // Reset the task list filters when coming from the push notification... This should be
            // mostly fine as they default to "only mine"...
            UserDefaults.setTaskListFilters(
                TaskListFilters(model: projectFC.model),
                forProjectId: projectFC.model.projectId
            )
            projectFC.showTaskListAction()
            self.projectFCStarted?.cancel()
            self.projectFCStarted = nil
        }
    }

    func selectOrganizationAction() {
        let organizations = projectsModel.mainRealm.objects(Organization.self).sorted(by: \.name)
        OrganizationSelectorCardViewController(
            organizations: [Organization](organizations),
            selectedOrganization: projectsModel.currentOrganization,
            onOrganizationSelected: { [weak self] org in
                self?.projectsModel.setCurrentOrganization(org)
            }
        ).installAndShowCard(in: self)
    }
}

// MARK: - user info

extension ProjectsFlowController {
    /// Ask newly signed up user for name and job title
    private func collectUserData() {
        guard let user = projectsModel.currentUser else { return }
        let enterAccountInfoViewModel = EnterAccountInfoViewModel()
        enterAccountInfoViewModel.email = user.email
        let enterAccountInfoView = EnterAccountInfoView(
            viewModel: enterAccountInfoViewModel,
            selectJobTitleAction: { [weak self] in self?.showJobTitleSelector(enterAccountInfoViewModel) },
            createAccountAction: { [weak self] in self?.updateUserAccount(enterAccountInfoViewModel) },
            logOutAction: { [weak self] in self?.onSignedOut?() }
        )
        let vc = UIHostingController(rootView: enterAccountInfoView)
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: false)
    }

    private func showJobTitleSelector(_ viewModel: EnterAccountInfoViewModel) {
        guard let presentedViewController = presentedViewController else { return }
        let jobTitlePickerVC = StringPickerCardViewController(
            title: "Select your Role",
            strings: [
                "Client / Customer",
                "Construction Supervisor",
                "Construction Trades",
                "Engineer",
                "GIS Analyst",
                "Interior Designer",
                "Land / Urban Planner",
                "Executive / Owner",
                "Project Manager",
                "Property Facility Manager",
                "Other",
            ],
            selectedString: viewModel.jobTitle
        )
        jobTitlePickerVC.onStringSelected = { [weak jobTitlePickerVC] jobTitle in
            viewModel.jobTitle = jobTitle
            jobTitlePickerVC?.dismiss(animated: true)
        }
        jobTitlePickerVC.installAndShowCard(in: presentedViewController)
    }

    private func updateUserAccount(_ viewModel: EnterAccountInfoViewModel) {
        guard !viewModel.firstName.isEmpty else {
            ToastWindow.shared.showError(text: "first name is empty")
            return
        }
        guard !viewModel.lastName.isEmpty else {
            ToastWindow.shared.showError(text: "last name is empty")
            return
        }
        guard let jobTitle = viewModel.jobTitle else {
            ToastWindow.shared.showError(text: "job title is empty")
            return
        }
        viewModel.isProcessing = true
        Task { @MainActor in
            do {
                defer {
                    viewModel.isProcessing = false
                }
                try await self.projectsModel.updateUserData(
                    firstName: viewModel.firstName,
                    lastName: viewModel.lastName,
                    jobTitle: jobTitle
                )
                ToastWindow.shared.showSuccess(text: "account created")
                presentedViewController?.dismiss(animated: true)
            } catch {
                Logger.firestore.error("update user data failed: \(error.localizedDescription)")
                ToastWindow.shared.showError(text: "Account creation failed")
            }
        }
    }
}
