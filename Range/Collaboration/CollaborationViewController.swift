import Foundation
import RealmSwift
import SnapKit
import UIKit

/// Collaboration view
/// Comprises of 3 parts:
/// 1. the header - the badge, status button (for tasks), close button and name
/// 2. the details - implemented in `CollaborationDetailsViewController` - description, tags, assignee, due date, CTAs, thumbnails, updates detail toggle
/// 3. feed - implemented in `CollaborationFeedViewController`
///
/// The details are added as a header for feed table view, so they scroll together with the feed
class CollaborationViewController: UIViewController, NonModalCardCoordinating {
    var cardDragging: NonModalCardDragging?

    unowned let mediaCache: MediaCache
    unowned let projectModel: ProjectModel
    let collaboration: Collaboration

    private var geometryNotificationToken: NotificationToken?
    private var collaborationNotificationToken: NotificationToken?

    /// whether this vc displays a task or a photo collaboration version of the view
    /// For now it's a constant set in init, so no support for switching the type of view
    let isTaskWindow: Bool

    var badgeView: CollaborationBadgeView!
    var statusButton: CollaborationStatusButton!
    /// shown for archived collaboration (for tasks it replaces the status button)
    var archivedLabel: LabelWithTextInsets!
    var moreButton: UIButton!
    var closeButton: UIButton!
    var nameTextView: UITextViewWithPlaceholder!

    var detailsVC: CollaborationDetailsViewController!
    var feedVC: FeedViewController!

    /// how high is the currently visible part of the keyboard
    private var keyboardHeightInWindow: CGFloat = 0

    /// handle for observing text view properties
    private var textViewObservation: NSKeyValueObservation?

    /// text view height changes with its content size
    private var textViewHeightConstraint: Constraint?
    /// textViewHeightConstraint does not expose the constant, so we need to keep it separately
    private var textViewHeight: CGFloat = 20.0 {
        didSet {
            textViewHeightConstraint?.update(offset: textViewHeight)
        }
    }

    /// callbacks for actions triggered from collaboration window
    var onClose: (() -> Void)?
    var onNameUpdated: ((String) -> Void)?

    private enum Constants {
        // distance between views
        static let verticalSpacing = 16.0
        // height from the top until the top of the name text field
        static let heightToName = 69.0
    }

    var roundedShadowView: RoundShadowView {
        view as! RoundShadowView
    }

    var containerView: UIView {
        roundedShadowView.containerView
    }

    /// - Parameters:
    init(mediaCache: MediaCache, projectModel: ProjectModel, collaboration: Collaboration) {
        self.mediaCache = mediaCache
        self.projectModel = projectModel
        self.collaboration = collaboration
        isTaskWindow = collaboration.status != nil
        super.init(nibName: nil, bundle: nil)

        feedVC = FeedViewController(
            mediaCache: mediaCache,
            projectModel: projectModel,
            collaboration: collaboration
        )
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

        badgeView = CollaborationBadgeView(collaboration)
        // quick actions on badgeView
        let singleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(statusBadgeTapped))
        singleTapRecognizer.numberOfTapsRequired = 1
        badgeView.addGestureRecognizer(singleTapRecognizer)
        let doubleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(statusBadgeTapped))
        doubleTapRecognizer.numberOfTapsRequired = 2
        badgeView.addGestureRecognizer(doubleTapRecognizer)
        singleTapRecognizer.require(toFail: doubleTapRecognizer)

        containerView.addSubview(badgeView)
        badgeView.snp.makeConstraints { make in
            make.leading.equalTo(16)
            make.top.equalTo(21)
        }

        statusButton = CollaborationStatusButton(collaboration)
        statusButton.addTarget(self, action: #selector(statusTapped), for: .touchUpInside)
        containerView.addSubview(statusButton)
        statusButton.snp.makeConstraints { make in
            make.height.equalTo(32)
            make.centerY.equalTo(badgeView)
            make.leading.equalTo(badgeView.snp.trailing).offset(10)
        }

        setupArchivedLabel()
        containerView.addSubview(archivedLabel)
        archivedLabel.snp.makeConstraints { make in
            make.height.equalTo(32)
            make.centerY.equalTo(badgeView)
            make.leading.equalTo(badgeView.snp.trailing).offset(10)
        }

        setupCloseButton()
        containerView.addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.width.height.equalTo(32)
            make.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().offset(21)
        }

        setupMoreButton()
        containerView.addSubview(moreButton)
        moreButton.snp.makeConstraints { make in
            make.width.height.top.equalTo(closeButton)
            make.trailing.equalTo(closeButton.snp.leading).offset(-8)
        }

        setupNameTextView()
        containerView.addSubview(nameTextView)
        nameTextView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(badgeView.snp.bottom).offset(Constants.verticalSpacing)
            textViewHeightConstraint = make.height.equalTo(textViewHeight).priority(.high).constraint
        }

        setupFeedVC()
        add(childController: feedVC, toView: containerView)
        feedVC.view.snp.makeConstraints { make in
            make.top.equalTo(nameTextView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }

        setupDetailsVC()

        updateColors()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        collaborationNotificationToken = collaboration.observe { [weak self] _ in
            self?.onCollaborationUpdated()
        }
        geometryNotificationToken = collaboration.feature.first?.geometry.first?.observe { [weak self] _ in
            self?.onCollaborationUpdated()
        }
        onCollaborationUpdated()
        // install keyboard observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // once it's layed out
        setupTextViewObservers()

        animateTextViewHeightIfChanged()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        collaborationNotificationToken?.invalidate()
        geometryNotificationToken?.invalidate()
        removeTextViewObservers()
        // remove keyboard observers
        NotificationCenter.default.removeObserver(self)
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

    /// "Quick action" for status badge
    /// - when tapped mark task as complete and close the collaboration window
    /// - when double tapped mark task as complete and archived and close the collaboration window
    @objc private func statusBadgeTapped(recognizer: UITapGestureRecognizer) {
        // only for tasks
        guard collaboration.status != nil else { return }
        let selector = recognizer.numberOfTapsRequired == 1
            ? #selector(ProjectFlowController.markTaskCompletedAction)
            : #selector(ProjectFlowController.markTaskCompletedAndArchiveAction)
        UIApplication.shared.sendAction(selector, to: nil, from: self, for: FlowEvent(collaboration))
        onClose?()
    }

    @objc private func statusTapped() {
        UIApplication.shared.sendAction(
            #selector(CollaborationFlowActions.editStatusAction), to: nil, from: self, for: nil
        )
    }
}

// MARK: Collaboration update

extension CollaborationViewController {
    private func onCollaborationUpdated() {
        guard !collaboration.isInvalidated else { return }
        badgeView.isUserInteractionEnabled = !collaboration.isArchived

        statusButton.isHidden = !isTaskWindow || collaboration.isArchived
        archivedLabel.isHidden = !collaboration.isArchived

        let name = collaboration.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !nameTextView.isFirstResponder {
            // don't overwrite the name when user is editing it
            nameTextView.text = name
        }
    }
}

// MARK: Views

extension CollaborationViewController {
    private func setupMoreButton() {
        moreButton = ButtonWithTapAreaInsets(
            configuration: UIButton.Configuration.closeButton(),
            primaryAction: UIAction(image: UIImage(systemName: "ellipsis")) { [weak self] _ in
                guard let self = self else { return }
                UIApplication.shared.sendAction(
                    #selector(ProjectFlowController.moreAction), to: nil, from: self,
                    for: FlowEvent(self.collaboration)
                )
            }
        )
        .withTapAreaInsets(UIEdgeInsets(top: -4, left: -4, bottom: -4, right: -4))
    }

    private func setupArchivedLabel() {
        archivedLabel = LabelWithTextInsets()
        archivedLabel.textInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        archivedLabel.font = UIFont._preferredFont(forTextStyle: .subheadline, symbolicTraits: .traitBold)
        archivedLabel.textColor = .Neutral_01
        archivedLabel.adjustsFontForContentSizeCategory = true
        archivedLabel.backgroundColor = .Archived
        archivedLabel.text = String(localized: "Archived")
        archivedLabel.autoround = true
    }

    private func setupCloseButton() {
        closeButton = ButtonWithTapAreaInsets(
            configuration: UIButton.Configuration.closeButton(),
            primaryAction: UIAction(image: UIImage(systemName: "xmark")) { [weak self] _ in
                self?.onClose?()
            }
        )
        .withTapAreaInsets(UIEdgeInsets(top: -4, left: -4, bottom: -4, right: -4))
    }

    private func setupNameTextView() {
        nameTextView = UITextViewWithPlaceholder(
            placeholderText: isTaskWindow ? "Add task pin name..." : "Add photo pin name..."
        )
        let font = UIFont._preferredFont(forTextStyle: .title3, symbolicTraits: .traitBold)
        nameTextView.textColor = .dynamic(.Neutral_04)
        nameTextView.placeholderLabel.font = font
        nameTextView.font = font
        nameTextView.tintColor = .Primary_Blue_04
        // left/right = 12 to achieve the visual 16 margin...
        nameTextView.textContainerInset = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        nameTextView.returnKeyType = .done
        nameTextView.adjustsFontForContentSizeCategory = true
        nameTextView.delegate = self
    }

    private func setupFeedVC() {
        feedVC.showMoreUpdates = UserDefaults.moreUpdatesInTheFeed
    }

    private func setupDetailsVC() {
        detailsVC = CollaborationDetailsViewController(
            mediaCache: mediaCache,
            projectModel: projectModel,
            collaboration: collaboration
        )
        detailsVC.onHeightChanged = { [weak self] in
            self?.updateFeedHeaderHeight()
        }
        detailsVC.onToggleMoreUpdates = { [weak self] showMore in
            self?.feedVC.showMoreUpdates = showMore
        }
        detailsVC.onThumbnailSelected = { [weak self] upload in
            self?.onThumbnailSelected(forUpload: upload)
        }

        // the size doesn't matter here. Width will be adapted to tableView width and height
        // is set/updated in `updateThumbnailsVisibility`
        let header = UIView(frame: CGRect(origin: .zero, size: CGSize(width: 100, height: detailsVC.height())))
        header.backgroundColor = containerView.backgroundColor
        feedVC.add(childController: detailsVC, toView: header)
        detailsVC.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        feedVC.tableView.tableHeaderView = header
    }

    /// update the feed header height based on the detailsVC height and animate the card height
    private func updateFeedHeaderHeight() {
        // update the height
        if let cardDragging = cardDragging {
            cardDragging.setPosition(cardDragging.position, withVelocity: 0, animated: true)
        }

        feedVC.tableView.beginUpdates()
        feedVC.tableView.tableHeaderView?.frame.size.height = detailsVC.height()
        feedVC.tableView.endUpdates()
    }
}

// MARK: Card presentable

extension CollaborationViewController: CardPresentable {
    // subtract bottom safe area insets from keyboard as card dragging adds it to the card anyway
    func extraSpaceForKeyboard(cardContainer: UIView) -> CGFloat {
        max(keyboardHeightInWindow - cardContainer.safeAreaInsets.bottom, 0)
    }

    func height(forContainer cardContainerView: UIView, cardPosition: CardPosition) -> CGFloat {
        if cardPosition == .min {
            return 0 // will be hidden when minimized
        }

        if cardPosition == .medium {
            // what's shown above the keyboard if keyboard visible, "header" height + avaiable spacing in the details view (so no content is shown)
            // The spacing available in details view is actually dependent on the type of collaboration and whether
            // there's a description, but it's at least `descriptionTopSpacing`
            let detailsTopSpace = CollaborationDetailsViewController.Constants.descriptionTopSpacing
            let baseHeight = Constants.heightToName + textViewHeight + detailsTopSpace

            // what's visible in the .medium card position but not when showing keyboard
            let additionalContentHeight = detailsVC.height(showingHalfOfUpdatesToggle: true)
                - detailsTopSpace + cardContainerView.safeAreaInsets
                .bottom // add bottom safe area as this card is in full screen mode

            let extraSpaceForKeyboard = max(keyboardHeightInWindow, 0)

            // show either keyboard or additional content
            return baseHeight + max(additionalContentHeight, extraSpaceForKeyboard)
        } else { // .max
            // the card display controller does not add handling for bottom safe area as we're
            // in full screen mode, so use the full cardContainer height
            let fullHeight = cardContainerView.bounds.height
            // the height of the collaboration view header that we want to hide
            // behind the header cover
            var headerHeight = Constants.heightToName + textViewHeight
            // 50 is the height of headerCover content
            let headerCoverHeight = cardContainerView.safeAreaInsets.top + 50
            // add enough so the "header" hides behind the headerCover
            return fullHeight - headerCoverHeight + headerHeight
        }
    }

    func drivingScrollView() -> UIScrollView? {
        feedVC.tableView
    }
}

// MARK: - keyboard handling

extension CollaborationViewController {
    /// Recalculate the `keyboardHeightInWindow` on keyboard frame change and update the card height
    @objc func keyboardWillChangeFrame(notification: NSNotification) {
        // only update the layout if name is being edited (and not when some presented
        // views, like 'add comment' present the keyboard)
        guard nameTextView.isFirstResponder else { return }
        // Get required info out of the notification
        if let window = view.window,
           let cardDragging = cardDragging,
           let userInfo = notification.userInfo,
           let endRect = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? AnyObject)?.cgRectValue,
           let durationValue = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey],
           let curveValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey]
        {
            // Calculate the height of the visible part of the keyboard
            keyboardHeightInWindow = window.frame.height - endRect.origin.y

            let textViewHeightUpdated = updateTextViewHeight()

            let duration = (durationValue as AnyObject).doubleValue
            let options = UIView.AnimationOptions(rawValue: UInt((curveValue as AnyObject).integerValue << 16))
            UIView.animate(withDuration: duration!, delay: 0, options: options, animations: {
                if textViewHeightUpdated {
                    self.view.layoutIfNeeded()
                }
                // update the card height
                cardDragging.setPosition(cardDragging.position, withVelocity: 0, animated: false)
            }, completion: nil)
        }
    }
}

// MARK: - text view expanding

extension CollaborationViewController {
    /// Observe the text view properties
    private func setupTextViewObservers() {
        textViewObservation = nameTextView.observe(\.contentSize) { [weak self] _, _ in
            self?.animateTextViewHeightIfChanged()
        }
    }

    private func removeTextViewObservers() {
        textViewObservation?.invalidate()
        textViewObservation = nil
    }

    /// Update the size of the text view based on its content. But not go above the full screen size for the whole view + the keyboard.
    /// Animate the text view and card height if changed.
    private func animateTextViewHeightIfChanged() {
        guard let cardDragging = cardDragging else { return }

        if updateTextViewHeight() {
            UIView.animate(withDuration: 0.1) {
                self.view.layoutIfNeeded()
                cardDragging.setPosition(cardDragging.position, withVelocity: 0, animated: false)
            }
        }
    }

    /// Update the textViewHeight and returns `true` if it has changed
    private func updateTextViewHeight() -> Bool {
        guard let cardDragging = cardDragging else { return false }
        let cardContainer = cardDragging.containerView

        // 20 is the height for the default font size, we just need some more less correct value here so the text view height is not initially 0
        let minTextViewHeight = 10.0

        // it cannot grow above the screen height (also taking into account the keyboard height)
        let availableSpaceInContainer = cardContainer.frame.height - cardContainer.safeAreaInsets.top
            - cardContainer.safeAreaInsets.bottom
        let contentHeight = Constants.heightToName
        // HACK: this could be calculated but is controlled on the CollaborationFlowController level
        // It's here so when editing a long name we limit the text view height so it doesn't trigger
        // showing the collaboration view header cover (which also displays the name)
        let extraSpaceForTopHeaderCover = 50.0
        let maxTextViewHeight = availableSpaceInContainer - contentHeight - extraSpaceForTopHeaderCover -
            extraSpaceForKeyboard(cardContainer: cardContainer)

        let newTextViewHeight = min(max(nameTextView.contentSize.height, minTextViewHeight), maxTextViewHeight)

        guard newTextViewHeight != textViewHeight else { return false }
        textViewHeight = newTextViewHeight
        return true
    }
}

// MARK: - name text field delegate

extension CollaborationViewController: UITextViewDelegate {
    func textViewDidEndEditing(_: UITextView) {
        // this is needed as user could switch to another field with keyboard still visible. In this
        // case we want to update this card immediately (and not wait for the keyboard to be hidden)
        keyboardHeightInWindow = 0
        guard let cardDragging = cardDragging else { return }
        cardDragging.setPosition(cardDragging.position, withVelocity: 0, animated: true)
    }

    func textView(_ textView: UITextView, shouldChangeTextIn _: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            onNameUpdated?((textView.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
            textView.resignFirstResponder()
            return false
        }
        return true
    }
}
