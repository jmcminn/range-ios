import Foundation
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
}

extension ProjectsFlowController: ProjectsFlowActions {
    func createProjectAction() {
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
}
