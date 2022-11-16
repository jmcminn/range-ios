import UIKit

/// The view displayed at the top of the screen that looks similar to navigation bar (but is a custom view)
class ProjectTopViewController: UIViewController {
    private let projectSummary: ProjectSummary
    private var backButton: UIButton!
    private var titleLabel: UILabel!
    var onBack: (() -> Void)?

    init(projectSummary: ProjectSummary) {
        self.projectSummary = projectSummary
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateShadow()

        view.backgroundColor = .dynamicColor(light: .Neutral_01, dark: .Neutral_10)

        let bottomStroke = UIView()
        bottomStroke
            .backgroundColor = .dynamicColor(light: .Neutral_04,
                                             dark: .Neutral_10) // in dark mode the same color as background as we don't want the stroke
        view.addSubview(bottomStroke)
        bottomStroke.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(1)
        }

        setupTitleLabel()
        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-11)
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top).offset(11)
        }

        setupBackButton()
        view.addSubview(backButton)
        backButton.snp.makeConstraints { make in
            make.width.height.equalTo(40)
            make.leading.equalToSuperview()
            make.centerY.equalTo(titleLabel.snp.centerY)
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
        let imageConfig = UIImage.SymbolConfiguration(textStyle: .body)
            .applying(UIImage.SymbolConfiguration(weight: .bold))
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
        config.preferredSymbolConfigurationForImage = imageConfig
        backButton = UIButton(
            configuration: config,
            primaryAction: UIAction(image: UIImage(systemName: "chevron.backward")) { [weak self] _ in
                self?.onBack?()
            }
        )
    }

    private func setupTitleLabel() {
        let font = UIFont.preferredFont(forTextStyle: .subheadline)
        let boldFont = UIFont(descriptor: font.fontDescriptor.withSymbolicTraits(.traitBold)!, size: 0)
        titleLabel = UILabel()
        titleLabel.text = projectSummary.name
        titleLabel.textColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
        titleLabel.font = boldFont
        titleLabel.adjustsFontForContentSizeCategory = true
    }
}
