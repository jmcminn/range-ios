import SnapKit
import UIKit

/// Top view for photo pin selection showing an "Add Location" text
class AddPhotoTopViewController: UIViewController {
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

        let imageConfig = UIImage.SymbolConfiguration(textStyle: .body)
            .applying(UIImage.SymbolConfiguration(weight: .bold))
        let image = UIImage(systemName: "mappin.and.ellipse", withConfiguration: imageConfig)
        let imageView = UIImageView(image: image)
        imageView.tintColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)

        let font = UIFont.preferredFont(forTextStyle: .body)
        let boldFont = UIFont(descriptor: font.fontDescriptor.withSymbolicTraits(.traitBold)!, size: 0)
        let textLabel = UILabel()
        textLabel.text = "Add Location"
        textLabel.textColor = imageView.tintColor
        textLabel.font = boldFont
        textLabel.adjustsFontForContentSizeCategory = true

        let imageAndTitle = UIStackView(arrangedSubviews: [imageView, textLabel])
        imageAndTitle.axis = .horizontal
        imageAndTitle.distribution = .equalSpacing
        imageAndTitle.spacing = 8
        imageAndTitle.alignment = .trailing
        view.addSubview(imageAndTitle)
        imageAndTitle.snp.makeConstraints { make in
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
}
