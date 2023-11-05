import Foundation
import UIKit

/// UITextView subclass that removes the padding around text (so text carret is rendered in the top/left = 0/0 position)
class UITextViewWithNoTextPadding: UITextView {
    override func layoutSubviews() {
        super.layoutSubviews()
        setup()
    }

    func setup() {
        textContainerInset = UIEdgeInsets.zero
        textContainer.lineFragmentPadding = 0
    }
}
