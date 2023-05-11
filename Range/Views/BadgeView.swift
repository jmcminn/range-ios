
import Foundation
import UIKit

/// View showing text in a colored circle. If text gets longer the circle is stretched horizontally
/// ACHTUNG: this view is very similar to StatusView. When we need a badge view with an icon it's worth adding the icon support here
/// and refactoring the StatusView to inherit from BadgeView
class BadgeView: UIView {
    // the label to display the badge text
    private let textLabel = LabelWithTextInsets()

    /// text color
    var textColor: UIColor = .Neutral_10 { didSet { textLabel.textColor = textColor }}

    /// text font
    var font: UIFont = .systemFont(ofSize: 11, weight: .bold) { didSet {
        textLabel.font = font
        updateIntrinsicContentSize()
    }}

    /// margins between the content (text and optional checkmark) and edges
    var contentInsets: UIEdgeInsets = .init(top: 2, left: 8, bottom: 2, right: 8) { didSet {
        textLabel.textInsets = contentInsets
        updateIntrinsicContentSize()
    }}

    var text: String = "" { didSet {
        textLabel.text = text
        updateIntrinsicContentSize()
    }}

    private var _intrinsicContentSize: CGSize? = .zero

    override var intrinsicContentSize: CGSize { _intrinsicContentSize ?? .zero }

    init() {
        super.init(frame: .zero)
        addSubview(textLabel)
        textLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Recalculates the view intrinsicContentSize
    private func updateIntrinsicContentSize() {
        textLabel.sizeToFit()
        var size = textLabel.frame.size
        if size.width < size.height {
            size.width = size.height
        }
        _intrinsicContentSize = size
        frame.size = size
        invalidateIntrinsicContentSize()
        setNeedsLayout()
        layoutIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = frame.height / 2
    }
}
