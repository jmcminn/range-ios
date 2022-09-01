import UIKit

/// Different button configurations used in the app
extension UIButton.Configuration {
    /// Configuration used for the "back" button in the bottom navigation
    static func bottomBackButton() -> UIButton.Configuration {
        let imageConfig = UIImage.SymbolConfiguration(textStyle: .footnote)
            .applying(UIImage.SymbolConfiguration(weight: .regular))
        var config = UIButton.Configuration.filled()
        config.contentInsets = NSDirectionalEdgeInsets(
            top: 14,
            leading: 0,
            bottom: 14,
            trailing: 0
        )
        config.baseBackgroundColor = .dynamicColor(light: .Neutral_02, dark: .Neutral_09)
        config.baseForegroundColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
        config.background.cornerRadius = 12
        config.background.strokeColor = .dynamicColor(light: .Neutral_03, dark: .Neutral_07)
        config.preferredSymbolConfigurationForImage = imageConfig
        config.imagePlacement = .leading
        config.imagePadding = 5
        return config
    }

    /// Configuration used for the "next" button in the bottom navigation
    static func bottomNextButton(imagePlacement: NSDirectionalRectEdge = .trailing) -> UIButton.Configuration {
        let imageConfig = UIImage.SymbolConfiguration(textStyle: .footnote)
            .applying(UIImage.SymbolConfiguration(weight: .regular))
        var config = UIButton.Configuration.filled()

        config.contentInsets = NSDirectionalEdgeInsets(
            top: 14,
            leading: 0,
            bottom: 14,
            trailing: 0
        )
        config.baseBackgroundColor = .Primary_Blue_04
        config.baseForegroundColor = .Neutral_01
        config.background.cornerRadius = 12
        config.background.strokeColor = .dynamicColor(light: .Primary_Blue_04, dark: .Primary_Blue_06)
        config.preferredSymbolConfigurationForImage = imageConfig
        config.imagePlacement = imagePlacement
        config.imagePadding = 5
        return config
    }

    static func iconButton(backgroundColor: UIColor, strokeColor: UIColor, cornerRadius: CGFloat = 24) -> UIButton
        .Configuration
    {
        let imageConfig = UIImage.SymbolConfiguration(textStyle: .caption1)
            .applying(UIImage.SymbolConfiguration(weight: .bold))
        var config = UIButton.Configuration.filled()

        config.baseBackgroundColor = backgroundColor
        config.baseForegroundColor = .Neutral_01
        config.background.cornerRadius = cornerRadius
        config.background.strokeColor = strokeColor
        config.preferredSymbolConfigurationForImage = imageConfig
        return config
    }
}
