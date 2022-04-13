import SnapKit
import UIKit

/// Main view controller for displaying a project.
/// It manages the UI state of project and all view transitions.
final class ProjectFlowController: UIViewController {
    let pdfSource: PDFSource

    /// for presenting map content
    let contentContainer = PassthroughView()
    /// for presenting cards (on top of content)
    let controlsContainer = PassthroughView()
    /// for presenting views on top of controls
    let overlaysContainer = PassthroughView()

    lazy var actionCardVC = installActionCardVC()
    lazy var bottomBlurView = setupBottomBlur()

    var photoFlow: PhotoFlowController?

    init(pdfSource: PDFSource) {
        self.pdfSource = pdfSource
        super.init(nibName: nil, bundle: nil)
        setupContainers()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    fileprivate func setupContainers() {
        view.addSubview(contentContainer)
        view.addSubview(controlsContainer)
        view.addSubview(overlaysContainer)
        controlsContainer.backgroundColor = .clear
        overlaysContainer.backgroundColor = .clear

        contentContainer.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        controlsContainer.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        overlaysContainer.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func start() {
        showSource()
    }

    fileprivate func showSource() {
        let sourceVC = AnnotatedPDFViewController(pdfSource: pdfSource)
        add(childController: sourceVC, toView: contentContainer)

        actionCardVC.showCard(animated: false)
        bottomBlurView.isHidden = false
    }

    fileprivate func setupBottomBlur() -> UIView {
        let blur = UIBlurEffect(style: .regular)
        let blurView = UIVisualEffectView(effect: blur)
        overlaysContainer.addSubview(blurView)
        blurView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(self.view.safeAreaInsets.bottom)
        }
        return blurView
    }

    fileprivate func installActionCardVC() -> ProjectActionCardViewController {
        let vc = ProjectActionCardViewController()
        vc.onCamera = { [weak self] in
            self?.startPhotoFlow()
        }
        installCard(
            cardViewController: vc,
            inView: controlsContainer
        )
        return vc
    }

    fileprivate func startPhotoFlow() {
        photoFlow = PhotoFlowController(projectFlow: self)
        photoFlow?.onStop = { [weak self] in
            self?.photoFlow = nil
        }
        photoFlow?.start()
    }
}
