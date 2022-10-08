import Foundation
import SnapKit
import UIKit

class AddCommentViewController: UIViewController, NonModalCardCoordinating {
    var cardDragging: NonModalCardDragging? {
        didSet { cardDragging?.delegate = self }
    }

    var onCancel: (() -> Void)?

    // top/left/bottom/right margins for views layout
    private static let margin = 16.0
    private static let commentButtonHeight = 32.0

    /// Whether user is creating a note or a comment
    private(set) var isNote: Bool = false {
        didSet { isNoteDidSet() }
    }

    private var placeholderText: String {
        isNote ? "Add an actionable note..." : "Add a comment..."
    }

    private var textView: UITextViewWithPlaceholder!
    private var flagButton: ButtonWithTapAreaInsets!
    private var commentButton: ButtonWithTapAreaInsets!

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

    override func viewDidLoad() {
        super.viewDidLoad()
        containerView.backgroundColor = .dynamicColor(light: .Neutral_01, dark: .Neutral_10)

        setupTextView()
        containerView.addSubview(textView)
        textView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(AddCommentViewController.margin)
            textViewHeightConstraint = make.height.equalTo(textViewHeight).priority(.high).constraint
        }

        setupCommentButton()
        containerView.addSubview(commentButton)
        commentButton.snp.makeConstraints { make in
            make.top.equalTo(textView.snp.bottom)
            make.trailing.equalToSuperview().offset(-AddCommentViewController.margin)
            make.height.equalTo(AddCommentViewController.commentButtonHeight).priority(.required)
        }

        setupFlagButton()
        containerView.addSubview(flagButton)
        flagButton.snp.makeConstraints { make in
            make.width.equalTo(56)
            make.height.equalTo(40)
            make.leading.equalToSuperview()
            make.centerY.equalTo(commentButton.snp.centerY)
        }
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
        // stroke visibility in dark mode depends on showDarkBorder (if false same color as background)
        roundedShadowView.topStrokeColor = darkMode ? .Neutral_10 : .Neutral_04
    }

    private func isNoteDidSet() {
        if isNote {
            flagButton.setImage(UIImage(systemName: "flag.fill"), for: .normal)
        } else {
            flagButton.setImage(UIImage(systemName: "flag"), for: .normal)
        }
        flagButton.setNeedsUpdateConfiguration()
        commentButton.setNeedsUpdateConfiguration()
        textView.placeholderText = placeholderText
    }

    /// The comment button is enabled when the text is not empty (or doesn't consist entirely of whitespace and new lines)
    private func updateCommentButtonEnabled() {
        commentButton.isEnabled = !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        textView.becomeFirstResponder()
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

extension AddCommentViewController {
    private func setupTextView() {
        textView = UITextViewWithPlaceholder(placeholderText: placeholderText)
        textView.textColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.delegate = self
    }

    private func setupFlagButton() {
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
        flagButton.configurationUpdateHandler = { [unowned self] button in
            var config = button.configuration
            config?.baseForegroundColor = self.isNote
                ? .Orange_03
                : .dynamicColor(light: .Neutral_06, dark: .Neutral_05)
            button.configuration = config
        }
        flagButton.setNeedsUpdateConfiguration()
    }

    private func setupCommentButton() {
        var commentConfig = UIButton.Configuration.filled()
        commentConfig.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        commentConfig.baseForegroundColor = .Neutral_01
        commentConfig.background.cornerRadius = 8
        commentConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.preferredFont(forTextStyle: .subheadline)
            return outgoing
        }
        commentButton = ButtonWithTapAreaInsets(
            configuration: commentConfig,
            primaryAction: UIAction(title: "Comment") { [weak self] _ in
                // TODO: 291 here
                self?.textView.resignFirstResponder()
            }
        )
        // more vertical tap area as button is only 32 points high
        commentButton.tapAreaInsets = UIEdgeInsets(top: -16, left: 0, bottom: -16, right: 0)
        commentButton.configurationUpdateHandler = { [unowned self] button in
            var config = button.configuration
            config?.baseBackgroundColor = self.isNote ? .Orange_03 : .Primary_Blue_04
            button.configuration = config
        }
        commentButton.setNeedsUpdateConfiguration()
        updateCommentButtonEnabled()
    }
}

// MARK: - Card dragging delegate

extension AddCommentViewController: CardDraggingDelegate {
    func cardOverlayTapped() {
        textView.resignFirstResponder()
        onCancel?()
    }
}

// MARK: - Card presentable

extension AddCommentViewController: CardPresentable {
    // subtract bottom safe area insets from keyboard as card dragging adds it to the card anyway
    func extraSpaceForKeyboard(cardContainer: UIView) -> CGFloat {
        max(keyboardHeightInWindow - cardContainer.safeAreaInsets.bottom, 0)
    }

    func height(forContainer cardContainer: UIView, cardPosition: CardPosition) -> CGFloat {
        if cardPosition == .medium {
            return -1 // not supported
        }

        return AddCommentViewController.margin + textViewHeight +
            AddCommentViewController.commentButtonHeight + AddCommentViewController.margin
            + extraSpaceForKeyboard(cardContainer: cardContainer)
    }

    func drivingScrollView() -> UIScrollView? {
        textView
    }
}

// MARK: - keyboard handling

extension AddCommentViewController {
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

extension AddCommentViewController {
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
        let contentHeight = 2 * AddCommentViewController.margin + AddCommentViewController.commentButtonHeight
        let maxTextViewHeight = availableSpaceInContainer - contentHeight -
            extraSpaceForKeyboard(cardContainer: cardContainer)

        let newTextViewHeight = min(max(textView.contentSize.height, minTextViewHeight), maxTextViewHeight)

        guard newTextViewHeight != textViewHeight else { return false }
        textViewHeight = newTextViewHeight
        return true
    }
}

// MARK: - text view delegate

extension AddCommentViewController: UITextViewDelegate {
    func textViewDidChange(_: UITextView) {
        updateCommentButtonEnabled()
    }
}
