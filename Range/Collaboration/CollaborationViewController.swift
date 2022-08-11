import Foundation
import SnapKit
import UIKit

class CollaborationViewController: UIViewController, NonModalCardCoordinating {
    var cardHandler: NonModalCardHandler?

    unowned let images: Images
    let collaboration: Collaboration
    var thumbnailsVC: ThumbnailsViewController!
    var onClose: (() -> Void)?

    var roundedShadowView: RoundShadowView {
        view as! RoundShadowView
    }

    var containerView: UIView {
        roundedShadowView.containerView
    }

    /// - Parameters:
    init(images: Images, collaboration: Collaboration) {
        self.images = images
        self.collaboration = collaboration
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = RoundShadowView(cornerRadius: 24)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        containerView.backgroundColor = .dynamicColor(light: .Neutral_01, dark: .Neutral_10)

        containerView.installSliderView()

        buildThumbnailsView()
        add(childController: thumbnailsVC)

        thumbnailsVC.view.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(29)
            make.height.equalTo(54) // make this view higher than in the design to have bigger buttons
        }

        updateColors()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
        }
    }

    private func updateColors() {
        let darkMode = traitCollection.userInterfaceStyle == .dark
        if darkMode {
            view.setShadowWithFigmaValues(y: -6, blur: 10, opacity: 0.2)
        } else {
            view.setShadowWithFigmaValues(y: -3, blur: 6, opacity: 0.05)
        }
        // stroke not visible in dark mode (same color as background)
        roundedShadowView.topStrokeColor = darkMode ? .Neutral_10 : .Neutral_04
    }

    private func buildThumbnailsView() {
        let uploads = collaboration.uploads.sorted(by: \Upload.timestamp, ascending: false)
        thumbnailsVC = ThumbnailsViewController(images: images, uploads: uploads)
    }
}

extension CollaborationViewController: CardPresentable {
    func height(forWidth _: CGFloat, cardPosition: CardPosition) -> CGFloat {
        if cardPosition == .min {
            return 0 // will be hidden when minimized
        }
        if cardPosition == .medium {
            return -1 // not supported
        }
        return 95
    }

    func cardDidChangePosition(_ position: CardPosition) {
        if position == .min {
            onClose?()
        }
    }

//    func drivingScrollView() -> UIScrollView? {
//    }
}
