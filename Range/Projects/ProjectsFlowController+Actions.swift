import Foundation

/// Protocol defining actions that projects flow can perform.
/// Required by the views sending actions, so they can use selectors for these functions.
/// See https://swiftrocks.com/understanding-the-ios-responder-chain.html for more info
@objc protocol ProjectsFlowActions: AnyObject {
    /// start the flow for creating the project
    func createProjectAction()
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
            self?.loadAndPushProjectFlowController(projectId: projectId, animated: true) { [weak self] in
                // show the card about the PDFs after the new project flow controller has started
                self?.projectFCStarted = self?.projectFC?.startedFuture?.sink { _ in
                    self?.showHowToAddPDFFloorPlansCard()
                }
            }
        }
        createProjectFC.modalPresentationStyle = .fullScreen
        present(createProjectFC, animated: true)
    }

    private func showHowToAddPDFFloorPlansCard() {
        guard let projectFC else { return }
        SheetCardViewController(
            icon: nil,
            title: "👋 How to add PDF Floor Plans",
            description: "To add PDF floor plans you will need to go to the web desktop app and edit the project PDF canvas sources."
        ).installAndShowCard(in: projectFC.canvasContainer, inView: projectFC.canvasContainer.controls)
    }
}
