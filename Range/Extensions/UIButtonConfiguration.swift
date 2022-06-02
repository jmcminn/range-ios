import UIKit

/// Different button configurations used in the app
extension UIButton.Configuration {
    /// Configuration used for the "back" button in the bottom navigation
    static func bottomBackButton() -> UIButton.Configuration {
        let imageConfig = UIImage.SymbolConfiguration(textStyle: .footnote)
            .applying(UIImage.SymbolConfiguration(weight: .regular))
        var config = UIButton.Configuration.filled()
        config.contentInsets = NSDirectionalEdgeInsets(
            top: 15,
            leading: 28,
            bottom: 15,
            trailing: 28
        )
        config.baseBackgroundColor = .dynamicColor(light: .Neutral_02, dark: .Neutral_09)
        config.baseForegroundColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
        config.background.cornerRadius = 12
        config.background.strokeColor = .dynamicColor(light: .Neutral_03, dark: .Neutral_08)
        config.preferredSymbolConfigurationForImage = imageConfig
        config.imagePlacement = .leading
        config.imagePadding = 5
        return config
    }

    /// Configuration used for the "next" button in the bottom navigation
    static func bottomNextButton() -> UIButton.Configuration {
        let imageConfig = UIImage.SymbolConfiguration(textStyle: .footnote)
            .applying(UIImage.SymbolConfiguration(weight: .regular))
        var config = UIButton.Configuration.filled()

        config.contentInsets = NSDirectionalEdgeInsets(
            top: 15,
            leading: 28,
            bottom: 15,
            trailing: 28
        )
        config.baseBackgroundColor = .Primary_Blue_04
        config.baseForegroundColor = .Neutral_01
        config.background.cornerRadius = 12
        config.preferredSymbolConfigurationForImage = imageConfig
        config.imagePlacement = .trailing
        config.imagePadding = 5
        return config
    }
}
