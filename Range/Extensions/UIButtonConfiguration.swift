import UIKit

/// Different button configurations used in the app
extension UIButton.Configuration {
    /// Configuration used for the "back" button in the bottom navigation
    static func grayButton() -> UIButton.Configuration {
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

    /// almost black...
    static func blackButton(
        imageTextStyle: UIFont.TextStyle = .footnote,
        imagePlacement: NSDirectionalRectEdge = .trailing,
        cornerRadius: CGFloat = 12
    ) -> UIButton.Configuration {
        let imageConfig = UIImage.SymbolConfiguration(textStyle: imageTextStyle)
            .applying(UIImage.SymbolConfiguration(weight: .regular))
        var config = UIButton.Configuration.filled()
        config.contentInsets = NSDirectionalEdgeInsets(
            top: 14,
            leading: 0,
            bottom: 14,
            trailing: 0
        )
        config.baseBackgroundColor = .Neutral_09
        config.baseForegroundColor = .Neutral_04
        config.background.cornerRadius = cornerRadius
        config.background.strokeColor = .dynamicColor(light: .Neutral_08, dark: .Neutral_07)
        config.preferredSymbolConfigurationForImage = imageConfig
        config.imagePlacement = imagePlacement
        config.imagePadding = 5
        return config
    }

    /// Configuration used for the "next" button in the bottom navigation
    static func blueButton(
        imageTextStyle: UIFont.TextStyle = .footnote,
        imagePlacement: NSDirectionalRectEdge = .trailing,
        cornerRadius: CGFloat = 12
    ) -> UIButton.Configuration {
        let imageConfig = UIImage.SymbolConfiguration(textStyle: imageTextStyle)
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
        config.background.cornerRadius = cornerRadius
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

    static func closeButton(cornerRadius: CGFloat = 16) -> UIButton
        .Configuration
    {
        let imageConfig = UIImage.SymbolConfiguration(textStyle: .caption1)
            .applying(UIImage.SymbolConfiguration(weight: .bold))
        var config = UIButton.Configuration.filled()

        config.baseBackgroundColor = .dynamicColor(light: .Neutral_02, dark: .Neutral_09)
        config.baseForegroundColor = .dynamicColor(light: .Neutral_06, dark: .Neutral_04)
        config.background.cornerRadius = cornerRadius
        config.background.strokeColor = .dynamicColor(light: .Neutral_03, dark: .Neutral_08)
        config.preferredSymbolConfigurationForImage = imageConfig
        return config
    }
}
