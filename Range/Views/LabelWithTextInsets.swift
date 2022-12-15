import Foundation
import UIKit

/// UILabel subclass that provides a text insets. It allows to render label view with a padding around text.
/// https://stackoverflow.com/a/21267507
class LabelWithTextInsets: UILabel {
    var textInsets = UIEdgeInsets.zero {
        didSet { invalidateIntrinsicContentSize() }
    }

    /// if configured it adds a border with given color and radius appropriate for the height
    var borderColor: UIColor? {
        didSet {
            updateBorderColor()
        }
    }

    override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int) -> CGRect {
        let insetRect = bounds.inset(by: textInsets)
        let textRect = super.textRect(forBounds: insetRect, limitedToNumberOfLines: numberOfLines)
        let invertedInsets = UIEdgeInsets(
            top: -textInsets.top,
            left: -textInsets.left,
            bottom: -textInsets.bottom,
            right: -textInsets.right
        )
        return textRect.inset(by: invertedInsets)
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: textInsets))
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateBorderColor()
        }
    }

    private func updateBorderColor() {
        if let borderColor = borderColor {
            layer.borderColor = borderColor.cgColor
            layer.borderWidth = 1
            clipsToBounds = true
        } else {
            layer.borderColor = nil
            clipsToBounds = false
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if borderColor != nil {
            layer.cornerRadius = frame.height / 2
        } else {
            layer.cornerRadius = 0
        }
    }
}
