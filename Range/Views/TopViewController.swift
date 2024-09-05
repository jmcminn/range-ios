import UIKit

/// The view displayed at the top of the screen that looks similar to navigation bar (but is a custom view)
class TopViewController: UIViewController {
    private let iconName: String?
    private let onBack: (() -> Void)?

    private var backButton: UIButton?
    private let imageAndTitle = UIStackView()
    private var imageView: UIImageView?
    private let titleLabel = UILabel()
    private let rightAction: UIAction?
    // the button for the rightAction
    private(set) var rightButton: UIButton?
    private var dataSyncIndicatorView: DataSyncIndicatorView?

    private var font: UIFont {
        ._preferredFont(forTextStyle: .callout, symbolicTraits: .traitBold)
    }

    private let userDataSyncState: UserDataSyncState?
    /// combine observers
    var onDataSyncButtonTapped: (() -> Void)?

    ///
    /// - Parameters:
    ///   - rightAction - the button displayed in the right of the bar
    init(
        iconName: String? = nil,
        title: String,
        onBack: (() -> Void)? = nil,
        rightAction: UIAction? = nil,
        userDataSyncState: UserDataSyncState? = nil
    ) {
        self.iconName = iconName
        titleLabel.text = title
        self.onBack = onBack
        self.rightAction = rightAction
        self.userDataSyncState = userDataSyncState
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateShadow()

        view.backgroundColor = .dynamic(.Neutral_10)

        let bottomStroke = UIView()
        bottomStroke.backgroundColor = .dynamicColor(light: .Neutral_04,
                                                     dark: .Neutral_10) // in dark mode the same color as background as we don't want the stroke
        view.addSubview(bottomStroke)
        bottomStroke.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(1)
        }

        imageAndTitle.axis = .horizontal
        imageAndTitle.distribution = .equalSpacing
        imageAndTitle.spacing = 8
        imageAndTitle.alignment = .trailing

        setupImageView()
        if let imageView = imageView {
            imageAndTitle.addArrangedSubview(imageView)
        }

        setupTitleLabel()
        imageAndTitle.addArrangedSubview(titleLabel)
        view.addSubview(imageAndTitle)
        imageAndTitle.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-10)
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top).offset(10)
        }

        setupBackButton()
        if let backButton {
            view.addSubview(backButton)
            backButton.snp.makeConstraints { make in
                make.width.height.equalTo(40)
                make.leading.equalToSuperview()
                make.centerY.equalTo(imageAndTitle.snp.centerY)
            }
        }

        setupRightButton()
        if let rightButton {
            view.addSubview(rightButton)
            rightButton.snp.makeConstraints { make in
                make.width.height.equalTo(40)
                make.trailing.equalToSuperview().inset(8)
                make.centerY.equalTo(imageAndTitle.snp.centerY)
            }
        }
        
        setupDataSyncIndicatorView()
        if let dataSyncIndicatorView {
            view.addSubview(dataSyncIndicatorView)
            dataSyncIndicatorView.snp.makeConstraints { make in
                if let rightButton {
                    make.trailing.equalTo(rightButton.snp.leading).offset(-8)
                } else {
                    make.trailing.equalToSuperview().inset(8)
                }
                make.centerY.equalTo(imageAndTitle.snp.centerY)
            }
        }
    }

    // Make sure that image/label is centered horizontally but not when if the text is long and
    // there's a back button, then we need to take the whole horizontal space
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        let leftLimitingView = backButton
        let rightLimitingView = dataSyncIndicatorView ?? rightButton
        
        imageAndTitle.snp.remakeConstraints { make in
            if let leftLimitingView {
                make.leading.greaterThanOrEqualTo(leftLimitingView.snp.trailing).offset(12)
            } else {
                make.leading.greaterThanOrEqualToSuperview().offset(12)
            }
            if let rightLimitingView {
                make.trailing.lessThanOrEqualTo(rightLimitingView.snp.leading).offset(-12)
            } else {
                make.trailing.lessThanOrEqualToSuperview().offset(-12)
            }
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-10)
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top).offset(10)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateShadow()
        }
    }

    private func updateShadow() {
        let darkMode = traitCollection.userInterfaceStyle == .dark
        if darkMode {
            view.setShadowWithFigmaValues(x: 0, y: 6, blur: 10, opacity: 0.1)
        } else {
            view.setShadowWithFigmaValues(x: 0, y: 3, blur: 6, opacity: 0.1)
        }
    }

    private func setupBackButton() {
        guard onBack != nil else { return }
        let imageConfig = UIImage.SymbolConfiguration(textStyle: .body)
            .applying(UIImage.SymbolConfiguration(weight: .bold))
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = .dynamic(.Neutral_04)
        config.preferredSymbolConfigurationForImage = imageConfig
        backButton = UIButton(
            configuration: config,
            primaryAction: UIAction(image: UIImage(systemName: "chevron.backward")) { [weak self] _ in
                self?.onBack?()
            }
        )
    }

    private func setupRightButton() {
        guard let rightAction else { return }
        let imageConfig = UIImage.SymbolConfiguration(textStyle: .body)
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = .dynamic(.Neutral_04)
        config.preferredSymbolConfigurationForImage = imageConfig
        rightButton = RangeButton(configuration: config, primaryAction: rightAction)
    }
    
    private func setupDataSyncIndicatorView() {
        guard let userDataSyncState else { return }
        dataSyncIndicatorView = DataSyncIndicatorView(userDataSyncState)
        dataSyncIndicatorView?.onTapped = onDataSyncButtonTapped
    }

    private func setupImageView() {
        guard let iconName = iconName else { return }
        imageView = UIImageView(image: UIImage(
            systemName: iconName,
            withConfiguration: UIImage.SymbolConfiguration(font: font)
        ))
        imageView?.setContentCompressionResistancePriority(.required, for: .horizontal)
        imageView?.tintColor = .dynamic(.Neutral_04)
    }

    private func setupTitleLabel() {
        titleLabel.textColor = .dynamic(.Neutral_04)
        titleLabel.font = font
        titleLabel.adjustsFontForContentSizeCategory = true
    }
}
