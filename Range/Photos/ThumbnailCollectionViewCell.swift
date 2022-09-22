import FirebaseStorage
import Foundation
import RealmSwift
import UIKit

/// Collection view cell for displaying an image view.
class ThumbnailCollectionViewCell: UICollectionViewCell {
    let imageView = UIImageView(frame: .zero)

    /// listen to changes in upload and reload the image
    private var notificationToken: NotificationToken?

    /// required to notify collectionView once the image is loaded so it can invalidate the layout (to use the image aspect ratio)
    weak var collectionView: UICollectionView?
    weak var imageCaches: ImageCaches?
    weak var projectModel: ProjectModel?
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

    private func reloadImage() {
        if let upload = upload, let imageCaches = imageCaches {
            imageView.kf.indicatorType = .activity
            imageView.kf.cancelDownloadTask()
            imageView.kf.setImage(
                with: imageCaches.imageProvider(forUpload: upload, thumbnailNumber: 0),
                placeholder: nil, options: nil, progressBlock: nil, completionHandler: { _ in
                    // once the image is loaded update the Upload.imageHeight2Width if it's not there
                    // yet, so the cell can have a proper height.
                    if upload.imageHeightToWidth == nil,
                       let image = self.imageView.image,
                       let projectModel = self.projectModel
                    {
                        projectModel.mainRealm.writeAsync({
                            upload.imageHeightToWidth = image.size.height / image.size.width
                        }, onComplete: { _ in
                            self.collectionView?.collectionViewLayout.invalidateLayout()
                        })
                    }
                }
            )
        } else {
            imageView.image = nil
        }
    }

    override func prepareForReuse() {
        upload = nil
    }
}
