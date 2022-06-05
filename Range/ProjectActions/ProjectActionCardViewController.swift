import SnapKit
import UIKit

class ProjectActionCardViewController: UIViewController, NonModalCardCoordinating {
    let actions: [ProjectAction]

    var cardHandler: NonModalCardHandler?

    var onCamera: (() -> Void)?

    static let topPadding = 21.0
    static let headerToActionsPadding = 16.0

    var searchView: SearchView!
    var photoButton: UIButton!
    var actionSelectorVC: ProjectActionSelectorViewController!

    var roundedShadowView: RoundShadowView {
        view as! RoundShadowView
    }

    var containerView: UIView {
        roundedShadowView.containerView
    }

    /// Initiates with additional actions to show in the action selector
    /// - Parameters:
    ///   - actions: array of actions
    init(actions: [ProjectAction] = []) {
        self.actions = actions
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

        searchView = SearchView(placeholderText: "Search")
        searchView.isUserInteractionEnabled = false
        containerView.addSubview(searchView)

        let photoImage = UIImage(
            systemName: "camera",
            withConfiguration: UIImage.SymbolConfiguration(textStyle: .subheadline)
                .applying(UIImage.SymbolConfiguration(weight: .medium))
        )

        var photoButtonConfig = UIButton.Configuration.filled()
        photoButtonConfig.contentInsets = NSDirectionalEdgeInsets(
            top: 15,
            leading: 12.5,
            bottom: 15,
            trailing: 12.5
        )
        photoButtonConfig.background.cornerRadius = 12
        photoButtonConfig.background.strokeColor = UIColor.Primary_Blue_06
        photoButtonConfig.baseForegroundColor = .Neutral_01
        photoButtonConfig.baseBackgroundColor = .Primary_Blue_04

        photoButton = UIButton(
            configuration: photoButtonConfig,
            primaryAction: UIAction(image: photoImage) { [weak self] _ in self?.onCamera?() }
        )
        photoButton.setContentHuggingPriority(.required, for: .horizontal)
        photoButton.setContentHuggingPriority(.required, for: .vertical)
        containerView.addSubview(photoButton)

        photoButton.snp.makeConstraints { make in
            make.right.equalTo(-16)
            make.top.equalTo(ProjectActionCardViewController.topPadding)
        }
        searchView.snp.makeConstraints { make in
            make.top.equalTo(photoButton)
            make.left.equalTo(16)
            make.height.equalTo(photoButton)
            make.right.equalTo(photoButton.snp.left).offset(-16)
        }

        actionSelectorVC = ProjectActionSelectorViewController(actions: actions)
        add(childController: actionSelectorVC, toView: containerView)
        actionSelectorVC.view.snp.makeConstraints { make in
            make.top.equalTo(photoButton.snp.bottom)
                .offset(ProjectActionCardViewController.headerToActionsPadding).priority(.required)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(12).priority(.required)
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
        searchView.updateColors()
    }
}

extension ProjectActionCardViewController: CardPresentable {
    func height(forWidth width: CGFloat, cardPosition: CardPosition) -> CGFloat {
        if cardPosition == .medium {
            return -1 // not supported
        }

        let fittingSize = CGSize(
            width: width,
            height: UIView.layoutFittingCompressedSize.height
        )

        var height = (
            ProjectActionCardViewController.topPadding +
                photoButton.systemLayoutSizeFitting(
                    fittingSize,
                    withHorizontalFittingPriority: .required,
                    verticalFittingPriority: .defaultLow
                ).height +
                ProjectActionCardViewController.headerToActionsPadding
        )

        if cardPosition == .max {
            height += (actionSelectorVC.tableView.contentSize.height + 12.0)
        }

        return height
    }

    func drivingScrollView() -> UIScrollView? {
        actionSelectorVC.tableView
    }
}
