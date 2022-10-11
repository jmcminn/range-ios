import Foundation
import OSLog
import UIKit

/// Handling projects selection and starting ProjectFlowController for selected project
/// This flow controller is a UINavigationController as it pushes project flow controller(s) onto the navigation stack
class ProjectsFlowController: UINavigationController {
    private let userId: String

    var onSignedOut: (() -> Void)?

    var projectFC: ProjectFlowController?

    init(userId: String) {
        self.userId = userId
        super.init(rootViewController: LaunchScreenViewController())
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func start() {
        setViewControllers([buildProjectsViewController()], animated: false)

        // TODO: 372 automatically push Project Flow for last project...
    }

    private func buildProjectsViewController() -> ActionSelectorViewController {
        let projectActions = [DemoProject.vanderbilt, DemoProject.preserve].map { project in
            ActionItem(title: project.name) { [weak self] in
                self?.loadAndPushProjectFlowController(project)
            }
        }
        let signOutAction = ActionItem(title: "Sign out", style: .destructive) { [weak self] in
            self?.signOut()
        }
        return ActionSelectorViewController(actions: projectActions + [signOutAction])
    }

    /// Loads and shows the project or displays the alert view if loading project failed
    private func loadAndPushProjectFlowController(_ demoProject: DemoProject) {
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
                self.projectFC = try await ProjectFlowController.buildProjectFlowController(
                    userId: userId,
                    demoProject: demoProject
                )
                projectFC!.onBack = { [weak self] in
                    _ = self?.popViewController(animated: true)
                    self?.setNavigationBarHidden(false, animated: true)
                }
                DispatchQueue.main.async {
                    self.pushViewController(self.projectFC!, animated: true)
                    // hide navigation bar when showing Project flow and show again on back.
                    // We want the navigation bar visible for now in projects view so there's
                    // some padding at the top ;) To be removed later as projects view will have
                    // a custom navigation bar anyway
                    self.setNavigationBarHidden(true, animated: true)
                }
            } catch {
                Logger.model.error("loading project failed: \(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async {
                    self.showProjectOpenError(withMessage: error.localizedDescription)
                }
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
        projectFC?.stop()
        projectFC = nil
        // TODO: delete all realm files on sign in when the user is different from the previous one?
        // We need to delete all projects, so Realm.deleteFiles(for: config) is not enough, manual removal
        // like describe here https://github.com/realm/realm-swift/issues/4625 needed
        onSignedOut?()
    }
}
