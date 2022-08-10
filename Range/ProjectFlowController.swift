import SnapKit
import SwiftUI
import UIKit

/// Main view controller for displaying a project.
/// It manages the UI state of project and all view transitions.
final class ProjectFlowController: UIViewController {
    unowned let model: ProjectModel
    let canvasContainer: CanvasContainerViewController
    var onSignOut: (() -> Void)?

    lazy var bottomBlurView = setupBottomBlur()
    lazy var actionCardVC = installActionCardVC()
    lazy var pinsHandler = PinsHandler(model: model, canvasContainer: canvasContainer)

    var addPhotoFlow: AddPhotoFlowController?

    init(model: ProjectModel) throws {
        self.model = model
        canvasContainer = try CanvasContainerViewController(model: model)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func start() {
        add(childController: canvasContainer)
        canvasContainer.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        showDebugSettingsButton()
        bottomBlurView.isHidden = false
        showDefaultCanvasUI(animated: false)
    }

    func stop() {
        canvasContainer.removeCard(cardViewController: actionCardVC)
        remove(childController: canvasContainer)
    }

    /// Show the default UI elements when viewing the canvas
    fileprivate func showDefaultCanvasUI(animated: Bool = true) {
        actionCardVC.showCard(animated: animated)
        pinsHandler.start()
    }

    /// Hide the default UI elements when viewing the canvas
    fileprivate func hideDefaultCanvasUI(animated: Bool = true) {
        actionCardVC.hideCard(animated: animated)
        pinsHandler.stop()
    }

    // TODO: this should be hidden in the production version
    /// Shows a button that shows the debug settings view
    fileprivate func showDebugSettingsButton() {
        let button = RoundButton(image: UIImage(systemName: "gearshape") ?? UIImage())
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
        addPhotoFlow = AddPhotoFlowController(model: model, canvasContainer: canvasContainer)
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
