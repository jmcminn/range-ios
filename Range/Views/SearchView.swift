import UIKit

/// Search view is a styled search field wrapped in a view with a border and a search icon

/// - Warning: some colors need to be manually updated on user interface style change (dark/light)
///             as it's applied as CGColor - use `updateColors` function for this.
class SearchView: UIView {
    /// Force unwrapped - don't use before `setupIcon`
    private var iconView: UIImageView!
    private var textField: UITextField!

    init(placeholderText: String) {
        super.init(frame: .zero)

        setupView()
        setupIcon()
        setupTextField(placeholderText: placeholderText)
        updateColors()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // alpha is 1 for frame height >= 40 then drops by 0.1 from 40 till 30
        let alpha = frame.height >= 40
            ? 1.0
            : max(frame.height - 30, 0) / 10.0
        // if the view is getting lower let's hide the internal views
        iconView.alpha = alpha
        textField.alpha = alpha
    }

    /// Setup the background, corner of the view
    private func setupView() {
        layer.cornerRadius = 12
        layer.borderWidth = 1
        backgroundColor = .dynamicColor(light: .Neutral_02, dark: .Neutral_09)
    }

    /// Add the magnifying glass icon
    private func setupIcon() {
        let icon = UIImage(
            systemName: "magnifyingglass",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        )
        iconView = UIImageView(image: icon)
        iconView.tintColor = UIColor.Neutral_05
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.setContentHuggingPriority(.required, for: .vertical)
        addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.left.equalTo(12)
            make.centerY.equalToSuperview()
        }
    }

    /// Setup the text field used for entering the search term
    private func setupTextField(placeholderText: String) {
        textField = UITextField()
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholderText,
            attributes: [.foregroundColor: UIColor.Neutral_05]
        )
        textField.font = UIFont.preferredFont(forTextStyle: .body)
        textField.adjustsFontForContentSizeCategory = true
        textField.tintColor = .Primary_Blue_04
        addSubview(textField)
        textField.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalTo(iconView.snp.right).offset(12)
            make.right.equalToSuperview()
        }
    }

    /// Adapt CG colors to interface style change
    public func updateColors() {
        layer.borderColor = UIColor.dynamicColor(light: .Neutral_03, dark: .Neutral_08).cgColor
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
