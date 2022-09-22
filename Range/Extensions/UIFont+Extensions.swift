import Foundation
import UIKit

extension UIFont {
    /// Returns a dynamic font for given text style and symbolic traits (e.g. bold)
    /// Falls back to just dynamic font for given text style if cannot construct font with given symbolic traits
    static func _preferredFont(forTextStyle textStyle: TextStyle,
                               symbolicTraits: UIFontDescriptor.SymbolicTraits) -> UIFont
    {
        if let fontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: textStyle)
            .withSymbolicTraits(symbolicTraits)
        {
            return UIFont(descriptor: fontDescriptor, size: 0)
        }
        return UIFont.preferredFont(forTextStyle: textStyle)
    }
}
