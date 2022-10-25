import Foundation
import RealmSwift
import UIKit

class FeedItemCells {
    static func createMoreButton(handler: @escaping UIActionHandler) -> UIButton {
        let imageConfig = UIImage.SymbolConfiguration(textStyle: .callout)
            .applying(UIImage.SymbolConfiguration(weight: .regular))
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = .dynamicColor(light: .Neutral_06, dark: .Neutral_05)
        config.preferredSymbolConfigurationForImage = imageConfig
        return UIButton(
            configuration: config,
            primaryAction: UIAction(image: UIImage(systemName: "ellipsis"), handler: handler)
        )
    }
}
