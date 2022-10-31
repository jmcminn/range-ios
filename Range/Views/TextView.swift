import SnapKit
import UIKit

/// A wrapper for UITextView that adds a rounded border
class TextView: UIView {
    /// wrapped text view, exposed for adding delegate
    let textView: UITextViewWithPlaceholder

    private let backgroundView = UIView()

    /// callback for Done accessory button
    var onDone: (() -> Void)?

    init(placeholderText: String) {
        textView = UITextViewWithPlaceholder(placeholderText: placeholderText)

        super.init(frame: .zero)

        backgroundColor = .dynamicColor(light: .Neutral_01, dark: .Neutral_10)

        setupBackgroundView()
        setupTextView()
        updateColors()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
        }
    }

    /// Adapt CG colors to interface style change
    private func updateColors() {
        // UIColor.dynamicColor didn't work for overrideUserInterfaceStyle = .dark
        layer.borderColor = chooseColor(light: .Neutral_03, dark: .Neutral_08).cgColor
    }

    private func setupBackgroundView() {
        backgroundView.backgroundColor = .dynamicColor(light: .Neutral_02, dark: .Neutral_09)
        backgroundView.layer.cornerRadius = 16
        backgroundView.layer.borderWidth = 1
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
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

    /// Create "Done" button that will be shown above the keyboard
    private func setupInputAccessoryView() -> UIView {
        // the width doesn't matter, it'll be equal to the keyboard(screen) width
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 80))
        view.backgroundColor = .dynamicColor(light: .Neutral_01, dark: .Neutral_10)
        let doneButton = UIButton(
            configuration: UIButton.Configuration.blueButton(),
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
