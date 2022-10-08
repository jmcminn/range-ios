import SnapKit
import UIKit

/// Subclass UITextView to add support for the placeholder text
class UITextViewWithPlaceholder: UITextView {
    private let placeholderLabel = UILabel()

    var placeholderText: String? {
        didSet {
            placeholderLabel.text = placeholderText
            placeholderLabel.sizeToFit()
        }
    }

    /// when text changes updates the placeholder visibility (called when setting text programmatically)
    override var text: String! {
        didSet {
            placeholderLabel.isHidden = hasText
        }
    }

    /// update the placeholder position when the text insets changes
    override var textContainerInset: UIEdgeInsets {
        didSet {
            placeholderLabel.snp.remakeConstraints { make in
                // 5 and 0.5 is derived experimentally
                make.leading.equalToSuperview().inset(textContainerInset.left + 5)
                make.top.equalToSuperview().offset(textContainerInset.top + 0.5)
            }
        }
    }

    init(placeholderText: String) {
        self.placeholderText = placeholderText
        super.init(frame: .zero, textContainer: nil)
        setupPlaceholderLabel()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textChanged),
            name: UITextView.textDidChangeNotification,
            object: self
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// show or hide the placeholder depending on the content of the text view when user types in the text
    @objc func textChanged(notification _: NSNotification) {
        placeholderLabel.isHidden = hasText
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// UITextView doesn't support placeholder, create a label for placeholder
    private func setupPlaceholderLabel() {
        placeholderLabel.font = UIFont.preferredFont(forTextStyle: .body)
        placeholderLabel.textColor = .dynamicColor(light: .Neutral_05, dark: .Neutral_05)
        placeholderLabel.backgroundColor = .clear
        placeholderLabel.adjustsFontForContentSizeCategory = true
        placeholderLabel.text = placeholderText
        placeholderLabel.sizeToFit()
        addSubview(placeholderLabel)
        placeholderLabel.snp.makeConstraints { make in
            // 5 and 0.5 is derived experimentally
            make.leading.equalToSuperview().inset(textContainerInset.left + 5)
            make.top.equalToSuperview().offset(textContainerInset.top + 0.5)
        }
    }
}
