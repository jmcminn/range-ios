import Foundation
import UIKit

extension UIFont.TextStyle {
    /// UI display name for UIFont.TextStyle following the naming used in
    /// https://developer.apple.com/design/human-interface-guidelines/foundations/typography#specifications
    var _displayName: String {
        switch self {
        case .caption2: return "Caption 2"
        case .caption1: return "Caption 1"
        case .footnote: return "Footnote"
        case .subheadline: return "Subhead"
        case .callout: return "Callout"
        case .body: return "Body"
        case .headline: return "Headline"
        case .title3: return "Title 3"
        case .title2: return "Title 2"
        case .title1: return "Title 1"
        case .largeTitle: return "Large Title"
        default: return "Unknown"
        }
    }
}
