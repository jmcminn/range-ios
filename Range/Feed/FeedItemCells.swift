import Foundation
import RealmSwift
import UIKit

class FeedItemCells {
    /// The leading layout margin for content, all cells should display the main content with this margin
    /// Some views might still be rendered outside this margin (avatars, etc.)
    static let leadingContentLayoutMargin = 56.0
    /// This is the the leading margin at which the vertical dashed line for the feed is drawn
    static let leadingVerticalLineMargin = 32.0

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

    /// Create a circle view rendered on the feed timeline dashed line for minor updates
    static func minorItemDotView() -> UIView {
        let view = UIView()
        view.layer.cornerRadius = 4
        view.backgroundColor = .dynamic(.Neutral_06)
        view.snp.makeConstraints { make in
            make.width.height.equalTo(8)
        }
        return view
    }
}
