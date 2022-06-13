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

    /// callback for Done accessory button
    var onDone: (() -> Void)?

    /// whether the bordered background should hug the text (`true`) or extend to the view bounds (`false`)
    var contentHugging: Bool = true {
        didSet {
            setNeedsLayout()
        }
    }

    init() {
        super.init(frame: .zero)

        buildViews()
        updateColors()
    }

    /// Adapt CG colors to interface style change
    public func updateColors() {
        backgroundView.layer.borderColor = UIColor.dynamicColor(light: .Neutral_03, dark: .Neutral_08).cgColor
    }

    private func buildViews() {
        backgroundColor = .dynamicColor(light: .Neutral_01, dark: .Neutral_10)

        buildBackgroundView()
        buildTextView()

        addSubview(backgroundView)
        addSubview(textView)
        textView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        /// adapt the background height to content size if contentHugging is enabled
        let backgroundHeight = contentHugging
            ? textView.contentSize.height
            : bounds.height
        backgroundView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: backgroundHeight)
    }

    private func buildBackgroundView() {
        backgroundView.backgroundColor = .dynamicColor(light: .Neutral_02, dark: .Neutral_09)
        backgroundView.layer.cornerRadius = 16
        backgroundView.layer.borderWidth = 1
    }

    private func buildTextView() {
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
        textView.inputAccessoryView = buildInputAccessoryView()
    }

    /// Create "Done" button that will be shown above the keyboard
    private func buildInputAccessoryView() -> UIView {
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
