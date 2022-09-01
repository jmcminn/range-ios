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
    var onSignOut: (() -> Void)?

    lazy var bottomBlurView = setupBottomBlur()
    lazy var actionCardVC = installActionCardVC()
    lazy var pinsDisplay = PinsDisplay(model: model, canvasContainer: canvasContainer)

    var addPhotoFlow: AddPhotoFlowController?

    var collaborationVC: CollaborationViewController?

    init(imageCaches: ImageCaches, model: ProjectModel) throws {
        self.imageCaches = imageCaches
        self.model = model
        canvasContainer = try CanvasContainerViewController(model: model)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func start() {
        pinsDisplay.onSelectedPinChange = { [weak self] geometryId in
            if let geometryId = geometryId {
                self?.showCollaborationWindow(forGeometry: geometryId, animated: true)
            } else {
                self?.hideCollaborationWindow(animated: true)
            }
        }
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
        pinsDisplay.stop()
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

    /// Finds the first collaboration for this geometry and show its window
    fileprivate func showCollaborationWindow(forGeometry geometryId: String, animated: Bool) {
        if let geometry = model.mainRealm.object(ofType: Geometry.self, forPrimaryKey: geometryId),
           let feature = geometry.features.first,
           let collaboration = feature.collaborations.first
        {
            let collaborationVC = CollaborationViewController(imageCaches: imageCaches, collaboration: collaboration)
            collaborationVC.onClose = { [weak self] in
                // unselect pin, this will result also in hiding the collaboration window
                self?.pinsDisplay.setSelectedPinId(nil)
            }

            canvasContainer.installCard(
                cardViewController: collaborationVC,
                inView: canvasContainer.controls,
                cardConfig: CardConfiguration(initialCardPosition: .medium)
            )

            // check if already showing, if so then ignore animated and replace instantly
            if self.collaborationVC != nil {
                hideCollaborationWindow(animated: false)
                collaborationVC.showCard(animated: false)
            } else {
                collaborationVC.showCard(animated: animated)
            }
            self.collaborationVC = collaborationVC
        } else {
            Logger.model.warning("""
                Trying to present collaboration window for geometry
                \(geometryId, privacy: .public) with no collaboration
            """)
        }
    }

    /// Hide the currently shown collaboration window
    fileprivate func hideCollaborationWindow(animated: Bool) {
        if let collaborationVC = collaborationVC {
            collaborationVC.hideCard(animated: animated) {
                self.canvasContainer.removeCard(cardViewController: collaborationVC)
            }
            self.collaborationVC = nil
        }
    }
}
