import Foundation
import SnapKit
import UIKit

/// Class for adding/editing comment/note
class CommentViewController: UIViewController, NonModalCardCoordinating {
    var cardDragging: NonModalCardDragging? {
        didSet { cardDragging?.delegate = self }
    }

    /// The UI differs a little depending on whether it's for adding a new comment/note, adding a comment only or editing the existing one
    enum Mode {
        case add, addComment, edit
    }

    let mode: Mode
    // whether the text view should automatically become first responder when shown
    private let startEditingWhenShown: Bool
    private let shownAboveView: UIView?

    var onCancel: (() -> Void)?
    var onDone: (() -> Void)?
    var onHeightUpdated: ((CGFloat) -> Void)?

    // top/left/bottom/right margins for views layout
    private static let margin = 16.0
    private static let commentButtonHeight = 32.0

    /// Whether user is creating a note or a comment
    var isNote: Bool = false {
        didSet { isNoteDidSet() }
    }

    /// get/set the comment text
    var commentText: String! {
        get {
            textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        set {
            textView.text = newValue
        }
    }

    private var placeholderText: String {
        isNote ? "Add an actionable note..." : "Add a comment..."
    }

    private var textView = UITextViewWithPlaceholder(placeholderText: "")
    private var flagButton: ButtonWithTapAreaInsets!
    private var commentButton: ButtonWithTapAreaInsets!
    private var cancelButton: ButtonWithTapAreaInsets!

    /// how high is the currently visible part of the keyboard
    private var keyboardHeightInWindow: CGFloat = 0

    /// handle for observing text view properties
    private var textViewObservation: NSKeyValueObservation?

    /// text view height changes with its content size
    private var textViewHeightConstraint: Constraint?
    /// textViewHeightConstraint does not expose the constant, so we need to keep it separately
    private var textViewHeight: CGFloat = 38.0 {
        didSet {
            textViewHeightConstraint?.update(offset: textViewHeight)
        }
    }

    private var roundedShadowView: RoundShadowView {
        view as! RoundShadowView
    }

    private var containerView: UIView {
        roundedShadowView.containerView
    }

    override func loadView() {
        view = RoundShadowView(cornerRadius: 24)
    }

    ///
    /// - Parameters:
    ///   - mode: the mode for the controller
    ///   - startEditingWhenShown: whether it should automatically start editing (show keyboard) when shown
    ///   - shownAboveView: hack, optional view above which this vc should be presented. (it uses the height/position of the provided view to adjust it's height, assuming this vc is presented behind it)
    init(mode: Mode, startEditingWhenShown: Bool = true, shownAboveView: UIView? = nil) {
        self.mode = mode
        self.startEditingWhenShown = startEditingWhenShown
        self.shownAboveView = shownAboveView
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        containerView.backgroundColor = .dynamic(.Neutral_10)

        setupTextView()
        containerView.addSubview(textView)
        textView.snp.makeConstraints { make in
            make.top.equalToSuperview()
                .inset(CommentViewController.margin / 2.0) // textView is higher so it takes half of the top margin
            make.leading.trailing.equalToSuperview().inset(CommentViewController.margin)
            textViewHeightConstraint = make.height.equalTo(textViewHeight).priority(.high).constraint
        }

        setupCommentButton()
        containerView.addSubview(commentButton)
        commentButton.snp.makeConstraints { make in
            make.top.equalTo(textView.snp.bottom).offset(CommentViewController.margin / 2.0)
            make.trailing.equalToSuperview().offset(-CommentViewController.margin)
            make.height.equalTo(CommentViewController.commentButtonHeight).priority(.required)
            if mode == .addComment || mode == .edit {
                make.width.equalToSuperview().multipliedBy(0.5).offset(-CommentViewController.margin - 6)
            }
        }

        setupCancelButton()
        containerView.addSubview(cancelButton)
        cancelButton.snp.makeConstraints { make in
            make.top.equalTo(textView.snp.bottom).offset(CommentViewController.margin / 2.0)
            if mode == .add {
                make.trailing.equalTo(commentButton.snp.leading).offset(-8)
            } else {
                make.leading.equalToSuperview().offset(CommentViewController.margin)
            }
            make.height.equalTo(CommentViewController.commentButtonHeight).priority(.required)
            make.width.equalTo(commentButton.snp.width)
        }

        if mode == .add {
            setupFlagButton()
            containerView.addSubview(flagButton)
            flagButton.snp.makeConstraints { make in
                make.width.equalTo(56)
                make.height.equalTo(40)
                make.leading.equalToSuperview()
                make.centerY.equalTo(commentButton.snp.centerY)
            }
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
        roundedShadowView.topStrokeColor = .dynamicColor(light: .Neutral_04, dark: .Neutral_07)
    }

    private func isNoteDidSet() {
        if mode == .add {
            if flagButton == nil {
                setupFlagButton()
            }
            if isNote {
                flagButton.setImage(UIImage(systemName: "flag.fill"), for: .normal)
            } else {
                flagButton.setImage(UIImage(systemName: "flag"), for: .normal)
            }
            flagButton.setNeedsUpdateConfiguration()
        }
        if commentButton == nil {
            setupCommentButton()
        }
        commentButton.setNeedsUpdateConfiguration()
        textView.placeholderText = placeholderText
    }

    /// The comment button is enabled when the text is not empty (or doesn't consist entirely of whitespace and new lines)
    private func updateCommentButtonEnabled() {
        commentButton.isEnabled = !commentText.isEmpty
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // install keyboard observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        if startEditingWhenShown {
            textView.becomeFirstResponder()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // once it's layed out
        setupTextViewObservers()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        removeTextViewObservers()
        // remove keyboard observers
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - views

extension CommentViewController {
    private func setupTextView() {
        textView.placeholderText = placeholderText
        textView.textColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.delegate = self
    }

    private func setupFlagButton() {
        guard flagButton == nil else { return }
        let imageConfig = UIImage.SymbolConfiguration(textStyle: .subheadline)
            .applying(UIImage.SymbolConfiguration(weight: .bold))
        var config = UIButton.Configuration.plain()
        config.preferredSymbolConfigurationForImage = imageConfig
        flagButton = ButtonWithTapAreaInsets(
            configuration: config,
            primaryAction: UIAction(image: UIImage(systemName: "flag")) { [weak self] _ in
                guard let self = self else { return }
                self.isNote = !self.isNote
            }
        )
        flagButton.configurationUpdateHandler = { [weak self] button in
            guard let self = self else { return }
            var config = button.configuration
            config?.baseForegroundColor = self.isNote
                ? .Orange_03
                : .dynamicColor(light: .Neutral_06, dark: .Neutral_05)
            button.configuration = config
        }
        flagButton.setNeedsUpdateConfiguration()
    }

    private func setupCancelButton() {
        var config = UIButton.Configuration.filled()
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        config.baseBackgroundColor = .dynamic(.Neutral_09)
        config.baseForegroundColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
        config.background.strokeColor = .dynamicColor(light: .Neutral_04, dark: .Neutral_07)
        config.cornerStyle = .fixed
        config.background.cornerRadius = 8
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.preferredFont(forTextStyle: .subheadline)
            return outgoing
        }
        cancelButton = ButtonWithTapAreaInsets(
            configuration: config,
            primaryAction: UIAction(title: "Cancel") { [weak self] _ in
                self?.onCancel?()
            }
        )
        // more vertical tap area as button is only 32 points high
        cancelButton.tapAreaInsets = UIEdgeInsets(top: -16, left: 0, bottom: -16, right: 0)
    }

    private func setupCommentButton() {
        guard commentButton == nil else { return }
        var commentConfig = UIButton.Configuration.filled()
        commentConfig.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        commentConfig.baseForegroundColor = .Neutral_01
        commentConfig.background.cornerRadius = 8
        commentConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.preferredFont(forTextStyle: .subheadline)
            return outgoing
        }
        let commentButtonText = mode == .edit ? "Save" : "Comment"
        commentButton = ButtonWithTapAreaInsets(
            configuration: commentConfig,
            primaryAction: UIAction(title: commentButtonText) { [weak self] _ in
                self?.onDone?()
            }
        )
        // more vertical tap area as button is only 32 points high
        commentButton.tapAreaInsets = UIEdgeInsets(top: -16, left: 0, bottom: -16, right: 0)
        commentButton.configurationUpdateHandler = { [weak self] button in
            guard let self = self else { return }
            var config = button.configuration
            config?.baseBackgroundColor = self.isNote ? .Orange_03 : .Primary_Blue_04
            button.configuration = config
        }
        commentButton.setNeedsUpdateConfiguration()
        updateCommentButtonEnabled()
    }
}

// MARK: - Card dragging delegate

extension CommentViewController: CardDraggingDelegate {
    func cardOverlayTapped() {
        textView.resignFirstResponder()
        onCancel?()
    }

    func cardHeightUpdated(_ height: CGFloat) {
        onHeightUpdated?(height)
    }
}

// MARK: - Card presentable

extension CommentViewController: CardPresentable {
    // subtract bottom safe area insets from keyboard as card dragging adds it to the card anyway
    func extraSpaceForKeyboard(cardContainer: UIView) -> CGFloat {
        max(keyboardHeightInWindow - cardContainer.safeAreaInsets.bottom, 0)
    }

    func height(forContainer cardContainer: UIView, cardPosition: CardPosition) -> CGFloat {
        if cardPosition == .medium {
            // just show the text view so it can be used to trigger the editing
            return CommentViewController.margin + textViewHeight + (shownAboveView?.frame.height ?? 0.0)
        }

        return CommentViewController.margin + textViewHeight
            + CommentViewController.commentButtonHeight + CommentViewController.margin
            + max(extraSpaceForKeyboard(cardContainer: cardContainer), shownAboveView?.frame.height ?? 0.0)
    }

    func drivingScrollView() -> UIScrollView? {
        textView
    }
}

// MARK: - keyboard handling

extension CommentViewController {
    /// Recalculate the `keyboardHeightInWindow` on keyboard frame change and update the card height (and possibly
    /// also the text view height)
    @objc func keyboardWillChangeFrame(notification: NSNotification) {
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

extension CommentViewController {
    /// Observe the text view properties
    private func setupTextViewObservers() {
        textViewObservation = textView.observe(\.contentSize) { [weak self] _, _ in
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

        // 38 is the height for the default font size, we just need some more less correct value here so the text view height is not initially 0
        let minTextViewHeight = 38.0

        // it cannot grow above the screen height (also taking into account the keyboard height)
        let availableSpaceInContainer = cardContainer.frame.height - cardContainer.safeAreaInsets.top
            - cardContainer.safeAreaInsets.bottom
        let contentHeight = 2 * CommentViewController.margin + CommentViewController.commentButtonHeight
        let maxTextViewHeight = availableSpaceInContainer - contentHeight -
            extraSpaceForKeyboard(cardContainer: cardContainer)

        let newTextViewHeight = min(max(textView.contentSize.height, minTextViewHeight), maxTextViewHeight)

        guard newTextViewHeight != textViewHeight else { return false }
        textViewHeight = newTextViewHeight
        return true
    }
}

// MARK: - text view delegate

extension CommentViewController: UITextViewDelegate {
    func textViewShouldBeginEditing(_: UITextView) -> Bool {
        if let cardDragging = cardDragging, cardDragging.position == .medium {
            cardDragging.setPosition(.max, withVelocity: 0, animated: true)
        }
        return true
    }

    func textViewDidChange(_: UITextView) {
        updateCommentButtonEnabled()
    }
}
