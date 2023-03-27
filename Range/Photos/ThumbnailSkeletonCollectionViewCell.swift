import FirebaseStorage
import Foundation
import RealmSwift
import UIKit

/// Collection view cell for displaying a skeleton cells in thumbnails collection.
/// The cell have no content, just indicates that there might be more thumbs
class ThumbnailSkeletonCollectionViewCell: UICollectionViewCell {
    override init(frame _: CGRect) {
        super.init(frame: .zero)

        contentView.layer.cornerRadius = 7
        contentView.backgroundColor = .dynamic(.Neutral_09)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
