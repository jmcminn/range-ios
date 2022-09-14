import OSLog
import SnapKit
import SwiftUI
import UIKit

/// Main view controller for displaying a project.
/// It manages the UI state of project and all view transitions.
final class ProjectFlowController: UIViewController {
    unowned let model: ProjectModel
    unowned let imageCaches: ImageCaches
    let canvasContainer: CanvasContainerViewController
    let collaborationFlow: CollaborationFlowController
    var onSignOut: (() -> Void)?

    var topViewController: ProjectTopViewController?
    lazy var bottomBlurView = setupBottomBlur()
    lazy var actionCardVC = installActionCardVC()
    lazy var pinsDisplay = PinsDisplay(model: model, canvasContainer: canvasContainer)

    var addPhotoFlow: AddPhotoFlowController?

    init(imageCaches: ImageCaches, model: ProjectModel) throws {
        self.imageCaches = imageCaches
        self.model = model
        canvasContainer = try CanvasContainerViewController(model: model)
        collaborationFlow = CollaborationFlowController(
            model: model,
            imageCaches: imageCaches,
            canvasContainer: canvasContainer
        )
        super.init(nibName: nil, bundle: nil)

        collaborationFlow.onCollaborationClose = { [weak self] in
            // unselect pin, this will result also in hiding the collaboration window
            self?.pinsDisplay.setSelectedPinId(nil)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func start() {
        pinsDisplay.onSelectedPinChange = { [weak self] geometryId in
            if let geometryId = geometryId {
                self?.collaborationFlow.showCollaborationWindow(forGeometry: geometryId, animated: true)
            } else {
                self?.collaborationFlow.hideCollaborationWindow(animated: true)
            }
        }
        add(childController: canvasContainer)
        canvasContainer.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        canvasContainer.view.setNeedsLayout()
        canvasContainer.view.layoutIfNeeded()
        showDebugSettingsButton()
        showTopViewController(animated: false)
        bottomBlurView.isHidden = false
        showDefaultCanvasUI(animated: false)
        collaborationFlow.start()
    }

    func stop() {
        canvasContainer.removeCard(cardViewController: actionCardVC)
        remove(childController: canvasContainer)
        pinsDisplay.stop()
        collaborationFlow.stop()
    }

    /// shows the view controller covering the top of of the screen
    private func showTopViewController(animated: Bool) {
        let topViewController = ProjectTopViewController(projectSummary: model.projectSummary)
        canvasContainer.add(childController: topViewController, toView: canvasContainer.controls)
        if animated {
            topViewController.view.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.bottom.equalTo(canvasContainer.controls.snp.top)
            }
            canvasContainer.controls.layoutIfNeeded()
            UIView.animate(withDuration: 0.2) {
                topViewController.view.snp.remakeConstraints { make in
                    make.leading.trailing.equalToSuperview()
                    make.top.equalToSuperview()
                }
                self.canvasContainer.controls.layoutIfNeeded()
            }
        } else {
            topViewController.view.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalToSuperview()
            }
            canvasContainer.controls.layoutIfNeeded()
        }
        self.topViewController = topViewController
    }

    /// hides the top view controller
    private func hideTopViewController() {
        if let topViewController = topViewController {
            UIView.animate(withDuration: 0.2) {
                topViewController.view.snp.remakeConstraints { make in
                    make.leading.trailing.equalToSuperview()
                    make.bottom.equalTo(self.canvasContainer.controls.snp.top)
                }
                self.canvasContainer.controls.layoutIfNeeded()
            }
        }
    }

    /// Show the default UI elements when viewing the canvas
    fileprivate func showDefaultCanvasUI(animated: Bool = true) {
        actionCardVC.showCard(animated: animated)
        pinsDisplay.start()
    }

    /// Hide the default UI elements when viewing the canvas
    fileprivate func hideDefaultCanvasUI(animated: Bool = true) {
        actionCardVC.hideCard(animated: animated)
        pinsDisplay.stop()
    }

    // TODO: this should be hidden in the production version
    /// Shows a button that shows the debug settings view
    fileprivate func showDebugSettingsButton() {
        let button = RoundShadowButton(image: UIImage(systemName: "gearshape") ?? UIImage())
        canvasContainer.controls.addSubview(button)
        button.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-10)
            make.centerY.equalToSuperview()
        }
        button.addTarget(self, action: #selector(showDebugSettingsAction), for: .touchUpInside)
    }

    /// Shows view controller for debug settings
    @objc func showDebugSettingsAction() {
        let debugSettingsVC = UIHostingController(
            rootView: DebugSettingsView().environmentObject(DebugSettings())
        )
        present(debugSettingsVC, animated: true)
    }

    fileprivate func setupBottomBlur() -> UIView {
        let blur = UIBlurEffect(style: .regular)
        let blurView = UIVisualEffectView(effect: blur)
        canvasContainer.overlays.addSubview(blurView)
        blurView.snp.makeConstraints { [weak self] make in
            guard let self = self else { return }
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(self.view.safeAreaInsets.bottom)
        }
        return blurView
    }

    fileprivate func installActionCardVC() -> ProjectActionCardViewController {
        let additionalCardActions = [
            ProjectAction(
                title: "Sign Out",
                imageName: "rectangle.portrait.and.arrow.right",
                handler: { [weak self] in
                    self?.onSignOut?()
                }
            ),
            ProjectAction(
                title: "Toggle Light/Dark mode",
                imageName: "lightbulb",
                handler: { [weak self] in
                    guard let self = self else { return }
                    self.view.window?.overrideUserInterfaceStyle = self.traitCollection
                        .userInterfaceStyle == .dark ? .light : .dark
                }
            ),
        ]
        let vc = ProjectActionCardViewController(actions: additionalCardActions)
        vc.onCamera = { [weak self] in
            self?.startAddPhotoFlow()
        }
        canvasContainer.installCard(cardViewController: vc, inView: canvasContainer.controls)
        return vc
    }

    fileprivate func startAddPhotoFlow() {
        addPhotoFlow = AddPhotoFlowController(model: model, imageCaches: imageCaches, canvasContainer: canvasContainer)
        addPhotoFlow?.onStop = { [weak self] in
            self?.showDefaultCanvasUI()
            self?.addPhotoFlow = nil
        }
        addPhotoFlow?.start { [weak self] started in
            // hide cards if photo flow started
            if started {
                self?.hideDefaultCanvasUI()
            } else {
                self?.addPhotoFlow = nil
            }
        }
    }
}
