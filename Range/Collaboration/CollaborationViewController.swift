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
    var thumbnailsVC: ThumbnailsViewController!
    var onClose: (() -> Void)?

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

        bottomView.backgroundColor = containerView.backgroundColor
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

        setupThumbnailsView()
        add(childController: thumbnailsVC, toView: containerView)

        thumbnailsVC.view.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(ctas.snp.bottom).offset(16)
            make.height.equalTo(54) // make this view higher than in the design to have bigger buttons
        }

        updateColors()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        collaborationNotificationToken = collaboration.observe { [weak self] _ in
            self?.onCollaborationUpdated()
        }
        onCollaborationUpdated()
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

// MARK: Collaboration update

extension CollaborationViewController {
    private func onCollaborationUpdated() {
        let name = collaboration.name.trimmingCharacters(in: .whitespacesAndNewlines)
        nameField.text = name
        namePencilView.isHidden = name.isEmpty

        let hideThumbnails = collaboration.uploads.isEmpty
        if hideThumbnails != thumbnailsVC.view.isHidden {
            thumbnailsVC.view.isHidden = hideThumbnails
            // update the height
            if let cardDragging = cardDragging {
                cardDragging.setPosition(cardDragging.position, withVelocity: 0, animated: true)
            }
        }
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
            primaryAction: UIAction(image: UIImage(systemName: "bubble.right")) { _ in }
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
            primaryAction: UIAction(image: UIImage(systemName: "camera")) { _ in }
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

    private func setupThumbnailsView() {
        let uploads = collaboration.uploads.sorted(by: \Upload.timestamp, ascending: false)
        thumbnailsVC = ThumbnailsViewController(imageCaches: imageCaches, projectModel: projectModel, uploads: uploads)
    }
}

// MARK: Card presentable

extension CollaborationViewController: CardPresentable {
    func height(forContainer containerView: UIView, cardPosition: CardPosition) -> CGFloat {
        let heightIncludingCTAs = 147.0
        if cardPosition == .min {
            return 0 // will be hidden when minimized
        } else if cardPosition == .medium {
            var height = heightIncludingCTAs + 16
            if !collaboration.uploads.isEmpty {
                height += 54 + 16
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
}
