import FirebaseStorage
import Foundation
import UIKit

/// Collection view cell for displaying an image view.
class ThumbnailCollectionViewCell: UICollectionViewCell {
    let imageView = UIImageView(frame: .zero)
    override init(frame _: CGRect) {
        super.init(frame: .zero)

        contentView.layer.cornerRadius = 7
        contentView.layer.borderWidth = 1

        contentView.addSubview(imageView)
        imageView.layer.cornerRadius = contentView.layer.cornerRadius
        imageView.clipsToBounds = true
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        imageView.image = nil
    }
}
