import UIKit

/// Different button configurations used in the app
extension UIButton.Configuration {
    /// Configuration used for the gray button with red text
    static func redButton() -> UIButton.Configuration {
        let imageConfig = UIImage.SymbolConfiguration(textStyle: .footnote)
            .applying(UIImage.SymbolConfiguration(weight: .bold))
        var config = UIButton.Configuration.filled()
        config.contentInsets = NSDirectionalEdgeInsets(
            top: 14,
            leading: 0,
            bottom: 14,
            trailing: 0
        )
        config.baseBackgroundColor = .dynamic(.Neutral_09)
        config.baseForegroundColor = .Red_03
        config.cornerStyle = .fixed
        config.background.cornerRadius = 12
        config.background.strokeColor = .dynamic(.Neutral_07)
        config.preferredSymbolConfigurationForImage = imageConfig
        config.imagePlacement = .leading
        config.imagePadding = 5
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = ._preferredFont(forTextStyle: .body, symbolicTraits: .traitBold)
            return outgoing
        }
        return config
    }

    /// Configuration used for the "back" button in the bottom navigation
    static func grayButton() -> UIButton.Configuration {
        let imageConfig = UIImage.SymbolConfiguration(textStyle: .footnote)
            .applying(UIImage.SymbolConfiguration(weight: .semibold))
        var config = UIButton.Configuration.filled()
        config.contentInsets = NSDirectionalEdgeInsets(
            top: 14,
            leading: 0,
            bottom: 14,
            trailing: 0
        )
        config.baseBackgroundColor = .dynamic(.Neutral_09)
        config.baseForegroundColor = .dynamic(.Neutral_04)
        config.cornerStyle = .fixed
        config.background.cornerRadius = 12
        config.background.strokeColor = .dynamic(.Neutral_07)
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
            .applying(UIImage.SymbolConfiguration(weight: .semibold))
        var config = UIButton.Configuration.filled()
        config.contentInsets = NSDirectionalEdgeInsets(
            top: 14,
            leading: 0,
            bottom: 14,
            trailing: 0
        )
        config.baseBackgroundColor = .dynamic(.Neutral_09)
        config.baseForegroundColor = .dynamic(.Neutral_04)
        config.cornerStyle = .fixed
        config.background.cornerRadius = cornerRadius
        config.background.strokeColor = .dynamic(.Neutral_07)
        config.preferredSymbolConfigurationForImage = imageConfig
        config.imagePlacement = imagePlacement
        config.imagePadding = 5
        return config
    }

    /// Configuration used for the "next" button in the bottom navigation
    static func blueButton(
        imageTextStyle: UIFont.TextStyle = .footnote,
        imagePlacement: NSDirectionalRectEdge = .trailing,
        cornerRadius: CGFloat = 12,
        horizontalInsets: CGFloat = 0
    ) -> UIButton.Configuration {
        let imageConfig = UIImage.SymbolConfiguration(textStyle: imageTextStyle)
            .applying(UIImage.SymbolConfiguration(weight: .semibold))
        var config = UIButton.Configuration.filled()

        config.contentInsets = NSDirectionalEdgeInsets(
            top: 14,
            leading: horizontalInsets,
            bottom: 14,
            trailing: horizontalInsets
        )
        config.baseBackgroundColor = .Primary_Blue_04
        config.baseForegroundColor = .Neutral_01
        config.cornerStyle = .fixed
        config.background.cornerRadius = cornerRadius
        config.background.strokeColor = .dynamicColor(light: .Primary_Blue_04, dark: .Primary_Blue_06)
        config.preferredSymbolConfigurationForImage = imageConfig
        config.imagePlacement = imagePlacement
        config.imagePadding = 5
        return config
    }

    static func iconButton(
        backgroundColor: UIColor,
        foregroundColor: UIColor = .Neutral_01,
        strokeColor: UIColor,
        cornerRadius: CGFloat = 24,
        imagePointSize: CGFloat? = nil
    ) -> UIButton
        .Configuration
    {
        // size 18 here corresponds to 22 in the design. I don't know where does the difference come from
        let imageConfig: UIImage.SymbolConfiguration
        if let imagePointSize = imagePointSize {
            imageConfig = UIImage.SymbolConfiguration(pointSize: imagePointSize)
        } else {
            imageConfig = UIImage.SymbolConfiguration(font: UIFont.systemFont(ofSize: 18, weight: .bold))
        }
        var config = UIButton.Configuration.filled()

        config.contentInsets = .zero
        config.baseBackgroundColor = backgroundColor
        config.baseForegroundColor = foregroundColor
        config.cornerStyle = .fixed
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

        config.baseBackgroundColor = .dynamic(.Neutral_09)
        config.baseForegroundColor = .dynamic(.Neutral_04)
        config.cornerStyle = .fixed
        config.background.cornerRadius = cornerRadius
        config.background.strokeColor = .dynamic(.Neutral_07)
        config.preferredSymbolConfigurationForImage = imageConfig
        return config
    }
}
