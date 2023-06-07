import FirebaseStorage
import Foundation
import Kingfisher
import RealmSwift
import UIKit

/// Collection view cell for displaying an image view.
class ThumbnailCollectionViewCell: UICollectionViewCell {
    let imageView = UIImageView(frame: .zero)

    /// listen to changes in upload and reload the image
    private var notificationToken: NotificationToken?

    var imageDataProvider: RangeImageDataProvider?
    weak var upload: Upload? {
        didSet {
            reloadImage()
            if let upload = upload {
                // not observe again if already observing (also helps for the crash mentioned below)
                if let previousUpload = oldValue, previousUpload.id == upload.id {
                    return
                }
                // observed Realm crash discussed in this issue: https://github.com/realm/realm-swift/issues/4818
                // so Realm notifies about changes while in transaction... WTF? That really sounds
                // like a bad idea and can have some random consequences like registering this observation
                // as a side effect of Upload.imageHeight2Width update ... or basically any other
                // Upload update... This is a hacky workaround (the dispatch async).
                // If it happens again we may want to reconsider switching to CoreData (or SQLite, etc.)
                // from Realm...
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.notificationToken = upload.observe { [weak self] change in
                        if case .deleted = change {
                            self?.upload = nil
                        } else {
                            self?.reloadImage()
                        }
                    }
                }
            } else {
                notificationToken?.invalidate()
            }
        }
    }

    override init(frame _: CGRect) {
        super.init(frame: .zero)

        contentView.layer.cornerRadius = 7
        contentView.layer.borderWidth = 1

        contentView.addSubview(imageView)
        imageView.backgroundColor = .dynamic(.Neutral_09)
        imageView.layer.cornerRadius = contentView.layer.cornerRadius
        imageView.clipsToBounds = true
        imageView.kf.indicatorType = .custom(indicator: ImageLoadingIndicator())
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func reloadImage() {
        if let imageDataProvider = imageDataProvider {
            imageView.kf.cancelDownloadTask()
            imageView.kf.setImage(
                with: imageDataProvider,
                options: [.targetCache(imageDataProvider.cache), .cacheSerializer(imageDataProvider.cacheSerializer)]
            )
        } else {
            imageView.image = nil
        }
    }

    override func prepareForReuse() {
        upload = nil
        imageDataProvider = nil
    }
}
