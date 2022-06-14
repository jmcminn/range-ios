import SnapKit
import UIKit

/// A wrapper for UITextView that adds a rounded border
///
/// - Warning: some colors need to be manually updated on user interface style change (dark/light)
///             as it's applied as CGColor - use `updateColors` function for this.
class TextView: UIView {
    /// wrapped text view, exposed for adding delegate
    let textView = UITextView()

    private let backgroundView = UIView()
    private let placeholderLabel = UILabel()

    /// callback for Done accessory button
    var onDone: (() -> Void)?

    /// whether the bordered background should hug the text (`true`) or extend to the view bounds (`false`)
    var contentHugging: Bool = true {
        didSet {
            setNeedsLayout()
        }
    }

    init(placeholderText: String) {
        super.init(frame: .zero)

        backgroundColor = .dynamicColor(light: .Neutral_01, dark: .Neutral_10)

        setupBackgroundView()
        setupTextView()
        setupPlaceholderLabel(placeholderText: placeholderText)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textChanged),
            name: UITextView.textDidChangeNotification,
            object: textView
        )

        updateColors()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// show or hide the placeholder depending on the content of the text view
    @objc func textChanged(notification _: NSNotification) {
        placeholderLabel.isHidden = textView.hasText
    }

    /// Adapt CG colors to interface style change
    public func updateColors() {
        backgroundView.layer.borderColor = UIColor.dynamicColor(light: .Neutral_03, dark: .Neutral_08).cgColor
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        /// adapt the background height to content size if contentHugging is enabled
        let backgroundHeight = contentHugging
            ? textView.contentSize.height
            : bounds.height
        backgroundView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: backgroundHeight)
    }

    private func setupBackgroundView() {
        backgroundView.backgroundColor = .dynamicColor(light: .Neutral_02, dark: .Neutral_09)
        backgroundView.layer.cornerRadius = 16
        backgroundView.layer.borderWidth = 1
        addSubview(backgroundView)
    }

    private func setupTextView() {
        textView.backgroundColor = .clear
        // we need some scroll indicator insets as the borders are rounded
        textView.scrollIndicatorInsets = UIEdgeInsets(top: 5, left: 0, bottom: 5, right: 5)
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.automaticallyAdjustsScrollIndicatorInsets = false
        textView.contentInsetAdjustmentBehavior = .always
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.textColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.inputAccessoryView = setupInputAccessoryView()
        addSubview(textView)
        textView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    /// UITextView doesn't support placeholder, create a label for placeholder
    private func setupPlaceholderLabel(placeholderText: String) {
        placeholderLabel.font = UIFont.preferredFont(forTextStyle: .body)
        placeholderLabel.textColor = .dynamicColor(light: .Neutral_05, dark: .Neutral_05)
        placeholderLabel.backgroundColor = .clear
        placeholderLabel.adjustsFontForContentSizeCategory = true
        placeholderLabel.text = placeholderText
        placeholderLabel.sizeToFit()
        addSubview(placeholderLabel)
        placeholderLabel.snp.makeConstraints { make in
            // 12 is the text container inset, 5 and 0.5 is derived experimentally
            make.leading.equalToSuperview().inset(12 + 5)
            make.top.equalToSuperview().offset(12 + 0.5)
        }
    }

    /// Create "Done" button that will be shown above the keyboard
    private func setupInputAccessoryView() -> UIView {
        // the width doesn't matter, it'll be equal to the keyboard(screen) width
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 80))
        view.backgroundColor = .dynamicColor(light: .Neutral_01, dark: .Neutral_10)
        let doneButton = UIButton(
            configuration: UIButton.Configuration.bottomNextButton(),
            primaryAction: UIAction(
                title: String(localized: "Done")
            ) { [weak self] _ in self?.onDone?() }
        )
        view.addSubview(doneButton)
        doneButton.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
            make.height.equalTo(48)
        }
        return view
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
