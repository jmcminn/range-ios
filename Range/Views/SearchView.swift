import UIKit

/// SearchView delegate, needs to be objc protocol because:
/// https://stackoverflow.com/questions/54403315/store-typealias-as-class-type-in-nshashtable
/// btw. the answer https://stackoverflow.com/a/54409652 is only partially right, as adding a Ref doesn't fix anything as
/// the ref is not stored anywhere strongly and is basically gone the moment it's inserted into NSHashTable
/// https://stackoverflow.com/questions/33112559/protocol-doesnt-conform-to-itself
/// So protocol doesn't confirm to itself unless it's an objc one. and NSHashTable needs AnyObject
@objc protocol SearchViewDelegate: AnyObject {
    /// Invoked when the use starts editing.
    @objc optional func searchViewActivated(_: SearchView)
    /// Invoked whenever the text in search view changes.
    @objc optional func searchView(_: SearchView, textDidChange: String)
    /// Invoked when the return button was hit on the keyboard
    @objc optional func searchViewReturnButtonTapped(_: SearchView)
}

/// Search view is a styled search field wrapped in a view with a border and a search icon
class SearchView: UIView {
    /// Force unwrapped - don't use before `setupIcon`
    private var iconView: UIImageView!
    var textField: UITextField!
    private var clearButton: UIButton?

    /// Allows for multiple delegates
    private var delegates = NSHashTable<SearchViewDelegate>.weakObjects()

    init(placeholderText: String, showClearButton: Bool) {
        super.init(frame: .zero)

        setupView()
        setupIcon()
        if showClearButton {
            setupClearButton()
        }
        setupTextField(placeholderText: placeholderText)
        updateClearButtonVisibility()
        updateColors()
    }

    /// Add delegate
    /// No option for removal as delegates are stored weakly
    func addDelegate(_ delegate: SearchViewDelegate) {
        delegates.add(delegate)
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
            make.leading.equalTo(12)
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
        textField.autocapitalizationType = .none
        // don't show the default clear button
        textField.clearButtonMode = .never
        textField.delegate = self
        textField.addTarget(self, action: #selector(textChangedAction), for: .editingChanged)
        addSubview(textField)
        textField.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(iconView.snp.trailing).offset(12)
            if let clearButton = clearButton {
                make.trailing.equalTo(clearButton.snp.leading)
            } else {
                make.trailing.equalToSuperview()
            }
        }
    }

    /// Custom clear button as we need the custom color
    private func setupClearButton() {
        clearButton = UIButton(type: .custom)
        clearButton?.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        clearButton?.imageView?.tintColor = .dynamicColor(light: .Neutral_06, dark: .Neutral_05)
        clearButton?.addTarget(self, action: #selector(clearAction), for: .touchUpInside)
        addSubview(clearButton!)
        clearButton!.snp.makeConstraints { make in
            make.height.equalToSuperview()
            make.width.equalTo(clearButton!.snp.height)
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
        }
    }

    /// Adapt CG colors to interface style change
    private func updateColors() {
        // UIColor.dynamicColor didn't work for overrideUserInterfaceStyle = .dark
        layer.borderColor = chooseColor(light: .Neutral_04, dark: .Neutral_07).cgColor
    }

    private func updateClearButtonVisibility() {
        clearButton?.isHidden = (textField.text == nil || textField.text!.isEmpty)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - actions

extension SearchView {
    @objc func clearAction() {
        textField.text = ""
        textChangedAction()
    }
}

// MARK: - text changed

extension SearchView {
    @objc func textChangedAction() {
        updateClearButtonVisibility()
        delegates.allObjects.forEach { $0.searchView?(self, textDidChange: textField.text ?? "") }
    }
}

// MARK: - textField delegate

extension SearchView: UITextFieldDelegate {
    func textFieldShouldBeginEditing(_: UITextField) -> Bool {
        delegates.allObjects.forEach { $0.searchViewActivated?(self) }
        return true
    }

    func textFieldShouldReturn(_: UITextField) -> Bool {
        delegates.allObjects.forEach { $0.searchViewReturnButtonTapped?(self) }
        return false
    }
}
