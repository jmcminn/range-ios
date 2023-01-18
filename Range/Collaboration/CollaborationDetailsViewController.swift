import Foundation
import RealmSwift
import SnapKit
import UIKit

/// The details of collaboration to be displayed in the CollaborationViewController
/// This view has everything that is not feed or the header of CollaborationViewController (see its docs for more details)
/// It's added as the header for CollaborationFeedViewController tableView, so it scrolls together with the feed.
class CollaborationDetailsViewController: UIViewController {
    enum Constants {
        // distance from top to description view
        static let descriptionTopSpacing = 10.0
        // distance from description to next view (the total of tap and bottom = verticalSpacing, so if description is 0 height the next view has proper spacing to top)
        static let descriptionBottomSpacing = 6.0
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
        static let thumbnailsHeight = ThumbnailsViewController.thumbnailHeight
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
    var onThumbnailSelected: ((Upload) -> Void)?
    // Bool: `true` = toggle more, `false` = toggle less
    var onToggleMoreUpdates: ((Bool) -> Void)?

    // -- BEGIN: only for task collaboration
    var descriptionTextView: UITextViewWithPlaceholder!
    /// handle for observing description text view content size
    private var descriptionTextViewObservations = [NSKeyValueObservation]()
    /// description text view height changes with its content size
    private var descriptionTextViewHeightConstraint: Constraint?
    /// descriptionTextViewHeightConstraint does not expose the constant, so we need to keep it separately
    private var descriptionTextViewHeight: CGFloat = 0 {
        didSet {
            descriptionTextViewHeightConstraint?.update(offset: descriptionTextViewHeight)
        }
    }

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
            setupDescriptionTextView()
            view.addSubview(descriptionTextView)
            descriptionTextView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalToSuperview().offset(Constants.descriptionTopSpacing).priority(.high)
                descriptionTextViewHeightConstraint = make.height.equalTo(0).constraint
            }

            setupTagsView()
            view.addSubview(tagsView)
            tagsView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalTo(descriptionTextView.snp.bottom).offset(Constants.descriptionBottomSpacing)
            }

            assigneeButton = AssigneeButton()
            assigneeButton.addTarget(self, action: #selector(assigneeTapped), for: .touchUpInside)
            view.addSubview(assigneeButton)
            assigneeButton.snp.makeConstraints { make in
                make.top.equalTo(tagsView.snp.bottom).offset(Constants.verticalSpacing)
                make.leading.equalTo(16)
                make.height.equalTo(Constants.assigneeButtonHeight)
                make.width.equalToSuperview().multipliedBy(0.5).offset(-24).priority(.high)
            }

            dueDateButton = DueDateButton(timeZone: projectModel.projectSummary.timeZone)
            dueDateButton.addTarget(self, action: #selector(dueDateTapped), for: .touchUpInside)
            view.addSubview(dueDateButton)
            dueDateButton.snp.makeConstraints { make in
                make.top.height.width.equalTo(assigneeButton)
                make.trailing.equalTo(-16)
            }
        }

        ctas = _createCollaborationCTAs()
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
        if isTaskWindow {
            setupDescriptionTextViewObserver()
        }
        onCollaborationUpdated()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isTaskWindow {
            removeDescriptionTextViewObserver()
        }
        collaborationNotificationToken?.invalidate()
    }

    /// Do not show thumbnails for task collaboration or when they are empty
    private var hideThumbnails: Bool {
        isTaskWindow || collaboration.uploads.isEmpty
    }

    private func onCollaborationUpdated() {
        if isTaskWindow {
            descriptionTextView.text = collaboration.collaborationDescription
            assigneeButton.assignee = collaboration.assignee
            dueDateButton.setDueDate(
                collaboration.dueDateTimestamp,
                markOverdue: !collaboration.isCompleted && !collaboration.isArchived && collaboration.isOverdue
            )
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
            return Constants.descriptionTopSpacing + descriptionTextViewHeight +
                Constants.descriptionBottomSpacing + Constants.tagsHeight +
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

// MARK: - actions

extension CollaborationDetailsViewController {
    @objc private func descriptionTapped() {
        UIApplication.shared.sendAction(
            #selector(CollaborationFlowActions.editDescriptionAction), to: nil, from: self,
            for: FlowEvent(collaboration)
        )
    }

    @objc private func tagsTapped() {
        UIApplication.shared.sendAction(
            #selector(ProjectFlowActions.editTagsAction), to: nil, from: self,
            for: FlowEvent(collaboration)
        )
    }

    @objc private func assigneeTapped() {
        UIApplication.shared.sendAction(
            #selector(CollaborationFlowActions.editAssigneeAction), to: nil, from: self,
            for: FlowEvent(collaboration)
        )
    }

    @objc private func dueDateTapped() {
        UIApplication.shared.sendAction(
            #selector(CollaborationFlowActions.editDueDateAction), to: nil, from: self,
            for: FlowEvent(collaboration)
        )
    }
}

// MARK: - views

extension CollaborationDetailsViewController {
    private func setupDescriptionTextView() {
        descriptionTextView = UITextViewWithPlaceholder(placeholderText: "Add a description...")
        descriptionTextView.textColor = .dynamicColor(light: .Neutral_06, dark: .Neutral_04)
        descriptionTextView.font = .preferredFont(forTextStyle: .subheadline)
        // left/right = 12 to achieve the visual 16 margin...
        // bottom = 10 so when there's an actual text we have 16 points to next view, if not, we have total 16 point space to top (see Constants)
        descriptionTextView.textContainerInset = UIEdgeInsets(top: 0, left: 12, bottom: 10, right: 12)
        descriptionTextView.returnKeyType = .done
        descriptionTextView.isEditable = false
        descriptionTextView.adjustsFontForContentSizeCategory = true
        descriptionTextView.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(descriptionTapped))
        )
    }

    private func setupTagsView() {
        tagsView = TagsView()
        tagsView.showAddTagCell = true
        tagsView.tags = collaboration.tags.where { $0.placeholder == false }
        tagsView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tagsTapped)))
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
            ActionItem(
                title: String(localized: "More updates"),
                handler: { [weak self] in
                    UserDefaults.moreUpdatesInTheFeed = true
                    self?.onToggleMoreUpdates?(true)
                }
            ),
            ActionItem(
                title: String(localized: "Less updates"),
                handler: { [weak self] in
                    UserDefaults.moreUpdatesInTheFeed = false
                    self?.onToggleMoreUpdates?(false)
                }
            ),
        ])
        if UserDefaults.moreUpdatesInTheFeed == false {
            updatesToggle.setSelectedSegmentIndex(1, animated: false)
        }
        updatesToggle.backgroundColor = view.backgroundColor
        view.addSubview(updatesToggle)
        updatesToggle.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(Constants.updatesTogglePaddings.left)
            make.trailing.equalToSuperview().inset(Constants.updatesTogglePaddings.right).priority(.high)
            make.height.equalTo(Constants.updatesToggleHeight)
            make.bottom.equalToSuperview().inset(Constants.updatesTogglePaddings.bottom)
        }
    }
}

extension UIViewController {
    /// Creates a view containing CTA buttons, to be reused for the bottom collaboration card
    func _createCollaborationCTAs() -> UIView {
        var titleAttributes = AttributeContainer()
        titleAttributes.font = UIFont.preferredFont(forTextStyle: .subheadline)

        var blackButtonConfig = UIButton.Configuration.blackButton(
            imageTextStyle: .caption1,
            imagePlacement: .leading,
            cornerRadius: 8
        )
        blackButtonConfig.attributedTitle = AttributedString("Add Comment", attributes: titleAttributes)
        let addCommentButton = UIButton(
            configuration: blackButtonConfig,
            primaryAction: UIAction(image: UIImage(systemName: "bubble.right")) { [weak self] _ in
                UIApplication.shared.sendAction(#selector(CollaborationFlowActions.addCommentAction),
                                                to: nil, from: self, for: nil)
            }
        )
//        let addAttachmentButton = UIButton(
//            configuration: blackButtonConfig,
//            primaryAction: UIAction(image: UIImage(systemName: "paperclip")) { _ in }
//        )

        var blueButtonConfig = UIButton.Configuration.blueButton(
            imageTextStyle: .caption1,
            imagePlacement: .leading,
            cornerRadius: 8
        )
        blueButtonConfig.attributedTitle = AttributedString("Add Photos", attributes: titleAttributes)
        let addPhotosButton = UIButton(
            configuration: blueButtonConfig,
            primaryAction: UIAction(image: UIImage(systemName: "camera")) { [weak self] _ in
                UIApplication.shared.sendAction(#selector(CollaborationFlowActions.addPhotosAction),
                                                to: nil, from: self, for: nil)
            }
        )
        let ctas = UIView()
        [addCommentButton, addPhotosButton].forEach(ctas.addSubview)
        // layout buttons so addComment and addAttachment take 50% space and addPhotos another 50%
        // (+ there's 16 points space between each button, the leading and trailing spacing is already
        // include as the whole ctas view has margins)
        addCommentButton.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.width.equalTo(addPhotosButton)
        }
        addPhotosButton.snp.makeConstraints { make in
            make.trailing.top.bottom.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(0.5).offset(-8)
        }
        return ctas
    }
}

// MARK: - text view sizing

extension CollaborationDetailsViewController {
    /// Observe the text view properties
    private func setupDescriptionTextViewObserver() {
        // observe text for case when it goes to empty (and content size does not change)
        descriptionTextViewObservations.append(descriptionTextView.observe(\.text) { [weak self] _, _ in
            self?.animateTextViewHeightIfChanged()
        })
        // observe content size - it can change without text changing (the layout did complete for example)
        descriptionTextViewObservations.append(descriptionTextView.observe(\.contentSize) { [weak self] _, _ in
            self?.animateTextViewHeightIfChanged()
        })
    }

    private func removeDescriptionTextViewObserver() {
        descriptionTextViewObservations.forEach { $0.invalidate() }
        descriptionTextViewObservations.removeAll()
    }

    /// Update the size of the text view based on its content.
    /// Notify about the height change if changed.
    private func animateTextViewHeightIfChanged() {
        let newDescriptionTextViewHeight = descriptionTextView.text.isEmpty
            ? max(0, descriptionTextView.placeholderHeight)
            : max(0, descriptionTextView.contentSize.height)
        guard descriptionTextViewHeight != newDescriptionTextViewHeight else { return }
        descriptionTextViewHeight = newDescriptionTextViewHeight
        onHeightChanged?()
    }
}
