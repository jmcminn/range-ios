import Foundation
import Kingfisher
import UIKit

class MediaCollectionViewCell: UICollectionViewCell {
    let imageView = UIImageView(frame: .zero)
    let avatarView = AvatarView()

    override init(frame _: CGRect) {
        super.init(frame: .zero)

        contentView.layer.cornerRadius = 12

        contentView.addSubview(imageView)
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .dynamicColor(light: .Neutral_02, dark: .Neutral_09)
        imageView.layer.cornerRadius = contentView.layer.cornerRadius
        imageView.clipsToBounds = true
        imageView.kf.indicatorType = .custom(indicator: ImageLoadingIndicator())
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentView.addSubview(avatarView)
        avatarView.snp.makeConstraints { make in
            make.leading.bottom.equalToSuperview().inset(8)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        imageView.kf.cancelDownloadTask()
        imageView.image = nil
        avatarView.setUser(nil)
    }

    func setUpload(_ upload: Upload, imageDataProvider: RangeImageDataProvider) {
        imageView.kf.cancelDownloadTask()
        imageView.kf.setImage(with: imageDataProvider)
        avatarView.setUser(upload.author)
    }
}
