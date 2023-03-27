import SnapKit
import UIKit

class ProjectActionCardViewController: UIViewController, NonModalCardCoordinating {
    let actions: [ActionItem]

    var cardDragging: NonModalCardDragging? {
        didSet { cardDragging?.delegate = self }
    }

    var onCamera: (() -> Void)?
    var onAddPin: (() -> Void)?

    static let topPadding = 21.0
    static let headerToActionsPadding = 16.0

    var addPinButton: UIButton!
    var expandButton: UIButton!
    var photoButton: UIButton!
    var actionSelectorVC: ActionSelectorViewController!

    var roundedShadowView: RoundShadowView {
        view as! RoundShadowView
    }

    var containerView: UIView {
        roundedShadowView.containerView
    }

    /// Initiates with additional actions to show in the action selector
    /// - Parameters:
    ///   - actions: array of actions
    init(actions: [ActionItem] = []) {
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
        containerView.backgroundColor = .dynamic(.Neutral_10)

        containerView.installSliderView()

        setupAddPinButton()

        setupAddPinButton()
        setupExpandButton()
        setupPhotoButton()

        [addPinButton, expandButton, photoButton].forEach(containerView.addSubview)

        addPinButton.snp.makeConstraints { make in
            make.top.equalTo(photoButton)
            make.height.equalTo(photoButton)
            make.leading.equalToSuperview().inset(16)
            make.trailing.equalTo(expandButton.snp.leading).offset(-16)
        }
        expandButton.snp.makeConstraints { make in
            make.top.equalTo(photoButton)
            make.height.equalTo(photoButton)
            make.width.greaterThanOrEqualTo(52)
            make.centerX.equalToSuperview()
        }
        photoButton.snp.makeConstraints { make in
            make.top.equalTo(ProjectActionCardViewController.topPadding)
            make.leading.equalTo(expandButton.snp.trailing).offset(16)
            make.trailing.equalTo(-16)
        }

        let allMediaAction = ActionItem(
            title: String(localized: "All Media"),
            imageName: "photo",
            handler: { [weak self] in
                UIApplication.shared.sendAction(
                    #selector(ProjectFlowActions.showMediaAction), to: nil, from: self, for: nil
                )
            }
        )
        let taskListAction = ActionItem(
            title: String(localized: "Task List"),
            imageName: "list.bullet",
            handler: { [weak self] in
                UIApplication.shared.sendAction(
                    #selector(ProjectFlowActions.showTaskListAction), to: nil, from: self, for: nil
                )
            }
        )
        actionSelectorVC = ActionSelectorViewController(actions: [allMediaAction, taskListAction] + actions)
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
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
        }
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            // animate the card to adjust for the possible height change because of font size change
            guard let cardDragging = cardDragging else { return }
            cardDragging.setPosition(cardDragging.position, withVelocity: 0)
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

    private func setupAddPinButton() {
        addPinButton = UIButton(
            configuration: UIButton.Configuration.blackButton(imagePlacement: .leading),
            primaryAction: UIAction(title: String(localized: "Add Pin"),
                                    image: UIImage(systemName: "mappin.and.ellipse")) { [weak self] _ in
                self?.onAddPin?()
            }
        )
    }

    private func setupExpandButton() {
        var config = UIButton.Configuration.blackButton()
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        expandButton = UIButton(
            configuration: config,
            primaryAction: UIAction(image: UIImage(systemName: "chevron.up")) { [weak self] _ in
                self?.toggleCardExpanded()
            }
        )
        expandButton.setContentHuggingPriority(.required, for: .horizontal)
    }

    private func setupPhotoButton() {
        photoButton = UIButton(
            configuration: UIButton.Configuration.blueButton(imagePlacement: .leading),
            primaryAction: UIAction(title: String(localized: "Capture"),
                                    image: UIImage(systemName: "camera")) { [weak self] _ in
                self?.onCamera?()
            }
        )
    }

    private func toggleCardExpanded() {
        guard let cardDragging = cardDragging else { return }
        let expand = cardDragging.position == .min
        cardDragging.setPosition(expand ? .max : .min, withVelocity: 0, animated: true)
    }
}

extension ProjectActionCardViewController: CardDraggingDelegate {
    func cardWillChangePosition(_ position: CardPosition) {
        expandButton.setImage(UIImage(systemName: position == .max ? "chevron.down" : "chevron.up"),
                              for: .normal)
    }
}

extension ProjectActionCardViewController: CardPresentable {
    func height(forContainer containerView: UIView, cardPosition: CardPosition) -> CGFloat {
        if cardPosition == .medium {
            return -1 // not supported
        }

        view.layoutIfNeeded()
        let fittingSize = CGSize(
            width: containerView.bounds.width,
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
