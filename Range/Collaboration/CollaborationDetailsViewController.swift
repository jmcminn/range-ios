import Foundation
import RealmSwift
import SnapKit
import UIKit

/// The details of collaboration to be displayed in the CollaborationViewController
/// This view has everything that is not feed or the header of CollaborationViewController (see its docs for more details)
/// It's added as the header for CollaborationFeedViewController tableView, so it scrolls together with the feed.
class CollaborationDetailsViewController: UIViewController {
    private enum Constants {
        // distance between views
        static let verticalSpacing = 16.0
        // height of the tags, not really used in layout as this is the intrinsic tags height
        // (but used in header/card height calculations)
        static let tagsHeight = 32.0
        // height of the assignee and duedate buttons
        static let assigneeButtonHeight = 48.0
        // height of the CTA buttons
        static let ctasHeight = 40.0
        // height of thumbnails view
        static let thumbnailsHeight = 54.0
        // height of the toggle to switch updates level of detail
        static let updatesToggleHeight = 32.0
        // the insets is used just as a container for top/left/bottom/right paddings around the toggle
        static let updatesTogglePaddings = UIEdgeInsets(top: 16, left: 16, bottom: 12, right: 16)
    }

    unowned let imageCaches: ImageCaches
    unowned let projectModel: ProjectModel
    let collaboration: Collaboration
    private var collaborationNotificationToken: NotificationToken?

    /// whether this vc displays a task or a photo collaboration version of the view
    /// For now it's a constant set in init, so no support for switching the type of view
    private let isTaskWindow: Bool

    var onHeightChanged: (() -> Void)?
    // TODO: 387 refactor to action?
    var onThumbnailSelected: ((Upload) -> Void)?
    // Bool: `true` = toggle more, `false` = toggle less
    var onToggleMoreUpdates: ((Bool) -> Void)?

    // -- BEGIN: only for task collaboration
    var tagsView: TagsView!
    var assigneeButton: AssigneeButton!
    var dueDateButton: DueDateButton!
    // ---- END: only for task collaboration
    var ctas: UIView!
    var thumbnailsVC: ThumbnailsViewController!
    var updatesToggle: SegmentedControl!

    /// - Parameters:
    init(imageCaches: ImageCaches, projectModel: ProjectModel, collaboration: Collaboration) {
        self.imageCaches = imageCaches
        self.projectModel = projectModel
        self.collaboration = collaboration
        isTaskWindow = collaboration.status != nil
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .dynamicColor(light: .Neutral_01, dark: .Neutral_10)

        if isTaskWindow {
            setupTagsView()
            view.addSubview(tagsView)
            tagsView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalToSuperview().offset(Constants.verticalSpacing)
            }

            assigneeButton = AssigneeButton()
            view.addSubview(assigneeButton)
            assigneeButton.snp.makeConstraints { make in
                make.top.equalTo(tagsView.snp.bottom).offset(Constants.verticalSpacing)
                make.leading.equalTo(16)
                make.height.equalTo(Constants.assigneeButtonHeight)
                make.width.equalToSuperview().multipliedBy(0.5).offset(-24).priority(.high)
            }

            dueDateButton = DueDateButton()
            view.addSubview(dueDateButton)
            dueDateButton.snp.makeConstraints { make in
                make.top.height.width.equalTo(assigneeButton)
                make.trailing.equalTo(-16)
            }
        }

        setupCTAs()
        view.addSubview(ctas)
        ctas.snp.makeConstraints { make in
            if isTaskWindow {
                make.top.equalTo(assigneeButton.snp.bottom).offset(Constants.verticalSpacing)
            } else {
                make.top.equalToSuperview().offset(Constants.verticalSpacing)
            }
            make.leading.trailing.equalToSuperview().inset(16).priority(.high)
            make.height.equalTo(Constants.ctasHeight)
        }

        setupThumbnails()
        add(childController: thumbnailsVC)
        thumbnailsVC.view.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(ctas.snp.bottom).offset(Constants.verticalSpacing)
            make.height.equalTo(Constants.thumbnailsHeight)
        }

        setupUpdatesToggle()
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

    /// Do not show thumbnails for task collaboration or when they are empty
    private var hideThumbnails: Bool {
        isTaskWindow || collaboration.uploads.isEmpty
    }

    private func onCollaborationUpdated() {
        if isTaskWindow {
            assigneeButton.assignee = collaboration.assignee
            dueDateButton.dueDate = collaboration.dueDateTimestamp
        }

        if hideThumbnails != thumbnailsVC.view.isHidden {
            thumbnailsVC.view.isHidden = hideThumbnails
            onHeightChanged?()
        }
    }
}

// MARK: - height

extension CollaborationDetailsViewController {
    /// Return the height of subviews up to and including CTAs
    func heightUpToCTAs() -> CGFloat {
        if isTaskWindow {
            return Constants.verticalSpacing + Constants.tagsHeight +
                Constants.verticalSpacing + Constants.assigneeButtonHeight +
                Constants.verticalSpacing + Constants.ctasHeight
        } else {
            return Constants.verticalSpacing + Constants.ctasHeight
        }
    }

    /// Return the height of the view
    /// - Parameters: showingHalfOfUpdatesToggle - if true then the height is smaller as it's only for showing half of the updatesToggle view, otherwise full
    func height(showingHalfOfUpdatesToggle: Bool = false) -> CGFloat {
        var height = heightUpToCTAs()
        height += Constants.verticalSpacing
        if !hideThumbnails {
            height += Constants.thumbnailsHeight + Constants.verticalSpacing
        }
        height += Constants.updatesTogglePaddings.top
        if showingHalfOfUpdatesToggle {
            height += Constants.updatesToggleHeight / 2.0
        } else {
            height += Constants.updatesToggleHeight + Constants.updatesTogglePaddings.bottom
        }
        return height
    }
}

// MARK: - views

extension CollaborationDetailsViewController {
    private func setupTagsView() {
        tagsView = TagsView()
        tagsView.showAddTagCell = true
        tagsView.tags = collaboration.tags.where { $0.placeholder == false }
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
        let ctas = UIView()
        [addCommentButton, addAttachmentButton, addPhotosButton].forEach(ctas.addSubview)
        // layout buttons so addComment and addAttachment take 50% space and addPhotos another 50%
        // (+ there's 16 points space between each button, the leading and trailing spacing is already
        // include as the whole ctas view has margins)
        addCommentButton.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.width.equalTo(addPhotosButton.snp.width).multipliedBy(0.5).offset(-8)
        }
        addAttachmentButton.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.equalTo(addCommentButton.snp.trailing).offset(16)
            make.width.equalTo(addCommentButton.snp.width)
        }
        addPhotosButton.snp.makeConstraints { make in
            make.trailing.top.bottom.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(0.5).offset(-8)
        }
        self.ctas = ctas
    }

    private func setupThumbnails() {
        let uploads = collaboration.uploads.sorted(by: \Upload.timestamp, ascending: false)
        thumbnailsVC = ThumbnailsViewController(imageCaches: imageCaches, projectModel: projectModel, uploads: uploads)
        thumbnailsVC.onUploadSelected = { [weak self] upload in
            self?.onThumbnailSelected?(upload)
        }
    }

    private func setupUpdatesToggle() {
        let updatesToggleBackground = UIView()
        updatesToggleBackground.backgroundColor = .dynamicColor(light: .Neutral_02, dark: .Neutral_09)
        view.addSubview(updatesToggleBackground)
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
                    self?.onToggleMoreUpdates?(true)
                }
            ),
            UIAction(
                title: String(localized: "Less updates"),
                handler: { [weak self] _ in
                    UserDefaults.moreUpdatesInTheFeed = false
                    self?.onToggleMoreUpdates?(false)
                }
            ),
        ])
        if UserDefaults.moreUpdatesInTheFeed == false {
            updatesToggle.selectedSegmentIndex = 1
        }
        updatesToggle.backgroundColor = view.backgroundColor
        // remove the border
        updatesToggle.layer.borderWidth = 0
        view.addSubview(updatesToggle)
        updatesToggle.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(Constants.updatesTogglePaddings.left)
            make.trailing.equalToSuperview().inset(Constants.updatesTogglePaddings.right).priority(.high)
            make.height.equalTo(Constants.updatesToggleHeight)
            make.bottom.equalToSuperview().inset(Constants.updatesTogglePaddings.bottom)
        }
    }
}
