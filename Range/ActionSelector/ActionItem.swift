import Foundation

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
    init(title: String? = nil, imageName: String? = nil, handler: (() -> Void)? = nil) {
        self.title = title
        self.imageName = imageName
        self.handler = handler
    }
}
