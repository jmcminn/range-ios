import Foundation
import OSLog
import UIKit

/// Protocol defining actions that projects flow can perform.
/// Required by the views sending actions, so they can use selectors for these functions.
/// See https://swiftrocks.com/understanding-the-ios-responder-chain.html for more info
@objc protocol ProjectsFlowActions: AnyObject {
    /// start the flow for creating the project
    func createProjectAction()
    /// show route
    func showRoute(sender: Any?, event: FlowEvent)
    /// filter projects
    func selectProjectFiltersAction()
    /// Show more menu for FlowEvent.object,
    func moreAction(sender: Any?, event: FlowEvent)
}

extension ProjectsFlowController: ProjectsFlowActions {
    func createProjectAction() {
        if !organizationLimitsAndCounts.canAddProject() {
            OrganizationLimitsCardViewController(organizationLimitsAndCounts)
                .installAndShowCard(in: self)
            return
        }
        
        guard let organizationModel = userModel.currentOrganizationModel else { return }
        let createProjectFC = CreateProjectFlowController(organizationModel)
        createProjectFC.onCancelled = { [weak createProjectFC] in
            createProjectFC?.dismiss(animated: true)
        }
        createProjectFC.onProjectCreated = { [weak createProjectFC, weak self] projectId in
            createProjectFC?.dismiss(animated: true)
            // redirect to the newly created project
            self?.loadAndPushProjectFlowController(
                projectId: projectId,
                initialRoute: ProjectRoute(projectId, .welcome),
                animated: true
            )
        }
        createProjectFC.modalPresentationStyle = .fullScreen
        present(createProjectFC, animated: true)
    }

    func showRoute(sender _: Any?, event: FlowEvent) {
        guard let url = event.object as? URL else { return }
        if let route = routeForURL(url) {
            Task {
                await showRoute(route)
            }
        } else {
            // url not recognized as app route, show in browser instead
            UIApplication.shared.open(url)
        }
    }

    func selectProjectFiltersAction() {
        guard let organizationModel = userModel.currentOrganizationModel else { return }
        let projectFiltersCardVC = ProjectFiltersCardViewController(
            model: organizationModel,
            filters: projectFilters
        )

        projectFiltersCardVC.onClose = { [weak self] in
            guard let self = self else { return }
            userPreferences.setProjectFilters(self.projectFilters)
        }
        projectFiltersCardVC.installAndShowCard(in: _rootViewController())
    }

    func moreAction(sender _: Any?, event: FlowEvent) {
        guard let organizationModel = userModel.currentOrganizationModel else { return }

        if let project = event.object as? ProjectSummary {
            guard !project.isInvalidated else { return }
            var actions: [ActionItem] = []
            if organizationModel.currentUser.canArchiveProject() {
                actions.append(ActionItem(
                    title: project.isArchived
                        ? String(localized: "Unarchive Project")
                        : String(localized: "Archive Project"),
                    imageName: project.isArchived ? "eye" : "eye.slash",
                    handler: { [weak self] in self?.toggleProjectArchived(project) }
                ))
            }
            if organizationModel.currentUser.canDeleteProject() {
                actions.append(ActionItem(
                    title: String(localized: "Delete Project"),
                    imageName: "trash",
                    style: .destructive,
                    handler: { [weak self] in self?.confirmAndDeleteProject(project) }
                ))
            }
            guard !actions.isEmpty else { return }
            ActionSelectorCardViewController(
                icon: UIImage(systemName: "ellipsis"), title: String(localized: "Project Menu"), actions: actions
            )
            .installAndShowCard(in: _rootViewController())
        }
    }

    private func toggleProjectArchived(_ project: ProjectSummary) {
        let isArchiving = !project.isArchived
        let activityView = showActivityView()
        Task {
            do {
                // hide the spinner when data store call is finished
                defer {
                    DispatchQueue.main.async {
                        activityView.removeFromSuperview()
                    }
                }
                try await userModel.currentOrganizationModel?.toggleProjectArchived(project)
                DispatchQueue.main.async {
                    ToastWindow.shared.showSuccess(text: isArchiving ? "Project Archived" : "Project Unarchived")
                }
            } catch {
                let networkStatus = self.networkMonitor.currentPath.status
                Logger.model.error("toggle project archived error: \(error.localizedDescription, privacy: .public)")
                let errorMessage: String
                if networkStatus == .unsatisfied {
                    errorMessage =
                        "Project unable to be \(isArchiving ? "archived" : "unarchived") because you are currently offline"
                } else {
                    errorMessage =
                        "Project failed to \(isArchiving ? "archive" : "unarchive"): \(error.localizedDescription)"
                }
                DispatchQueue.main.async {
                    ToastWindow.shared.showError(text: errorMessage)
                }
            }
        }
    }

    private func confirmAndDeleteProject(_ project: ProjectSummary) {
        let deleteProjectConfirmationCard = DeleteProjectConfirmationCardViewController(project)
        deleteProjectConfirmationCard.onDelete = { [weak self] in
            self?.deleteProject(project)
        }
        deleteProjectConfirmationCard.installAndShowCard(in: _rootViewController())
    }
    
    private func deleteProject(_ project: ProjectSummary) {
        let activityView = showActivityView()
        Task {
            do {
                // hide the spinner when data store call is finished
                defer {
                    DispatchQueue.main.async {
                        activityView.removeFromSuperview()
                    }
                }
                try await userModel.currentOrganizationModel?.deleteProject(project)
                DispatchQueue.main.async {
                    ToastWindow.shared.showSuccess(text: "Project Deleted")
                }
            } catch {
                let networkStatus = self.networkMonitor.currentPath.status
                Logger.model.error("delete project error: \(error.localizedDescription, privacy: .public)")
                let errorMessage: String
                if networkStatus == .unsatisfied {
                    errorMessage = "Project unable to be deleted because you are currently offline"
                } else {
                    errorMessage = "Project failed to delete: \(error.localizedDescription)"
                }
                DispatchQueue.main.async {
                    ToastWindow.shared.showError(text: errorMessage)
                }
            }
        }
    }
    
    // show activity view (a spinner) that covers the screen disabling any user interactions
    private func showActivityView() -> UIActivityIndicatorView {
        let activityView = UIActivityIndicatorView(style: .large)
        activityView.backgroundColor = .black.withAlphaComponent(0.3)
        activityView.color = .Pink_03
        _rootViewController().view.addSubview(activityView)
        activityView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        activityView.startAnimating()
        return activityView
    }
}
