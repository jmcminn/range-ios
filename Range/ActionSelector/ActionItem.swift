import Foundation
import UIKit

/// Helper class for definining actions displayed by ``ActionSelectorViewController``
///
/// This class resembles the UIKit.UIAction - if UIAction exposed its `handler` we could use it instead...
///
/// This class should probably be called `UIAction` but ... well, UIKit uses it so let's not do it.
class ActionItem {
    /// Short display title.
    let title: String?
    /// image systemName
    let imageName: String?
    /// action to be performed
    let handler: (() -> Void)?
    /// The style of the action, reusing the styles defined for UIAlertAction. The `cancel` style renders in the same way as the `default`.
    let style: UIAlertAction.Style
    init(
        title: String? = nil,
        imageName: String? = nil,
        handler: (() -> Void)? = nil,
        style: UIAlertAction.Style = .default
    ) {
        self.title = title
        self.imageName = imageName
        self.handler = handler
        self.style = style
    }
}
