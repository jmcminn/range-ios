import Foundation
import UIKit

/// For now this view shows user initials in a gray circle.
/// Later it'll support showing user avatar.
class AvatarView: UIView {
    private let label = UILabel()
    private var height: Double = 0

    init() {
        super.init(frame: .zero)

        backgroundColor = .Neutral_07

        label.textColor = .Neutral_01
        addSubview(label)
        label.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: height, height: height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = frame.height / 2
    }

    func setUser(_ user: Participant?) {
        // need to reset the font to use dynamic font
        label.font = ._preferredFont(forTextStyle: .caption2, symbolicTraits: .traitBold)
        if let user = user {
            label.text = user.initials
        } else {
            label.text = " "
        }
        label.sizeToFit()
        height = label.frame.height + 8 // make the circle bigger than the label
        invalidateIntrinsicContentSize()
        setNeedsLayout()
        layoutIfNeeded()
    }
}
