import RealmSwift
import SnapKit
import UIKit

class ProjectActionCardViewController: UIViewController, NonModalCardCoordinating {
    let model: ProjectModel

    var cardDragging: NonModalCardDragging?

    var onCamera: (() -> Void)?
    var onAddPin: (() -> Void)?

    static let topPadding = 21.0
    static let headerToActionsPadding = 16.0

    var addPinButton: UIButton?
    var addSnippetButton: UIButton?
    var photoButton: UIButton?

    var allMediaButton: UIButton? // only for Guest
    var taskListButton: UIButton? // only for Guest

    var actionSelectorVC: ActionSelectorViewController?

    var roundedShadowView: RoundShadowView {
        view as! RoundShadowView
    }

    var containerView: UIView {
        roundedShadowView.containerView
    }

    private var currentUserNotificationToken: NotificationToken?
    private var createPinSectionShown: Bool = false

    init(model: ProjectModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)

        currentUserNotificationToken = model.currentUser.observe { [weak self] _ in
            guard let self = self else { return }
            if self.createPinSectionShown != self.model.currentUser.canCreateCollaboration() {
                self.updateLayout()
                guard let cardDragging = cardDragging else { return }
                cardDragging.setPosition(.min, withVelocity: 0)
            }
        }
    }

    deinit {
        currentUserNotificationToken?.invalidate()
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

        updateLayout()

        updateColors()
    }

    private func updateLayout() {
        containerView.subviews.forEach { $0.removeFromSuperview() }
        actionSelectorVC = nil
        
        createPinSectionShown = model.currentUser.canCreateCollaboration()

        if createPinSectionShown {
            containerView.installSliderView()

            setupAddPinButton()
            setupAddSnippetButton()
            setupPhotoButton()

            [addPinButton!, addSnippetButton!, photoButton!].forEach(containerView.addSubview)

            addPinButton!.snp.makeConstraints { make in
                make.top.equalTo(photoButton!)
                make.height.equalTo(photoButton!)
                make.leading.equalToSuperview().inset(16)
                make.trailing.equalTo(addSnippetButton!.snp.leading).offset(-16)
            }
            addSnippetButton!.snp.makeConstraints { make in
                make.top.equalTo(photoButton!)
                make.height.equalTo(photoButton!)
                make.width.greaterThanOrEqualTo(52)
                make.centerX.equalToSuperview()
            }
            photoButton!.snp.makeConstraints { make in
                make.top.equalTo(ProjectActionCardViewController.topPadding)
                make.leading.equalTo(addSnippetButton!.snp.trailing).offset(16)
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

            actionSelectorVC = ActionSelectorViewController(actions: [allMediaAction, taskListAction])
            add(childController: actionSelectorVC!, toView: containerView)
            actionSelectorVC!.view.snp.makeConstraints { make in
                make.top.equalTo(photoButton!.snp.bottom)
                    .offset(ProjectActionCardViewController.headerToActionsPadding).priority(.required)
                make.leading.trailing.equalToSuperview()
                make.bottom.equalToSuperview().offset(12).priority(.required)
            }
        } else {
            // if there's no "create pin" section in the header, we put the "All Media" and "Task List"
            // there (and not in the ActionSelectorViewController table below the header)
            setupAllMediaButton()
            setupTaskListButton()
            [allMediaButton!, taskListButton!].forEach(containerView.addSubview)

            allMediaButton!.snp.makeConstraints { make in
                make.top.equalTo(16)
                make.leading.equalToSuperview().inset(16)
                make.width.equalToSuperview().dividedBy(2).offset(-24)
            }
            taskListButton!.snp.makeConstraints { make in
                make.top.height.width.equalTo(allMediaButton!)
                make.trailing.equalTo(-16)
            }
        }
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
        addPinButton = RangeButton(
            configuration: UIButton.Configuration.blackButton(imagePlacement: .leading),
            primaryAction: UIAction(title: String(localized: "Add Pin"),
                                    image: UIImage(systemName: "mappin.and.ellipse")) { [weak self] _ in
                self?.onAddPin?()
            }
        )
        .withCustomRangeHighlightColor()
    }

    private func setupAddSnippetButton() {
        var config = UIButton.Configuration.pinkButton()
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        addSnippetButton = RangeButton(
            configuration: config,
            primaryAction: UIAction(image: UIImage(systemName: "scissors")) { [weak self] _ in
                UIApplication.shared.sendAction(
                    #selector(ProjectFlowActions.takeSnapshotAction), to: nil, from: self, for: nil
                )
            }
        )
        .withCustomRangeHighlightColor()

        addSnippetButton!.setContentHuggingPriority(.required, for: .horizontal)
    }

    private func setupPhotoButton() {
        photoButton = RangeButton(
            configuration: UIButton.Configuration.blueButton(imagePlacement: .leading),
            primaryAction: UIAction(title: String(localized: "Capture"),
                                    image: UIImage(systemName: "camera")) { [weak self] _ in
                self?.onCamera?()
            }
        )
        .withCustomRangeHighlightColor()
    }

    private func setupAllMediaButton() {
        allMediaButton = RangeButton(
            configuration: UIButton.Configuration.blackButton(imagePlacement: .leading),
            primaryAction: UIAction(title: String(localized: "All Media"),
                                    image: UIImage(systemName: "photo")) { [weak self] _ in
                UIApplication.shared.sendAction(
                    #selector(ProjectFlowActions.showMediaAction), to: nil, from: self, for: nil
                )
            }
        )
        .withCustomRangeHighlightColor()
    }

    private func setupTaskListButton() {
        taskListButton = RangeButton(
            configuration: UIButton.Configuration.blackButton(imagePlacement: .leading),
            primaryAction: UIAction(title: String(localized: "Task List"),
                                    image: UIImage(systemName: "list.bullet")) { [weak self] _ in
                UIApplication.shared.sendAction(
                    #selector(ProjectFlowActions.showTaskListAction), to: nil, from: self,
                    for: nil
                )
            }
        )
        .withCustomRangeHighlightColor()
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

        var height = 0.0
        if let photoButton {
            height += ProjectActionCardViewController.topPadding + photoButton.systemLayoutSizeFitting(
                fittingSize,
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .defaultLow
            ).height +
                ProjectActionCardViewController.headerToActionsPadding
        } else if let allMediaButton {
            height += 16 + allMediaButton.systemLayoutSizeFitting(
                fittingSize,
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .defaultLow
            ).height +
                ProjectActionCardViewController.headerToActionsPadding
        }

        if cardPosition == .max, let actionSelectorVC {
            height += (actionSelectorVC.tableView.contentSize.height + 12.0)
        }

        return height
    }

    func drivingScrollView() -> UIScrollView? {
        actionSelectorVC?.tableView
    }
}
