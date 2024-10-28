import Combine
import Foundation
import Network
import OSLog
import Realm
import RealmSwift
import SwiftUI
import UIKit

/// Handling projects selection and starting ProjectFlowController for selected project
/// This flow controller is a UINavigationController as it pushes project flow controller(s) onto the navigation stack
class ProjectsFlowController: UINavigationController {
    private let userId: String
    let userModel: UserModel
    let localFiles: LocalFiles
    let mediaCache: MediaCache
    let canvasFileLoader: CanvasFileLoader
    let userSettings: UserSettings
    let userPreferences: UserPreferences
    let pendingUploadsModel: FirebasePendingUploadsModel
    let pendingActionsModel: PendingActionsModelImpl
    let userDataSyncState: UserDataSyncState
    let organizationCountsAndLimits: OrganizationCountsAndLimits

    var onSignedOut: (() -> Void)?

    var tabBarVC: UITabBarController!

    /// The navigation controller presenting the ProjectsViewController (or empty state view if no org is selected)
    var projectsNavigationController: UINavigationController?
    /// The navigation controller for presenting InAppFeed VC for the current organization
    var feedNavigationController: UINavigationController?

    var currentUserNotificationToken: NotificationToken?
    var projectFC: ProjectFlowController?
    private var currentOrganizationObservation: NSKeyValueObservation?
    var currentProjectNotificationToken: NotificationToken?
    private var organizationsNotificationToken: NotificationToken?

    override var shouldAutomaticallyForwardAppearanceMethods: Bool { true }

    /// if present show this route when user signs in
    var showRouteOnLogin: OrgRoute?
    /// if present show this project route when user signs in
    var showProjectRouteOnLogin: ProjectRoute?

    /// combine observers for given organization
    private var organizationSubscriptions = Set<AnyCancellable>()

    let projectFilters: ProjectFilters

    /// for monitoring network access
    let networkMonitor = NWPathMonitor()

    init(userId: String, newlySignedIn: Bool) throws {
        self.userId = userId
        userPreferences = UserPreferences(userId: userId)
        userModel = try UserModel(userId: userId, newlySignedIn: newlySignedIn, userPreferences: userPreferences)
        localFiles = try LocalFiles(userId: userId)
        mediaCache = MediaCache(localFiles: localFiles)
        canvasFileLoader = try CanvasFileLoader()
        userSettings = UserSettings(userId: userId, knockClient: userModel.knockClient)
        pendingActionsModel = PendingActionsModelImpl(userId: userId)
        pendingUploadsModel = try FirebasePendingUploadsModel(
            userId: userId,
            localFiles: localFiles,
            mediaCache: mediaCache,
            userSettings: userSettings,
            userPreferences: userPreferences,
            pendingActionsModel: pendingActionsModel
        )
        userDataSyncState = UserDataSyncState(
            pendingActionsModel: pendingActionsModel,
            pendingUploadsModel: pendingUploadsModel
        )
        organizationCountsAndLimits = OrganizationCountsAndLimits(
            userModel: userModel,
            pendingActionsModel: pendingActionsModel
        )
        projectFilters = userPreferences.projectFilters()
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
        try await userModel.start()
        try await pendingUploadsModel.start()
        pendingActionsModel.start()

        if let user = userModel.currentUser, !user.accountReady {
            collectUserData()
        }

        tabBarVC = setupTabBarViewController()
        updateProjectsViewController()

        let tryLoadProject: (String, ProjectRoute?) async -> Void = { [weak self] projectId, initialRoute in
            guard let self else { return }
            do {
                self.projectFC = try await self.buildProjectFlowController(
                    projectId: projectId,
                    initialRoute: initialRoute
                )
                self.setViewControllers([self.tabBarVC, self.projectFC!], animated: false)
                self.updateLastOpenProjectAndCanvas()
                self.observeCurrentProject()
            } catch {
                Logger.model.error("loading project failed: \(error.localizedDescription, privacy: .public)")
                // fallback to projects list only
                self.setViewControllers([self.tabBarVC], animated: false)
            }
        }

        // open some project on start?
        if let showRouteOnLogin {
            switch showRouteOnLogin.route {
            case .projects:
                // nothing, projects view is the default
                setViewControllers([tabBarVC], animated: false)
            case let .project(projectRoute):
                await tryLoadProject(projectRoute.projectId, projectRoute)
            }
        } else if let projectRoute = showProjectRouteOnLogin {
            // open project from push notification and open the route
            await tryLoadProject(projectRoute.projectId, projectRoute)
        } else if _debugSettings.openLastProjectOnStart,
                  let organizationId = userPreferences.lastOpenOrganizationId,
                  let lastOpenProjectId = userPreferences.recentProjectIds(forOrganizationId: organizationId).first
        {
            // reopen last project
            await tryLoadProject(lastOpenProjectId, nil)
        } else {
            setViewControllers([tabBarVC], animated: false)
        }
        observeCurrentUser()
        observeCurrentOrganization()
        observeOrganizations()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(triggerDataSyncNotificationOnResignActive),
                                               name: UIApplication.willResignActiveNotification,
                                               object: nil)

        networkMonitor.start(queue: DispatchQueue.main)
    }

    @objc private func triggerDataSyncNotificationOnResignActive() {
        let state = userDataSyncState.state
        guard state != .noPending else { return }
        let content = UNMutableNotificationContent()
        content.title = state == .offlinePending ? "Range • Offline Mode" : "Range • Data Sync In-progress"
        content.body = state == .offlinePending
            ?
            "You have offline data that has not been synced. Once you have an Internet connection, open the Range app to sync your offline data."
            :
            "You have offline data that has not been synced. Please open the Range app to complete the data sync process."

        let uuidString = UUID().uuidString
        let request = UNNotificationRequest(identifier: uuidString, content: content, trigger: nil)

        Task {
            let notificationCenter = UNUserNotificationCenter.current()
            do {
                try await notificationCenter.add(request)
            } catch {}
        }
    }

    func triggerDataSyncNotificationOnSignOut() {
        let state = userDataSyncState.state
        guard state != .noPending else { return }
        let content = UNMutableNotificationContent()
        content.title = "Range • Data Sync In-progress"
        content.body = "Please sign back into the Range app to continue syncing your data."

        let uuidString = UUID().uuidString
        let request = UNNotificationRequest(identifier: uuidString, content: content, trigger: nil)

        Task {
            let notificationCenter = UNUserNotificationCenter.current()
            do {
                try await notificationCenter.add(request)
            } catch {}
        }
    }

    private func autoShowOrganizationSelectorIfNeeded() {
        if projectFC == nil, shouldAutoShowOrganizationSelector() {
            selectOrganizationAction()
        }
    }

    /// show organization selector when new organizations added for user (but only if there's more than 1, otherwise user already sees the org)
    private func shouldAutoShowOrganizationSelector() -> Bool {
        let currentOrganizationIds = Set<String>(userModel.mainRealm.objects(Organization.self).map(\.id))
        guard currentOrganizationIds.count > 1 else { return false }
        let lastPresentedOrganizationIds = Set<String>(userPreferences.lastPresentedOrganizationIds ?? [])

        let newOrganizationIds = currentOrganizationIds.subtracting(lastPresentedOrganizationIds)

        return !newOrganizationIds.isEmpty
    }

    func stop() async {
        // first do all the "sync" stops (not doing any network calls, etc.)
        pendingUploadsModel.stop()
        pendingActionsModel.stop()
        currentUserNotificationToken?.invalidate()
        currentOrganizationObservation?.invalidate()
        currentProjectNotificationToken?.invalidate()
        organizationsNotificationToken?.invalidate()
        // then wait for the userModel to stop (which is async)
        do {
            try await userModel.stop()
        } catch {
            Logger.model.error("Failed to stop the userModel: \(error)s")
        }
        networkMonitor.cancel()
    }

    private func setupSettingsViewController() -> UIViewController {
        userSettings.signOutAction = { [weak self] in
            self?.signOut()
        }
        return UIHostingController(
            rootView: UserSettingsView(userPreferences: userPreferences)
                .environmentObject(userSettings)
                .environmentObject(userModel.currentUser!)
        )
    }

    /// Sets the root view controller of this navigation controller to be a tab bar with "My Projects" and "Settings" tabs
    private func setupTabBarViewController() -> UITabBarController {
        let projectsNavC = UINavigationController(rootViewController: LaunchScreenViewController())
        projectsNavC.tabBarItem = UITabBarItem(
            title: String(localized: "My Projects"),
            image: UIImage(named: "projects_icon"),
            tag: 0
        )
        projectsNavigationController = projectsNavC

        feedNavigationController = UINavigationController(rootViewController: LaunchScreenViewController())
        feedNavigationController!.tabBarItem = UITabBarItem(
            title: String(localized: "Notifications"),
            image: UIImage(systemName: "bell", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13)),
            tag: 1
        )

        let tabBarVC = UITabBarController()
        tabBarVC.setViewControllers([projectsNavC, feedNavigationController!], animated: false)

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

    /// Based on current organizationModel show its projects or show the empty view
    private func updateProjectsViewController() {
        guard let projectsNavigationController, let feedNavigationController else { return }
        organizationSubscriptions.removeAll()
        if let organizationModel = userModel.currentOrganizationModel {
            let projectsVC = ProjectsViewController(
                model: organizationModel,
                userPreferences: userPreferences,
                userDataSyncState: userDataSyncState,
                filters: projectFilters
            )
            projectsVC.title = String(localized: "My Projects")
            projectsVC.onOrganizationButtonTap = { [weak self] in
                self?.selectOrganizationAction()
            }
            projectsVC.onSettingsButtonTap = { [weak self] in
                guard let self else { return }
                let settingsVC = setupSettingsViewController()
                let settingsNavC = UINavigationController(rootViewController: settingsVC)
                settingsVC.title = String(localized: "Settings")
                self.present(settingsNavC, animated: true)
            }
            projectsVC.onProjectSelected = { [weak self] project in
                self?.loadAndPushProjectFlowController(projectId: project.id, initialRoute: nil, animated: true)
            }
            projectsVC.onViewWillAppear = { [weak self] in
                guard let self else { return }
                self.userModel.currentOrganizationModel?.updateStatusCounts()
                self.autoShowOrganizationSelectorIfNeeded()
            }
            projectsNavigationController.setViewControllers([projectsVC], animated: false)

            let feedVC = OrganizationInAppFeedViewController(
                model: organizationModel,
                userDataSyncState: userDataSyncState
            )
            feedVC.onOrganizationButtonTap = { [weak self] in
                self?.selectOrganizationAction()
            }
            feedNavigationController.setViewControllers([feedVC], animated: false)
            organizationModel.knockFeedModel.$feed
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.updateInAppUnseenItemsBadge()
                }
                .store(in: &organizationSubscriptions)

        } else {
            let emptyStateView = ProjectsEmptyStateView(state: .noOrganization, createProjectAction: { [weak self] in
                self?.createProjectAction()
            })
            projectsNavigationController.setViewControllers(
                [UIHostingController(rootView: emptyStateView)],
                animated: false
            )
            feedNavigationController.setViewControllers([LaunchScreenViewController()], animated: false)
        }
    }

    /// Loads and shows the project or displays the alert view if loading project failed
    func loadAndPushProjectFlowController(
        projectId: String,
        initialRoute: ProjectRoute?,
        animated: Bool,
        completion: (() -> Void)? = nil
    ) {
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

                if let currentProjectFC = self.projectFC, currentProjectFC.model.projectId == projectId,
                   currentProjectFC.uiState == .default || currentProjectFC.uiState == .collaboration
                {
                    // if we're already showing the project flow controller for given projectId just show the route
                    // but only in some selected states as the showRoute doesn't support getting the
                    // project flow controller to its initial state if user is in the middle of photo flow, etc
                    if let initialRoute {
                        currentProjectFC.showRoute(initialRoute)
                    }
                } else {
                    // if there's no current project flow controller or there is one for a different
                    // project then we build the new project flow controller and show it instead of
                    // the current one
                    let previousProjectFC = self.projectFC
                    self.projectFC = try await buildProjectFlowController(
                        projectId: projectId,
                        initialRoute: initialRoute
                    )
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
        guard let organizationId = userModel.currentOrganizationModel?.organization.id else { return }
        userPreferences.addRecentProjectId(projectModel.projectId, forOrganizationId: organizationId)
        userPreferences.setLastOpenCanvasId(
            projectModel.currentCanvas.id,
            forProjectId: projectModel.projectId
        )
        userPreferences.setLastOpenCanvasSourceId(
            projectModel.currentCanvas.currentCanvasSource.id,
            forCanvasId: projectModel.currentCanvas.id
        )
    }

    /// Build and configure project flow controller
    private func buildProjectFlowController(projectId: String,
                                            initialRoute: ProjectRoute?) async throws -> ProjectFlowController
    {
        let projectFC = try await ProjectFlowController(
            userModel: userModel,
            projectId: projectId,
            canvasId: userPreferences.lastOpenCanvasId(forProjectId: projectId),
            localFiles: localFiles,
            mediaCache: mediaCache,
            canvasFileLoader: canvasFileLoader,
            pendingUploadsModel: pendingUploadsModel,
            pendingActionsModel: pendingActionsModel,
            userDataSyncState: userDataSyncState,
            organizationCountsAndLimits: organizationCountsAndLimits,
            userSettings: userSettings,
            userPreferences: userPreferences,
            initialRoute: initialRoute
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
        // reset the current organization in-app feed as the changes in project level
        // feed are not reflected live in the organization level feed, so we need to refetch
        // to get any updates
        userModel.currentOrganizationModel?.knockFeedModel.reset()
    }

    private func observeCurrentUser() {
        guard let currentUser = userModel.currentUser else {
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

    private func observeCurrentOrganization() {
        currentOrganizationObservation = userModel.observe(\.currentOrganizationModel) { [weak self] _, _ in
            self?.updateProjectsViewController()
        }
    }

    private func observeCurrentProject() {
        guard let projectId = projectFC?.model.projectId else {
            fatalError("observeCurrentProject called when no project is open")
        }
        guard let organizationModel = userModel.currentOrganizationModel else {
            fatalError("observeCurrentProject called when no organization is selected")
        }
        guard let project = organizationModel.mainRealm.object(ofType: ProjectSummary.self, forPrimaryKey: projectId)
        else { return }
        currentProjectNotificationToken?.invalidate()
        currentProjectNotificationToken = project.observe { [weak self] change in
            if case .deleted = change {
                ToastWindow.shared.showWarning(text: "Project removed")
                self?.closeCurrentProject()
            }
        }
    }

    /// observe organizations and show org selector if needed
    private func observeOrganizations() {
        organizationsNotificationToken = userModel.mainRealm.objects(Organization.self).observe { [weak self] change in
            // not initially, only on update
            // initially it's handled when showing projects view controller, here it would be too soon from the UI layout perspective
            if case .update = change {
                self?.autoShowOrganizationSelectorIfNeeded()
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
        if userDataSyncState.state != .noPending {
            // dismiss the Settings vc
            dismiss(animated: true)
            let alertController = UIAlertController(
                title: "Media still syncing",
                message: "If you sign out, any pending media will not sync until you sign back in again. Are you sure you want to continue?",
                preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            })
            alertController.addAction(UIAlertAction(title: "Sign out", style: .destructive) { [weak self] _ in
                self?.onSignedOut?()
            })
            present(alertController, animated: true)
        } else {
            onSignedOut?()
        }
    }

    func showRoute(_ orgRoute: OrgRoute) async {
        do {
            try await userModel.setCurrentOrganization(orgRoute.organizationId)
            if case let .project(projectRoute) = orgRoute.route {
                loadAndPushProjectFlowController(
                    projectId: projectRoute.projectId,
                    initialRoute: projectRoute,
                    animated: false
                )
            } else {
                // go back to projects if in project but receiving .projects route
                if projectFC != nil { closeCurrentProject() }
            }
        } catch {
            ToastWindow.shared.showError(text: "failed to select the organization")
        }
    }

    /// Push notifications come with no orgId so we go directly to given project.
    /// This doesn't change the current org selection.
    /// When user is doing some editing this function will ask for permission to change the view (unlike the universal links handling).
    /// The projectName is needed for this interruption permission message.
    func showProjectRouteFromPushNotification(_ route: ProjectRoute, projectName: String) {
        if let projectFC = projectFC {
            let reloadProject = { [weak self] in
                if route.projectId == projectFC.model.projectId {
                    // this project is already open, reload the project flow controller with no animations
                    // We reload instead of reusing the current projectFC to avoid cleaning up its UI
                    // state (open views, etc.)
                    self?.loadAndPushProjectFlowController(
                        projectId: route.projectId,
                        initialRoute: route,
                        animated: false
                    )
                } else {
                    // a different project is open, replace animated
                    self?.loadAndPushProjectFlowController(
                        projectId: route.projectId,
                        initialRoute: route,
                        animated: true
                    )
                }
            }
            if projectFC.isUserEditingProject {
                let alert = UIAlertController(
                    title: "View Collaboration",
                    message: "It looks like you're in the middle of something. Are you sure you want to view the collaboration for \(projectName)?",
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
            loadAndPushProjectFlowController(projectId: route.projectId, initialRoute: route, animated: true)
        }
    }

    func selectOrganizationAction() {
        let organizations = userModel.mainRealm.objects(Organization.self).sorted(by: \.name)
        OrganizationSelectorCardViewController(
            organizations: [Organization](organizations),
            selectedOrganization: userModel.currentOrganizationModel?.organization,
            onOrganizationSelected: { [weak self] org in
                Task { @MainActor in
                    do {
                        try await self?.userModel.setCurrentOrganization(org.id)
                    } catch {
                        ToastWindow.shared.showError(text: "failed to select the organization")
                    }
                }
            }
        ).installAndShowCard(in: self)
        userPreferences.lastPresentedOrganizationIds = organizations.map(\.id)
    }

    func updateInAppUnseenItemsBadge() {
        guard let tabItems = tabBarVC.tabBar.items,
              let unseenCount = userModel.currentOrganizationModel?.knockFeedModel.feed.meta.unseen_count
        else { return }
        let tabItem = tabItems[1]
        if unseenCount == 0 {
            tabItem.badgeValue = nil
        } else {
            tabItem.badgeColor = .Special_01
            tabItem.badgeValue = unseenCount > 9 ? "9⁺" : String(unseenCount)
        }
    }
}

// MARK: - user info

extension ProjectsFlowController {
    /// Ask newly signed up user for name and job title
    private func collectUserData() {
        guard let user = userModel.currentUser else { return }
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
        jobTitlePickerVC.onStringSelected = { jobTitle in
            viewModel.jobTitle = jobTitle
            viewModel.isUIDisabled = false
        }
        jobTitlePickerVC.onClose = {
            viewModel.isUIDisabled = false
        }
        // a hack - disable swift UI controls, otherwise the touches that should be
        // consumed by jobTitlePicker are also sent to the underlying swiftUI view
        viewModel.isUIDisabled = true
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
                try await self.userModel.updateUserData(
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
