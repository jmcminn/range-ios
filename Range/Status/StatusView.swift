import Foundation
import UIKit

/// A static (not responding to object changes) view showing the status label in a bubble with the status color
/// It also optionally shows a checkmark when "selected" using `setStatus(:,selected:)`
class StatusView: UIView {
    // the label to display the status name
    private let textLabel = LabelWithTextInsets()

    var checkmark: UIImageView?

    /// text font
    var font: UIFont = ._preferredFont(forTextStyle: .footnote, symbolicTraits: .traitBold)
    /// margins between the content (text and optional checkmark) and edges
    var contentInsets: UIEdgeInsets = .init(top: 2, left: 8, bottom: 2, right: 8)

    private var _intrinsicContentSize: CGSize? = .zero

    override var intrinsicContentSize: CGSize { _intrinsicContentSize ?? .zero }

    init() {
        super.init(frame: .zero)
        textLabel.textColor = UIColor.Neutral_01
        addSubview(textLabel)
        textLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// If `count` is provided it displays it in the parentheses next to the status name
    func setStatus(_ status: Status, selected: Bool = false, count: Int? = nil) {
        backgroundColor = status.color

        textLabel.font = font
        textLabel.textInsets = contentInsets

        if selected {
            let imageConfig = UIImage.SymbolConfiguration(textStyle: .subheadline)
            let checkmark = UIImageView(image: UIImage(systemName: "checkmark", withConfiguration: imageConfig))
            checkmark.tintColor = .Neutral_01
            addSubview(checkmark)
            checkmark.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.trailing.equalToSuperview().inset(contentInsets.right)
            }
            let distanceBetweenTextAndCheckmark = 4.0
            textLabel.textInsets.right = distanceBetweenTextAndCheckmark
            textLabel.snp.remakeConstraints { make in
                make.centerY.equalToSuperview()
                make.trailing.equalTo(checkmark.snp.leading)
            }
            self.checkmark = checkmark
        } else {
            checkmark?.removeFromSuperview()
            checkmark = nil
            textLabel.snp.remakeConstraints { make in
                make.center.equalToSuperview()
            }
        }

        var text = status.name
        if let count = count {
            text += " (\(count))"
        }
        textLabel.text = text
        textLabel.sizeToFit()
        var statusSize = textLabel.frame.size
        if selected {
            statusSize.width += ((checkmark?.image?.size.width ?? 0.0) + contentInsets.right)
        }
        _intrinsicContentSize = statusSize
        frame.size = statusSize
        invalidateIntrinsicContentSize()
        setNeedsLayout()
        layoutIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = frame.height / 2
    }
}
