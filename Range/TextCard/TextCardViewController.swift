import Foundation
import SnapKit
import UIKit

/// Card view controller presenting a text view for inserting text
/// It presents the overlay over the presenting view controller.
/// It can be dismissed by tapping the overlay, dragging down or tappin on the close button.
class TextCardViewController: SheetCardViewController {
    private let initialText: String?

    var onTextSaved: ((String) -> Void)?
    private var textView: TextView!
    private var textViewBottomConstraint: Constraint?

    /// Initializer
    ///
    /// - Parameters:
    ///     - title:                         title of the card
    ///     - initialText:                initial text
    ///     - onTextSaved:          callback for saving the text
    init(title: String, initialText: String?, onTextSaved: ((String) -> Void)? = nil) {
        self.initialText = initialText
        super.init(icon: UIImage(systemName: "text.quote"), title: title)
        self.onTextSaved = onTextSaved
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        buildTextView()
        containerView.addSubview(textView)
        textView.snp.makeConstraints { make in
            make.top.equalTo(closeButton.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
//            self.textViewBottomConstraint = make.bottom.equalToSuperview().inset(16).constraint
            self.textViewBottomConstraint = make.bottom.equalTo(containerView.safeAreaLayoutGuide.snp.bottom).inset(16)
                .constraint
        }
    }

    override func height(forContainer cardContainerView: UIView, cardPosition: CardPosition) -> CGFloat {
        if cardPosition == .max {
            // make it max, so it doesn't depend on the content height
            return Double.greatestFiniteMagnitude
        } else {
            return super.height(forContainer: cardContainerView, cardPosition: cardPosition)
        }
    }

    private func buildTextView() {
        textView = TextView(
            placeholderText: "Add a description...",
            doneText: String(localized: "Save"),
            showCancelButton: true
        )
        textView.onDone = { [weak self] in
            self?.dismissCard()
            self?.onTextSaved?(self?.textView.textView.text ?? "")
        }
        textView.onCancel = { [weak self] in
            self?.dismissCard()
        }
        textView.textView.text = initialText
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // install keyboard observers
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        textView.textView.becomeFirstResponder()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // remove keyboard observers
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: keyboard handling

extension TextCardViewController {
    /// Adjust the textView constraints when keyboard shows
    @objc func keyboardWillShow(notification: NSNotification) {
        // Get required info out of the notification
        if let userInfo = notification.userInfo,
           let endValue = userInfo[UIResponder.keyboardFrameEndUserInfoKey],
           let durationValue = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey],
           let curveValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey]
        {
            // Transform the keyboard's frame into our view's coordinate system
            let endRect = containerView.convert((endValue as AnyObject).cgRectValue, from: view.window)

            let scrollView = textView.textView
            let scrollRect = scrollView.superview!.convert(scrollView.frame, to: view.window)
            // Find out how much the keyboard overlaps our scroll view
            let keyboardOverlap = scrollRect.maxY - endRect.origin.y - containerView.safeAreaInsets.bottom

            textViewBottomConstraint?.update(inset: keyboardOverlap)

            let duration = (durationValue as AnyObject).doubleValue
            let options = UIView.AnimationOptions(rawValue: UInt((curveValue as AnyObject).integerValue << 16))
            UIView.animate(withDuration: duration!, delay: 0, options: options, animations: {
                self.view.layoutIfNeeded()
            }, completion: nil)
        }
    }

    /// Reset textView constraints when the keyboard hides
    @objc func keyboardWillHide(notification _: NSNotification) {
        textViewBottomConstraint?.update(inset: 16)
    }
}
