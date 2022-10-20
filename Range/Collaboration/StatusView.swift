import Foundation
import UIKit

/// A static (not responding to object changes) view showing the status label in a bubble with the status color
class StatusView: UIView {
    // the label to display the status name
    let textLabel = LabelWithTextInsets()

    private let _intrinsicContentSize: CGSize

    init(status: Status) {
        textLabel.textInsets = UIEdgeInsets(top: 2, left: 8, bottom: 2, right: 8)
        textLabel.text = status.name
        textLabel.textColor = UIColor.Neutral_01
        textLabel.font = ._preferredFont(forTextStyle: .footnote, symbolicTraits: .traitBold)
        textLabel.sizeToFit()

        _intrinsicContentSize = textLabel.frame.size

        super.init(frame: CGRect(origin: .zero, size: _intrinsicContentSize))

        backgroundColor = status.color
        addSubview(textLabel)
        textLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        setNeedsLayout()
        layoutIfNeeded()
    }

    override var intrinsicContentSize: CGSize { _intrinsicContentSize }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = frame.height / 2
    }
}
