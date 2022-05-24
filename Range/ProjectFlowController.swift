import SnapKit
import SwiftUI
import UIKit

/// Main view controller for displaying a project.
/// It manages the UI state of project and all view transitions.
final class ProjectFlowController: UIViewController {
    let canvasContainer: CanvasContainerViewController
    var onSignOut: (() -> Void)?

    lazy var actionCardVC = installActionCardVC()
    lazy var bottomBlurView = setupBottomBlur()

    var photoFlow: PhotoFlowController?

    init(model: ProjectModel) throws {
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
        showActionCard()
    }

    func stop() {
        canvasContainer.removeCard(cardViewController: actionCardVC)
        remove(childController: canvasContainer)
    }

    fileprivate func showActionCard() {
        actionCardVC.showCard(animated: false)
        bottomBlurView.isHidden = false
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
            self?.startPhotoFlow()
        }
        canvasContainer.installCard(cardViewController: vc, inView: canvasContainer.controls)
        return vc
    }

    fileprivate func startPhotoFlow() {
        photoFlow = PhotoFlowController(canvasContainer: canvasContainer)
        photoFlow?.onStop = { [weak self] in
            self?.actionCardVC.showCard(animated: true)
            self?.photoFlow = nil
        }
        photoFlow?.start { [weak self] started in
            // hide cards if photo flow started
            if started {
                self?.actionCardVC.hideCard(animated: true)
            } else {
                self?.photoFlow = nil
            }
        }
    }
}
