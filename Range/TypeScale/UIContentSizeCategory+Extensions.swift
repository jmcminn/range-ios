import Foundation
import UIKit

extension UIContentSizeCategory {
    /// UI display name for content size category following the naming used in
    /// https://developer.apple.com/design/human-interface-guidelines/foundations/typography#specifications
    var _displayName: String {
        switch self {
        case UIContentSizeCategory.extraSmall: return "xSmall"
        case UIContentSizeCategory.small: return "Small"
        case UIContentSizeCategory.medium: return "Medium"
        case UIContentSizeCategory.large: return "Large (Default)"
        case UIContentSizeCategory.extraLarge: return "xLarge"
        case UIContentSizeCategory.extraExtraLarge: return "xxLarge"
        case UIContentSizeCategory.extraExtraExtraLarge: return "xxxLarge"
        case UIContentSizeCategory.accessibilityMedium: return "AX1"
        case UIContentSizeCategory.accessibilityLarge: return "AX2"
        case UIContentSizeCategory.accessibilityExtraLarge: return "AX3"
        case UIContentSizeCategory.accessibilityExtraExtraLarge: return "AX4"
        case UIContentSizeCategory.accessibilityExtraExtraExtraLarge: return "AX5"
        case UIContentSizeCategory.unspecified: return "Unspecified"
        default: return "Unknown"
        }
    }
}
