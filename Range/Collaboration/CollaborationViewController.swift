import Foundation
import RealmSwift
import SnapKit
import UIKit

class CollaborationViewController: UIViewController, NonModalCardCoordinating {
    var cardDragging: NonModalCardDragging?

    unowned let imageCaches: ImageCaches
    unowned let projectModel: ProjectModel
    let collaboration: Collaboration

    private var collaborationNotificationToken: NotificationToken?

    /// a view below content to cover the space visible when dragging up past the max height
    var bottomView = UIView()
    var closeButton: UIButton!
    var nameField: UITextField!
    var namePencilView: UIImageView!
    var ctas: UIStackView!
    var feedVC: CollaborationFeedViewController!
    var thumbnailsVC: ThumbnailsViewController!
    var updatesToggle: SegmentedControl!

    /// callbacks for actions triggered from collaboration window
    var onClose: (() -> Void)?

    private enum Constants {
        // height of thumbnails view
        static let thumbnailsHeight = 54.0
        // height for top and bottom thumbnails view padding
        static let thumbnailsVerticalPaddings = 16.0
        // height of the toggle to switch updates level of detail
        static let updatesToggleHeight = 32.0
        // the insets is used just as a container for top/left/bottom/right paddings around the toggle
        static let updatesTogglePaddings = UIEdgeInsets(top: 16, left: 16, bottom: 12, right: 16)
    }

    var roundedShadowView: RoundShadowView {
        view as! RoundShadowView
    }

    var containerView: UIView {
        roundedShadowView.containerView
    }

    /// - Parameters:
    init(imageCaches: ImageCaches, projectModel: ProjectModel, collaboration: Collaboration) {
        self.imageCaches = imageCaches
        self.projectModel = projectModel
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

        bottomView.backgroundColor = .dynamicColor(light: .Neutral_02, dark: .Neutral_09)
        // added to view (rounded view) as the containerView has a layer mask
        // and bottom view is added outside of its bounds
        view.addSubview(bottomView)
        bottomView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(view.snp.bottom)
            // magic number, just enough so the user won't drag higher than that (beyond the max height)
            make.height.equalTo(500)
        }

        let badgeView = CollaborationBadgeView(collaboration)
        containerView.addSubview(badgeView)
        badgeView.snp.makeConstraints { make in
            make.leading.equalTo(16)
            make.top.equalTo(21)
        }

        setupCloseButton()
        containerView.addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.width.height.equalTo(32)
            make.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().offset(21)
        }

        setupNameField()
        setupNamePencilView()
        containerView.addSubview(nameField)
        containerView.addSubview(namePencilView)
        nameField.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.trailing.equalTo(namePencilView.snp.leading).offset(-4)
            make.top.equalTo(badgeView.snp.bottom).offset(16)
        }
        namePencilView.snp.makeConstraints { make in
            make.centerY.equalTo(nameField.snp.centerY)
            make.trailing.equalToSuperview().offset(-16).priority(.required)
        }

        setupCTAs()
        containerView.addSubview(ctas)
        ctas.snp.makeConstraints { make in
            make.top.equalTo(nameField.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(40)
        }

        setupFeedVC()
        add(childController: feedVC, toView: containerView)
        feedVC.view.snp.makeConstraints { make in
            make.top.equalTo(ctas.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }

        setupFeedHeader()

        updateColors()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        collaborationNotificationToken = collaboration.observe { [weak self] _ in
            self?.onCollaborationUpdated()
        }
        onCollaborationUpdated()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Fill info at viewDidAppear to make sure UIKit
        // has configured this view's next responder.
        originalNextResponder = super.next
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        collaborationNotificationToken?.invalidate()
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
}

// MARK: actions

extension CollaborationViewController {
    private func onThumbnailSelected(forUpload upload: Upload) {
        if let cardDragging = cardDragging {
            if cardDragging.position != .max {
                cardDragging.setPosition(.max, withVelocity: 0, animated: true)
            }
        }
        feedVC.scroll(toUpload: upload)
    }
}

// MARK: Collaboration update

extension CollaborationViewController {
    private func onCollaborationUpdated() {
        let name = collaboration.name.trimmingCharacters(in: .whitespacesAndNewlines)
        nameField.text = name
        namePencilView.isHidden = name.isEmpty

        let hideThumbnails = collaboration.uploads.isEmpty
        if hideThumbnails != thumbnailsVC.view.isHidden {
            updateThumbnailsVisibility()
            // update the height
            if let cardDragging = cardDragging {
                cardDragging.setPosition(cardDragging.position, withVelocity: 0, animated: true)
            }
        }
    }

    /// show/hide the thumbnails and update the feed header height accordingly
    private func updateThumbnailsVisibility() {
        let hidden = collaboration.uploads.isEmpty
        thumbnailsVC.view.isHidden = hidden

        let totalUpdatesToggleHeight = Constants.updatesTogglePaddings.top +
            Constants.updatesToggleHeight + Constants.updatesTogglePaddings.bottom

        feedVC.tableView.beginUpdates()
        feedVC.tableView.tableHeaderView?.frame.size.height = hidden
            ? Constants.thumbnailsVerticalPaddings + totalUpdatesToggleHeight
            : Constants.thumbnailsHeight + 2 * Constants.thumbnailsVerticalPaddings + totalUpdatesToggleHeight
        feedVC.tableView.endUpdates()
    }
}

// MARK: Views

extension CollaborationViewController {
    private func setupCloseButton() {
        closeButton = ButtonWithTapAreaInsets(
            configuration: UIButton.Configuration.closeButton(),
            primaryAction: UIAction(image: UIImage(systemName: "xmark")) { [weak self] _ in
                self?.onClose?()
            }
        )
        .withTapAreaInsets(UIEdgeInsets(top: -4, left: -4, bottom: -4, right: -4))
    }

    private func setupNameField() {
        nameField = UITextField()
        nameField.attributedPlaceholder = NSAttributedString(
            string: "Add a photo collection name...",
            attributes: [.foregroundColor: UIColor.dynamicColor(light: .Neutral_06, dark: .Neutral_05)]
        )
        nameField.textColor = .dynamicColor(light: .Neutral_06, dark: .Neutral_04)
        nameField.font = .systemFont(ofSize: 17, weight: .bold)
        nameField.adjustsFontForContentSizeCategory = true
        nameField.tintColor = .Primary_Blue_04
        nameField.autocapitalizationType = .sentences
        nameField.adjustsFontSizeToFitWidth = true
        nameField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        nameField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        // TODO: 294
        nameField.isUserInteractionEnabled = false
//        nameField.delegate = self
//        nameField.addTarget(self, action: #selector(textChangedAction), for: .editingChanged)
    }

    private func setupCTAs() {
        var blackButtonConfig = UIButton.Configuration.blackButton(imageTextStyle: .caption1, cornerRadius: 8)
        blackButtonConfig.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
        let addCommentButton = UIButton(
            configuration: blackButtonConfig,
            primaryAction: UIAction(image: UIImage(systemName: "bubble.right")) { [weak self] _ in
                UIApplication.shared.sendAction(#selector(CollaborationFlowActions.addCommentAction),
                                                to: nil, from: self, for: nil)
            }
        )
        let addAttachmentButton = UIButton(
            configuration: blackButtonConfig,
            primaryAction: UIAction(image: UIImage(systemName: "paperclip")) { _ in }
        )

        var blueButtonConfig = UIButton.Configuration.blueButton(
            imageTextStyle: .caption1,
            imagePlacement: .leading,
            cornerRadius: 8
        )
        var titleAttributes = AttributeContainer()
        titleAttributes.font = UIFont.preferredFont(forTextStyle: .subheadline)
        blueButtonConfig.attributedTitle = AttributedString("Add Photos", attributes: titleAttributes)
        let addPhotosButton = UIButton(
            configuration: blueButtonConfig,
            primaryAction: UIAction(image: UIImage(systemName: "camera")) { [weak self] _ in
                UIApplication.shared.sendAction(#selector(CollaborationFlowActions.addPhotosAction),
                                                to: nil, from: self, for: nil)
            }
        )
        ctas = UIStackView(arrangedSubviews: [addCommentButton, addAttachmentButton, addPhotosButton])
        ctas.axis = .horizontal
        ctas.distribution = .fillProportionally
        ctas.spacing = 16
    }

    private func setupNamePencilView() {
        let imageConfig = UIImage.SymbolConfiguration(pointSize: 17, weight: .bold)
        let image = UIImage(systemName: "pencil", withConfiguration: imageConfig)
        namePencilView = UIImageView(image: image)
        namePencilView.tintColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
        namePencilView.setContentHuggingPriority(.required, for: .horizontal)
    }

    private func setupFeedVC() {
        feedVC = CollaborationFeedViewController(
            imageCaches: imageCaches,
            projectModel: projectModel,
            collaboration: collaboration
        )
        feedVC.showMoreUpdates = UserDefaults.moreUpdatesInTheFeed
    }

    /// the thumbnails and major/minor updates toggle belong to the feed header so they scroll with table view
    private func setupFeedHeader() {
        let uploads = collaboration.uploads.sorted(by: \Upload.timestamp, ascending: false)
        thumbnailsVC = ThumbnailsViewController(imageCaches: imageCaches, projectModel: projectModel, uploads: uploads)
        thumbnailsVC.onUploadSelected = { [weak self] upload in
            self?.onThumbnailSelected(forUpload: upload)
        }

        // the size doesn't matter here. Width will be adapted to tableView width and height
        // is set/updated in `updateThumbnailsVisibility`
        let header = UIView(frame: CGRect(origin: .zero, size: CGSize(width: 100, height: 100)))
        header.backgroundColor = containerView.backgroundColor

        feedVC.add(childController: thumbnailsVC, toView: header)
        thumbnailsVC.view.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(Constants.thumbnailsVerticalPaddings)
            make.height.equalTo(Constants.thumbnailsHeight)
        }

        let updatesToggleBackground = UIView()
        updatesToggleBackground.backgroundColor = .dynamicColor(light: .Neutral_02, dark: .Neutral_09)
        header.addSubview(updatesToggleBackground)
        updatesToggleBackground.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(Constants.updatesTogglePaddings.top + Constants.updatesToggleHeight
                + Constants.updatesTogglePaddings.bottom)
        }

        let updatesToggleSeparator = UIView()
        updatesToggleSeparator.backgroundColor = .dynamicColor(light: .Neutral_04, dark: .Neutral_07)
        updatesToggleBackground.addSubview(updatesToggleSeparator)
        updatesToggleSeparator.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.height.equalTo(1)
        }

        updatesToggle = SegmentedControl(items: [
            UIAction(
                title: String(localized: "More updates"),
                handler: { [weak self] _ in
                    UserDefaults.moreUpdatesInTheFeed = true
                    self?.feedVC.showMoreUpdates = true
                }
            ),
            UIAction(
                title: String(localized: "Less updates"),
                handler: { [weak self] _ in
                    UserDefaults.moreUpdatesInTheFeed = false
                    self?.feedVC.showMoreUpdates = false
                }
            ),
        ])
        if UserDefaults.moreUpdatesInTheFeed == false {
            updatesToggle.selectedSegmentIndex = 1
        }
        updatesToggle.backgroundColor = containerView.backgroundColor
        // remove the border
        updatesToggle.layer.borderWidth = 0
        header.addSubview(updatesToggle)
        updatesToggle.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(Constants.updatesTogglePaddings.left)
            make.trailing.equalToSuperview().inset(Constants.updatesTogglePaddings.right).priority(.high)
            make.height.equalTo(Constants.updatesToggleHeight)
            make.bottom.equalToSuperview().inset(Constants.updatesTogglePaddings.bottom)
        }

        feedVC.tableView.tableHeaderView = header
        updateThumbnailsVisibility()
    }
}

// MARK: Card presentable

extension CollaborationViewController: CardPresentable {
    func height(forContainer containerView: UIView, cardPosition: CardPosition) -> CGFloat {
        let heightIncludingCTAs = 147.0
        if cardPosition == .min {
            return 0 // will be hidden when minimized
        } else if cardPosition == .medium {
            var height = heightIncludingCTAs + Constants.thumbnailsVerticalPaddings
            // include half of the updatesToggle
            height += Constants.updatesTogglePaddings.top + Constants.updatesToggleHeight / 2.0
            if !collaboration.uploads.isEmpty {
                height += Constants.thumbnailsHeight
                    + Constants.thumbnailsVerticalPaddings
            }
            return height
        } else { // .max
            // the card display controller adds handling for bottom safe area so
            // we need to subtract it
            let fullHeight = containerView.bounds.height - containerView.safeAreaInsets.bottom
            // the height of the collaboration view header that we want to hide
            // behing the header cover
            let headerHeight = heightIncludingCTAs
            // 50 is the height of headerCover content
            let headerCoverHeight = containerView.safeAreaInsets.top + 50
            // add enough so the "header" hides behind the headerCover
            return fullHeight - headerCoverHeight + headerHeight
        }
    }

    func drivingScrollView() -> UIScrollView? {
        feedVC.tableView
    }
}
