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

    unowned let imageCaches: ImageCaches
    unowned let projectModel: ProjectModel
    let collaboration: Collaboration

    private var collaborationNotificationToken: NotificationToken?

    /// whether this vc displays a task or a photo collaboration version of the view
    /// For now it's a constant set in init, so no support for switching the type of view
    let isTaskWindow: Bool

    /// a view below content to cover the space visible when dragging up past the max height
    var bottomView = UIView()
    var statusButton: CollaborationStatusButton!
    var moreButton: UIButton!
    var closeButton: UIButton!
    var nameField: UITextField!

    var detailsVC: CollaborationDetailsViewController!
    var feedVC: CollaborationFeedViewController!

    /// how high is the currently visible part of the keyboard
    private var keyboardHeightInWindow: CGFloat = 0

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
    init(imageCaches: ImageCaches, projectModel: ProjectModel, collaboration: Collaboration) {
        self.imageCaches = imageCaches
        self.projectModel = projectModel
        self.collaboration = collaboration
        isTaskWindow = collaboration.status != nil
        super.init(nibName: nil, bundle: nil)

        feedVC = CollaborationFeedViewController(
            imageCaches: imageCaches,
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

        statusButton = CollaborationStatusButton(collaboration)
        statusButton.addTarget(self, action: #selector(statusTapped), for: .touchUpInside)
        containerView.addSubview(statusButton)
        statusButton.snp.makeConstraints { make in
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

        setupNameField()
        containerView.addSubview(nameField)
        nameField.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.trailing.equalToSuperview().offset(-16).priority(.required)
            make.top.equalTo(badgeView.snp.bottom).offset(Constants.verticalSpacing)
        }

        setupFeedVC()
        add(childController: feedVC, toView: containerView)
        feedVC.view.snp.makeConstraints { make in
            make.top.equalTo(nameField.snp.bottom)
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
        onCollaborationUpdated()
        // install keyboard observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        collaborationNotificationToken?.invalidate()
        // remove keyboard observers
        NotificationCenter.default.removeObserver(self)
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

    @objc private func statusTapped() {
        UIApplication.shared.sendAction(
            #selector(CollaborationFlowActions.editStatusAction), to: nil, from: self, for: nil
        )
    }
}

// MARK: Collaboration update

extension CollaborationViewController {
    private func onCollaborationUpdated() {
        statusButton.isHidden = !isTaskWindow

        let name = collaboration.name.trimmingCharacters(in: .whitespacesAndNewlines)
        nameField.text = name
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
                    #selector(CollaborationFlowActions.moreAction),
                    to: nil,
                    from: self,
                    for: FlowEvent(self.collaboration)
                )
            }
        )
        .withTapAreaInsets(UIEdgeInsets(top: -4, left: -4, bottom: -4, right: -4))
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

    private func setupNameField() {
        nameField = UITextField()
        nameField.attributedPlaceholder = NSAttributedString(
            string: isTaskWindow ? "Add a task name..." : "Add a photo collection name...",
            attributes: [.foregroundColor: UIColor.dynamicColor(light: .Neutral_06, dark: .Neutral_05)]
        )
        nameField.textColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
        nameField.font = ._preferredFont(forTextStyle: .body, symbolicTraits: .traitBold)
        nameField.adjustsFontForContentSizeCategory = true
        nameField.tintColor = .Primary_Blue_04
        nameField.autocapitalizationType = .sentences
        nameField.adjustsFontSizeToFitWidth = true
        nameField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        nameField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        nameField.returnKeyType = .done
        nameField.delegate = self
    }

    private func setupFeedVC() {
        feedVC.showMoreUpdates = UserDefaults.moreUpdatesInTheFeed
    }

    private func setupDetailsVC() {
        detailsVC = CollaborationDetailsViewController(
            imageCaches: imageCaches,
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
    func height(forContainer cardContainerView: UIView, cardPosition: CardPosition) -> CGFloat {
        if cardPosition == .min {
            return 0 // will be hidden when minimized
        }

        // +2 is a hack for nameField being bigger than line height
        let nameHeight = ceil(nameField.font?.lineHeight ?? 22.0) + 2.0

        if cardPosition == .medium {
            // what's shown above the keyboard if keyboard visible, "header" height + avaiable spacing in the details view (so no content is shown)
            // The spacing available in details view is actually dependent on the type of collaboration and whether
            // there's a description, but it's at least `descriptionTopSpacing`
            let detailsTopSpace = CollaborationDetailsViewController.Constants.descriptionTopSpacing
            let baseHeight = Constants.heightToName + nameHeight + detailsTopSpace

            // what's visible in the .medium card position but not when showing keyboard
            let additionalContentHeight = detailsVC.height(showingHalfOfUpdatesToggle: true) - detailsTopSpace

            let extraSpaceForKeyboard = max(keyboardHeightInWindow - cardContainerView.safeAreaInsets.bottom, 0)

            // show either keyboard or additional content
            return baseHeight + max(additionalContentHeight, extraSpaceForKeyboard)
        } else { // .max
            // the card display controller adds handling for bottom safe area so
            // we need to subtract it
            let fullHeight = cardContainerView.bounds.height - cardContainerView.safeAreaInsets.bottom
            // the height of the collaboration view header that we want to hide
            // behind the header cover
            var headerHeight = Constants.heightToName + nameHeight
            if isTaskWindow {
                // for task we present all the details
            } else {
                // photo collaboration hides the CTAs by default
                headerHeight += detailsVC.heightUpToCTAs()
            }
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
        guard nameField.isEditing else { return }
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

            let duration = (durationValue as AnyObject).doubleValue
            let options = UIView.AnimationOptions(rawValue: UInt((curveValue as AnyObject).integerValue << 16))
            UIView.animate(withDuration: duration!, delay: 0, options: options, animations: {
                // update the card height
                cardDragging.setPosition(cardDragging.position, withVelocity: 0, animated: false)
            }, completion: nil)
        }
    }
}

// MARK: - name text field delegate

extension CollaborationViewController: UITextFieldDelegate {
    /// when text field did end editing update the keyboard height.
    func textFieldDidEndEditing(_: UITextField, reason _: UITextField.DidEndEditingReason) {
        // this is needed as user could switch to another field with keyboard still visible. In this
        // case we want to update this card immediately (and not wait for the keyboard to be hidden)
        keyboardHeightInWindow = 0
        guard let cardDragging = cardDragging else { return }
        cardDragging.setPosition(cardDragging.position, withVelocity: 0, animated: true)
    }

    /// Notify about name updated
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        onNameUpdated?((textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
        return true
    }
}
