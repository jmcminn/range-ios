import Foundation
import UIKit

/// This view shows either user avatar or user initials if avatar image not available.
class AvatarView: UIView {
    let label = UILabel()
    let imageView = UIImageView()

    init() {
        super.init(frame: .zero)

        backgroundColor = .dynamic(.Neutral_07)
        clipsToBounds = true

        label.textColor = .dynamic(.Neutral_01)
        label.font = ._preferredFont(forTextStyle: .footnote, symbolicTraits: .traitBold)
        imageView.contentMode = .scaleAspectFill

        addSubview(label)
        label.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = frame.height / 2
    }

    func setAvatar(forParticipant participant: Participant?) {
        setAvatar(participant?.avatarImage, initials: participant?.initials)
    }

    func setAvatar(_ image: UIImage?, initials: String?) {
        if let image {
            imageView.isHidden = false
            label.isHidden = true
            imageView.image = image
        } else {
            imageView.isHidden = true
            label.isHidden = false
            label.text = initials
        }
    }
}
